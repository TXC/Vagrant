#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

echo "CONFIGURING NGINX"

mkdir -p "${LOGS_PATH}/nginx"
chown -R vagrant: "${LOGS_PATH}"
chown -R vagrant: "/var/log/nginx/*"
mkdir -p /etc/nginx/includes

echo -n "SETTING config..."
sed -i -e "s/^user .*;/user vagrant;/" \
       -e "s#^access_log .*;#access_log ${LOGS_PATH}/nginx/access\.log#" \
       -e "s#^error_log .*;#error_log ${LOGS_PATH}/nginx/error\.log#" \
       /etc/nginx/nginx.conf

CONFDIR="/etc/nginx/conf.d"
INCLDIR="/etc/nginx/includes"

if [ ! -f "${CONFDIR}/modules.conf" ]; then
  cp "${STUBROOT}/nginx/conf.d/modules.conf" \
     "${CONFDIR}/modules.conf"
fi;

if [ ! -f "${CONFDIR}/ssl.conf" ]; then
  cp "${STUBROOT}/nginx/conf.d/ssl.conf" \
     "${CONFDIR}/ssl.conf"
fi;

if [ ! -f "${CONFDIR}/logging.conf" ]; then
  cp "${STUBROOT}/nginx/conf.d/logging.conf" \
     "${CONFDIR}/logging.conf"
fi;

if [ ! -f "${INCLDIR}/common.conf" ]; then
  cat "${STUBROOT}/nginx/includes/common.conf" | \
     envsubst '$LOGS_PATH' > \
     "${INCLDIR}/common.conf"
fi;

if [ ! -f "${INCLDIR}/headers.conf" ]; then
  cp "${STUBROOT}/nginx/includes/headers.conf" \
     "${INCLDIR}/headers.conf"
fi;

if [ ! -f "${INCLDIR}/deflate.conf" ]; then
  cp "${STUBROOT}/nginx/includes/deflate.conf" \
     "${INCLDIR}/deflate.conf"
fi;

echo "DONE"

if [[ "${HTTPD}" != "nginx" ]]; then
  systemctl disable nginx.service
fi;

systemctl stop nginx.service