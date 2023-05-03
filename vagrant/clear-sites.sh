#!/usr/bin/env bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

if [ -L /usr/local/sbin/clear_sites ]; then
    ln -sf "/vagrant/vagrant/clear-sites.sh" "/usr/local/sbin/clear_sites";
fi

SRC_PATH="/etc/apache2/sites-enabled"
if [ -d "${SRC_PATH}" ] && [ $(ls -l "${SRC_PATH}" | grep "\-ssl" | wc -l) -gt 0 ]; then
  APACHE_EXCLUDE_SSL=""
  APACHE_EXCLUDE_LOG=""

  for f in "${SRC_PATH}"/*-ssl.conf; do
    COMMONKEY=$(grep PHPSOCKET $f | awk '{print $3}')
    SERVERNAME=$(grep ServerName $f | awk '{print $2}')
    APACHE_EXCLUDE_SSL="${APACHE_EXCLUDE_SSL} -not -name '*${SERVERNAME%":443"}*'"
    APACHE_EXCLUDE_LOG="${APACHE_EXCLUDE_LOG} -not -name '*${COMMONKEY}*.log'"
  done
  sudo rm -f /etc/apache2/sites-enabled/*
  sudo find ${SITE_PATH}/apache2/ -type f -not -name '*default*.conf' -print0 -delete
fi;

SRC_PATH="/etc/nginx/sites-enabled"
if [ -d "${SRC_PATH}" ] && [ $(ls -l "${SRC_PATH}" | grep "\-ssl"  | wc -l) -gt 0 ]; then

  NGINX_EXCLUDE_SSL=""
  NGINX_EXCLUDE_LOG=""

  for f in "${SRC_PATH}"/*-ssl.conf; do
    COMMONKEY=$(grep PHPSOCKET $f |awk '{ print $2 }' |cut -d':' -f2 |cut -d';' -f1)
    SERVERNAME=$(grep server_name $f | awk '{print $2}' |cut -d';' -f1)
    NGINX_EXCLUDE_SSL="${NGINX_EXCLUDE_SSL} -not -name '*${SERVERNAME}*'"
    NGINX_EXCLUDE_LOG="${NGINX_EXCLUDE_LOG} -not -name '*${COMMONKEY}*.log'"
  done

  #sudo find /etc/nginx/sites-enabled/ -type f -not -name 'default' -print0 -delete
  sudo rm -f /etc/nginx/sites-enabled/*
  sudo find ${SITE_PATH}/nginx/ -type f -not -name 'default' -print0 -delete
fi;

sudo find /etc/php/ -path "*/fpm/pool.d/*" -type f -not -name "www.conf" -print0 -delete
if [ ! -z "${LOGS_PATH}" ]; then
  sudo find ${LOGS_PATH}/ -type f -not -name "other_vhosts_access.log" -not -name "access.log" -not -name "error.log" ${EXCLUDE_LOG} -print0 -delete
fi
if [ ! -z "${SSL_PATH}" ]; then
  sudo find ${SSL_PATH}/ -type f -not -name "base.*" -not -name "ca.*" ${EXCLUDE_SSL} -print0 -delete
fi