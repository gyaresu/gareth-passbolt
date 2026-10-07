package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"sync"
	"sync/atomic"

	"github.com/passbolt/go-passbolt/api"
	"github.com/passbolt/go-passbolt/helper"
)

/*
Two things make a five-figure seed run take longer than it needs to.

First, the SDK refetches the whole resource-type list on every single create:
helper.CreateResourceGeneric calls findResourceTypeBySlug, which calls the
uncached GetResourceTypes. The client has a GetResourceTypesCached that the helper
does not use. That is one extra round trip per resource, and the response never
changes during a run, so resourceTypesCache serves it from memory after the first.

Second, the work is one resource at a time, each waiting on a round trip. Running
several in parallel is the larger win. It needs one api.Client per worker: the
client writes csrfToken without holding a lock (api.go sets it, auth.go clears it,
client.go reads it on every request), so sharing one across goroutines is a data
race. Each worker logging in separately costs a GPG operation at startup and
nothing after that.
*/

// resourceTypesPath is the endpoint whose response is cached for the run.
const resourceTypesPath = "/resource-types.json"

// resourceTypesCache serves a repeated GET of the resource-type list from memory.
// Scoped to one process and one seed run, so staleness is not a concern: the list
// cannot change while we are the only thing writing to the instance.
type resourceTypesCache struct {
	base http.RoundTripper

	mu     sync.Mutex
	body   []byte
	header http.Header
	status int
}

func (c *resourceTypesCache) RoundTrip(req *http.Request) (*http.Response, error) {
	if req.Method != http.MethodGet || req.URL.Path != resourceTypesPath {
		return c.base.RoundTrip(req)
	}

	c.mu.Lock()
	cached := c.body != nil
	body, header, status := c.body, c.header, c.status
	c.mu.Unlock()

	if cached {
		return newResponse(req, status, header, body), nil
	}

	resp, err := c.base.RoundTrip(req)
	if err != nil {
		return nil, err
	}
	raw, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		return nil, err
	}

	c.mu.Lock()
	// Another worker may have populated it first; either copy is equivalent.
	if c.body == nil {
		c.body, c.header, c.status = raw, resp.Header.Clone(), resp.StatusCode
	}
	c.mu.Unlock()

	return newResponse(req, resp.StatusCode, resp.Header, raw), nil
}

func newResponse(req *http.Request, status int, header http.Header, body []byte) *http.Response {
	return &http.Response{
		Status:        http.StatusText(status),
		StatusCode:    status,
		Header:        header.Clone(),
		Body:          io.NopCloser(bytes.NewReader(body)),
		ContentLength: int64(len(body)),
		Request:       req,
	}
}

// workerCount decides how many resources to create in parallel. One keeps the
// original behaviour for the small hand-authored sets, where parallelism would
// buy nothing. Larger sets default to four, which is well inside the stack's
// php-fpm worker budget. WORKERS overrides either way.
func workerCount(resources int) int {
	if n := envInt("WORKERS", 0); n > 0 {
		return n
	}
	if resources > 1000 {
		return 4
	}
	return 1
}

// seedCounts is the tally returned to the caller.
type seedCounts struct {
	created    atomic.Int64
	favourited atomic.Int64
	shared     atomic.Int64
}

// seedResources creates every resource in the set, using workers goroutines each
// with its own client. The first error cancels the rest and is returned.
func seedResources(
	ctx context.Context,
	specs []resourceSpec,
	newClient func(context.Context) (*api.Client, error),
	folderIDs map[string]string,
	groupIDs []string,
	usersByEmail map[string]string,
	workers int,
	progress func(done int),
) (created, favourited, shared int, err error) {
	jobs := make(chan resourceSpec)
	var counts seedCounts

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	var (
		wg       sync.WaitGroup
		errOnce  sync.Once
		firstErr error
	)
	fail := func(e error) {
		errOnce.Do(func() {
			firstErr = e
			cancel()
		})
	}

	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()

			client, err := newClient(ctx)
			if err != nil {
				fail(fmt.Errorf("worker login: %w", err))
				return
			}

			for spec := range jobs {
				if ctx.Err() != nil {
					return
				}
				fav, shr, err := seedOne(ctx, client, spec, folderIDs, groupIDs, usersByEmail)
				if err != nil {
					fail(err)
					return
				}
				done := counts.created.Add(1)
				if fav {
					counts.favourited.Add(1)
				}
				if shr {
					counts.shared.Add(1)
				}
				if progress != nil {
					progress(int(done))
				}
			}
		}()
	}

	for _, spec := range specs {
		select {
		case jobs <- spec:
		case <-ctx.Done():
		}
		if ctx.Err() != nil {
			break
		}
	}
	close(jobs)
	wg.Wait()

	return int(counts.created.Load()), int(counts.favourited.Load()), int(counts.shared.Load()), firstErr
}

// seedOne creates a single resource and applies its favourite and shares.
func seedOne(
	ctx context.Context,
	client *api.Client,
	r resourceSpec,
	folderIDs map[string]string,
	groupIDs []string,
	usersByEmail map[string]string,
) (favourited, shared bool, err error) {
	slug, metadata, secret := buildResource(r)

	id, err := helper.CreateResourceGeneric(ctx, client, slug, folderIDs[r.Folder], metadata, secret)
	if err != nil {
		return false, false, fmt.Errorf("creating resource %q: %w", r.Name, err)
	}

	if r.Favorite {
		if _, err := client.CreateFavorite(ctx, id); err != nil {
			return false, false, fmt.Errorf("favouriting %q: %w", r.Name, err)
		}
		favourited = true
	}

	var shareGroupIDs []string
	if r.Shared {
		shareGroupIDs = groupIDs
	}
	var shareUserIDs []string
	for _, email := range r.ShareUsers {
		if uid, ok := usersByEmail[email]; ok {
			shareUserIDs = append(shareUserIDs, uid)
		} else {
			fmt.Printf("warning: share user %q not found for %q\n", email, r.Name)
		}
	}
	if len(shareGroupIDs) > 0 || len(shareUserIDs) > 0 {
		if err := helper.ShareResourceWithUsersAndGroups(ctx, client, id, shareUserIDs, shareGroupIDs, permissionUpdate); err != nil {
			return favourited, false, fmt.Errorf("sharing resource %q: %w", r.Name, err)
		}
		shared = true
	}

	return favourited, shared, nil
}
