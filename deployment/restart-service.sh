#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

echo "RESTARTING SERVICES"

set -x

HTTPD=""
if [ -f /etc/apache2/apache2.conf ]; then
  HTTPD="apache2.service"
elif [ -f /etc/nginx/nginx.conf ]; then
  HTTPD="nginx.service"
fi

SERVICES="${HTTPD}";
for version in ${PHP_VERSIONS}; do
  SERVICES+=" php${version}-fpm";
done;
echo "RESTARTING: ${SERVICES}"

set +x

systemctl enable "${HTTPD}";
systemctl restart ${SERVICES};
