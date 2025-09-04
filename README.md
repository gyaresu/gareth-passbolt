lect # Passbolt Pro Demonstration Stack

**Example/Demo Repository** - Docker Compose setup for testing and demonstrating Passbolt Pro with SSO integration, LDAPS directory synchronization, and TLS/SSL security for web services, LDAP, and SMTP.

> **⚠️ Demo Environment**: This repository contains demo credentials and self-signed certificates for testing purposes only. Do not use in production without proper security configuration.

## What This Demonstrates

- **Passbolt Pro** with OIDC SSO integration (Keycloak over TLS)
- **LDAP over TLS** for directory synchronization
- **SMTP over TLS** for secure email communication
- **HTTP over TLS** for Passbolt and Keycloak web interfaces
- **Testing environment** with email, database, and user management
- **Certificate automation** for development and testing scenarios

## Prerequisites

- Docker and Docker Compose installed
- Passbolt Pro subscription key
- Basic knowledge of LDAP, Keycloak, and Docker
- Local development environment (macOS/Linux)

## Table of Contents

- [Quick Start](#quick-start)
- [Services Overview](#services-overview)
- [LDAPS Configuration](#ldaps-configuration)
- [Keycloak SSO Configuration](#keycloak-sso-configuration)
- [SMTP Configuration](#smtp-configuration)
- [User and Group Management](#user-and-group-management)
- [Testing and Verification](#testing-and-verification)
- [Troubleshooting](#troubleshooting)
- [Repository Structure](#repository-structure)

## Quick Start

### Automated Setup
For the fastest setup, use the automated setup script:
```bash
./scripts/setup.sh
```

This script will:
- Check for required certificate files
- Verify Docker installation
- Start all services
- **Automatically fix LDAPS certificate bundle** (critical for LDAP connectivity)
- Restart Passbolt to pick up the correct certificates
- **Automatically create admin user 'ada'** (sends registration email to SMTP4Dev)
- Provide access URLs

### Manual Setup

1. **Add host entries:**
   ```bash
   echo "127.0.0.1 passbolt.local keycloak.local ldap.local smtp.local" | sudo tee -a /etc/hosts
   ```

2. **Add Passbolt Pro subscription key:**
   ```bash
   cp /path/to/your/subscription_key.txt ./subscription_key.txt
   ```

3. **Generate SSL certificates:**
   ```bash
   ./scripts/generate-certificates.sh
   ```

4. **Make scripts executable:**
   ```bash
   chmod +x scripts/ldap/*/*.sh scripts/tests/*/*.sh
   ```

5. **Start the environment:**
   ```bash
   docker compose up -d
   ```

6. **Setup LDAP test data:**
   ```bash
   ./scripts/ldap/setup/initial-setup.sh
   ```

7. **Create the default admin user (optional - now automatic in setup.sh):**
   ```bash
   ./scripts/ldap/setup/create-admin.sh
   ```

8. **Configure LDAPS in Passbolt:**
   - Log in to Passbolt as an administrator
   - Go to Organization Settings > Users Directory
   - Configure LDAPS settings (see LDAPS Configuration section)

> **Important**: The order of operations is crucial. LDAP users must be set up before creating the Passbolt admin user to ensure proper synchronization.

> **SMTP Configuration Note**: When configuring SMTP in Passbolt UI, set "Use TLS" to **No** because TLS is implicit (enabled via `ssl://smtp.local`). The certificate CN must match `smtp.local`.

> **Required**: Valid Passbolt Pro subscription key in `subscription_key.txt` in the project root.

> **Demo Credentials**: All passwords and credentials in this repository are for demonstration purposes only. In production, use strong, unique credentials and proper certificate authorities.

## Services Overview

| Service   | URL                       | Credentials        | Purpose |
|-----------|---------------------------|-------------------|---------|
| Passbolt  | https://passbolt.local    | Created during setup | Main application |
| Keycloak  | https://keycloak.local:8443 | admin / admin    | SSO provider |
| SMTP4Dev  | http://smtp.local:5050    | N/A               | Email testing |
| LDAP      | ldap.local:636 (LDAPS)    | cn=readonly,dc=passbolt,dc=local / readonly | User directory (read-only sync) |

## LDAP Configuration

### LDAP Connection Options

The setup supports two LDAP connection methods:

#### Default: LDAPS (Implicit SSL) - Currently Working
- **Port**: 636  
- **Method**: LDAPS (implicit SSL/TLS)
- **Compatibility**: Works reliably with current LDAP server configuration
- **Setup**: Automatic via `./scripts/setup.sh`

#### Alternative: LDAP with STARTTLS (Not Currently Working)
- **Port**: 389
- **Method**: STARTTLS (explicit TLS upgrade)
- **Compatibility**: LDAP server requires TLS for all connections
- **Setup**: Requires LDAP server configuration changes

### Certificate Management

The setup uses a streamlined certificate process that **downloads certificates from the LDAP server**:

1. **`./scripts/generate-certificates.sh`** - Creates SMTP certificates only
2. **`./scripts/fix-ldaps-certificates.sh`** - Downloads LDAP server certificate:
   - Extracts actual certificate from running LDAP server
   - Creates `certs/ldap-local.crt` with the server's certificate
   - Built into Passbolt container during build process
   - **Called automatically by `setup.sh`**

### Switching to STARTTLS (Alternative Configuration)

To use STARTTLS instead of LDAPS, edit `docker-compose.yaml`:

```yaml
# Change these lines in the passbolt service environment:
PASSBOLT_PLUGINS_DIRECTORY_SYNC_DIRECTORY_PORT: "389"
PASSBOLT_PLUGINS_DIRECTORY_SYNC_DIRECTORY_USE_SSL: "false"
PASSBOLT_PLUGINS_DIRECTORY_SYNC_DIRECTORY_USE_TLS: "true"
```

Then rebuild the container:
```bash
docker compose build passbolt
docker compose up -d passbolt
```

**Note**: STARTTLS requires the LDAP server to be configured to allow plain connections on port 389, which is not currently the case. The LDAP server is configured to require TLS for all connections.

### Certificate System Overview

- **Root CA**: Self-signed Certificate Authority (`keys/rootCA.crt`)
- **LDAP Certificate**: The LDAP server uses its own self-signed certificate (issued by `docker-light-baseimage`)
- **LDAPS Bundle**: Contains the CA certificate from the LDAP server for Passbolt verification
- **SMTP Certificate**: For secure email communication
- **Keycloak Certificate**: For SSO integration

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

#### Server Configuration (LDAPS - Default)
- **Host**: `ldap.local`
- **Port**: `636`
- **Use SSL**: ✅ **Checked** (implicit SSL/TLS)
- **Use TLS**: ❌ **Unchecked**
- **Verify SSL/TLS certificate**: ✅ **Checked** (certificate is trusted)
- **Username**: `cn=readonly,dc=passbolt,dc=local`
- **Password**: `readonly`
- **Domain**: `passbolt.local`
- **Base DN**: `dc=passbolt,dc=local`

#### Server Configuration (STARTTLS - Alternative)
- **Host**: `ldap.local`
- **Port**: `389`
- **Use SSL**: ❌ **Unchecked** (we're using STARTTLS, not SSL)
- **Use TLS**: ✅ **Checked** (this enables STARTTLS)
- **Verify SSL/TLS certificate**: ✅ **Checked** (certificate is trusted)
- **Username**: `cn=readonly,dc=passbolt,dc=local` (recommended for security)
- **Password**: `readonly`
- **Domain**: `passbolt.local`
- **Base DN**: `dc=passbolt,dc=local`

> **Note**: The readonly user is automatically created by the LDAP container and has read-only access to the directory, which is the recommended approach for Passbolt directory synchronization. Passbolt directory sync is **one-way read-only** - it reads user and group data from LDAP but does not write back to LDAP.

#### Directory Settings
- **Users Path**: `ou=users`
- **Group Path**: `ou=groups`
- **User Filter**: `(objectClass=inetOrgPerson)`
- **Group Filter**: `(objectClass=groupOfUniqueNames)`

#### Attributes
- **Username**: `mail`
- **Group**: `cn`
- **First Name**: `givenName`
- **Last Name**: `sn`
- **Email**: `mail`

#### SSL Configuration
- **SSL Verification**: `Enabled`
- **CA Certificate**: Built into container (automatically configured)
- **Allow Self-Signed**: `Enabled`

> **Note**: The LDAP server's certificate is automatically downloaded and built into the Passbolt container during setup, allowing Passbolt to verify the LDAP connection securely.

> **Important**: The LDAP admin user `cn=admin,dc=passbolt,dc=local` is automatically created during the setup process for administrative operations. For Passbolt directory synchronization, use the readonly user `cn=readonly,dc=passbolt,dc=local` which is also automatically created by the LDAP container.

### Directory Synchronization
**One-way read-only** from LDAP to Passbolt. LDAP serves as the source of truth for user identity and group membership. Passbolt reads user/group data during sync but never writes back to LDAP.

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

**Keycloak Client Configuration**

<img src="./assets/keycloak_client.png" alt="Keycloak Client Configuration" width="600">

**Keycloak User Setup**

<img src="./assets/keycloak_user.png" alt="Keycloak User Setup" width="600">

**Passbolt SSO Configuration**

<img src="./assets/passbolt_config.png" alt="Passbolt SSO Configuration" width="600">

**Passbolt OIDC Login**

<img src="./assets/passbolt_oidc_login.png" alt="Passbolt OIDC Login" width="600">

## SMTP Configuration

### Services Overview

- **SMTP4Dev**: http://smtp.local:5050 (port 465, implicit TLS)

### Current Configuration

Passbolt configured to use SMTP4Dev with TLS:

```yaml
EMAIL_TRANSPORT_DEFAULT_HOST: "ssl://smtp.local"
EMAIL_TRANSPORT_DEFAULT_PORT: 25
EMAIL_TRANSPORT_DEFAULT_USERNAME: ""
EMAIL_TRANSPORT_DEFAULT_PASSWORD: ""
EMAIL_DEFAULT_FROM: "admin@passbolt.com"
```

### TLS Certificate Setup

```bash
# Create certificates directory
mkdir -p smtp4dev/certs

# Generate private key and certificate
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

#### Quick Setup: Add a Single User
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

#### Reset Groups to Initial State
```bash
./scripts/ldap/setup/reset-groups.sh
```

#### Database User Restoration
```bash
./scripts/ldap/ldap-restore-user.sh <username> <database> <mysql_user> <mysql_password>
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

**Root Cause**: The LDAP server uses its own self-signed certificate issued by `docker-light-baseimage`, but the certificate bundle contains the wrong CA certificate.

**Solutions**:
1. **Verify the certificate bundle contains the correct CA:**
   ```bash
   openssl x509 -in certs/ldaps_bundle.crt -text -noout | grep -A 5 -B 5 "Subject:"
   # Should show: Subject: CN=docker-light-baseimage
   ```

2. **If the CA is wrong, fix it:**
   ```bash
   # Get the actual certificate chain from LDAP server
echo "" | openssl s_client -connect ldap.local:636 -servername ldap.local -showcerts 2>/dev/null | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > certs/ldap_server_chain.crt
   
   # Extract the CA certificate (second certificate in chain)
   awk 'split_after==1{n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1} {print > ("certs/cert" n ".crt")}' certs/ldap_server_chain.crt
   
   # Copy the CA certificate to the bundle
   cp certs/cert1.crt certs/ldaps_bundle.crt
   
   # Restart Passbolt
   docker compose restart passbolt
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

# Step 3: Fix LDAPS bundle for Passbolt (automatic in setup.sh)
./scripts/fix-ldaps-certificates.sh

# Step 4: Restart services to pick up new certificates
docker compose down && docker compose up -d
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

### LDAP Container Configuration Issues
**Symptoms**: LDAPS connection fails after modifying docker-compose.yaml

**Root Cause**: Adding incorrect environment variables to the osixia/openldap container can break its internal certificate management.

**Solutions**:
1. **Remove any custom LDAP_TLS_* environment variables** that are not documented in the osixia/openldap documentation
2. **Use only the standard environment variables:**
   ```yaml
   LDAP_TLS: "true"
   LDAP_TLS_VERIFY_CLIENT: "never"
   LDAP_TLS_CIPHER_SUITE: "SECURE256"
   LDAP_TLS_PROTOCOL_MIN: "3.1"
   LDAP_TLS_CERT_FILE: "/container/service/slapd/assets/certs/ldap.crt"
   LDAP_TLS_KEY_FILE: "/container/service/slapd/assets/certs/ldap.key"
   LDAP_TLS_CA_CERT_FILE: "/container/service/slapd/assets/certs/ca.crt"
   LDAP_TLS_ENFORCE: "true"
   LDAP_TLS_ENFORCE_CLIENT: "false"
   ```

3. **Restart the LDAP container after removing incorrect variables:**
   ```bash
   docker compose restart ldap
   ```

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

```
passbolt-docker-pro/
├── docker-compose.yaml              # Main Docker Compose configuration
├── Dockerfile.passbolt              # Custom Passbolt Docker image
├── .env                             # Environment variables for Docker component naming
├── .gitignore                       # Git ignore rules
├── scripts/                         # Utility scripts
│   ├── ldap/                        # LDAP management scripts
│   │   ├── users/                   # User management
│   │   │   ├── add.sh              # Add new users
│   │   │   └── remove.sh           # Remove users
│   │   ├── groups/                  # Group management
│   │   │   ├── add.sh              # Add groups
│   │   │   ├── remove.sh           # Remove groups
│   │   │   ├── add-user.sh         # Add user to group
│   │   │   └── remove-user.sh      # Remove user from group
│   │   ├── setup/                   # Setup scripts
│   │   │   ├── initial-setup.sh    # Initial LDAP setup
│   │   │   ├── create-admin.sh     # Create admin user
│   │   │   ├── admin_user.ldif     # LDAP admin user definition
│   │   │   └── reset-groups.sh     # Reset groups to initial state
│   │   ├── add-edith.sh            # Quick Edith setup
│   │   └── ldap-restore-user.sh    # Database user restoration
│   ├── tests/                       # Test scripts
│   │   ├── integration/            # Integration tests
│   │   │   └── test-ldap.sh        # LDAP integration tests
│   │   ├── sync/                   # Sync tests
│   │   │   └── test-sync.sh        # Sync testing
│   │   └── scripts/                # Script testing
│   │       └── test-scripts.sh     # Script testing
│   ├── generate-certificates.sh     # Certificate generation
│   ├── generate-smtp-certs.sh      # SMTP certificate generation
│   ├── setup-ldap-certs.sh         # LDAP certificate setup
│   ├── fix-ldaps-certificates.sh   # Fix LDAPS certificate bundle for Passbolt
│   ├── setup-ldap-data.sh          # LDAP data setup
│   ├── setup-ldap-users.sh         # LDAP users setup
│   ├── generate-ldaps-certs.sh     # LDAPS bundle generation (legacy)
│   ├── ldap-entrypoint.sh          # LDAP container entrypoint
│   └── setup.sh                    # Automated setup
├── certs/                           # Certificate files
│   └── ldaps_bundle.crt            # LDAPS certificate bundle (contains CA certificate for LDAP server verification)
├── ldap-certs/                      # LDAP certificates
│   ├── ldap.crt                    # LDAP server certificate
│   ├── ldap.key                    # LDAP private key
│   ├── ldap-chain.crt              # LDAP certificate chain
│   ├── ldap.csr                    # LDAP certificate signing request
│   └── ldap_ssl_config.txt         # LDAP SSL configuration
├── keys/                           # Root CA and other certificates
│   ├── ca.crt                      # Root CA certificate
│   ├── keycloak.crt                # Keycloak certificate
│   ├── keycloak.key                # Keycloak private key
│   ├── keycloak-chain.crt          # Keycloak certificate chain
│   ├── keycloak.csr                # Keycloak certificate signing request
│   └── keycloak_ssl_config.txt     # Keycloak SSL configuration
├── smtp4dev/                       # SMTP4Dev service and certificates
│   └── certs/                      # SMTP TLS certificates
│       ├── tls.crt                 # SMTP server certificate
│       ├── tls.key                 # SMTP private key
│       └── tls.pfx                 # SMTP certificate bundle
├── config/                         # Configuration files
│   ├── ldap/                       # LDAP configuration
│   │   └── avatars/                # User avatar images
│   ├── php/                        # PHP configuration
│   │   ├── php.ini                 # PHP settings
│   │   ├── ssl.ini                 # PHP SSL settings
│   │   └── www.conf                # PHP-FPM configuration
│   ├── ssl/                        # SSL configuration templates
│   │   ├── keycloak_ssl_config.txt # Keycloak SSL config template
│   │   └── ldap_ssl_config.txt     # LDAP SSL config template
│   └── db/                         # Database configuration
│       └── init-keycloak-db.sql    # Keycloak database initialization
├── assets/                         # Documentation screenshots
└── README.md                       # This file
```

## Use Cases

This example repository is useful for:

- **Learning**: Understanding Passbolt Pro SSO and LDAPS integration
- **Testing**: Validating configurations before production deployment
- **Development**: Local development environment for Passbolt integrations
- **Demonstration**: Showing integration capabilities

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
