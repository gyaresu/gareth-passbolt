#!/bin/sh

openssl req -x509 -sha256 -days 2000 -newkey rsa:2048 -subj "/C=LU/ST=Luxembourg/L=Esch-Sur-Alzette/O=Local CA/OU=Local CA/CN=My RootCA" -nodes -keyout rootCA.key -out rootCA.crt

openssl req -newkey rsa:2048  -subj "/C=LU/ST=Luxembourg/L=Esch-Sur-Alzette/O=Keycloak local/OU=Keycloak local test/CN=keycloak.local/" -nodes -addext "subjectAltName = DNS:keycloak.local" -keyout domain.key -out domain.csr

openssl x509 -req -CA rootCA.crt -CAkey rootCA.key -in domain.csr -out domain.crt -days 365 -CAcreateserial -extfile ssl_gen_config.txt
