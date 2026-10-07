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

**After changing anything in this directory, pass `--build`.** The binary is
compiled into the image, and `compose run` reuses the cached image, so without it
your change is silently ignored and the previous binary runs:

```bash
docker compose --profile seed run --rm --build seeder
```

Editing a file under `datasets/` counts: those are embedded into the binary too.

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
- `bulk` - a generated set for performance work. Not a file; see below.

### The `bulk` set

`bulk` is generated in the binary rather than read from `datasets/`, because a vault
big enough to measure is several megabytes of JSON and does not belong in the repo.
It exists to make the stack slow on purpose, so large-vault behaviour can be
reproduced and profiled locally: cold-start login time, the client-side decrypt and
local-storage write, and list rendering. Those costs scale with resource count, and
a 48-entry demo vault cannot show them.

```bash
docker compose --profile seed run --rm -e DATASET=bulk -e COUNT=10000 seeder
```

`COUNT` defaults to 10000 and is ignored by every other set. The content is uniform
and dull on purpose: the point is the count and the size of the encrypted metadata,
not the words. Entries are derived from their index, so a given `COUNT` always
produces the same vault and two runs can be compared.

**The folder tree** is 20 systems, each with 5 environments: 100 leaf folders plus
the 20 parents, 120 in all. Resources fill the leaves evenly, so `COUNT=12000` puts
120 in each. Environment varies fastest, so every leaf is reached within each run of
100 and the spread stays even at any count.

**A bulk vault needs more than the stock PHP memory limit.** `config/php/www.conf`
raises it for this stack. On a default install the server cannot serve a
10,000-resource index at all: it exhausts the 128M limit while serializing the
response, and the browser extension retries forever showing no error.

Nothing is starred or given a TOTP, and by default nothing is shared either. Every
resource is a real API create with its secret and v5 metadata encrypted client side,
so a five-figure run still takes minutes rather than seconds.

`COUNT` is also how you cross the browser extension's page boundary: it requests
10,000 resources per page, so `COUNT=10001` is the smallest vault that makes the
extension fetch a second page.

| Variable | Default | Meaning |
|---|---|---|
| `COUNT` | `10000` | How many resources to generate |
| `BULK_OWNER` | `ada@passbolt.com` | Who owns the vault |
| `BULK_SHARE_PCT` | `0` | Percentage of resources to share, 0 to 100 |
| `BULK_SHARE_GROUPS` | `developers,demoteam` | Groups to share with, when sharing is on |
| `TIMEOUT_MINUTES` | scaled to the set | Hard ceiling on the whole run |
| `WORKERS` | 4 above 1000 resources, else 1 | How many resources to create in parallel |

**How long it actually takes.** Two complete runs on a local stack, at the default
four workers:

| Run | Rate | Time |
|---|---|---|
| 12,000, unshared | 74/s | 2m43s |
| 12,000, 20% shared | 34/s | 5m50s |

Sharing roughly halves throughput, but on a 12,000 run that is three extra minutes,
not hours.

Two things got it there: four workers instead of one, and fetching the resource-type
list once for the run rather than once per create (the SDK's create helper refetches
it every time). Raise `WORKERS` to push harder; this stack's php-fpm allows 20
children, so there is room, but the gain flattens once the server is the limit.

Whether throughput holds as the vault grows is what the progress output, printed
every 500 resources with a running rate, will tell you.

**The deadline is a ceiling, not an estimate.** The run is killed if it overruns,
because being killed partway leaves a half-populated vault. For the small
hand-authored sets the ceiling is ten minutes; for a generated set it scales with
resources and shares, and is set several times above measured throughput so that a
slowdown does not cost you the run. `TIMEOUT_MINUTES` overrides it.

### Sharing

Off by default. A share re-encrypts the secret to every recipient's key and costs an
extra API call, so it is the most expensive thing per resource, though on a 12,000
run it adds minutes rather than hours. Missing groups are warned about and skipped.

```bash
# 20% of a 10k vault shared with the default groups
docker compose --profile seed run --rm \
  -e DATASET=bulk -e COUNT=10000 -e BULK_SHARE_PCT=20 seeder
```

Turn it on when the thing under test involves a user who is **not** the owner, or
the server-side permission lookup. Leave it off when testing the owner's own
cold-start login: with shared metadata keys the metadata is encrypted to the same
key whether or not the resource is shared, and the logging-in user still gets one
permission record per resource either way.

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
