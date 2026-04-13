#!/bin/bash
set -euo pipefail

# Install dependencies if not present (devcontainer features only install via CLI/IDE)
if ! command -v node &>/dev/null || ! command -v git &>/dev/null; then
  apt-get update &>/dev/null
  apt-get install -y \
    git curl wget jq \
    mariadb-client \
    ldap-utils \
    php-cli php-mbstring php-xml \
    python3 python3-venv \
    iputils-ping dnsutils net-tools \
    vim less \
    shellcheck \
    &>/dev/null
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - &>/dev/null
  apt-get install -y nodejs &>/dev/null
fi

# Backfill shellcheck on existing containers (schlock's shellcheck rule and /verify workflows both use it)
if ! command -v shellcheck &>/dev/null; then
  apt-get update &>/dev/null
  apt-get install -y shellcheck &>/dev/null
fi

# Backfill python3 on existing containers (required by the schlock plugin's hook entry points)
if ! command -v python3 &>/dev/null; then
  apt-get update &>/dev/null
  apt-get install -y python3 python3-venv &>/dev/null
fi

# Install/update Claude Code
if command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code@latest &>/dev/null &
else
  npm install -g @anthropic-ai/claude-code &>/dev/null
fi

echo "Devcontainer ready."
exec sleep infinity
