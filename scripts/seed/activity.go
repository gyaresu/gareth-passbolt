package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path"
	"sort"
	"strings"

	"github.com/passbolt/go-passbolt/api"
)

/*
A freshly seeded vault has one actor: the owner created everything in the same
minute. That undersells the activity sidebar and the action logs, which this stack
exists to demonstrate (see the SIEM audit logging section of the top-level README).

The activity pass logs in as every other user with a key in KEYS_DIR and reads a few
of the secrets shared with them, through the same API the apps use, so the logs show
several people touching shared entries. It only finds something to read once group
shares actually reach those users.
*/

// simulateActivity logs in as each non-owner user that has a key file and reads up
// to ACTIVITY_READS (default 3) secrets shared with them. A user who cannot log in,
// for example one who has not completed setup, is warned about and skipped.
func simulateActivity(ctx context.Context, httpClient *http.Client, baseURL, keysDir, owner string) error {
	emails, err := keyEmails(keysDir, owner)
	if err != nil {
		return err
	}
	reads := envInt("ACTIVITY_READS", 3)

	for _, email := range emails {
		n, err := readSharedSecrets(ctx, httpClient, baseURL, keysDir, email, reads)
		if err != nil {
			fmt.Printf("warning: activity as %s: %v\n", email, err)
			continue
		}
		fmt.Printf("Activity: %s read %d shared secret(s)\n", email, n)
	}
	return nil
}

// keyEmails lists the users with a private key in keysDir, the owner excluded,
// sorted so runs are repeatable.
func keyEmails(keysDir, owner string) ([]string, error) {
	entries, err := os.ReadDir(keysDir)
	if err != nil {
		return nil, fmt.Errorf("reading keys dir %s: %w", keysDir, err)
	}
	var emails []string
	for _, e := range entries {
		email, ok := strings.CutSuffix(e.Name(), ".key")
		if !ok || e.IsDir() || email == owner {
			continue
		}
		emails = append(emails, email)
	}
	sort.Strings(emails)
	return emails, nil
}

// readSharedSecrets logs in as email (passphrase is the email, as for every demo
// key) and fetches up to limit secrets of resources shared with them.
func readSharedSecrets(ctx context.Context, httpClient *http.Client, baseURL, keysDir, email string, limit int) (int, error) {
	key, err := os.ReadFile(path.Join(keysDir, email+".key"))
	if err != nil {
		return 0, err
	}
	c, err := api.NewClient(httpClient, "demo-seeder", baseURL, string(key), email)
	if err != nil {
		return 0, fmt.Errorf("creating client: %w", err)
	}
	if err := c.Login(ctx); err != nil {
		return 0, fmt.Errorf("login: %w", err)
	}
	defer c.Logout(ctx)

	resources, err := c.GetResources(ctx, &api.GetResourcesOptions{FilterIsSharedWithMe: true})
	if err != nil {
		return 0, fmt.Errorf("listing shared resources: %w", err)
	}
	n := 0
	for _, r := range resources {
		if n == limit {
			break
		}
		if _, err := c.GetSecret(ctx, r.ID); err != nil {
			return n, fmt.Errorf("reading secret %s: %w", r.ID, err)
		}
		n++
	}
	return n, nil
}
