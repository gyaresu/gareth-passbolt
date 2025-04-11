# SSL/TLS and Certificate System Setup

## Certificate Chain Structure

- `rootCA.crt`: Self-signed root Certificate Authority (CA) certificate
- `domain.crt`: Certificate for `keycloak.local` signed by your root CA
- `chain.crt`: Concatenation of both certificates in the correct order (domain first, then root CA)

## Certificate Trust Flow

```
Browser/Client → domain.crt → rootCA.crt → Trusted Root Store
```

- When a client connects to `keycloak.local:8443`, it receives the domain certificate
- The client checks if it can trace the certificate back to a trusted root
- Since your root CA is now in the system's trust store, the chain is valid

## System Certificate Store Integration

- The certificate is mounted at `/usr/local/share/ca-certificates/keycloak.crt`
- The `update-ca-certificates` command at container startup:
  - Reads certificates from `/usr/local/share/ca-certificates/`
  - Combines them with system certificates
  - Creates a unified certificate store at `/etc/ssl/certs/ca-certificates.crt`

## PHP Configuration

```ini
[PHP]
openssl.cafile = /etc/ssl/certs/ca-certificates.crt
curl.cainfo = /etc/ssl/certs/ca-certificates.crt
```

- Both PHP's OpenSSL and cURL extensions are configured to use the system certificate store
- This ensures consistent certificate verification across all PHP components

## Keycloak Configuration

```yaml
KC_HTTPS_CERTIFICATE_FILE: /opt/keycloak/conf/server.crt.pem
KC_HTTPS_CERTIFICATE_KEY_FILE: /opt/keycloak/conf/server.key.pem
```

- Keycloak uses the same certificate chain for its HTTPS server
- The private key (`domain.key`) is kept secure and only used by Keycloak

## OIDC Configuration

```yaml
OIDC_ISSUER: "https://keycloak.local:8443/realms/passbolt"
OIDC_VERIFY_SSL: "true"
```

- Passbolt is configured to verify SSL when communicating with Keycloak
- The issuer URL matches the realm being accessed

## Trust Chain Verification

When Passbolt makes a request to Keycloak:
1. PHP's cURL initiates an HTTPS connection
2. Keycloak presents its domain certificate
3. PHP verifies the certificate using the system certificate store
4. The verification succeeds because the root CA is trusted

## Browser Integration

By importing `rootCA.crt` into your browser:
- The browser now trusts certificates signed by your root CA
- You can access `keycloak.local:8443` without SSL warnings
- The browser can verify the full certificate chain

## Benefits of This Setup

- Secure communication between all components
- Proper certificate verification
- Consistent trust across the entire system
- No SSL warnings in browsers
- A proper PKI (Public Key Infrastructure) setup for your development environment

## Key Insight

The key to making this work was properly integrating the certificates into the system's trust store rather than trying to use them directly, which is the standard and most reliable way to handle certificates in Linux systems. 