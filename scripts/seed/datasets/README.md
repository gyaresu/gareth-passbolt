# Data sets

One JSON file per set, embedded into the binary at build time (`//go:embed
datasets/*.json`). `DATASET` picks which to seed, default `software`.

- `software.json` - cloud consoles, CI/CD, databases.
- `secops.json` - SIEM, EDR, firewall, PAM, AppSec, incident-response runbooks.
- `healthcare.json` - EHR, PACS, pharmacy, lab, billing, by department.

## There is a fourth set, and it is not in here

`DATASET=bulk` is generated in code (`../bulk.go`), not read from this directory.
It exists for performance work: a vault large enough to show cold-start login time,
client-side decrypt and list rendering, which a 48-entry set cannot.

It is not a file here for two reasons. It is parameterised, so `COUNT=10000` and
`COUNT=12000` are the same set at different sizes rather than two artefacts. And at
10,000 resources it serialises to about 6.5 MB, which is generated output and has no
business in a public repo's history.

See `../README.md` for `COUNT`, `WORKERS`, `BULK_SHARE_PCT` and the rest.

## Adding a set here

Drop in a `.json` file shaped like the others and it is picked up by name, no code
change needed. Remember that `datasets/` is embedded into the binary, so a change
here needs `docker compose --profile seed run --rm --build ...` to take effect.
