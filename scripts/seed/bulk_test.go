package main

import (
	"encoding/json"
	"testing"
	"time"
)

// The bulk set is generated, so there is no file to eyeball when it goes wrong.
// These guard the three properties the perf runs depend on: the count is honoured,
// names are unique (duplicates would make a vault that cannot be reasoned about),
// and two runs produce the same vault so timings are comparable.
func TestGenerateBulk(t *testing.T) {
	for _, n := range []int{1, 10000} {
		data := generateBulk(n)

		if len(data.Resources) != n {
			t.Fatalf("COUNT=%d: got %d resources", n, len(data.Resources))
		}
		if data.Owner == "" {
			t.Fatalf("COUNT=%d: no owner set", n)
		}
		if len(data.Folders) == 0 {
			t.Fatalf("COUNT=%d: no folders generated", n)
		}

		seen := make(map[string]bool, n)
		for _, r := range data.Resources {
			if r.Name == "" || r.Username == "" || r.Folder == "" || r.Description == "" {
				t.Fatalf("COUNT=%d: incomplete resource %+v", n, r)
			}
			if seen[r.Name] {
				t.Fatalf("COUNT=%d: duplicate resource name %q", n, r.Name)
			}
			seen[r.Name] = true
		}
	}
}

// Every leaf folder the set declares must actually receive resources. Deriving
// system and environment from i independently silently stranded 100 of the 120
// folders, because len(bulkEnvs) divides len(bulkSystems).
func TestGenerateBulkFillsEveryLeafFolder(t *testing.T) {
	leaves := len(bulkSystems) * len(bulkEnvs)

	for _, n := range []int{leaves, 10000} {
		data := generateBulk(n)

		used := make(map[string]int, leaves)
		for _, r := range data.Resources {
			used[r.Folder]++
		}
		if len(used) != leaves {
			t.Fatalf("COUNT=%d: resources landed in %d of %d leaf folders", n, len(used), leaves)
		}

		for _, s := range bulkSystems {
			for _, e := range bulkEnvs {
				if path := s + "/" + e; used[path] == 0 {
					t.Errorf("COUNT=%d: folder %q is empty", n, path)
				}
			}
		}
	}
}

func TestGenerateBulkIsDeterministic(t *testing.T) {
	first, err := json.Marshal(generateBulk(500))
	if err != nil {
		t.Fatal(err)
	}
	second, err := json.Marshal(generateBulk(500))
	if err != nil {
		t.Fatal(err)
	}
	if string(first) != string(second) {
		t.Fatal("generateBulk produced different data on two runs; timings would not be comparable")
	}
}

func TestGenerateBulkSharingIsOffByDefault(t *testing.T) {
	data := generateBulk(100)
	if len(data.ShareGroups) != 0 {
		t.Fatalf("expected no share groups by default, got %v", data.ShareGroups)
	}
	for _, r := range data.Resources {
		if r.Shared {
			t.Fatalf("expected nothing shared by default, but %q is", r.Name)
		}
	}
}

func TestGenerateBulkSharePercentage(t *testing.T) {
	t.Setenv("BULK_SHARE_PCT", "25")
	data := generateBulk(1000)

	if len(data.ShareGroups) == 0 {
		t.Fatal("sharing enabled but no share groups set")
	}
	shared := 0
	for _, r := range data.Resources {
		if r.Shared {
			shared++
		}
	}
	if shared != 250 {
		t.Fatalf("expected 250 of 1000 shared at 25%%, got %d", shared)
	}
}

func TestGenerateBulkShareGroupsOverride(t *testing.T) {
	t.Setenv("BULK_SHARE_PCT", "10")
	t.Setenv("BULK_SHARE_GROUPS", " alpha , ,beta ")
	data := generateBulk(10)

	want := []string{"alpha", "beta"}
	if len(data.ShareGroups) != len(want) {
		t.Fatalf("expected %v, got %v", want, data.ShareGroups)
	}
	for i := range want {
		if data.ShareGroups[i] != want[i] {
			t.Fatalf("expected %v, got %v", want, data.ShareGroups)
		}
	}
}

func TestRunDeadlineScalesWithWork(t *testing.T) {
	small := runDeadline(generateBulk(48))
	large := runDeadline(generateBulk(12000))
	if large <= small {
		t.Fatalf("deadline should grow with the set: 48 got %s, 12000 got %s", small, large)
	}
	// The run that prompted this died at ~7000 of 12000 on a flat ten minutes.
	if large < time.Hour {
		t.Fatalf("12000 resources should allow well over an hour, got %s", large)
	}
}

func TestRunDeadlineHonoursOverride(t *testing.T) {
	t.Setenv("TIMEOUT_MINUTES", "5")
	if got := runDeadline(generateBulk(12000)); got != 5*time.Minute {
		t.Fatalf("expected the override to win, got %s", got)
	}
}

func TestEnvIntFallsBackOnJunk(t *testing.T) {
	t.Setenv("COUNT", "not-a-number")
	if got := envInt("COUNT", 10000); got != 10000 {
		t.Fatalf("expected fallback 10000, got %d", got)
	}
	t.Setenv("COUNT", "-5")
	if got := envInt("COUNT", 10000); got != 10000 {
		t.Fatalf("expected fallback for negative value, got %d", got)
	}
	t.Setenv("COUNT", "250")
	if got := envInt("COUNT", 10000); got != 250 {
		t.Fatalf("expected 250, got %d", got)
	}
}
