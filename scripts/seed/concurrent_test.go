package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
)

// countingTransport records how many requests actually reach the network.
type countingTransport struct {
	calls atomic.Int64
	body  string
}

func (t *countingTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	t.calls.Add(1)
	rec := httptest.NewRecorder()
	rec.Header().Set("Content-Type", "application/json")
	rec.WriteString(t.body)
	resp := rec.Result()
	resp.Request = req
	return resp, nil
}

func get(t *testing.T, rt http.RoundTripper, path string) string {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, "https://passbolt.local"+path, nil)
	if err != nil {
		t.Fatal(err)
	}
	resp, err := rt.RoundTrip(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return string(body)
}

// The create helper refetches the resource-type list for every resource, so on a
// 10k run this is the difference between one request and ten thousand.
func TestResourceTypesAreFetchedOnce(t *testing.T) {
	base := &countingTransport{body: `[{"slug":"v5-default"}]`}
	cache := &resourceTypesCache{base: base}

	for range 50 {
		if got := get(t, cache, resourceTypesPath); !strings.Contains(got, "v5-default") {
			t.Fatalf("cached body came back wrong: %q", got)
		}
	}

	if n := base.calls.Load(); n != 1 {
		t.Fatalf("expected 1 upstream request, got %d", n)
	}
}

func TestOnlyResourceTypesIsCached(t *testing.T) {
	base := &countingTransport{body: `{}`}
	cache := &resourceTypesCache{base: base}

	for range 5 {
		get(t, cache, "/resources.json")
	}

	if n := base.calls.Load(); n != 5 {
		t.Fatalf("other endpoints must not be cached; expected 5 upstream requests, got %d", n)
	}
}

// Workers share one transport, so the cache is hit concurrently. Run with -race.
func TestResourceTypesCacheIsConcurrencySafe(t *testing.T) {
	base := &countingTransport{body: `[{"slug":"v5-default"}]`}
	cache := &resourceTypesCache{base: base}

	var wg sync.WaitGroup
	for range 16 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range 20 {
				req, _ := http.NewRequest(http.MethodGet, "https://passbolt.local"+resourceTypesPath, nil)
				resp, err := cache.RoundTrip(req)
				if err != nil {
					t.Error(err)
					return
				}
				io.Copy(io.Discard, resp.Body)
				resp.Body.Close()
			}
		}()
	}
	wg.Wait()

	// A couple of workers can race to populate it before the first response lands,
	// but it must not keep going back to the network.
	if n := base.calls.Load(); n > 4 {
		t.Fatalf("expected the cache to collapse the requests, got %d upstream", n)
	}
}

func TestWorkerCount(t *testing.T) {
	if got := workerCount(48); got != 1 {
		t.Fatalf("small sets should stay sequential, got %d", got)
	}
	if got := workerCount(12000); got != 4 {
		t.Fatalf("large sets should parallelise, got %d", got)
	}

	t.Setenv("WORKERS", "8")
	if got := workerCount(48); got != 8 {
		t.Fatalf("WORKERS should override, got %d", got)
	}

	t.Setenv("WORKERS", "junk")
	if got := workerCount(12000); got != 4 {
		t.Fatalf("junk WORKERS should fall back, got %d", got)
	}
}
