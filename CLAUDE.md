# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based demonstration stack for Passbolt Pro password manager showcasing enterprise features: LDAP synchronization via aggregation proxy, OIDC SSO via Keycloak, LDAPS, audit logging, and SCIM API testing.

## Quick Start

```bash
./scripts/setup.sh                    # Start full stack (Traefik, LDAP aggregation, Keycloak)
```

### Configuration Options

Set environment variables before running setup. Both are off by default — Keycloak runs,
and audit logs go to file only, unless you set these:

```bash
ENABLE_RSYSLOG=true ./scripts/setup.sh   # Enable rsyslog audit logging sidecar (default: off, file logging still works)
SKIP_KEYCLOAK=true ./scripts/setup.sh    # Skip Keycloak SSO service (default: Keycloak enabled)
```

### Important: Manual LDAP Configuration Required

LDAP Directory Sync settings **cannot** be configured via environment variables. After setup, configure in the browser:

1. Go to https://passbolt.local
2. Log in as admin (ada@passbolt.com, passphrase: ada@passbolt.com)
3. Administration → Directory Synchronization
4. Enter LDAP settings:
   - Host: `ldap-meta.local`
   - Port: `636` (LDAPS)
   - Base DN: `dc=unified,dc=local`
   - Username: `cn=admin,dc=unified,dc=local`
   - Password: `secret`
   - Use SSL: `true`

## Common Commands

### Docker Operations

```bash
docker compose up -d                  # Start all services
docker compose down                   # Stop all services
docker compose logs -f <service>      # Follow service logs (passbolt, keycloak, ldap1, ldap2, db)
docker compose exec passbolt <cmd>    # Run command in Passbolt container
docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt  # Database access
```

### LDAP Management

```bash
./scripts/ldap/setup/initial-setup.sh           # Initialize LDAP1 directory
./scripts/ldap2/setup/initial-setup.sh          # Initialize LDAP2 directory
./scripts/ldap/users/add.sh "First" "Last" "email@domain"  # Add user to LDAP1
```

### Directory Sync

```bash
docker compose exec passbolt su -s /bin/bash -c "/usr/share/php/passbolt/bin/cake directory_sync all --persist --quiet" www-data
```

### Testing

```bash
./scripts/tests/integration/test-ldap.sh    # LDAP integration tests
./scripts/tests/sync/test-sync.sh           # Directory sync tests
./scripts/tests/scripts/test-scripts.sh     # Script validation
```

### Demo Data

```bash
# Populate the instance with folders, logins, TOTPs, favourites and coloured
# icons for screenshots/videos. Run after the stack is up and users exist.
# Requires encrypted metadata (v5) enabled in Administration. See scripts/seed/README.md.
docker compose --profile seed run --rm seeder

# Re-seed cleanly: delete all resources/folders first, then seed (keeps users).
docker compose --profile seed run --rm -e RESET=1 seeder

# Delete all resources/folders without re-seeding (keeps users).
docker compose --profile seed run --rm -e CLEAN=1 seeder

# Pick an industry data set (default software; also secops, healthcare).
docker compose --profile seed run --rm -e RESET=1 -e DATASET=secops seeder

# Performance testing: generate a large vault to reproduce and profile large-vault
# behaviour (cold-start login, client-side decrypt, local-storage write, list
# rendering). Generated in the binary, so nothing large is committed. COUNT defaults
# to 10000. Every resource is created through the API with client-side encryption,
# so even across workers this takes minutes. WORKERS and BULK_SHARE_PCT tune it;
# see scripts/seed/README.md.
docker compose --profile seed run --rm --build -e DATASET=bulk -e COUNT=10000 seeder
```

After editing anything under `scripts/seed/`, pass `--build`. Without it compose
reuses the cached image and silently runs the previous binary.

A large vault needs more than the stock PHP memory limit. `config/php/www.conf`
raises it; a default install cannot serve a 10,000-resource index and the browser
extension retries forever with no visible error.

### Certificate Management

```bash
./scripts/generate-certificates.sh           # Generate all TLS certificates (keys/)
./scripts/generate-ldap-meta-cert.sh         # Generate the LDAP meta proxy cert (certs/)
./scripts/generate-smtp-certs.sh             # Generate the SMTP4Dev cert (smtp4dev/certs/)
./scripts/validate-traefik-config.sh         # Validate Traefik YAML config
```

### Database Diagnostics

```bash
# Run database growth diagnostics
docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt < scripts/diagnose-db-growth.sql | column -t
```

## Architecture

```
Browser → Traefik (reverse proxy) → Passbolt (PHP-FPM)
                                       ├── MariaDB (persistence)
                                       ├── Valkey (sessions)
                                       ├── Keycloak (SSO)
                                       ├── ldap-meta (LDAP aggregation)
                                       │   ├── ldap1 (Passbolt)
                                       │   └── ldap2 (Example Corp.)
                                       └── SMTP4Dev (email testing)

Rsyslog ← Audit logging sidecar (optional, ENABLE_RSYSLOG=true)
```

### LDAP Integration

The stack uses LDAP aggregation via OpenLDAP meta backend (`ldap-meta`). Passbolt connects to a unified view at `dc=unified,dc=local` which proxies to both backend LDAP servers transparently.

### Demo Users

LDAP1 (Passbolt) is seeded with five famous women in computing; GPG key passphrase = email. LDAP2 (Example Corp: John Smith, Sarah Johnson, Michael Chen, Lisa Rodriguez) is a deliberately separate, generically named org for the aggregation demo.

| User | Known for | Email |
|------|-----------|-------|
| Ada Lovelace | First published algorithm for a machine | `ada@passbolt.com` (admin) |
| Betty Holberton | Original ENIAC programmer | `betty@passbolt.com` |
| Carol Shaw | Early professional video-game designer | `carol@passbolt.com` |
| Dame Stephanie Shirley | Founded a women-staffed software house | `dame@passbolt.com` |
| Edith Clarke | First US woman EE professor | `edith@passbolt.com` |

### Key Configuration Files

- `docker-compose.yaml` - Service definitions (passbolt pinned to floating `latest-pro`; tracks newest Pro release on pull, not version-pinned)
- `.env` - Project name and configuration options
- `config/traefik/` - Reverse proxy routing and TLS
- `config/ldap-meta/slapd.conf` - OpenLDAP meta backend config
- `config/rsyslog/rsyslog.conf` - Audit log forwarding (when enabled)

### Services and Ports

| Service | Port | URL |
|---------|------|-----|
| Passbolt | 443 | https://passbolt.local |
| Keycloak | 443 | https://keycloak.local |
| SMTP4Dev | 443/465 | https://smtp.local |
| Traefik | 443/8081 | https://traefik.local |
| LDAP Meta | 3389/3636 | ldap-meta.local (LDAP/LDAPS) |

### Directory Structure

- `scripts/` - Setup and management scripts
- `config/` - Service configurations (traefik, ldap-meta, passbolt, php, db, rsyslog)
- `keys/` - TLS certificates and GPG keys
- `certs/` - LDAPS certificate bundles
- `bruno/` - SCIM API test collection
- `logs/` - Application and audit logs (gitignored)

## Hosts File Entries Required

```
127.0.0.1 passbolt.local keycloak.local smtp.local traefik.local ldap1.local ldap2.local ldap-meta.local
```

## Logs

```bash
tail -f logs/passbolt/action-logs.log         # Passbolt action logs
grep "passbolt-audit" logs/passbolt/syslog.log  # Audit events via syslog (if ENABLE_RSYSLOG=true)
```

## Reaching this stack from Claude

If Claude Code runs in a separate devcontainer, join that container to this stack's docker network to reach its services by hostname. The network is `dev_default` (the compose project name is `dev`; confirm with `docker network ls`); join it as an external network via a `docker-compose.override.yml`.

Once joined, services resolve directly: `passbolt.local`, `db`, `valkey`, `keycloak.local`, `ldap-meta.local`, `smtp.local`.
