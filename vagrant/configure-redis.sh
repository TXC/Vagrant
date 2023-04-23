#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

echo "CONFIGURING redis"

sed -i "s/^bind .*/bind 127.0.0.1 ::1 $HOSTIP/" /etc/redis/redis.conf
systemctl restart redis
