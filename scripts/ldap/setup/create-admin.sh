#!/bin/bash

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

echo "Creating default admin user..."
docker compose exec passbolt su -m -c "/usr/share/php/passbolt/bin/cake passbolt register_user \
    -u ada@passbolt.com \
    -f \"Ada\" \
    -l \"Lovelace\" \
    -r admin" -s /bin/bash www-data

echo "The password for the key is: ada@passbolt.com"
echo "Please check SMTP4Dev (http://smtp.local:5050) for the registration email."
echo "When asked to generate a key, import the private key from the [passbolt test repo](https://github.com/passbolt/passbolt-test-data/tree/master/config/gpg)" 