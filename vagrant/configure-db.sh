#!/bin/bash

HOSTIP=$1

echo "CONFIGURING DB"

RESULT_VARIABLE="$(sudo mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user='vagrant');")";
if [ "$RESULT_VARIABLE" -ne "1" ]; then
  sudo mysql -u root -e "CREATE USER 'vagrant'@'%' IDENTIFIED BY 'vagrant';"
fi;
