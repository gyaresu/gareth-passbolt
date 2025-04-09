#!/bin/bash
# Create a temporary directory for the certificates
mkdir -p ldap-certs
# Copy the certificates with correct permissions
cp keys/domain.crt ldap-certs/ldap.crt
cp keys/domain.key ldap-certs/ldap.key
# Set permissions that OpenLDAP can read and write
chmod 666 ldap-certs/ldap.crt
chmod 666 ldap-certs/ldap.key
# Set ownership to match OpenLDAP container user (911:911)
sudo chown 911:911 ldap-certs/ldap.crt
sudo chown 911:911 ldap-certs/ldap.key
