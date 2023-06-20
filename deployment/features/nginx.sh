#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

echo "INSTALLING NGINX"
add-apt-repository ppa:ondrej/nginx -yn

aptinstall nginx

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

if [ ! -f "${CONFDIR}/fastcgi.conf" ]; then
  cp "${STUBROOT}/nginx/conf.d/fastcgi.conf" \
    "${CONFDIR}/fastcgi.conf"
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

#if [ ! -f "${INCLDIR}/php.conf" ]; then
#  cp "${STUBROOT}/nginx/includes/php.conf" \
#    "${INCLDIR}/php.conf"
#fi;

echo "DONE"

systemctl disable nginx.service
systemctl stop nginx.service
