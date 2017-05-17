#!/bin/bash -ex

export USER="$(jq -r '.data.username' creds.json)"
export PASS="$(jq -r '.data.password' creds.json)"

docker run --rm --net=host -e"MYSQL_PWD=$PASS" mysql sh -c "echo 'SELECT DISTINCT User FROM mysql.user;' | mysql --table -h127.0.0.1 -u$USER"
