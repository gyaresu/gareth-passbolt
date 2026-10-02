# Demo data seeder

Populates the running stack with a tidy, good-looking vault for screenshots and
videos: folders, logins, TOTPs, favourites, and per-resource icons and
background colours. One command, no hand entry.

It talks to the Passbolt API exactly as the apps do. It logs in as a user with
their private key, encrypts every secret and the v5 metadata (which is where the
icon and colour live) on the client, and creates resources through the public
API. Nothing is written to the database directly, so it stays correct across
schema changes.

## Prerequisites

1. The stack is up (`./scripts/setup.sh`) and the demo users exist. Keys are read
   from `keys/gpg/<email>.key`, passphrase is the email.
2. **Encrypted metadata (v5) is enabled** on the instance. Icons and colours are
   v5 metadata, and the seeder creates v5 resources. Turn it on once as admin
   under Administration > Encrypted metadata (this also creates the metadata
   key). Without it the run stops with a "v5 creation disabled" error.

## Run it

```bash
docker compose --profile seed run --rm seeder
```

The `seed` profile keeps this out of the normal `docker compose up`. The service
builds a small Go binary, joins the stack network (so it reaches
`passbolt.local`), mounts the user keys and the CA cert read-only, runs once, and
exits.

Seeding only ever adds, so running twice creates a second copy. To lay the data
down fresh, reset first:

```bash
docker compose --profile seed run --rm -e RESET=1 seeder
```

`RESET=1` deletes every resource and folder the admin can remove, then seeds.
Users, groups and keys are left untouched, so you do not have to re-instantiate
accounts. It clears the whole vault, not just previously seeded items, so only
use it on an instance whose contents are disposable.

To remove the data **without** seeding again, use `CLEAN=1`:

```bash
docker compose --profile seed run --rm -e CLEAN=1 seeder
```

Same deletion as `RESET=1` (all resources and folders, users left alone), but it
stops there instead of re-seeding.

## Data sets

The data lives in `datasets/`, one JSON file per set. `DATASET` picks which to seed
(default `software`):

```bash
docker compose --profile seed run --rm -e RESET=1 -e DATASET=secops seeder
```

Built-in sets:

- `software` - cloud consoles, CI/CD, databases (the default).
- `secops` - SIEM, EDR, firewall, PAM, AppSec, incident-response runbooks.
- `healthcare` - EHR, PACS, pharmacy, lab, billing, by department.

To seed a set you generated outside the repo, mount it and point `DATASET_FILE` at
it (this takes precedence over `DATASET`):

```bash
docker compose --profile seed run --rm \
  -v /path/to/myset.json:/data/set.json:ro -e DATASET_FILE=/data/set.json seeder
```

A set that doesn't exist prints the available names.

## What it creates

- The folder tree from the selected set (for `software`: Clients/Gibson/..., Admin,
  Marketing, etc.).
- Every entry with its username, URL, description, icon and colour; a TOTP where
  flagged; favourites where flagged.
- Everything is owned by the set's `owner` (Ada, the admin). Items outside the
  private folders are shared with the `shareGroups` so the demo shows real shared
  vaults.

## Change what gets created

Edit the set under `datasets/` (e.g. `datasets/software.json`). Each file is the
source of truth for its set and needs no build step of its own (the Dockerfile
embeds the whole `datasets/` directory):

```json
{
  "name": "Gitlab",
  "username": "ada@passbolt.com",
  "uri": "https://about.gitlab.com/",
  "folder": "Clients/Gibson/DevOps",
  "description": "CI/CD and source hosting for the Gibson account.",
  "icon": 30,
  "color": "#FC6D26",
  "totp": true,
  "favorite": true,
  "shared": true
}
```

- `icon` is a KeePass glyph index, 0 to 68. passbolt shows that glyph on a tile in
  the colour you set. Pick whichever glyph fits; the colour is what makes the vault
  look good on screen.
- `color` is `#RRGGBB`.
- `username` is just the text shown on the entry (the login for that service). It
  does not have to be a real Passbolt user.

Optional fields for richer entries:

- `type` - the resource type. Omit for a normal login (`v5-default`, or
  `v5-default-with-totp` when `totp` is set). Also accepts `v5-note` (a secure note,
  with its body in `description`) and `v5-totp-standalone` (a TOTP on its own).
- `uris` - an array of URLs, for entries with more than one. Takes precedence over
  the single `uri`.
- `totp` - `true` adds a demo TOTP.
- `favorite` - `true` stars it (for the owner).
- `shared` - `true` shares it with the groups in `shareGroups`.
- `shareUsers` - an array of user emails to share the entry with directly, on top of
  any group share.
- `customFields` - an array of `{ "name", "value", "type" }`. `type` is one of
  `text` (default), `password`, `uri`, `number`, `boolean`; the value is stored
  encrypted.

## Configuration

All have defaults suited to this stack; override with environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `DATASET` | `software` | Which embedded set under `datasets/` to seed |
| `DATASET_FILE` | unset | Path to an external set file to seed (overrides `DATASET`) |
| `PASSBOLT_URL` | `https://passbolt.local` | Instance base URL |
| `KEYS_DIR` | `/keys` | Directory of `<email>.key` files (mounted from `keys/gpg`) |
| `CA_CERT` | `/ca/ca.crt` | PEM CA to trust (mounted from `keys/ca.crt`) |
| `PASSPHRASE` | the owner's email | Owner key passphrase |
| `RESET` | unset | Set to `1` to delete all resources/folders before seeding |
| `CLEAN` | unset | Set to `1` to delete all resources/folders and stop (no seeding) |

## Notes

- Passwords and TOTP seeds are generated at run time and are throwaway. Nothing
  here is a real secret.
- Tags are not created (not yet in the Go SDK). Everything else on the entry is.
- Timestamps are set by the server at creation, so entries show fresh dates.
- To re-seed cleanly, use `RESET=1` (above) rather than wiping the stack, which
  would destroy the user accounts and force a manual per-user re-login.
