# PHP SSL Configuration Changes

## Initial Problem

We were trying to use a custom certificate file directly:
- Certificate mounted at `/etc/ssl/certs/keycloak.crt`
- PHP configured through environment variables:
  ```yaml
  PHP_OPENSSL_CAFILE: "/etc/ssl/certs/keycloak.crt"
  PHP_CURL_SSL_VERIFYPEER: "1"
  PHP_CURL_SSL_VERIFYHOST: "2"
  ```

## Final Solution

We moved to using the system's certificate store:

1. **PHP Configuration File (`ssl.ini`)**:
   ```ini
   [PHP]
   openssl.cafile = /etc/ssl/certs/ca-certificates.crt
   curl.cainfo = /etc/ssl/certs/ca-certificates.crt
   ```

2. **File Locations**:
   - PHP config: `/etc/php/8.2/cli/conf.d/99-ssl.ini`
   - Certificate: `/usr/local/share/ca-certificates/keycloak.crt`

3. **Container Startup**:
   - Added `update-ca-certificates` to the startup command
   - This ensures certificates are properly registered in the system store

## Key Changes

1. **Certificate Management**:
   - Switched from direct certificate file usage to system certificate store
   - Moved from environment variables to PHP configuration file
   - Used standard system paths for certificate storage

2. **Configuration Method**:
   - From: Environment variables
   - To: PHP configuration file (`ssl.ini`)
   - Location: `/etc/php/8.2/cli/conf.d/99-ssl.ini`

3. **Certificate Integration**:
   - From: Direct file usage
   - To: System certificate store
   - Path: `/etc/ssl/certs/ca-certificates.crt`

## Why This Works Better

1. **Standardization**:
   - Uses the standard Linux certificate management system
   - Follows system defaults and conventions
   - More maintainable and predictable

2. **Consistency**:
   - Ensures consistent certificate verification across all PHP components
   - Both OpenSSL and cURL use the same certificate store
   - Reduces configuration complexity

3. **Reliability**:
   - Leverages system's certificate management tools
   - More robust error handling
   - Better integration with system security features

4. **Maintainability**:
   - Uses standard paths and procedures
   - Easier to understand and modify
   - Follows Linux best practices

## Implementation Details

1. **Certificate Storage**:
   ```yaml
   volumes:
     - ./php-fpm/ssl.ini:/etc/php/8.2/cli/conf.d/99-ssl.ini
     - ./keys/chain.crt:/usr/local/share/ca-certificates/keycloak.crt
   ```

2. **Container Startup**:
   ```yaml
   command:
     - /bin/bash
     - -c
     - |
       update-ca-certificates
       /usr/bin/wait-for.sh -t 0 db:3306 -- /docker-entrypoint.sh
   ```

3. **PHP Configuration**:
   ```ini
   [PHP]
   openssl.cafile = /etc/ssl/certs/ca-certificates.crt
   curl.cainfo = /etc/ssl/certs/ca-certificates.crt
   ```

## Conclusion

The main shift was from trying to configure PHP to use a custom certificate directly to properly integrating our certificate into the system's certificate store and letting PHP use the system defaults. This approach is more robust, maintainable, and follows Linux best practices for certificate management. 