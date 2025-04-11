#!/bin/bash

# Create certificates directory if it doesn't exist
mkdir -p /container/service/slapd/assets/certs

# Copy certificates with correct permissions
cp /certs/domain.crt /container/service/slapd/assets/certs/
cp /certs/domain.key /container/service/slapd/assets/certs/
cp /certs/rootCA.crt /container/service/slapd/assets/certs/

# Set correct permissions
chown -R openldap:openldap /container/service/slapd/assets/certs
chmod 600 /container/service/slapd/assets/certs/*

# Run the original entrypoint
exec /container/tool/run 