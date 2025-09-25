# Passbolt Pro Setup

This is a minimal Docker Compose setup for Passbolt Pro with only the essential services.

## Services Included

- **Database (MariaDB)**: Required for Passbolt data storage
- **Passbolt**: The main application
- **Valkey**: Session storage and caching (Redis-compatible)

## Services Excluded

- **Keycloak**: SSO provider (optional)
- **LDAP servers**: Directory synchronization (optional)
- **SMTP4Dev**: Email testing server (optional)

## Quick Start

1. **Prerequisites**:
   - Docker and Docker Compose installed
   - Passbolt Pro subscription key in `subscription_key.txt`
   - SSL certificates in `keys/` directory

2. **Start the setup**:
   ```bash
   docker compose up -d
   ```

3. **Access Passbolt**:
   - URL: https://passbolt.local/example
   - Add to `/etc/hosts`: `127.0.0.1 passbolt.local`

## Environment Variables

The setup uses a `.env` file for configuration:

- `COMPOSE_PROJECT_NAME`: Used for volume naming (prevents conflicts)
- Database credentials
- Passbolt configuration
- SSL settings

## Volume Persistence

All volumes use the `${COMPOSE_PROJECT_NAME}` prefix to ensure:
- Data persists between container restarts
- No conflicts with other Docker projects
- Easy identification of project volumes

## Configuration Files

The minimal setup still requires these configuration files:
- `config/php/www.conf` - PHP-FPM configuration
- `config/php/ssl.ini` - SSL certificate paths
- `config/nginx/nginx-passbolt.conf` - Nginx configuration
- `keys/passbolt.crt` and `keys/passbolt.key` - SSL certificates
- `subscription_key.txt` - Passbolt Pro license

## Comparison with Full Setup

| Feature | Minimal | Full Setup |
|---------|---------|------------|
| Passbolt Core | ✅ | ✅ |
| Database | ✅ | ✅ |
| Session Storage | ✅ | ✅ |
| SSO (Keycloak) | ❌ | ✅ |
| LDAP Sync | ❌ | ✅ |
| Email Testing | ❌ | ✅ |
| Multi-domain LDAP | ❌ | ✅ |

## Use Cases

This minimal setup is ideal for:
- Basic Passbolt Pro testing
- Development environments
- Simple deployments without SSO/LDAP requirements
- Learning Passbolt core functionality

## Next Steps

To add more features, you can:
1. Use the full `docker-compose.yaml` for complete functionality
2. Add services incrementally to the minimal setup
3. Configure SSO, LDAP, or email services as needed
