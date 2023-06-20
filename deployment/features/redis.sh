#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

echo "INSTALLING redis"
aptinstall redis


echo "CONFIGURING redis"

sed -i "s/^bind .*/bind 127.0.0.1 ::1 $HOSTIP/" /etc/redis/redis.conf
systemctl restart redis
