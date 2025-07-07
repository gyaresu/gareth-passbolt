# Keycloak SSO Integration with Passbolt Pro

This comprehensive guide explains how to set up and configure Keycloak as a Single Sign-On (SSO) provider for Passbolt Pro, including best practices and troubleshooting tips.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Database Configuration](#database-configuration)
- [Certificate System](#certificate-system)
- [PHP SSL Configuration](#php-ssl-configuration)
- [Keycloak Configuration](#keycloak-configuration)
- [Passbolt Configuration](#passbolt-configuration)
- [Testing the Integration](#testing-the-integration)
- [LDAP Integration](#ldap-integration)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

## Overview

This integration allows users to authenticate to Passbolt using their Keycloak credentials, providing a seamless single sign-on experience. The setup uses:

- Passbolt Pro with OIDC plugin
- Keycloak 26.3.0 (latest stable version)
- MariaDB for both Passbolt and Keycloak databases
- Optional LDAP integration

## Prerequisites

- Docker and Docker Compose installed
- Basic knowledge of Passbolt and Keycloak
- A valid Passbolt Pro license key (placed in `subscription_key.txt` file)

## Environment Setup

### 1. Configure Hosts File

Add the following entries to your hosts file:

```
127.0.0.1 passbolt.local
127.0.0.1 keycloak.local
```

### 2. Generate SSL Certificates

Run the certificate generation script:

```bash
./scripts/generate-certificates.sh
```

This creates:
- A root CA certificate
- Service-specific certificates for Keycloak and LDAP
- Proper certificate chains with intuitive naming

### 3. Start the Environment

```bash
docker compose up -d
```

This starts all services:
- Passbolt Pro
- Keycloak (v26.3.0)
- MariaDB (shared database for both services)
- LDAP server (optional)
- Mailpit (SMTP testing)

## Database Configuration

The environment uses a shared MariaDB instance with separate databases:

- `passbolt` database for Passbolt
- `keycloak` database for Keycloak

The database configuration in `docker-compose.yaml` includes:

```yaml
db:
  image: mariadb:10.11
  environment:
    MYSQL_ROOT_PASSWORD: "rootpassword"
    MYSQL_DATABASE: "passbolt"
    MYSQL_USER: "passbolt"
    MYSQL_PASSWORD: "P4ssb0lt"
```

For Keycloak to use MariaDB, these environment variables are set:

```yaml
keycloak:
  environment:
    KC_DB: mariadb
    KC_DB_URL_HOST: db
    KC_DB_URL_DATABASE: keycloak
    KC_DB_USERNAME: passbolt
    KC_DB_PASSWORD: P4ssb0lt
```

The `init-keycloak-db.sql` script creates the Keycloak database and grants permissions:

```sql
CREATE DATABASE IF NOT EXISTS keycloak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON keycloak.* TO 'passbolt'@'%';
FLUSH PRIVILEGES;
```

## Certificate System

### Certificate Chain Structure

- `rootCA.crt`: Self-signed root Certificate Authority (CA) certificate
- `keycloak.crt`: Certificate for `keycloak.local` signed by your root CA
- `keycloak-chain.crt`: Concatenation of both certificates in the correct order (domain first, then root CA)

### Certificate Trust Flow

```
Browser/Client → keycloak.crt → rootCA.crt → Trusted Root Store
```

- When a client connects to `keycloak.local:8443`, it receives the domain certificate
- The client checks if it can trace the certificate back to a trusted root
- Since your root CA is now in the system's trust store, the chain is valid

### System Certificate Store Integration

- The certificate is mounted at `/usr/local/share/ca-certificates/keycloak.crt`
- The `update-ca-certificates` command at container startup:
  - Reads certificates from `/usr/local/share/ca-certificates/`
  - Combines them with system certificates
  - Creates a unified certificate store at `/etc/ssl/certs/ca-certificates.crt`

## PHP SSL Configuration

### Configuration Files

The PHP SSL configuration is managed through two main files:

1. **ssl.ini** - Sets system-wide PHP SSL certificate paths:
```ini
[PHP]
openssl.cafile = /etc/ssl/certs/ca-certificates.crt
curl.cainfo = /etc/ssl/certs/ca-certificates.crt
```

2. **www.conf** - Configures PHP-FPM with certificate paths for web requests:
```ini
[www]
user = www-data
group = www-data
listen = 0.0.0.0:9000
pm = dynamic
pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.max_requests = 500
php_admin_value[openssl.cafile] = "/etc/ssl/certs/ca-certificates.crt"
php_admin_value[curl.cainfo] = "/etc/ssl/certs/ca-certificates.crt"
```

These configurations are mounted in the container:

```yaml
volumes:
  - ./config/php/www.conf:/etc/php-fpm.d/www.conf
  - ./config/php/ssl.ini:/etc/php/8.2/cli/conf.d/99-ssl.ini
  - ./keys/ca.crt:/usr/local/share/ca-certificates/keycloak.crt
```

Additionally, PHP SSL settings are also configured through environment variables:

```yaml
environment:
  # PHP SSL configuration
  PHP_OPENSSL_CAFILE: "/etc/ssl/certs/keycloak.crt"
  PHP_CURL_SSL_VERIFYPEER: "1"
  PHP_CURL_SSL_VERIFYHOST: "2"
```

### Container Startup

The container startup command includes `update-ca-certificates` to ensure certificates are properly registered:

```yaml
command:
  - /bin/bash
  - -c
  - |
    update-ca-certificates
    /usr/bin/wait-for.sh -t 0 db:3306 -- /docker-entrypoint.sh
```

### Why This Approach Works Better

1. **Standardization**: Uses the standard Linux certificate management system
2. **Consistency**: Ensures consistent certificate verification across all PHP components
3. **Reliability**: Leverages system's certificate management tools
4. **Maintainability**: Uses standard paths and procedures

## Passbolt Docker Image

The setup uses a custom Passbolt Docker image built with the following Dockerfile:

```dockerfile
FROM passbolt/passbolt:latest-pro

# Copy your CA certificate into the appropriate directory
COPY keys/ca.crt /usr/local/share/ca-certificates/keycloak.crt
# Update the CA trust store
RUN update-ca-certificates
```

This custom image:
1. Uses the latest Passbolt Pro image as the base
2. Adds the CA certificate to the trusted certificate store
3. Updates the system's certificate trust store

The image is built during `docker compose up` using the configuration in docker-compose.yaml:

```yaml
passbolt:
  build:
    context: .
    dockerfile: Dockerfile.passbolt
  image: passbolt/passbolt:latest-pro
```

## Keycloak Configuration

### 1. Access Keycloak Admin Console

- URL: https://keycloak.local:8443
- Username: admin
- Password: admin

### 2. Create a New Realm

- Click "Create Realm"
- Name: "passbolt"
- Click "Create"

### 3. Create a Client

- Go to "Clients" > "Create client"
- Client type: OpenID Connect
- Client ID: "passbolt-client"
- Client authentication: ON
- Authorization: OFF
- Click "Save"

### 4. Configure Client Settings

- **Settings tab**:
  - Valid redirect URIs: https://passbolt.local/auth/login
  - Web origins: https://passbolt.local
  - Click "Save"

- **Credentials tab**:
  - Copy the "Client secret" value (needed for Passbolt configuration)
  - Default value in our setup: "9cBUxO4c68E7SYJJJPJ8FjtIDLgMdHqi"

### 5. Create a User

- Go to "Users" > "Add user"
- Username: ada
- Email: ada@passbolt.com (must match your Passbolt admin email)
- First name: Ada
- Last name: Lovelace
- Click "Create"

- Go to "Credentials" tab:
  - Set password: passbolt
  - Temporary: OFF
  - Click "Set password"

## Passbolt Configuration

The Passbolt container is pre-configured with these OIDC settings in docker-compose.yaml:

```yaml
PASSBOLT_PLUGINS_SSO_PROVIDER_OAUTH2_ENABLED: "true"
OIDC_ENABLED: "true"
OIDC_ISSUER: "https://keycloak.local:8443/realms/passbolt"
OIDC_CLIENT_ID: "passbolt-client"
OIDC_CLIENT_SECRET: "9cBUxO4c68E7SYJJJPJ8FjtIDLgMdHqi"
OIDC_SCOPES: "openid profile email"
OIDC_VERIFY_SSL: "true"
```

### Certificate Trust

For secure communication, Passbolt must trust Keycloak's certificate:

```yaml
PHP_OPENSSL_CAFILE: "/etc/ssl/certs/keycloak.crt"
PHP_CURL_SSL_VERIFYPEER: "1"
PHP_CURL_SSL_VERIFYHOST: "2"
```

The CA certificate is mounted in the container:

```yaml
- ./keys/ca.crt:/usr/local/share/ca-certificates/keycloak.crt
```

## Testing the Integration

1. Access Passbolt at https://passbolt.local
2. Click "SSO Login"
3. You'll be redirected to Keycloak
4. Log in with the ada@passbolt.com / passbolt credentials
5. You'll be redirected back to Passbolt and logged in

## LDAP Integration

### 1. Set Up LDAP Certificates

```bash
./scripts/setup-ldap-certs.sh
```

### 2. Populate LDAP with Test Data

```bash
./scripts/setup-ldap-data.sh
```

### 3. Configure Keycloak LDAP Integration

- Go to "User Federation" in your realm
- Add an LDAP provider
- Configure the connection:
  - Vendor: Other
  - Connection URL: ldap://ldap.local:389
  - Bind DN: cn=admin,dc=passbolt,dc=local
  - Bind Credential: P4ssb0lt
  - Edit mode: WRITABLE
  - Users DN: ou=users,dc=passbolt,dc=local

## Troubleshooting

### Certificate Issues

If you encounter certificate trust issues:
- Verify certificates were generated correctly
- Check that the CA certificate is properly mounted
- Run `update-ca-certificates` in the containers

### Database Connection Issues

If Keycloak fails to connect to the database:
- Check database credentials in docker-compose.yaml
- Verify the keycloak database exists and permissions are set
- Check MariaDB logs for connection errors

### SSO Login Failures

If SSO login doesn't work:
- Verify the client ID and secret match between Keycloak and Passbolt
- Check that the redirect URI is correctly configured
- Ensure the user exists in both systems with matching email addresses

### OpenID Configuration Path

If Passbolt can't fetch the OpenID configuration:
- Ensure the path includes the leading dot: `/.well-known/openid-configuration`
- Verify the Keycloak realm name is correct in the URL

### Trust Chain Verification

When Passbolt makes a request to Keycloak:
1. PHP's cURL initiates an HTTPS connection
2. Keycloak presents its domain certificate
3. PHP verifies the certificate using the system certificate store
4. The verification succeeds because the root CA is trusted

## Advanced Configuration

### Multiple Realms

For multiple organizations:
1. Create separate realms in Keycloak
2. Create a client in each realm
3. Configure Passbolt to use the appropriate realm's client

### Custom User Attributes

To map additional user attributes:
1. Add custom attributes in Keycloak
2. Create protocol mappers in the client configuration
3. Configure Passbolt to use these attributes

### Browser Integration

By importing `rootCA.crt` into your browser:
- The browser now trusts certificates signed by your root CA
- You can access `keycloak.local:8443` without SSL warnings
- The browser can verify the full certificate chain

## Version Notes

- This guide uses Keycloak 26.3.0
- The admin-fine-grained-authz feature is included by default in Keycloak 23+
- Always keep both Keycloak and Passbolt updated with security patches

## Screenshots

![keycloak client](./assets/keycloak_client.png)
![keycloak_user.png](./assets/keycloak_user.png)
![passbolt_config.png](./assets/passbolt_config.png)
![passbolt_oidc_login.png](./assets/passbolt_oidc_login.png) 