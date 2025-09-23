# Passbolt Pro Demonstration Stack

> Demo Environment: This repository contains demo credentials and self-signed certificates for testing only. Do not use in production without proper security configuration.

## What This Demonstrates

- Passbolt Pro with OIDC SSO integration (Keycloak over HTTPS)
- LDAP result aggregation from multiple directory servers using OpenLDAP meta backend
- LDAPS (implicit TLS) for secure LDAP connections with domain-specific certificates
- SMTPS for secure email communication
- Valkey session handling for improved performance
- Certificate automation for development and testing
- Multi-directory user synchronization for enterprise environments

## Prerequisites

- Docker and Docker Compose installed
- Passbolt Pro subscription key
- Basic knowledge of LDAP, Keycloak, and Docker
- Local development environment (macOS/Linux)

## Table of Contents

- [Quick Start](#quick-start)
- [LDAP Aggregation](#ldap-aggregation)
- [Services Overview](#services-overview)
- [LDAPS Configuration](#ldaps-configuration)
- [Valkey Session Handling](#valkey-session-handling)
- [Keycloak SSO Configuration](#keycloak-sso-configuration)
- [SMTP Configuration](#smtp-configuration)
- [User and Group Management](#user-and-group-management)
- [Testing and Verification](#testing-and-verification)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Automated Setup

#### LDAP Aggregation Demo (Recommended)
Use the complete aggregation setup script for the full merger scenario:
```bash
./scripts/setup-aggregation-demo.sh
```

This script will:
- Set up LDAP1 (Passbolt Inc.) with historical computing pioneers
- Set up LDAP2 (Example Corp.) with modern tech professionals
- Configure OpenLDAP meta backend for result aggregation
- Generate ECC GPG keys for all demo users (passphrase = email)
- Create Passbolt admin user 'ada' (exists in LDAP before creation)
- Demonstrate enterprise LDAP aggregation for company mergers

#### Basic Single LDAP Setup
Use the original setup script for single directory:
```bash
./scripts/setup.sh
```

This script provides the basic single LDAP setup without aggregation.

### Manual Setup

1. Add host entries:
   ```bash
   echo "127.0.0.1 passbolt.local keycloak.local ldap.local smtp.local" | sudo tee -a /etc/hosts
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

5. Start the environment (LDAP aggregation is now default):
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

8. Configure LDAPS in Passbolt:
   - Log in to Passbolt as an administrator
   - Go to Organization Settings > Users Directory
   - Configure LDAPS settings (see LDAPS Configuration section)

> Important: The order of operations is crucial. LDAP users must be set up before creating the Passbolt admin user to ensure proper synchronization.

> SMTP Configuration Note: When configuring SMTP in Passbolt UI, set "Use TLS" to No because SMTPS (implicit TLS) is used (enabled via `ssl://smtp.local`). The certificate CN must match `smtp.local`.

> Required: Valid Passbolt Pro subscription key in `subscription_key.txt` in the project root.

> Demo Credentials: All passwords and credentials in this repository are for demonstration purposes only. In production, use strong, unique credentials and proper certificate authorities.

## Multi-Domain LDAP Synchronization

This setup demonstrates multi-domain LDAP directory synchronization using Passbolt's PHP configuration. Multiple LDAP directories are aggregated at the application level for unified user and group management.

### Configuration

Multi-domain LDAP synchronization is the default setup:
```bash
docker compose up -d
```

For single LDAP directory (basic demo):
```bash
docker compose -f docker-compose.single-ldap.yaml up -d
```

### Architecture

- **ldap1**: Passbolt Inc. directory (dc=passbolt,dc=local)
- **ldap2**: Example Corp directory (dc=example,dc=com)
- **Passbolt**: Aggregates users and groups from both directories via PHP configuration

### Multi-Domain Configuration

- **LDAP1**: `ldap1.local:636` (LDAPS) - Passbolt Inc. (Historical computing pioneers)
- **LDAP2**: `ldap2.local:636` (LDAPS) - Example Corp (Modern tech professionals)
- **Configuration**: `config/passbolt/ldap.php` - Defines both domains with LDAPS security

### Technical Implementation

The multi-domain LDAP synchronization uses Passbolt's PHP configuration to achieve application-level aggregation:

#### **Multi-Domain Configuration**
- **Purpose**: Defines multiple LDAP domains in a single PHP configuration file
- **LDAP1 domain**: `passbolt` domain connecting to `ldap1.local:389`
- **LDAP2 domain**: `example` domain connecting to `ldap2.local:389`
- **Authentication**: Each domain uses its own service account credentials

#### **Application-Level Aggregation**
- **Sync process**: Passbolt queries both LDAP servers during directory sync
- **User aggregation**: Users from both domains imported into single Passbolt instance
- **Group aggregation**: Groups from both domains created with proper memberships
- **Field mapping**: OpenLDAP `uniqueMember` attribute mapped for group membership resolution

#### **Key Configuration Elements**
- **Domain definitions**: Each LDAP server defined as separate domain in PHP config
- **Field mapping**: `fieldsMapping` specifies `uniqueMember` for OpenLDAP group membership
- **Object classes**: `inetOrgPerson` for users, `groupOfUniqueNames` for groups
- **Directory paths**: Domain-specific `user_path` and `group_path` for different OU structures

#### **Why This Works**
- **Native support**: Uses Passbolt's built-in multi-domain LDAP capabilities
- **No proxy needed**: Direct connection to each LDAP server
- **Automatic sync**: Hourly cron job keeps users and groups synchronized
- **Scalable**: Can add more domains by extending the PHP configuration

### Implementation Approach

This repository implements multi-domain LDAP synchronization using Passbolt's native PHP configuration:

#### **Configuration Architecture**
- **Base approach**: PHP configuration file defines multiple LDAP domains
- **No proxy needed**: Direct connections to each LDAP server
- **Configuration method**: Static PHP file (`config/passbolt/ldap.php`) for version control

#### **Key Implementation Files**
- **`config/passbolt/ldap.php`**: Multi-domain LDAP configuration with field mappings
- **`docker-compose.yaml`**: Service orchestration for both LDAP servers
- **`/etc/cron.hourly/passbolt-directory-sync`**: Automatic synchronization script

#### **Configuration Strategy**
- **Multi-domain setup**: Each LDAP server defined as separate domain
- **Field mapping**: Explicit mapping of `uniqueMember` for group membership resolution
- **Automatic sync**: Hourly cron job ensures continuous synchronization
- **Domain-specific paths**: Custom `user_path` and `group_path` for different directory structures

### References

- **Passbolt LDAP Documentation**: https://www.passbolt.com/configure/ldap
- **LdapRecord Multi-Domain**: https://ldaprecord.com/docs/laravel/v2/configuration
- **OpenLDAP Admin Guide**: https://www.openldap.org/doc/admin24/
- **RFC 4511 (LDAP Protocol)**: https://tools.ietf.org/html/rfc4511

### Passbolt Configuration

Passbolt is configured via the PHP file (`config/passbolt/ldap.php`) which defines both LDAP domains:

**LDAP1 (Passbolt Inc.):**
- Server: ldap1.local
- Port: 389
- Base DN: dc=passbolt,dc=local
- Username: cn=readonly,dc=passbolt,dc=local
- Password: readonly

**LDAP2 (Example Corp.):**
- Server: ldap2.local
- Port: 389
- Base DN: dc=example,dc=com
- Username: cn=reader,dc=example,dc=com
- Password: reader123

**Note**: Configuration is handled entirely through the PHP file - no web UI LDAP configuration needed

## Services Overview

| Service   | URL                       | Credentials        | Purpose |
|-----------|---------------------------|-------------------|---------|
| Passbolt  | https://passbolt.local    | Created during setup | Main application |
| Keycloak  | https://keycloak.local:8443 | admin / admin    | SSO provider |
| SMTP4Dev  | http://smtp.local:5050    | N/A               | Email testing |
| LDAP1     | ldap1.local:389 (LDAPS/STARTTLS) | cn=readonly,dc=passbolt,dc=local / readonly | Passbolt Inc. directory |
| LDAP2     | ldap2.local:389 (LDAPS/STARTTLS) | cn=reader,dc=example,dc=com / reader123 | Example Corp directory |
| Valkey    | valkey:6379 (internal)    | N/A               | Session storage and caching |

## Valkey Session Handling

This setup uses Valkey for session storage instead of file-based sessions. Valkey is Redis-compatible and provides better performance and scalability.

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

The Docker Compose configuration uses environment variables that are documented in the official Passbolt documentation:

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
- **Directory Sync detailed configuration** (host, port, credentials, filters) is done via Passbolt Web UI, not environment variables
- **PHP TLS configuration** is handled in `config/php/ssl.ini`, not as Passbolt environment variables
- All environment variables used are documented in the official Passbolt documentation

## LDAPS Configuration

### Security Features

This setup implements LDAPS (LDAP over SSL/TLS) for secure directory synchronization:

- **Encryption**: All LDAP connections use LDAPS (port 636) with SSL/TLS
- **Certificate Validation**: Domain-specific CA certificates for certificate validation
- **Authentication**: Read-only LDAP service accounts
- **Multi-Domain**: Both LDAP domains use encrypted connections

### Configuration Details

**LDAP1 (Passbolt Inc.):**
- Server: ldap1.local
- Port: 636 (LDAPS)
- Security: `use_ssl => true`
- Certificate: Domain-specific CA certificate validation

**LDAP2 (Example Corp.):**
- Server: ldap2.local  
- Port: 636 (LDAPS)
- Security: `use_ssl => true`
- Certificate: Domain-specific CA certificate validation

### Certificate Management

The setup uses domain-specific CA certificates for LDAPS connections:

- **ldap1-ca.crt**: CA certificate for ldap1.local domain
- **ldap2-ca.crt**: CA certificate for ldap2.local domain
- **Certificate validation**: `LDAP_OPT_X_TLS_REQUIRE_CERT => LDAP_OPT_X_TLS_NEVER` for self-signed certs

### Testing LDAPS

```bash
# Test LDAPS connectivity
docker compose exec passbolt php -r "
\$ldap = ldap_connect('ldaps://ldap1.local', 636);
ldap_set_option(\$ldap, LDAP_OPT_PROTOCOL_VERSION, 3);
ldap_set_option(\$ldap, LDAP_OPT_X_TLS_REQUIRE_CERT, LDAP_OPT_X_TLS_NEVER);
\$bind = ldap_bind(\$ldap, 'cn=readonly,dc=passbolt,dc=local', 'readonly');
echo \$bind ? 'LDAPS: SUCCESS' : 'LDAPS: FAILED';
ldap_close(\$ldap);
"

# Test Passbolt directory sync with LDAPS
docker compose exec passbolt su -s /bin/bash -c "/usr/share/php/passbolt/bin/cake directory_sync all --persist --quiet" www-data
```

## LDAP Configuration

### osixia/openldap Docker Image

This setup uses the osixia/openldap:1.5.0 Docker image, which provides a fully configured OpenLDAP server with TLS support. The image is based on osixia/light-baseimage and includes automatic certificate generation and LDAP configuration.

### LDAP Server Environment Variables

The LDAP container is configured with the following environment variables:

```yaml
# Basic LDAP Configuration
LDAP_ORGANISATION: "Passbolt"
LDAP_DOMAIN: "passbolt.local"
LDAP_BASE_DN: "dc=passbolt,dc=local"
LDAP_ADMIN_PASSWORD: "P4ssb0lt"
LDAP_CONFIG_PASSWORD: "P4ssb0lt"

# TLS Configuration
LDAP_TLS: "true"                    # Enables TLS capabilities (both LDAPS (implicit TLS) and LDAP with STARTTLS)
LDAP_TLS_VERIFY_CLIENT: "never"     # Allows unverified client certificates

# Readonly User (for Passbolt directory sync)
LDAP_READONLY_USER: "true"
LDAP_READONLY_USER_USERNAME: "readonly"
LDAP_READONLY_USER_PASSWORD: "readonly"

# User and Group Structure
LDAP_USERS_DN: "ou=users,dc=passbolt,dc=local"
LDAP_GROUPS_DN: "ou=groups,dc=passbolt,dc=local"
```

### LDAP Connection Options

The setup supports two LDAP connection methods:

- **LDAPS (implicit TLS)**: Port 636 (typically) - Currently used by Passbolt
- **LDAP with STARTTLS**: Port 389 (typically) - Another option for Passbolt

Both methods use the same certificate configuration and are automatically enabled via `LDAP_TLS=true`.

### osixia/openldap Features

The osixia/openldap image provides several key features:

#### Automatic Certificate Generation
- Self-signed certificates: Generated automatically using the container hostname
- Certificate location: `/container/service/slapd/assets/certs/`
- Files created:
  - `ldap.crt` - Server certificate
  - `ldap.key` - Private key
  - `ca.crt` - CA certificate (docker-light-baseimage)
  - `dhparam.pem` - DH parameters
- Certificate extraction: The `fix-ldaps-certificates.sh` script automatically extracts these certificates from the running container to create the certificate bundle used by Passbolt

#### TLS Configuration
- LDAP_TLS=true: Enables both LDAPS (implicit TLS) (port 636 typically) and LDAP with STARTTLS (port 389 typically)
- LDAP_TLS_VERIFY_CLIENT=never: Allows unverified client certificates
- Automatic TLS setup: No manual certificate configuration required

#### User Management
- Admin user: `cn=admin,dc=passbolt,dc=local` with password `P4ssb0lt`
- Readonly user: `cn=readonly,dc=passbolt,dc=local` with password `readonly`
- Automatic user creation: Users and groups created via bootstrap LDIF files

### Certificate Management

The setup uses a streamlined certificate process that extracts certificates directly from the LDAP container:

1. `./scripts/generate-certificates.sh` - Creates SMTP certificates only
2. `./scripts/fix-ldaps-certificates.sh` - Extracts LDAP certificates from container:
   - Extracts server certificate from `/container/service/slapd/assets/certs/ldap.crt`
   - Extracts CA certificate from `/container/service/slapd/assets/certs/ca.crt`
   - Creates `certs/ldaps_bundle.crt` with both server and CA certificates
   - Creates `certs/ldap-local.crt` with server certificate only (backward compatibility)
   - Built into Passbolt container during build process
   - Called automatically by `setup.sh`

### Passbolt Configuration

The setup is configured with basic Directory Sync settings via environment variables. Detailed LDAP connection settings (host, port, credentials, etc.) are configured through the Passbolt Web UI.

**Environment Variables (docker-compose.yaml):**
```yaml
# Directory Sync Plugin (basic settings only - Note: Currently not working, see task PB-45139 for fix)
PASSBOLT_PLUGINS_DIRECTORY_SYNC_ENABLED: "true"
```

**Web UI Configuration:**
- Access Passbolt as administrator
- Go to Organization Settings > Users Directory
- Configure LDAP connection details (host, port, credentials, filters, etc.)
- The setup supports both LDAPS (port 636) and LDAP with STARTTLS (port 389)

### Certificate System Overview

- Root CA: Self-signed Certificate Authority (`keys/rootCA.crt`)
- LDAP Certificate: The LDAP server uses its own self-signed certificate (issued by `docker-light-baseimage`)
- LDAPS Bundle: Contains the CA certificate from the LDAP server for Passbolt verification
- SMTP Certificate: For secure email communication
- Keycloak Certificate: For SSO integration

### LDAP Directory Structure

```
dc=passbolt,dc=local
├── ou=users
│   ├── cn=ada (Ada Lovelace - ada@passbolt.com)
│   ├── cn=betty (Betty Holberton - betty@passbolt.com)
│   ├── cn=carol (Carol Shaw - carol@passbolt.com)
│   ├── cn=dame (Dame Stephanie Shirley - dame@passbolt.com)
│   └── cn=edith (Edith Clarke - edith@passbolt.com)
└── ou=groups
    ├── cn=passbolt (Main user group)
    ├── cn=developers (Development team)
    ├── cn=demoteam (Demo team)
    └── cn=admins (Administrators)
```

### Passbolt LDAP Settings

Configure in Passbolt web interface under Organization Settings > Directory:
- Host: `ldap.local`
- Port: `636` (LDAPS - implicit TLS) or `389` (LDAP with STARTTLS)
- Username: `cn=readonly,dc=passbolt,dc=local`
- Password: `readonly`
- Base DN: `dc=passbolt,dc=local`
- Verify TLS certificate: Checked (certificate bundle is trusted)

> Note: The readonly user is automatically created by the LDAP container and has read-only access to the directory, which is the recommended approach for Passbolt directory synchronization. Passbolt directory sync is one-way read-only - it reads user and group data from LDAP but does not write back to LDAP.

#### Directory Settings
- Users Path: `ou=users`
- Group Path: `ou=groups`
- User Filter: `(objectClass=inetOrgPerson)`
- Group Filter: `(objectClass=groupOfUniqueNames)`

#### Attributes
- Username: `mail`
- Group: `cn`
- First Name: `givenName`
- Last Name: `sn`
- Email: `mail`

#### TLS Configuration
- TLS Verification: Enabled
- CA Certificate: Built into container (automatically configured)
- Allow Self-Signed: Enabled

> Note: The LDAP server's certificate is automatically downloaded and built into the Passbolt container during setup, allowing Passbolt to verify the LDAP connection securely.

> Important: The LDAP admin user `cn=admin,dc=passbolt,dc=local` is automatically created during the setup process for administrative operations. For Passbolt directory synchronization, use the readonly user `cn=readonly,dc=passbolt,dc=local` which is also automatically created by the LDAP container.

### Directory Synchronization
One-way read-only from LDAP to Passbolt. LDAP serves as the source of truth for user identity and group membership. Passbolt reads user/group data during sync but never writes back to LDAP.

## Keycloak SSO Configuration

### Environment Setup

The setup uses:
- Passbolt Pro with OIDC plugin
- Keycloak 26.3.0
- MariaDB for both Passbolt and Keycloak databases
- Shared certificate system

### Database Configuration

Shared MariaDB instance with separate databases:
- `passbolt` database for Passbolt
- `keycloak` database for Keycloak

The `init-keycloak-db.sql` script creates the Keycloak database and grants permissions.

### Certificate Trust Flow

```
Browser/Client → keycloak.crt → rootCA.crt → Trusted Root Store
```

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
     - Copy the "Client secret" value
     - Default value: "9cBUxO4c68E7SYJJJPJ8FjtIDLgMdHqi"

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
- **Client ID**: `passbolt-client`
- **Client Secret**: `9cBUxO4c68E7SYJJJPJ8FjtIDLgMdHqi`
- **Scopes**: `openid profile email`
- **SSL Verification**: Enabled

### Testing SSO Integration

1. Access Passbolt at https://passbolt.local
2. Click "SSO Login"
3. Redirected to Keycloak
4. Log in with ada@passbolt.com / passbolt
5. Redirected back to Passbolt and logged in

### Screenshots

See `assets/` directory for configuration screenshots:
- Keycloak client configuration
- Keycloak user setup  
- Passbolt SSO configuration
- Passbolt OIDC login

## SMTP Configuration

### Services Overview

- SMTP4Dev: http://smtp.local:5050 (port 465 typically, SMTPS (implicit TLS))

### Current Configuration

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

#### Manual Email Test
Send a test email using SMTP4Dev API:
```bash
curl -X POST http://smtp.local:5050/api/v2/messages \
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

## Use Cases

This example repository is useful for:

- Learning: Understanding Passbolt Pro SSO and LDAPS integration
- Testing: Validating configurations before production deployment
- Development: Local development environment for Passbolt integrations
- Demonstration: Showing integration capabilities

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
