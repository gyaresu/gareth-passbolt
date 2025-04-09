#!/bin/bash

# Create a temporary container to copy the certificates
docker run --rm -v pro_working_ldap_certs:/certs -v $(pwd)/keys:/source alpine sh -c "\
    rm -f /certs/* && \
    cp /source/domain.crt /certs/ldap.crt && \
    cp /source/domain.key /certs/ldap.key && \
    cp /source/domain.crt /certs/ca.crt && \
    chmod 644 /certs/ldap.crt && \
    chmod 644 /certs/ldap.key && \
    chmod 644 /certs/ca.crt && \
    chown -R 911:911 /certs && \
    # Create a symbolic link for the CA certificate
    ln -sf /certs/ca.crt /certs/ca.pem"

# Verify the certificates were copied
echo "Verifying certificates in volume..."
docker run --rm -v pro_working_ldap_certs:/certs alpine ls -la /certs 