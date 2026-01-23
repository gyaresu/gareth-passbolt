# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based demonstration stack for Passbolt Pro password manager showcasing enterprise features: LDAP synchronization via aggregation proxy, OIDC SSO via Keycloak, LDAPS, audit logging, and SCIM API testing.

## Quick Start

```bash
./scripts/setup.sh                    # Start full stack (Traefik, LDAP aggregation, Keycloak)
```

### Configuration Options

Set environment variables before running setup:

```bash
ENABLE_RSYSLOG=true ./scripts/setup.sh   # Enable rsyslog audit logging sidecar
SKIP_KEYCLOAK=true ./scripts/setup.sh    # Skip Keycloak SSO service
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

### Certificate Management

```bash
./scripts/generate-certificates.sh           # Generate all TLS certificates
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
                                       │   ├── ldap1 (Passbolt Inc.)
                                       │   └── ldap2 (Example Corp.)
                                       └── SMTP4Dev (email testing)

Rsyslog ← Audit logging sidecar (optional, ENABLE_RSYSLOG=true)
```

### LDAP Integration

The stack uses LDAP aggregation via OpenLDAP meta backend (`ldap-meta`). Passbolt connects to a unified view at `dc=unified,dc=local` which proxies to both backend LDAP servers transparently.

### Key Configuration Files

- `docker-compose.yaml` - Service definitions
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
| Traefik | 8080 | https://traefik.local |
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

## Bug Investigation Scripts

The `scripts/tests/` directory contains SQL scripts and shell scripts for investigating specific Passbolt behaviors:

- `diagnose-duplicate-users.sql` / `cleanup-duplicate-users.sql` - Duplicate user detection
- `check-mfa-duo-config.sql` - MFA configuration diagnostics
- `check-action-logs-secret-updates.sql` - Audit log analysis
- `test-duplicate-user-bug.sh` - Reproduces duplicate user scenarios
- `test-secret-update-resource-modified.sh` - Tests resource modification behavior

Each has an accompanying README explaining the investigation context.
