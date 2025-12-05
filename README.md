# Passbolt Pro Demonstration Stack

> Demo Environment: This repository contains demo credentials and self-signed certificates for testing only. Do not use in production without proper security configuration.

## What This Demonstrates

- Passbolt Pro with OIDC SSO integration (Keycloak over HTTPS)
- Multi-directory LDAP synchronization (aggregation and direct approaches)
- LDAPS (implicit TLS) for secure LDAP connections
- SMTPS for secure email communication
- Valkey session handling
- Certificate automation for development and testing
- SCIM API testing with Bruno

## Prerequisites

- Docker and Docker Compose
- Passbolt Pro subscription key
- macOS or Linux

## Table of Contents

- [Quick Start](#quick-start)
- [LDAP Integration](#ldap-integration)
- [Traefik Reverse Proxy (Default)](#traefik-reverse-proxy-default)
- [Services Overview](#services-overview)
- [Valkey Session Handling](#valkey-session-handling)
- [Environment Variables Configuration](#environment-variables-configuration)
- [SIEM Audit Logging](#siem-audit-logging)
- [Keycloak SSO Configuration](#keycloak-sso-configuration)
- [SMTP Configuration](#smtp-configuration)
- [GPG Primer](#gpg-primer)
- [User and Group Management](#user-and-group-management)
- [Testing and Verification](#testing-and-verification)
  - [SCIM API Testing with Bruno](#scim-api-testing-with-bruno)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Automated Setup

Choose your LDAP integration approach:

**Default (Traefik + LDAP Aggregation):**
```bash
./scripts/setup.sh
```
Full stack with Traefik reverse proxy, LDAP aggregation via OpenLDAP meta backend.

**LDAP Aggregation with Nginx:**
```bash
./scripts/setup-aggregation-demo.sh
```
OpenLDAP meta backend with Nginx instead of Traefik. Uses direct port access.

**Direct Multi-Domain:**
```bash
./scripts/setup-dual-ldap.sh
```
Passbolt connects directly to multiple LDAP servers via PHP configuration.

**Single LDAP with Nginx:**
```bash
./scripts/setup-nginx-single.sh
```
Basic single directory setup with Nginx.

All scripts set up LDAP directories, generate GPG keys, and create Passbolt admin user 'ada'. See [LDAP Integration](#ldap-integration) for detailed comparison.

### Manual Setup

1. Add host entries:
   ```bash
   echo "127.0.0.1 passbolt.local keycloak.local smtp.local traefik.local ldap1.local ldap2.local ldap-meta.local" | sudo tee -a /etc/hosts
   ```

2. Add Passbolt Pro subscription key:
   ```bash
   cp /path/to/your/subscription_key.txt ./subscription_key.txt
   ```

3. Generate TLS certificates:
   ```bash
   ./scripts/generate-certificates.sh
   ```

4. Make scripts executable:
   ```bash
   chmod +x scripts/ldap/*/*.sh scripts/tests/*/*.sh
   ```

5. Start the environment:
   ```bash
   docker compose up -d
   ```

6. Setup LDAP test data:
   ```bash
   ./scripts/ldap/setup/initial-setup.sh
   ```

7. Create the default admin user (optional - now automatic in setup.sh):
   ```bash
   ./scripts/ldap/setup/create-admin.sh
   ```

8. Configure LDAP in Passbolt:
   - Log in to Passbolt as administrator
   - Go to Organization Settings > Users Directory
   - Configure LDAP settings (see [LDAP Integration](#ldap-integration))

**Important Notes:**
- LDAP users must be set up before creating the Passbolt admin user
- SMTP: Set "Use TLS" to No (SMTPS implicit TLS is used via `ssl://smtp.local`)
- Requires valid Passbolt Pro subscription key in `subscription_key.txt`
- Demo credentials are for testing only - use strong credentials in production

## LDAP Integration

Two approaches for multi-directory LDAP integration for educational comparison.

### Approach Comparison

| Aspect | Aggregation (Default) | Direct Multi-Domain |
|--------|----------------------|---------------------|
| Architecture | Infrastructure proxy | Application-level |
| Configuration | Web UI or PHP file | Web UI or PHP file |
| LDAP Endpoint | Single unified (ldap-meta) | Multiple direct (ldap1, ldap2) |
| Setup Script | `setup-aggregation-demo.sh` | `setup-dual-ldap.sh` |

### Directory Structure

**LDAP1 (Passbolt Inc.) - dc=passbolt,dc=local:**
```
ou=users: Ada, Betty, Carol, Dame, Edith
ou=groups: passbolt, developers, demoteam, admins
```

**LDAP2 (Example Corp) - dc=example,dc=com:**
```
ou=people: John, Sarah, Michael, Lisa
ou=teams: project-teams, security, operations, creative
```

**Aggregation Unified View (dc=unified,dc=local):**
```
dc=passbolt,dc=unified,dc=local → LDAP1
dc=example,dc=unified,dc=local → LDAP2
```

### Aggregation Approach Configuration

Passbolt connects to single meta backend. Configure via Web UI or use included PHP configuration (`config/passbolt/ldap.php`).

**LDAP Meta Settings:**
- Host: `ldap-meta.local`
- Port: `636` (LDAPS)
- Base DN: `dc=unified,dc=local`
- Username: `cn=readonly,dc=passbolt,dc=unified,dc=local` (PHP config) or `cn=admin,dc=unified,dc=local` (Web UI)
- Password: `readonly` (PHP config) or `secret` (Web UI)
- Use SSL: `true`

The meta backend transparently proxies to both LDAP1 and LDAP2.

### Direct Multi-Domain Approach Configuration

Passbolt connects directly to both LDAP servers. Configure via Passbolt Web UI or use the included PHP configuration example (`config/passbolt/ldap.php`).

**PHP Configuration Example:**

The repository includes a ready-to-use multi-domain configuration at `config/passbolt/ldap.php` with two domains:

**LDAP1 (Passbolt domain):**
- Host: `ldap1.local`
- Port: `636` (LDAPS)
- Base DN: `dc=passbolt,dc=local`
- Username: `cn=readonly,dc=passbolt,dc=local`
- Password: `readonly`
- Paths: `ou=users`, `ou=groups`

**LDAP2 (Example domain):**
- Host: `ldap2.local`
- Port: `636` (LDAPS)
- Base DN: `dc=example,dc=com`
- Username: `cn=reader,dc=example,dc=com`
- Password: `reader123`
- Paths: `ou=people`, `ou=teams`

**Note:** The PHP config is not used by default (Web UI configuration takes precedence). To use the PHP config, mount it into the Passbolt container.

**Sync Command:**
```bash
docker compose exec passbolt su -s /bin/bash -c "/usr/share/php/passbolt/bin/cake directory_sync all --persist --quiet" www-data
```

### Security (LDAPS)

All LDAP connections use LDAPS (port 636) with SSL/TLS encryption.

**Certificate Management:**
- osixia/openldap auto-generates self-signed certificates
- `./scripts/fix-ldaps-certificates.sh` extracts certificates from containers
- Certificates bundled into Passbolt container at build time

**Test LDAPS:**
```bash
docker compose exec passbolt openssl s_client -connect ldap:636 \
  -servername ldap.local -CAfile /etc/ssl/certs/ldaps_bundle.crt -brief
```

### LDAP Server Configuration

**osixia/openldap Environment Variables:**
```yaml
LDAP_ORGANISATION: "Passbolt"
LDAP_DOMAIN: "passbolt.local"
LDAP_BASE_DN: "dc=passbolt,dc=local"
LDAP_ADMIN_PASSWORD: "P4ssb0lt"
LDAP_TLS: "true"
LDAP_READONLY_USER: "true"
LDAP_READONLY_USER_USERNAME: "readonly"
LDAP_READONLY_USER_PASSWORD: "readonly"
```

**Connection Methods:**
- LDAPS (implicit TLS): Port 636 - Used by Passbolt
- STARTTLS: Port 389 - Alternative option

**Certificate Location in Container:**
- `/container/service/slapd/assets/certs/ldap.crt` - Server certificate
- `/container/service/slapd/assets/certs/ca.crt` - CA certificate
- `/container/service/slapd/assets/certs/ldap.key` - Private key

### Directory Synchronization Settings

**Passbolt Web UI (Organization Settings > Directory):**
- Users Path: `ou=users`
- Group Path: `ou=groups`
- User Filter: `(objectClass=inetOrgPerson)`
- Group Filter: `(objectClass=groupOfUniqueNames)`
- Username: `mail`
- Email: `mail`
- First Name: `givenName`
- Last Name: `sn`

**Sync Behavior:**
One-way read-only from LDAP to Passbolt. LDAP is the source of truth.

### References

- Passbolt LDAP: https://www.passbolt.com/configure/ldap
- LdapRecord Multi-Domain: https://ldaprecord.com/docs/laravel/v2/configuration
- OpenLDAP Admin: https://www.openldap.org/doc/admin24/

## Traefik Reverse Proxy (Default)

Traefik provides automatic HTTPS routing and service discovery.

### Setup

```bash
./scripts/setup.sh
```

Uses the default `docker-compose.yaml` file.

### Configuration

YAML files (fixes indentation issues in Passbolt docs):
- `config/traefik/traefik.yaml` - Main config with HTTP to HTTPS redirect
- `config/traefik/conf.d/tls.yaml` - TLS 1.2+ settings
- `config/traefik/conf.d/headers.yaml` - Security headers

### Access

- Passbolt: https://passbolt.local
- Keycloak: https://keycloak.local
- SMTP4Dev: https://smtp.local
- Traefik Dashboard: https://traefik.local

### Validate Config

```bash
./scripts/validate-traefik-config.sh  # Checks YAML syntax, tabs, indentation
```

### Use Nginx Instead

```bash
docker compose down
docker compose -f docker-compose.nginx.yaml up -d
```

## Services Overview

| Service   | URL                       | Credentials        | Purpose |
|-----------|---------------------------|-------------------|---------|
| Passbolt  | https://passbolt.local    | Created during setup | Main application |
| Keycloak  | https://keycloak.local | admin / admin    | SSO provider |
| SMTP4Dev  | https://smtp.local    | N/A               | Email testing |
| Traefik   | https://traefik.local | N/A | Reverse proxy dashboard |
| LDAP1     | ldap1.local:636 (LDAPS) | cn=readonly,dc=passbolt,dc=local / readonly | Passbolt Inc. directory |
| LDAP2     | ldap2.local:636 (LDAPS) | cn=reader,dc=example,dc=com / reader123 | Example Corp directory |
| LDAP Meta | ldap-meta.local:636 (LDAPS) | cn=admin,dc=unified,dc=local / secret | Aggregation proxy |
| Valkey    | valkey:6379 (internal)    | N/A               | Session storage |

## Valkey Session Handling

Valkey provides Redis-compatible session storage for better performance than file-based sessions.

### Configuration

Valkey service:
```yaml
valkey:
  image: valkey/valkey:9.0-trixie
  ports: ["6379:6379"]
  volumes: [valkey_data:/data]
  command: valkey-server --appendonly yes
```

Passbolt environment variables:
```yaml
CACHE_CAKECORE_CLASSNAME: Cake\Cache\Engine\RedisEngine
CACHE_CAKECORE_HOST: valkey
CACHE_CAKECORE_PORT: 6379
CACHE_CAKECORE_PASSWORD: ""
CACHE_CAKECORE_DATABASE: 0
SESSION_DEFAULTS: cache
```

### Testing
```bash
# Test connectivity
docker compose exec valkey valkey-cli ping

# Check sessions
docker compose exec valkey valkey-cli keys "*session*"
```

## Environment Variables Configuration

Environment variables documented in official Passbolt documentation:

### Core Application Variables
- `APP_FULL_BASE_URL` - Passbolt application URL
- `DATASOURCES_DEFAULT_*` - Database connection settings

### Email Configuration
- `EMAIL_TRANSPORT_DEFAULT_*` - SMTP server settings
- `EMAIL_DEFAULT_FROM` - Default sender email address

### Plugin Configuration
- `PASSBOLT_PLUGINS_DIRECTORY_SYNC_ENABLED` - Enable Directory Sync plugin (Note: Currently not working, see task PB-45139 for fix)
- `PASSBOLT_PLUGINS_SSO_ENABLED` - Enable SSO plugin
- `PASSBOLT_PLUGINS_SSO_PROVIDER_OAUTH2_ENABLED` - Enable OAuth2 SSO provider
- `PASSBOLT_SECURITY_SSO_SSL_VERIFY` - SSO SSL verification

### Session Configuration
- `CACHE_CAKECORE_*` - Valkey cache engine settings
- `SESSION_DEFAULTS` - Session storage method

### Important Notes
- Directory Sync details (host, port, credentials, filters) configured via Passbolt Web UI
- PHP TLS configuration in `config/php/ssl.ini`

## SIEM Audit Logging

Passbolt supports file-based and syslog-based audit logging. Both can run simultaneously.

### Configuration

**File Logging:**
```yaml
LOG_ACTION_LOGS_ON_FILE_ENABLED: "true"
LOG_ACTION_LOGS_ON_FILE_PATH: "/var/log/passbolt/"  # trailing slash required on macOS
LOG_ACTION_LOGS_ON_FILE_FILE: "action-logs.log"
LOG_ACTION_LOGS_ON_FILE_STRATEGY: 'Passbolt\Log\Strategy\ActionLogsDefaultQueryStrategy'
```

**Syslog Logging:**
```yaml
LOG_ACTION_LOGS_ON_SYSLOG_ENABLED: "true"
LOG_ACTION_LOGS_ON_SYSLOG_STRATEGY: 'Passbolt\Log\Strategy\ActionLogsUsernameQueryStrategy'
LOG_ACTION_LOGS_ON_SYSLOG_PREFIX: 'passbolt-audit:'
```

### Logging Strategies

Strategies are independent of output method (file or syslog). Any strategy can be used with either.

**ActionLogsDefaultQueryStrategy:**
- Emits every action log row (all actions, success and error)
- Raw JSON with `user_id`, `action_id`, `details` (no resolved usernames)

**ActionLogsErrorsOnlyQueryStrategy:**
- Same format as default but only failed actions

**ActionLogsUsernameQueryStrategy:**
- JSON with resolved usernames and full names
- Only logs specific actions: login, logout, password access/update/add/delete, share
- Does not log user creation, ownership transfers, or other actions outside its allowlist

### Log Locations

**File Logs:**
- Location: `./logs/passbolt/action-logs.log` (on host)
- Format: Raw JSON, one entry per line
- Example:
```json
{"id":"...","user_id":"...","action_id":"...","context":"PUT /resources/...","status":1,"created":"2025-11-24T23:11:33+00:00"}
```

**Syslog Logs:**
- Location: `./logs/passbolt/syslog.log` (on host)
- Format: Syslog format with JSON payload
- Filter: Use `grep "passbolt-audit"` to see only Passbolt entries
- Example:
```
2025-11-24T23:11:33.093198+00:00 1d3ec95b1d81 passbolt-audit:: 2025-11-24 23:11:33 info: {"timestamp":"2025-11-24 23:11:33","user":"ada@passbolt.com","action":"password_update","context":"Ada Lovelace (ada@passbolt.com) updated password","status":1,"resource_id":"f6c326ee-c967-437a-8f9e-e163eb73c929",...}
```

### Monitoring Logs

**Watch file logs in real-time:**
```bash
tail -f logs/passbolt/action-logs.log
```

**Watch syslog (Passbolt entries only):**
```bash
tail -f logs/passbolt/syslog.log | grep --line-buffered 'passbolt-audit'
```

**View recent Passbolt audit entries:**
```bash
grep "passbolt-audit" logs/passbolt/syslog.log | tail -n 20
```

### Rsyslog Sidecar

Rsyslog sidecar container:
- Receives logs from Passbolt via shared Unix socket (`/dev/log`)
- Writes to `./logs/passbolt/syslog.log`
- Can forward to external syslog servers

**Configuration:**
- Rsyslog config: `config/rsyslog/rsyslog.conf`
- Socket: Shared via Docker named volume `syslog_socket`
- Documentation: https://github.com/rsyslog/rsyslog/tree/main/packaging/docker

**Forward to remote syslog server:**
Modify `config/rsyslog/rsyslog.conf`:
```conf
# Forward to remote syslog server
*.* action(type="omfwd" target="siem.example.com" port="514" protocol="udp")
```

### Logged Actions (UsernameQueryStrategy)

The username strategy logs these actions:
- `user_login` - User authentication
- `user_logout` - User logout
- `password_access` - Resource viewed/accessed
- `password_add` - Resource created
- `password_update` - Resource updated
- `password_delete` - Resource deleted
- `share` - Resource shared with users/groups

Actions not logged by username strategy (use default strategy to capture all):
- User creation/invitation
- Ownership transfers
- Folder operations
- Permission changes (outside of share action)

## URL/Domain Tracking

Passbolt does not store which URL, domain, or hostname users access in its database. To identify which users access which URLs (useful for multi-domain setups, DNS aliases, or environment tracking), correlate nginx access logs with Passbolt action logs.

### Nginx Configuration

Nginx access logs include the Host header (requested domain/hostname) in each request. The custom log format is configured in `config/nginx/nginx-passbolt.conf`:

```nginx
log_format with_host '$remote_addr - $remote_user [$time_local] "$request" '
                     '$status $body_bytes_sent "$http_referer" '
                     '"$http_user_agent" "$http_host"';
```

### Log Correlation

**Nginx logs** (via `docker compose logs passbolt`):
- IP address, request path, Host header (domain/hostname), timestamp
- Example: `[27/Nov/2025:01:50:40] "POST /auth/login.json" ... "passbolt.local"`

**Passbolt logs** (`./logs/passbolt/syslog.log`):
- User email, action type, timestamp
- Example: `{"timestamp":"2025-11-27 01:50:40","user":"ada@passbolt.com","action":"user_login"}`

**Correlation method:**
1. Find `POST /auth/login.json` requests in nginx logs (includes Host header)
2. Match with `user_login` actions in Passbolt syslog logs (includes user email)
3. Match by timestamp (±2-3 seconds) and request path
4. Result: `user@email.com` → `domain.example.com`

**Example:**
- Nginx: `[27/Nov/2025:01:50:40] "POST /auth/login.json" ... "passbolt.local"`
- Passbolt: `{"timestamp":"2025-11-27 01:50:40","user":"ada@passbolt.com","action":"user_login"}`
- Result: `ada@passbolt.com` accessed `passbolt.local`

### Implementation

Parse logs with a script or log aggregation tool (ELK, Splunk, etc.) to automatically correlate and generate reports showing which users access which domains/URLs.

## Keycloak SSO Configuration

### Environment Setup

Stack components:
- Passbolt Pro with OIDC plugin
- Keycloak 26.4
- Shared MariaDB (`passbolt` and `keycloak` databases)
- Shared certificate system

### PHP SSL Configuration

Two main configuration files:

1. **ssl.ini** - System-wide PHP SSL certificate paths:
```ini
[PHP]
openssl.cafile = /etc/ssl/certs/ca-certificates.crt
curl.cainfo = /etc/ssl/certs/ca-certificates.crt
```

2. **www.conf** - PHP-FPM configuration with certificate paths:
```ini
[www]
php_admin_value[openssl.cafile] = "/etc/ssl/certs/ca-certificates.crt"
php_admin_value[curl.cainfo] = "/etc/ssl/certs/ca-certificates.crt"
```

### Keycloak Setup

1. **Access Keycloak Admin Console:**
   - URL: https://keycloak.local:8443
   - Username: admin
   - Password: admin

2. **Create Realm:**
   - Click "Create Realm"
   - Name: "passbolt"
   - Click "Create"

3. **Create Client:**
   - Go to "Clients" > "Create client"
   - Client type: OpenID Connect
   - Client ID: "passbolt-client"
   - Client authentication: ON
   - Authorization: OFF
   - Click "Save"

4. **Configure Client Settings:**
   - **Settings tab**:
     - Valid redirect URIs: https://passbolt.local/auth/login
     - Web origins: https://passbolt.local
     - Click "Save"
   - **Credentials tab**:
     - Copy the generated "Client secret" value

5. **Create User:**
   - Go to "Users" > "Add user"
   - Username: ada
   - Email: ada@passbolt.com (must match Passbolt admin email)
   - First name: Ada
   - Last name: Lovelace
   - Click "Create"
   - Go to "Credentials" tab:
     - Set password: passbolt
     - Temporary: OFF
     - Click "Set password"

### Passbolt OAuth2 Configuration

Configure in Passbolt web interface under Administration → Authentication → SSO:

- **Issuer URL**: `https://keycloak.local:8443/realms/passbolt`
- **OpenID Configuration Path**: `/.well-known/openid-configuration`
- **Client ID**: `passbolt-client`
- **Client Secret**: Use value from Keycloak Credentials tab
- **Scopes**: `openid profile email`
- **SSL Verification**: Enabled

**Full OpenID Configuration URL**: `https://keycloak.local:8443/realms/passbolt/.well-known/openid-configuration`

This endpoint provides the complete OAuth2/OIDC discovery document, including authorization, token, and userinfo endpoints.

**Verify Configuration:**
```bash
curl -k https://keycloak.local:8443/realms/passbolt/.well-known/openid-configuration | jq
```
*Note: `-k` flag skips certificate verification for self-signed certificates in development.*

**Expected Output (excerpt):**
```json
{
  "issuer": "https://keycloak.local:8443/realms/passbolt",
  "authorization_endpoint": "https://keycloak.local:8443/realms/passbolt/protocol/openid-connect/auth",
  "token_endpoint": "https://keycloak.local:8443/realms/passbolt/protocol/openid-connect/token",
  "userinfo_endpoint": "https://keycloak.local:8443/realms/passbolt/protocol/openid-connect/userinfo",
  ...
}
```

### Testing SSO Integration

1. Access Passbolt at https://passbolt.local
2. Click "SSO Login"
3. Redirected to Keycloak
4. Log in with ada@passbolt.com / passbolt
5. Redirected back to Passbolt and logged in

**Note:** Configuration examples in `assets/` directory.

## SMTP Configuration

SMTP4Dev: https://smtp.local (SMTPS port 465)

### Configuration

Passbolt configured to use SMTP4Dev with SMTPS (implicit TLS):

```yaml
# Email Configuration
EMAIL_TRANSPORT_DEFAULT_HOST: "ssl://smtp.local"
EMAIL_TRANSPORT_DEFAULT_PORT: 25
EMAIL_TRANSPORT_DEFAULT_USERNAME: ""
EMAIL_TRANSPORT_DEFAULT_PASSWORD: ""
EMAIL_DEFAULT_FROM: "admin@passbolt.com"

# SMTP Settings (SMTPS - implicit TLS)
# Note: SMTP security settings are configured via Passbolt Web UI
```

### TLS Certificate and Private Key Setup

```bash
# Create certificates directory
mkdir -p smtp4dev/certs

# Generate private key and corresponding certificate
openssl req -x509 -newkey rsa:4096 \
  -keyout smtp4dev/certs/tls.key \
  -out smtp4dev/certs/tls.crt \
  -days 365 -nodes \
  -subj "/CN=smtp.local"

# Create PKCS12 bundle
openssl pkcs12 -export \
  -out smtp4dev/certs/tls.pfx \
  -inkey smtp4dev/certs/tls.key \
  -in smtp4dev/certs/tls.crt \
  -passout pass:changeme
```

### Testing Email

1. Create a test user in Passbolt
2. Check for registration email in SMTP4Dev web interface
3. Verify email content and headers

## GPG Primer

OpenPGP uses public-key cryptography: each user has a key pair (private + public). In passbolt, users generate or import GPG keys through the browser extension during account setup.

**Note:** passbolt handles GPG operations automatically through the browser extension. Users typically don't need to use command-line GPG tools.

### How passbolt Uses GPG

**User Authentication:**
- Each user has a GPG key pair (private + public)
- Private key stored in browser extension (never sent to server)
- Public key stored on server for encryption
- User authenticates by decrypting server challenges with private key

**Secret Encryption:**
- Hybrid encryption model: session keys + GPG
- Secrets encrypted with random session keys (symmetric)
- Session keys encrypted with recipient public keys (asymmetric GPG)
- Each recipient gets their own encrypted session key
- Messages can be encrypted for main key or subkey (both supported)
- Browser extension (OpenPGP.js) handles encryption/decryption client-side

**Metadata Encryption (v5):**
- Separate GPG key pairs for encrypting metadata (resource names, URIs, descriptions)
- Metadata keys are ECC (Ed25519) GPG keys generated per user
- Two types of metadata encryption:
  - **Personal resources**: Encrypted with user's main GPG key (`metadata_key_type: user_key`, `metadata_key_id: null`)
  - **Shared resources**: Encrypted with user's metadata keys (`metadata_key_type: shared_key`, `metadata_key_id: UUID`)
- Metadata private keys encrypted with user's main GPG key and stored in database
- Encrypted metadata stored as OpenPGP armored messages in `metadata` column (JSON containing name, uri, description)
- Same GPG validation rules apply

**Database Storage:**
- `gpgkeys` table: Stores user public keys (GPG armored format in `armored_key` column)
  - One active key per user (`user_id`, `deleted = false`)
  - `fingerprint` (unique), `key_id`, `type`, `bits`, `uid`, `key_created`, `expires`
  - Used for encrypting secrets and session keys for recipients
- `metadata_keys` table: Stores metadata public keys (GPG armored format in `armored_key` column, `fingerprint` for key identification)
- `metadata_private_keys` table: Stores encrypted metadata private keys per user (encrypted with user's main GPG key, in `data` column as OpenPGP message)
  - Multiple users can share the same `metadata_key_id` (same public key, different encrypted private keys per user)
  - `user_id` links encrypted private key to specific user
- `resources` table: 
  - `metadata` column (MEDIUMTEXT) stores encrypted metadata as OpenPGP armored message (JSON with name, uri, description)
  - `metadata_key_id` references which metadata key was used (can be set for both types)
  - `metadata_key_type` indicates encryption method (`user_key` or `shared_key`)
  - Legacy columns (`name`, `uri`, `description`) still exist for v4 resources
- `folders` table: Similar structure (`metadata`, `metadata_key_id`, `metadata_key_type` columns)
- Metadata keys are shared across users; each user has their own encrypted copy of the private key

**Key Management:**
- Users have one active public key at a time (stored in `gpgkeys` table)
- Public keys retrieved from database when encrypting for recipients
- Metadata keys can be rotated: create new key, expire old key, re-encrypt resources, delete old key
- Metadata keys can be expired (user keys cannot have expiry dates)
- Keys can be soft-deleted (`deleted` flag)
- Keys validated for encryption capability before use
- Revocation checking: revoked keys rejected (RSA only; ECC revocation checking not yet supported)

**Key Identifiers:**
- **Fingerprint**: 40 hex characters, primary identifier (e.g., `ABCDEF1234...`)
- **Key ID**: 8 (short) or 16 (long) hex characters
- Long key IDs recommended for security (short IDs vulnerable to collision)

**Browser Extension:**
- Uses OpenPGP.js library for all GPG operations
- Private keys never leave the browser
- Decryption happens client-side
- Supports both RSA and ECC keys
- Key generation during user setup (client-side)
- Account recovery: GPG keys used to decrypt recovery data

**Message Validation:**
- OpenPGP messages validated for parsing, format, and structure
- Recipient validation: messages must be encrypted for intended recipient's key/subkey
- Symmetric and asymmetric packet validation
- Signature verification for authentication challenges and signed data

### Key Types

passbolt supports both RSA and ECC (Elliptic Curve Cryptography) GPG keys:

**RSA Keys:**
- Traditional key type (supported since early versions)
- Allowed sizes: 2048 (non-strict), 3072, 4096 bits
- Strict mode (recommended): 3072 or 4096 bits only
- Larger key sizes provide stronger security but slower operations

**ECC Keys (v5.6.0+):**
- Modern Ed25519/Curve25519 (default for new users since v5.6.0)
- Curve format: `curve25519_legacy+ed25519_legacy`
- Comparable security to RSA-3072 with better performance
- Smaller payload size, faster encryption/decryption

**Key Validation:**
- Supported algorithms: RSA, ECC, ECDSA, DH (strict mode excludes DSA, ELGAMAL)
- No expiry dates allowed
- Keys must not be expired or revoked
- Keys must not contain multiple main packets
- Fingerprint: 40 hex characters
- Key ID: 8 or 16 hex characters (long IDs recommended)
- Email must be present in key UID and match user email
- Subkeys required: ECDH subkey for ECC, RSA subkey for RSA
- Keys without subkeys: messages encrypted for main key ID (legacy support)

**Configuration (environment variables):**
- `PASSBOLT_PLUGINS_USER_KEY_POLICIES_PREFERRED_KEY_TYPE` - `rsa` or `curve` (default: `curve`)
- `PASSBOLT_PLUGINS_USER_KEY_POLICIES_PREFERRED_KEY_SIZE` - RSA key size: `3072` or `4096` (null for ECC)
- `PASSBOLT_PLUGINS_USER_KEY_POLICIES_PREFERRED_KEY_CURVE` - ECC curve: `curve25519_legacy+ed25519_legacy` (default)

**Reference:** [passbolt User Key Policies Configuration](https://www.passbolt.com/docs/hosting/configure/environment-reference/#user-key-policies-configuration)

### Demo User Keys

Demo GPG keys for passbolt users are in `keys/gpg/`. Generated by `scripts/gpg/generate-demo-keys.sh`, these are private keys (`.key`) and public keys (`.pub`) for demo accounts.

**For passbolt login:** Import the private key (`.key` file) into your passbolt account during setup via the browser extension. Passphrase is the user's email address.

### Container Keyring

passbolt stores its server GPG keyring at `/var/lib/passbolt/.gnupg` in the container. Server keys are imported from `/etc/passbolt/gpg/serverkey_private.asc` on startup.

**Server Key Purpose:**
- Server signing, encryption, decryption, and verification operations
- Used for internal server operations (not user authentication)
- Server key fingerprint and passphrase stored in configuration
- Server key imported into container keyring on startup

```bash
# List keys in container
docker compose exec passbolt su -s /bin/bash -c "gpg --home /var/lib/passbolt/.gnupg --list-keys" www-data

# Export server public key
docker compose exec passbolt su -s /bin/bash -c "gpg --home /var/lib/passbolt/.gnupg --armor --export" www-data

# Import key into container keyring
docker compose exec passbolt su -s /bin/bash -c "gpg --home /var/lib/passbolt/.gnupg --import" www-data < keyfile.asc
```

### Server Keyring Structure

The passbolt server keyring at `/var/lib/passbolt/.gnupg` contains:

```
.gnupg/
├── pubring.kbx          # Public keys database
├── pubring.kbx~         # Backup of public keys database
├── trustdb.gpg          # Trust database
├── private-keys-v1.d/  # Private keys (encrypted, one file per key)
├── S.gpg-agent*         # GPG agent sockets
└── random_seed          # Entropy pool
```

**Note:** User keys are stored in the browser extension, not on the server. Only the server's own GPG keys are in this directory.

## User and Group Management

### Adding Users

#### Add a Single User
```bash
./scripts/ldap/users/add.sh "Firstname" "Lastname" "username@passbolt.com"

# Example: Add Edith Clarke
./scripts/ldap/users/add.sh "Edith" "Clarke" "edith@passbolt.com"
```

#### Quick Setup: Add Edith Clarke
```bash
./scripts/ldap/add-edith.sh
```

#### Verify User Addition
```bash
# Check if user was added to LDAP
docker compose exec ldap ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
  -b "dc=passbolt,dc=local" "(cn=username)"

# Run manual sync in Passbolt:
# 1. Log in to Passbolt as an administrator
# 2. Go to Organization Settings > Directory Synchronization
# 3. Click 'Synchronize Now'
```

### Managing Groups

#### Add a Group
```bash
./scripts/ldap/groups/add.sh <groupname> "<description>" [user1 user2 ...]

# Examples:
./scripts/ldap/groups/add.sh developers "Development Team" ada betty
./scripts/ldap/groups/add.sh developers "Development Team"  # Empty group
```

#### Remove a Group
```bash
./scripts/ldap/groups/remove.sh <groupname>
```

#### Add User to Group
```bash
./scripts/ldap/groups/add-user.sh <username> <groupname>
```

#### Remove User from Group
```bash
./scripts/ldap/groups/remove-user.sh <username> <groupname>
```

#### Verify Group Operations
```bash
docker compose exec ldap ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
  -b "dc=passbolt,dc=local" "(cn=<groupname>)"
```

### Testing User Removal and Reactivation

#### Configure Passbolt for User Suspension
Before testing user removal, ensure Passbolt is configured to suspend users rather than delete them:

1. Log in to Passbolt as an administrator
2. Go to Organization Settings > Directory Synchronization
3. Under "Synchronization Options", set:
   - "Delete Users" to "No"
   - "Default Group Manager" to your preferred setting
   - "Default Group Admin" to your preferred setting

#### Test User Suspension
```bash
# Remove user from LDAP
./scripts/ldap/users/remove.sh <username>

# Run manual sync in Passbolt to suspend the user
```

#### Test User Reactivation
```bash
# Add user back to LDAP
./scripts/ldap/users/add.sh "Firstname" "Lastname" "username@passbolt.com"

# Run manual sync in Passbolt to reactivate the user
```

## Testing and Verification

### LDAPS Connectivity Test
```bash
# Test LDAPS connection from Passbolt container
docker compose exec passbolt openssl s_client -connect ldap:636 \
  -servername ldap.local -CAfile /etc/ssl/certs/ldaps_bundle.crt -brief

# Test LDAPS connection from host (if certificates are trusted)
openssl s_client -connect ldap.local:636 -servername ldap.local -brief
```

### SMTP Service Status
```bash
# Check SMTP4Dev logs
docker compose logs smtp4dev

# Check Passbolt email logs
docker compose logs passbolt | grep -i email
```

### Valkey Session Storage Test
```bash
# Test Valkey connectivity
docker compose exec valkey valkey-cli ping

# List active sessions
docker compose exec valkey valkey-cli keys "*session*"
```

### LDAP Integration Tests
```bash
./scripts/tests/integration/test-ldap.sh
```

### Synchronization Tests
```bash
./scripts/tests/sync/test-sync.sh
```

### Script Testing Framework
```bash
./scripts/tests/scripts/test-scripts.sh
```

### SCIM API Testing with Bruno

Test Passbolt's SCIM (System for Cross-domain Identity Management) endpoints using Bruno API client.

#### Setup Bruno

1. **Install Bruno**: Download from [usebruno.com](https://www.usebruno.com/)
2. **Open Collection**: Open the `bruno/passbolt-scim-testing` folder in Bruno
3. **Configure Environment**: The `local` environment is pre-configured with:
   - Base URL: `https://passbolt.local`
   - SCIM Base URL: `https://passbolt.local/scim/v2/935452c2-7a21-4413-8457-8085b50376d3`
   - Bearer Token: `pb_wwpDka8H0AORBBVGcL8tU8xtJTJJI0etBO7F0QeshLj`
   - Content-Type: `application/scim+json`

#### SCIM Test Workflow

1. **Get Service Provider Config** - Verify SCIM is enabled
2. **List Users** - See existing users
3. **Create User** - Add a test user
4. **Get User by ID** - Verify user creation
5. **Update User** - Modify user attributes
6. **Patch User** - Partial update (e.g., deactivate)
7. **Search Users** - Find users with filters
8. **Delete User** - Remove test user

#### Passbolt SCIM Requirements

- **Email Type**: Passbolt requires `"type": "work"` in email objects
- **Authentication**: Uses Bearer token authentication
- **Content-Type**: Must be `application/scim+json`
- **User Schema**: Requires `userName`, `name`, and `emails` with work type

#### cURL Example

```bash
curl -k --request GET \
  --url 'https://passbolt.local/scim/v2/935452c2-7a21-4413-8457-8085b50376d3/Users?startIndex=1&count=100' \
  --header 'authorization: Bearer pb_wwpDka8H0AORBBVGcL8tU8xtJTJJI0etBO7F0QeshLj' \
  --header 'content-type: application/scim+json'
```
*Note: `-k` flag skips certificate verification for self-signed certificates in development.*

#### Common Issues

- **"Email not found" error**: Ensure email has `"type": "work"`
- **Authentication errors**: Verify bearer token is correct in environment
- **User not found**: Check if user exists in Passbolt first

### Manual Verification
```bash
# Check LDAP server status
docker compose exec ldap ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
  -b "dc=passbolt,dc=local" "(objectClass=*)"

# Check Passbolt logs
docker compose logs passbolt

# Check LDAP logs
docker compose logs ldap
```

## Troubleshooting

### Certificate Issues

#### Certificate Verification Failures
**Symptoms**: `verify error:num=19:self-signed certificate in certificate chain` or "Can't contact LDAP server"

**Root Cause**: The LDAP server uses its own self-signed certificate issued by `docker-light-baseimage`, but the certificate bundle is missing the CA certificate or contains incorrect certificates.

**Solutions**:
1. **Verify the certificate bundle contains both server and CA certificates:**
   ```bash
   # Check certificate count (should be 2)
   grep -c "BEGIN CERTIFICATE" certs/ldaps_bundle.crt
   
   # Check server certificate subject
   openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -A 2 -B 2 "Subject:" | head -3
   # Should show: Subject: CN=ldap.local
   ```

2. **If the bundle is incorrect, regenerate it:**
   ```bash
   # Run the certificate fix script (extracts from container)
   ./scripts/fix-ldaps-certificates.sh
   
   # Rebuild Passbolt container to pick up new bundle
   docker compose build passbolt
   docker compose up -d passbolt
   ```

3. **Verify the certificate SAN matches:**
   ```bash
   openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -A 5 "Subject Alternative Name"
   # Should show: DNS:ldap.local
   ```

#### Regenerate Certificates
```bash
# Step 1: Generate new certificate hierarchy
./scripts/generate-certificates.sh

# Step 2: Deploy certificates to LDAP container (optional - for custom certificates)
./scripts/setup-ldap-certs.sh

# Step 3: Fix LDAPS bundle for Passbolt (extracts from container)
./scripts/fix-ldaps-certificates.sh

# Step 4: Rebuild Passbolt container to pick up new certificate bundle
docker compose build passbolt
docker compose up -d passbolt
```

#### Verify Certificate Chain
```bash
# Verify LDAP certificate details
openssl x509 -in ldap-certs/ldap.crt -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"

# Verify certificate chain integrity
openssl verify -CAfile keys/rootCA.crt ldap-certs/ldap.crt

# Verify LDAPS bundle (used by Passbolt)
openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
```

### LDAPS Connection Issues
**Symptoms**: Passbolt cannot connect to LDAP server

**Solutions**:
- Verify LDAP server is running with TLS enabled
- Check that custom certificates are properly deployed
- Ensure network connectivity between containers

```bash
docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 \
  -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
  -b "dc=passbolt,dc=local" "(objectClass=*)"
```

### User Synchronization Issues
**Symptoms**: Users appear in LDAP but not in Passbolt

**Solutions**:
- Verify LDAP search filters are correct
- Check that users have the required `objectClass` attributes
- Ensure the bind DN has proper search permissions
- Run manual synchronization in Passbolt UI
- Check that users have valid email addresses (required for Passbolt)

**Note**: Remember that sync is one-way from LDAP to Passbolt. Changes to user data must be made in LDAP, not in Passbolt.

### LDAP Admin User Issues
**Symptoms**: "Can't contact LDAP server" during bind attempts

**Root Cause**: The LDAP admin user `cn=admin,dc=passbolt,dc=local` may be missing from the LDAP directory.

**Solutions**:
1. **Check if admin user exists:**
   ```bash
   docker exec ldap ldapsearch -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w "P4ssb0lt" -b "dc=passbolt,dc=local" -x "(cn=admin)"
   ```

2. **If admin user is missing, create it:**
   ```bash
   # Create admin user LDIF file
   cat > certs/admin_user.ldif << EOF
   dn: cn=admin,dc=passbolt,dc=local
   objectClass: simpleSecurityObject
   objectClass: organizationalRole
   cn: admin
   description: LDAP administrator
   userPassword: P4ssb0lt
   EOF
   
   # Add admin user to LDAP
   docker cp certs/admin_user.ldif ldap:/tmp/admin_user.ldif
   docker exec ldap ldapadd -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w "P4ssb0lt" -f /tmp/admin_user.ldif
   ```

3. **Verify admin user was created:**
   ```bash
   docker exec ldap ldapsearch -H ldaps://localhost:636 -D "cn=admin,dc=passbolt,dc=local" -w "P4ssb0lt" -b "dc=passbolt,dc=local" -x "(cn=admin)"
   ```

### Group Membership Issues
**Symptoms**: Group memberships not syncing to Passbolt

**Solutions**:
- Verify users have activated their Passbolt accounts
- Check that groups use `groupOfUniqueNames` object class
- Ensure member references use full DNs

#### LDAP Meta Backend DN Transformation Issue
**Symptoms**: Users sync to Passbolt but group memberships fail to sync, or incorrect users appear in groups

**Root Cause**: The LDAP meta backend's `suffixmassage` feature doesn't automatically transform DN references in attributes like `uniqueMember`. Group memberships contain DNs in the original backend format instead of the unified namespace format.

**Diagnosis**:
```bash
# Check group membership DNs through aggregator
docker exec ldap-meta ldapsearch -H ldap://localhost:389 -D "cn=admin,dc=unified,dc=local" -w "secret" -b "dc=unified,dc=local" "(cn=operations)"

# Check user DN in unified namespace
docker exec ldap-meta ldapsearch -H ldap://localhost:389 -D "cn=admin,dc=unified,dc=local" -w "secret" -b "dc=unified,dc=local" "(mail=user@example.com)"
```

**Solution**: The setup scripts have been updated to use the correct DN format from the start. If you encounter this issue with existing deployments, update group membership DNs to use the unified namespace format:
```bash
# Create LDIF file to fix group memberships
cat > fix_group_memberships.ldif << EOF
# Fix operations group
dn: cn=operations,ou=teams,dc=example,dc=com
changetype: modify
replace: uniqueMember
uniqueMember: cn=User Name,ou=people,dc=example,dc=unified,dc=local

# Fix project-teams group
dn: cn=project-teams,ou=teams,dc=example,dc=com
changetype: modify
replace: uniqueMember
uniqueMember: cn=User Name,ou=people,dc=example,dc=unified,dc=local
EOF

# Apply the fix to backend LDAP server
docker exec -i ldap2 ldapmodify -H ldap://localhost:389 -D "cn=admin,dc=example,dc=com" -w "Ex4mple123" < fix_group_memberships.ldif

# Clean up
rm fix_group_memberships.ldif
```

**Prevention**: The setup scripts now create groups with the correct DN format automatically. This issue should not occur in fresh deployments.

**Verification**: After applying the fix, run directory sync in Passbolt to verify group memberships are correctly synchronized.

### SSO Login Failures
**Symptoms**: SSO login doesn't work

**Solutions**:
- Verify the client ID and secret match between Keycloak and Passbolt
- Check that the redirect URI is correctly configured
- Ensure the user exists in both systems with matching email addresses

### Database Connection Issues
**Symptoms**: Keycloak fails to connect to the database

**Solutions**:
- Check database credentials in docker-compose.yaml
- Verify the keycloak database exists and permissions are set
- Check MariaDB logs for connection errors

### Email Not Sending
**Symptoms**: Passbolt emails not being sent

**Solutions**:
- Check certificate files exist and have correct permissions
- Verify SMTP configuration in Passbolt
- Check SMTP4Dev logs for connection issues

### Valkey Session Issues
**Symptoms**: Session handling failures, users getting logged out unexpectedly

**Solutions**:
- Verify Valkey container is running: `docker compose ps valkey`
- Check Valkey connectivity: `docker compose exec passbolt ping valkey`
- Check Valkey logs: `docker compose logs valkey`

### Traefik Configuration Issues
**Symptoms**: "no valid configuration found in file: /traefik.yaml"

**Cause**: Improperly indented YAML (usually from copying Passbolt docs).

**Fix**:
```bash
# Validate config
./scripts/validate-traefik-config.sh

# Check logs
docker compose logs traefik

# Verify indentation (use 2 spaces, no tabs)
grep -P '\t' config/traefik/*.yaml  # Should return nothing
```

YAML must use consistent spacing:
```yaml
# Wrong
api:
	dashboard: true

# Correct
api:
  dashboard: true
```

### Traefik Routing Issues
**Symptoms**: 404 errors, services not accessible

**Fix**:
- Check dashboard: http://localhost:8080
- Verify certificates exist in `keys/`
- Confirm Docker socket mounted: `/var/run/docker.sock:/var/run/docker.sock:ro`
- Check service has `traefik.enable=true` label

#### Manual Email Test
Send a test email using SMTP4Dev API:
```bash
curl -k -X POST https://smtp.local/api/v2/messages \
  -H "Content-Type: application/json" \
  -d '{
    "to": "test@example.com",
    "subject": "Test Email",
    "body": "This is a test email from Passbolt"
  }"
```

### File Permission Issues
**Symptoms**: Docker mount errors or "permission denied"

**Solutions**:
```bash
chmod 644 certs/*.crt smtp4dev/certs/*.crt
chmod 600 keys/*.key smtp4dev/certs/*.key
chmod 644 smtp4dev/certs/tls.pfx
```

### osixia/openldap Specific Issues

#### LDAP Container Configuration Issues
**Symptoms**: LDAPS connection fails after modifying docker-compose.yaml

**Root Cause**: Adding incorrect environment variables to the osixia/openldap container can break its internal certificate management.

**Solutions**:
1. **Use only documented environment variables** from the osixia/openldap documentation:
   ```yaml
   # Basic Configuration
   LDAP_ORGANISATION: "Passbolt"
   LDAP_DOMAIN: "passbolt.local"
   LDAP_BASE_DN: "dc=passbolt,dc=local"
   LDAP_ADMIN_PASSWORD: "P4ssb0lt"
   LDAP_CONFIG_PASSWORD: "P4ssb0lt"
   
   # TLS Configuration
   LDAP_TLS: "true"
   LDAP_TLS_VERIFY_CLIENT: "never"
   
   # Readonly User
   LDAP_READONLY_USER: "true"
   LDAP_READONLY_USER_USERNAME: "readonly"
   LDAP_READONLY_USER_PASSWORD: "readonly"
   ```

2. **Avoid custom LDAP_TLS_* variables** that are not in the official documentation
3. **Restart the LDAP container after changes:**
   ```bash
   docker compose restart ldap
   ```

#### Certificate Issues with osixia/openldap
**Symptoms**: "Can't contact LDAP server" or certificate verification failures

**Root Cause**: The osixia/openldap image generates its own self-signed certificates using the `docker-light-baseimage` CA.

**Solutions**:
1. **Verify the certificate chain:**
   ```bash
   # Check LDAP server certificate
   docker compose exec ldap openssl x509 -in /container/service/slapd/assets/certs/ldap.crt -text -noout | grep -A 2 -B 2 "Subject:"
   
   # Check CA certificate
   docker compose exec ldap openssl x509 -in /container/service/slapd/assets/certs/ca.crt -text -noout | grep -A 2 -B 2 "Subject:"
   ```

2. **Verify certificate bundle in Passbolt:**
   ```bash
   # Check the certificate bundle used by Passbolt
   openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -A 2 -B 2 "Subject:"
   # Should show: CN=ldap.local
   ```

3. **Regenerate certificate bundle if needed:**
   ```bash
   ./scripts/fix-ldaps-certificates.sh
   docker compose build passbolt
   docker compose up -d passbolt
   ```

#### LDAP Connection Issues
**Symptoms**: Passbolt cannot connect to LDAP server

**Solutions**:
- Verify LDAP server is running with TLS enabled
- Check that custom certificates are properly deployed
- Ensure network connectivity between containers

```bash
docker compose exec ldap ldapsearch -x -H ldaps://localhost:636 \
  -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
  -b "dc=passbolt,dc=local" "(objectClass=*)"
```

#### STARTTLS vs LDAPS Configuration
**Symptoms**: STARTTLS works externally but not from Passbolt container

**Root Cause**: This is expected behavior. The osixia/openldap image supports both:
- LDAPS (implicit TLS) on port 636 - used by Passbolt
- LDAP with STARTTLS on port 389 - another option for Passbolt

**Solutions**:
- For Passbolt: Use LDAPS on port 636 (current configuration)
- For another option: Use LDAP with STARTTLS on port 389
- Both methods work with the same certificate configuration

#### Verify Certificate Files Exist
```bash
ls -la certs/ldaps_bundle.crt
ls -la smtp4dev/certs/tls.crt smtp4dev/certs/tls.pfx
ls -la ldap-certs/ldap.crt ldap-certs/ldap.key ldap-certs/ca.crt
ls -la keys/rootCA.crt keys/keycloak.crt
```

#### Verify Subscription Key
```bash
ls -la subscription_key.txt
# Should show: lrwxr-xr-x ... subscription_key.txt -> /path/to/actual/key
```

### Database Growth Diagnostics

If backup size increases unexpectedly, use the diagnostic script to identify the cause:

```bash
# Run against local demo database (formatted columns)
docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt < scripts/diagnose-db-growth.sql | column -t

# Or save to file
docker compose exec -T db mariadb -u passbolt -pP4ssb0lt passbolt < scripts/diagnose-db-growth.sql > db-diagnosis.txt

# Or against production MySQL (formatted)
mysql -u user -p database < scripts/diagnose-db-growth.sql | column -t
```

**Interpreting Results:**

1. **Largest tables** - Focus on tables >100MB. `action_logs` is often the culprit.
2. **Soft deletes** - High `deleted` counts mean records aren't being purged. Example: `users 37 total, 25 deleted` = 68% are soft-deleted.
3. **Action logs** - Check `logs_last_30d` vs `logs_last_60d`. Rapid growth indicates database logging even with file logging enabled.
4. **History tables** - `*_history` tables accumulate over time. Check their sizes.
5. **Secrets table** - `total_secret_data_mb` shows actual encrypted data size. Compare `avg_secret_size_bytes` before/after v5 migration.
6. **V5 migration** - `first_created` date shows when v5 migration occurred. Correlate with backup size increase timeline.
7. **Email queue** - Stuck emails accumulate if not processed.
8. **Binary logs** - Check separately as root (see "Possible causes" below for commands). File-level backups include binary logs (mysqldump does not).

**Possible causes:**
- **Binary logs not purged** - MySQL 8.0+ enables binary logging by default (5.7 and earlier: disabled). If `expire_logs_days=0` or `binlog_expire_logs_seconds=0`, logs never auto-purge. **File-level backups include binary logs** (mysqldump does not). Check as root:
  ```bash
  mysql -u root -p -e "SHOW BINARY LOGS;"
  mysql -u root -p -e "SHOW VARIABLES LIKE 'expire_logs_days';"
  ```
  Even with "no significant API hits", internal writes (syncs, maintenance) generate binary log entries.
- Action logs in database (even with file logging enabled)
- Soft deletes accumulating over time
- V5 encryption increasing secret sizes

### Log Analysis

#### Passbolt Logs
```bash
docker compose logs passbolt
docker compose logs -f passbolt
```

#### LDAP Logs
```bash
docker compose logs ldap
docker compose exec ldap ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=passbolt,dc=local" -w P4ssb0lt \
  -b "cn=config" "(objectClass=*)"
```

## Repository Structure

Key directories:
- `scripts/` - Setup and management scripts
- `certs/` - Certificate files (LDAPS bundle, SMTP certificates)
- `config/` - Configuration files (PHP, SSL, database)
- `assets/` - Documentation screenshots
- `docker-compose.yaml` - Main configuration

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License (AGPL) as published by the Free Software Foundation version 3.

The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate agreement with Passbolt SA.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.html).
