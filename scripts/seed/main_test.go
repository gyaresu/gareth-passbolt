package main

import (
	"os"
	"path"
	"slices"
	"strings"
	"testing"
	"time"
)

// Every embedded set must load and pass validateSet, so a typo in a hand-edited
// set fails here rather than partway through a demo seed.
func TestEmbeddedSetsValidate(t *testing.T) {
	for _, name := range availableDatasets() {
		if name == bulkDatasetName {
			continue
		}
		t.Setenv("DATASET", name)
		data, _, err := loadDataset()
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if err := validateSet(data); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
	}
}

func TestPermissionLevel(t *testing.T) {
	cases := map[string]int{"": 7, "update": 7, "read": 1, "owner": 15}
	for name, want := range cases {
		got, err := permissionLevel(name)
		if err != nil || got != want {
			t.Fatalf("permissionLevel(%q) = %d, %v; want %d", name, got, err, want)
		}
	}
	if _, err := permissionLevel("Read"); err == nil {
		t.Fatal("permissionLevel accepted a name that is not lower case")
	}
}

// A bad permission must be caught before anything is created, not on the first
// share call after the folders already exist.
func TestValidateSetRejectsUnknownPermission(t *testing.T) {
	data := seedData{Resources: []resourceSpec{{Name: "x", Permission: "admin"}}}
	if err := validateSet(data); err == nil || !strings.Contains(err.Error(), `"x"`) {
		t.Fatalf("want an error naming the resource, got %v", err)
	}
	data = seedData{Folders: []folderSpec{{Path: "a/b", Permission: "write"}}}
	if err := validateSet(data); err == nil || !strings.Contains(err.Error(), `"a/b"`) {
		t.Fatalf("want an error naming the folder, got %v", err)
	}
}

func TestExpiryFromOffset(t *testing.T) {
	now := time.Date(2026, 11, 18, 10, 30, 15, 500, time.UTC)
	if got := expiryFromOffset(now, -30); !got.Equal(time.Date(2026, 10, 19, 10, 30, 15, 0, time.UTC)) {
		t.Fatalf("-30 days: got %s", got)
	}
	if got := expiryFromOffset(now, 7); !got.Equal(time.Date(2026, 11, 25, 10, 30, 15, 0, time.UTC)) {
		t.Fatalf("+7 days: got %s", got)
	}
}

// The keys directory also holds .pub files and recovery-kit .txt files; only
// private keys count, and the owner is left out because they already acted.
func TestKeyEmails(t *testing.T) {
	dir := t.TempDir()
	for _, f := range []string{
		"ada@passbolt.com.key", "ada@passbolt.com.pub",
		"carol@passbolt.com.key", "betty@passbolt.com.key", "betty@passbolt.com.pub",
		"organization-recovery-private-key_2025-11-11.txt",
	} {
		if err := os.WriteFile(path.Join(dir, f), nil, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	got, err := keyEmails(dir, "ada@passbolt.com")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"betty@passbolt.com", "carol@passbolt.com"}
	if !slices.Equal(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}
