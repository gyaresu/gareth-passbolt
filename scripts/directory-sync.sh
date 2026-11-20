#!/bin/bash

# Run passbolt directory sync from the host.
#
# The passbolt image works out the server key fingerprint at startup and exports
# it only into its own process, so a plain `docker compose exec` shell lacks it and
# sync crashes decrypting its settings (setDecryptKeyFromFingerprint(): null given).
# This reads the fingerprint from the server key and passes it in.
#
# Arguments go to `cake directory_sync`; the default is `all --persist`.
# Example dry run: ./scripts/directory-sync.sh all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || { echo "Error: Failed to change to root directory"; exit 1; }

fpr="$(docker compose exec -T -u www-data passbolt \
    gpg --show-keys --with-colons /etc/passbolt/gpg/serverkey.asc | awk -F: '/^fpr/ {print $10; exit}')"
if [ -z "$fpr" ]; then
    echo "Error: could not read the server key fingerprint"
    exit 1
fi

if [ $# -eq 0 ]; then
    set -- all --persist
fi

docker compose exec -T -u www-data -e PASSBOLT_GPG_SERVER_KEY_FINGERPRINT="$fpr" passbolt \
    /usr/share/php/passbolt/bin/cake directory_sync "$@"
