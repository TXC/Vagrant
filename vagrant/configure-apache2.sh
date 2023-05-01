#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

echo "CONFIGURING APACHE"

mkdir -p "${LOGS_PATH}/apache2"
chown -R vagrant: "${LOGS_PATH}"
mkdir -p /etc/apache2/includes

echo -n "SETTING envvars..."
sed -i -e "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=vagrant/" \
       -e "s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=vagrant/" \
       -e "s#^export APACHE_LOG_DIR=.*#export APACHE_LOG_DIR=${LOGS_PATH}/apache2\$SUFFIX#" \
          /etc/apache2/envvars
(
  source /etc/apache2/envvars;
  mkdir -p $APACHE_LOG_DIR;
  sudo chown -R vagrant: $APACHE_LOG_DIR;
)
echo "DONE"
CONFDIR="/etc/apache2/conf-available"
INCLDIR="/etc/apache2/includes"

if [ ! -f "${CONFDIR}/vagrant.conf" ]; then
  cp "${STUBROOT}/apache2/conf-available/vagrant.conf" \
     "${CONFDIR}/vagrant.conf"
fi;

if [ ! -f "${CONFDIR}/itk.conf" ]; then
  cp "${STUBROOT}/apache2/conf-available/itk.conf" \
     "${CONFDIR}/itk.conf"
fi;

if [ ! -f "${CONFDIR}/modules.conf" ]; then
  cp "${STUBROOT}/apache2/conf-available/modules.conf" \
     "${CONFDIR}/modules.conf"
fi;

if [ ! -f "${INCLDIR}/logging.conf" ]; then
  cp "${STUBROOT}/apache2/includes/logging.conf" \
     "${INCLDIR}/logging.conf"
fi;

if [ ! -f "${INCLDIR}/php.conf" ]; then
  cp "${STUBROOT}/apache2/includes/php.conf" \
     "${INCLDIR}/php.conf"
fi;

if [ ! -f "${INCLDIR}/vhost.conf" ]; then
  cp "${STUBROOT}/apache2/includes/vhost.conf" \
     "${INCLDIR}/vhost.conf"
fi;

echo -n "SETTING mod_ssl..."
sed -i -e "s/SSLCipherSuite.*/SSLCipherSuite HIGH:!MEDIUM:!aNULL:!MD5:!RC4/" \
       -e "s/SSLProtocol.*/SSLProtocol -ALL +TLSv1.2 +TLSv1.3/" \
          "/etc/apache2/mods-available/ssl.conf"
echo "DONE"

a2enconf vagrant itk modules
a2dismod mpm_event mpm_prefork mpm_worker
a2enmod actions cgid expires headers mpm_event http2 proxy_fcgi rewrite ssl

if [[ "${HTTPD}" != "nginx" ]]; then
  systemctl disable apache2.service
fi;

systemctl stop apache2.service
