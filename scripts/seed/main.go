// Command seed populates the demo Passbolt instance with a tidy, good-looking
// set of dummy data (folders, logins, TOTPs, favourites, icons + colours) so
// the stack is ready for screenshots and videos without hand-entering anything.
//
// It talks to the Passbolt API the same way the apps do: it logs in with a
// user's private key, encrypts every secret and (v5) metadata client-side, and
// creates resources through the public API. Nothing is written to the database
// directly, so it stays correct across schema changes.
//
// The catalogue of what to create lives in data.json (edit that to change the
// look). Passwords and TOTP seeds are generated at run time and are throwaway.
//
// Configuration (env, all have sensible defaults for this stack):
//
//	PASSBOLT_URL   Base URL of the instance        (default https://passbolt.local)
//	KEYS_DIR       Dir holding <email>.key files   (default /keys)
//	CA_CERT        PEM CA to trust for TLS          (default /ca/ca.crt)
//	PASSPHRASE     Owner key passphrase            (default: the owner's email)
package main

import (
	"context"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"embed"
	"encoding/base32"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"path"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/passbolt/go-passbolt/api"
	"github.com/passbolt/go-passbolt/helper"
)

//go:embed datasets/*.json
var datasetsFS embed.FS

// permissionUpdate is Passbolt's "can update" permission level (1 read, 7 update, 15 owner).
const permissionUpdate = 7

type folderSpec struct {
	Path   string `json:"path"`
	Shared bool   `json:"shared"`
}

type customFieldSpec struct {
	Name  string `json:"name"`
	Value string `json:"value"`
	Type  string `json:"type"` // text (default), password, uri, number, boolean
}

type resourceSpec struct {
	Name     string   `json:"name"`
	Username string   `json:"username"`
	URI      string   `json:"uri"`  // single URI (back-compat)
	URIs     []string `json:"uris"` // multiple URIs (takes precedence over uri)
	Folder   string   `json:"folder"`
	// Type is the resource-type slug. Empty = v5-default, or v5-default-with-totp
	// when totp is set. Also accepts v5-note, v5-totp-standalone, v5-password-string.
	Type         string            `json:"type"`
	Description  string            `json:"description"`
	Icon         int               `json:"icon"`
	Color        string            `json:"color"`
	Totp         bool              `json:"totp"`
	Favorite     bool              `json:"favorite"`
	Shared       bool              `json:"shared"`
	ShareUsers   []string          `json:"shareUsers"` // emails to share with directly
	CustomFields []customFieldSpec `json:"customFields"`
}

type seedData struct {
	Owner       string         `json:"owner"`
	ShareGroups []string       `json:"shareGroups"`
	Folders     []folderSpec   `json:"folders"`
	Resources   []resourceSpec `json:"resources"`
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// loadDataset loads the set to seed: an external file if DATASET_FILE is set
// (for a generated set mounted in), otherwise the embedded set named by DATASET
// (default "software"). Returns the parsed data and a label for logging.
func loadDataset() (seedData, string, error) {
	var data seedData
	if file := os.Getenv("DATASET_FILE"); file != "" {
		b, err := os.ReadFile(file)
		if err != nil {
			return data, "", fmt.Errorf("reading DATASET_FILE %q: %w", file, err)
		}
		if err := json.Unmarshal(b, &data); err != nil {
			return data, "", fmt.Errorf("parsing %q: %w", file, err)
		}
		return data, file, nil
	}

	name := env("DATASET", "software")
	if name == bulkDatasetName {
		count := envInt("COUNT", 10000)
		return generateBulk(count), fmt.Sprintf("%s (%d resources)", name, count), nil
	}

	b, err := datasetsFS.ReadFile("datasets/" + name + ".json")
	if err != nil {
		return data, "", fmt.Errorf("unknown dataset %q; available: %s", name, strings.Join(availableDatasets(), ", "))
	}
	if err := json.Unmarshal(b, &data); err != nil {
		return data, "", fmt.Errorf("parsing dataset %q: %w", name, err)
	}
	return data, name, nil
}

// availableDatasets lists the set names that DATASET accepts: the embedded files
// (without .json), plus the generated "bulk" set, which has no file behind it.
func availableDatasets() []string {
	entries, err := datasetsFS.ReadDir("datasets")
	if err != nil {
		return []string{bulkDatasetName}
	}
	names := make([]string, 0, len(entries)+1)
	for _, e := range entries {
		names = append(names, strings.TrimSuffix(e.Name(), ".json"))
	}
	return append(names, bulkDatasetName)
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "seed: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	data, setName, err := loadDataset()
	if err != nil {
		return err
	}
	fmt.Printf("Dataset: %s\n", setName)

	baseURL := env("PASSBOLT_URL", "https://passbolt.local")
	keysDir := env("KEYS_DIR", "/keys")
	caCert := env("CA_CERT", "/ca/ca.crt")
	passphrase := env("PASSPHRASE", data.Owner)

	privKey, err := os.ReadFile(path.Join(keysDir, data.Owner+".key"))
	if err != nil {
		return fmt.Errorf("reading owner key for %s: %w", data.Owner, err)
	}

	httpClient, err := httpClientTrusting(caCert)
	if err != nil {
		return err
	}

	deadline := runDeadline(data)
	if len(data.Resources) > 1000 {
		fmt.Printf("Large set: %d resources, allowing up to %s\n", len(data.Resources), deadline.Round(time.Minute))
	}
	ctx, cancel := context.WithTimeout(context.Background(), deadline)
	defer cancel()

	// Workers each need their own client: the SDK client writes csrfToken without a
	// lock, so one shared across goroutines is a data race.
	newLoggedInClient := func(ctx context.Context) (*api.Client, error) {
		c, err := api.NewClient(httpClient, "demo-seeder", baseURL, string(privKey), passphrase)
		if err != nil {
			return nil, fmt.Errorf("creating client: %w", err)
		}
		if err := c.Login(ctx); err != nil {
			return nil, fmt.Errorf("login as %s: %w", data.Owner, err)
		}
		return c, nil
	}

	client, err := api.NewClient(httpClient, "demo-seeder", baseURL, string(privKey), passphrase)
	if err != nil {
		return fmt.Errorf("creating client: %w", err)
	}
	if err := client.Login(ctx); err != nil {
		return fmt.Errorf("login as %s: %w", data.Owner, err)
	}
	defer client.Logout(ctx)
	fmt.Printf("Logged in as %s at %s\n", data.Owner, baseURL)

	// Clean-only: delete the data and stop, without seeding. No v5 needed to delete.
	if wantClean() {
		return resetAll(ctx, client)
	}

	// Fail before creating anything if v5 is off: icons/colours are v5 metadata
	// and the resources are v5, so without it nothing useful would be created.
	if !client.MetadataTypeSettings().AllowCreationOfV5Resources {
		return fmt.Errorf("v5 resource creation is disabled on this instance; enable encrypted metadata in Administration first")
	}

	if wantReset() {
		if err := resetAll(ctx, client); err != nil {
			return err
		}
	}

	groupIDs, err := resolveGroups(ctx, client, data.ShareGroups)
	if err != nil {
		return err
	}
	usersByEmail, err := resolveUsers(ctx, client)
	if err != nil {
		return err
	}

	// Create folders parents-first (data.json is ordered that way) and share
	// the shared ones with the groups.
	folderIDs := map[string]string{}
	for _, f := range data.Folders {
		parentPath, name := splitPath(f.Path)
		parentID := folderIDs[parentPath] // "" at the root
		id, err := helper.CreateFolder(ctx, client, parentID, name)
		if err != nil {
			return fmt.Errorf("creating folder %q: %w", f.Path, err)
		}
		folderIDs[f.Path] = id
		if f.Shared && len(groupIDs) > 0 {
			if err := helper.ShareFolderWithUsersAndGroups(ctx, client, id, nil, groupIDs, permissionUpdate); err != nil {
				return fmt.Errorf("sharing folder %q: %w", f.Path, err)
			}
		}
	}
	fmt.Printf("Created %d folders\n", len(data.Folders))

	workers := workerCount(len(data.Resources))
	if workers > 1 {
		fmt.Printf("Creating %d resources across %d workers\n", len(data.Resources), workers)
	}

	started := time.Now()
	total := len(data.Resources)
	// Large sets run for a long time with nothing to show for it, so report
	// progress and a running rate rather than appearing hung.
	progress := func(done int) {
		if done == 0 || done%500 != 0 {
			return
		}
		elapsed := time.Since(started)
		rate := float64(done) / elapsed.Seconds()
		remaining := time.Duration(float64(total-done)/rate) * time.Second
		fmt.Printf("  %d/%d resources (%.0f/s, about %s left)\n",
			done, total, rate, remaining.Round(time.Second))
	}

	created, favourited, shared, err := seedResources(
		ctx, data.Resources, newLoggedInClient, folderIDs, groupIDs, usersByEmail, workers, progress)
	if err != nil {
		return err
	}

	fmt.Printf("Done: %d resources (%d favourites, %d shared) in %s\n",
		created, favourited, shared, time.Since(started).Round(time.Second))
	return nil
}

// buildResource constructs the resource-type slug plus the metadata and secret
// maps for one entry, shaped to that type's schema. Fields that a given type's
// schema does not define are left out so metadata validation passes.
func buildResource(r resourceSpec) (string, map[string]any, map[string]any) {
	slug := r.Type
	if slug == "" {
		if r.Totp {
			slug = "v5-default-with-totp"
		} else {
			slug = "v5-default"
		}
	}

	metadata := map[string]any{
		"name": r.Name,
		"icon": map[string]any{
			"type":             "keepass-icon-set",
			"value":            r.Icon,
			"background_color": r.Color,
		},
	}
	secret := map[string]any{}

	uris := r.URIs
	if len(uris) == 0 && r.URI != "" {
		uris = []string{r.URI}
	}

	switch slug {
	case "v5-note":
		// A secure note keeps its body in the (encrypted) secret, not metadata.
		if r.Description != "" {
			secret["description"] = r.Description
		}
	case "v5-totp-standalone":
		secret["totp"] = totpSecret()
	default: // v5-default, v5-default-with-totp
		metadata["username"] = r.Username
		if len(uris) > 0 {
			metadata["uris"] = uris
		}
		if r.Description != "" {
			metadata["description"] = r.Description // routed into the secret by the SDK
		}
		secret["password"] = generatePassword(20)
		if slug == "v5-default-with-totp" || r.Totp {
			secret["totp"] = totpSecret()
		}
	}

	// Custom fields: the name lives in the metadata half, the value in the secret
	// half, joined by a shared uuid (as the web extension does).
	if len(r.CustomFields) > 0 {
		var metaCF, secretCF []map[string]any
		for _, cf := range r.CustomFields {
			t := cf.Type
			if t == "" {
				t = "text"
			}
			id := uuid.NewString()
			metaCF = append(metaCF, map[string]any{"id": id, "type": t, "metadata_key": cf.Name})
			secretCF = append(secretCF, map[string]any{"id": id, "type": t, "secret_value": cf.Value})
		}
		metadata["custom_fields"] = metaCF
		secret["custom_fields"] = secretCF
	}

	return slug, metadata, secret
}

func totpSecret() map[string]any {
	return map[string]any{
		"secret_key": generateTotpSecret(),
		"period":     30,
		"digits":     6,
		"algorithm":  "SHA1",
	}
}

// resolveUsers maps user email (username) to user ID, for direct resource shares.
func resolveUsers(ctx context.Context, client *api.Client) (map[string]string, error) {
	users, err := client.GetUsers(ctx, &api.GetUsersOptions{})
	if err != nil {
		return nil, fmt.Errorf("listing users: %w", err)
	}
	m := make(map[string]string, len(users))
	for _, u := range users {
		m[u.Username] = u.ID
	}
	return m, nil
}

// wantReset reports whether a clean-out was requested, via RESET=1 (env, handy
// for the compose service) or a --reset argument (handy for the binary).
func wantReset() bool {
	switch os.Getenv("RESET") {
	case "1", "true", "yes":
		return true
	}
	for _, a := range os.Args[1:] {
		if a == "--reset" || a == "reset" {
			return true
		}
	}
	return false
}

// wantClean reports whether a delete-only run was requested, via CLEAN=1 (env)
// or a --clean argument. Unlike reset, this removes the data and stops.
func wantClean() bool {
	switch os.Getenv("CLEAN") {
	case "1", "true", "yes":
		return true
	}
	for _, a := range os.Args[1:] {
		if a == "--clean" || a == "clean" {
			return true
		}
	}
	return false
}

// resetAll deletes every resource and folder the logged-in admin can remove, so
// the dummy data can be laid down fresh. Users, groups and keys are untouched.
// Deleting a folder orphans any survivors up to its parent rather than cascading,
// so order does not matter: each folder is removed as it is reached.
func resetAll(ctx context.Context, client *api.Client) error {
	resources, err := client.GetResources(ctx, &api.GetResourcesOptions{})
	if err != nil {
		return fmt.Errorf("listing resources: %w", err)
	}
	delR, skipR := 0, 0
	for _, r := range resources {
		if err := client.DeleteResource(ctx, r.ID); err != nil {
			skipR++ // e.g. a resource the admin does not own; leave it be
			continue
		}
		delR++
	}

	folders, err := client.GetFolders(ctx, &api.GetFoldersOptions{})
	if err != nil {
		return fmt.Errorf("listing folders: %w", err)
	}
	delF, skipF := 0, 0
	for _, f := range folders {
		if err := client.DeleteFolder(ctx, f.ID); err != nil {
			skipF++
			continue
		}
		delF++
	}

	fmt.Printf("Reset: removed %d resources, %d folders", delR, delF)
	if skipR+skipF > 0 {
		fmt.Printf(" (left %d resources, %d folders the admin could not delete)", skipR, skipF)
	}
	fmt.Println()
	return nil
}

// httpClientTrusting returns an HTTP client that trusts the given PEM CA, so the
// stack's self-signed certificate validates.
func httpClientTrusting(caPath string) (*http.Client, error) {
	ca, err := os.ReadFile(caPath)
	if err != nil {
		return nil, fmt.Errorf("reading CA cert %s: %w", caPath, err)
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(ca) {
		return nil, fmt.Errorf("no certificates found in %s", caPath)
	}
	// Shared by every worker. The transport pools connections, and the wrapper
	// collapses the per-create resource-type refetch into one request for the run.
	transport := &http.Transport{
		TLSClientConfig:     &tls.Config{RootCAs: pool},
		MaxIdleConnsPerHost: 32,
	}
	return &http.Client{
		Timeout:   60 * time.Second,
		Transport: &resourceTypesCache{base: transport},
	}, nil
}

// resolveGroups maps group names to their IDs, which the share calls require.
func resolveGroups(ctx context.Context, client *api.Client, names []string) ([]string, error) {
	if len(names) == 0 {
		return nil, nil
	}
	groups, err := client.GetGroups(ctx, &api.GetGroupsOptions{})
	if err != nil {
		return nil, fmt.Errorf("listing groups: %w", err)
	}
	byName := map[string]string{}
	for _, g := range groups {
		byName[g.Name] = g.ID
	}
	ids := make([]string, 0, len(names))
	for _, name := range names {
		id, ok := byName[name]
		if !ok {
			fmt.Printf("warning: group %q not found, skipping share to it\n", name)
			continue
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// splitPath splits "Clients/Gibson/DevOps" into ("Clients/Gibson", "DevOps").
func splitPath(p string) (parent, name string) {
	for i := len(p) - 1; i >= 0; i-- {
		if p[i] == '/' {
			return p[:i], p[i+1:]
		}
	}
	return "", p
}

const passwordAlphabet = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*-_=+?"

// generatePassword returns a strong, throwaway demo password.
func generatePassword(n int) string {
	out := make([]byte, n)
	for i := range out {
		k, _ := rand.Int(rand.Reader, big.NewInt(int64(len(passwordAlphabet))))
		out[i] = passwordAlphabet[k.Int64()]
	}
	return string(out)
}

// generateTotpSecret returns a valid base32 (A-Z2-7) TOTP seed.
func generateTotpSecret() string {
	b := make([]byte, 20)
	_, _ = rand.Read(b)
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b)
}
