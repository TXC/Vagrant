#!/bin/bash

HOSTIP=$1

echo "CONFIGURING redis"

sed -i "s/^bind .*/bind 127.0.0.1 ::1 $HOSTIP/" /etc/redis/redis.conf
systemctl restart redis
