# Passbolt Pro Docker compose file with MariaDB, Mailpit, and Keycloak.


## Mailpit SMTP server
[http://passbolt.local:8025](http://passbolt.local:8025)

## passbolt server

edit your local hosts file: 

`127.0.0.1 passbolt.local`

### passbolt license key

mount key somewhere outside the repo:

`~/.passbolt/licensekey/subscription_key.txt to /etc/passbolt/subscription_key.txt`

### bring up:

`docker-compose -f docker-compose-pro-current.yaml up`

### bring down containers (not just ctrl+c)

`docker-compose -f docker-compose-pro-current.yaml down`

### lazydocker

#### containers

```
mailpit
local_folder_name-db-1
local_folder_name-passbolt-1
ubi8-minimal # keycloak build their image off UBI 8 Red Hat image
```

#### drop into a docker shell through lazydocker 
`shift+E to shell container`

## execute in passbolt container as user from host shell

```
docker-compose -f docker-compose-pro-current.yaml \
exec passbolt su -m -c "/usr/share/php/passbolt/bin/cake \
passbolt register_user \
-u ada@passbolt.com \
-f ada \
-l lovelace \
-r admin" -s /bin/sh www-data
```

## Keycloak
https://keycloak.local
Create realm > create realm client > create client credential > create user > create user credential

Blog post: ["Wanna use Keycloak to sign in to your Passbolt instance? Here's the way to go"](https://www.passbolt.com/blog/how-to-connect-keycloak-with-passbolt-for-sso)

notes:
 * typo: `/.well-known/openid-configuration` missing the first dot in blog post: _"OpenId configuration path: /well-known/openid-configuration"_
 * Using Keycloak `20.0.3` as `quay.io/keycloak/keycloak:latest` had broken Java on macOS. ¯\_(ツ)_/¯
