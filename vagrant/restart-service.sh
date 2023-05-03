#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

echo "RESTARTING SERVICES"


if [[ "${HTTPD}" != "nginx" ]]; then
  systemctl disable nginx.service
fi;

systemctl stop nginx.service

SERVICES="${HTTPD}.service";
for version in ${PHP_VERSIONS}; do
  SERVICES+=" php${version}-fpm";
done;
echo "RESTARTING: ${SERVICES}"

systemctl enable "${HTTPD}";
systemctl restart ${SERVICES};
