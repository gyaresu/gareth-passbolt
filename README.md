# Passbolt Pro Docker with Mailpit for local SMTP server

## Mailpit SMTP server
[http://passbolt.local:8025](http://passbolt.local:8025)

## passbolt server

edit your local hosts file: 

`127.0.0.1 passbolt.local`

## passbolt license key

mount key somewhere outside the repo:

`~/.passbolt/licensekey/subscription_key.txt to /etc/passbolt/subscription_key.txt`

## .env variables set container names
use unique names when hosting multiple instances of this docker build

```
COMPOSE_PROJECT_NAME=passbolt_pro
MAILPIT_CONTAINER_NAME=mailpit-03
```

## bring up:

`docker-compose -f docker-compose-pro-current.yaml up`

## bring down containers (not just ctrl+c)

`docker-compose -f docker-compose-pro-current.yaml down`

## remove persistent docker volumes after finished testing

`docker-compose down --volumes`

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
