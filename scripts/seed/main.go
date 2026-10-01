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
	_ "embed"
	"encoding/base32"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"path"
	"time"

	"github.com/passbolt/go-passbolt/api"
	"github.com/passbolt/go-passbolt/helper"
)

//go:embed data.json
var dataJSON []byte

// permissionUpdate is Passbolt's "can update" permission level (1 read, 7 update, 15 owner).
const permissionUpdate = 7

type folderSpec struct {
	Path   string `json:"path"`
	Shared bool   `json:"shared"`
}

type resourceSpec struct {
	Name        string `json:"name"`
	Username    string `json:"username"`
	URI         string `json:"uri"`
	Folder      string `json:"folder"`
	Description string `json:"description"`
	Icon        int    `json:"icon"`
	Color       string `json:"color"`
	Totp        bool   `json:"totp"`
	Favorite    bool   `json:"favorite"`
	Shared      bool   `json:"shared"`
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

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "seed: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	var data seedData
	if err := json.Unmarshal(dataJSON, &data); err != nil {
		return fmt.Errorf("parsing data.json: %w", err)
	}

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

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	client, err := api.NewClient(httpClient, "demo-seeder", baseURL, string(privKey), passphrase)
	if err != nil {
		return fmt.Errorf("creating client: %w", err)
	}
	if err := client.Login(ctx); err != nil {
		return fmt.Errorf("login as %s: %w", data.Owner, err)
	}
	defer client.Logout(ctx)
	fmt.Printf("Logged in as %s at %s\n", data.Owner, baseURL)

	// Fail before creating anything if v5 is off: icons/colours are v5 metadata
	// and the resources are v5, so without it nothing useful would be created.
	if !client.MetadataTypeSettings().AllowCreationOfV5Resources {
		return fmt.Errorf("v5 resource creation is disabled on this instance; enable encrypted metadata in Administration first")
	}

	groupIDs, err := resolveGroups(ctx, client, data.ShareGroups)
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

	created, favourited, shared := 0, 0, 0
	for _, r := range data.Resources {
		slug := "v5-default"
		secret := map[string]any{"password": generatePassword(20)}
		if r.Totp {
			slug = "v5-default-with-totp"
			secret["totp"] = map[string]any{
				"secret_key": generateTotpSecret(),
				"period":     30,
				"digits":     6,
				"algorithm":  "SHA1",
			}
		}
		metadata := map[string]any{
			"name":        r.Name,
			"username":    r.Username,
			"description": r.Description, // routed into the encrypted secret by the SDK
			"icon": map[string]any{
				"type":             "keepass-icon-set",
				"value":            r.Icon,
				"background_color": r.Color,
			},
		}
		if r.URI != "" {
			metadata["uris"] = []string{r.URI}
		}

		id, err := helper.CreateResourceGeneric(ctx, client, slug, folderIDs[r.Folder], metadata, secret)
		if err != nil {
			return fmt.Errorf("creating resource %q: %w", r.Name, err)
		}
		created++

		if r.Favorite {
			if _, err := client.CreateFavorite(ctx, id); err != nil {
				return fmt.Errorf("favouriting %q: %w", r.Name, err)
			}
			favourited++
		}
		if r.Shared && len(groupIDs) > 0 {
			if err := helper.ShareResourceWithUsersAndGroups(ctx, client, id, nil, groupIDs, permissionUpdate); err != nil {
				return fmt.Errorf("sharing resource %q: %w", r.Name, err)
			}
			shared++
		}
	}

	fmt.Printf("Done: %d resources (%d favourites, %d shared to groups)\n", created, favourited, shared)
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
	return &http.Client{
		Timeout:   60 * time.Second,
		Transport: &http.Transport{TLSClientConfig: &tls.Config{RootCAs: pool}},
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
