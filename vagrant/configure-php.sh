#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

#TIMEZONE=$(timedatectl | grep "Time zone" | awk {' print $3 '})

echo "CONFIGURING PHP"

if [ ! -f "/etc/php/common.conf" ]; then
  cp "${STUBROOT}/vagrant-common.ini" \
     "/etc/php/common.ini"
fi

for f in ${STUBROOT}/php*; do
  if [ ! -d "${f}" ]; then
    continue;
  fi;

  dir=${f##*/}
  ver=$(echo ${dir} | cut -c4-)
  poolroot="/etc/php/${ver}/fpm/pool.d"
  modroot="/etc/php/${ver}/mods-available"

  PMC=$(grep -E "^pm = " "${poolroot}/www.conf" | awk '{ print $3 }')
  if [ $PMC != "ondemand" ]; then
    sed -i "s/^pm = .*/pm = ondemand/" "${poolroot}/www.conf"
  fi

  if [ ! -f "${modroot}/vagrant.ini" ]; then
    cp "${STUBROOT}/${dir}/vagrant.ini" \
       "${modroot}/vagrant.ini"

    sed -i -e "s#^xdebug\.remote_host.*#xdebug\.remote_host=${HOSTIP}#;" \
           -e "s#^xdebug\.client_host.*#xdebug\.client_host=${HOSTIP}#;" \
           -e "s#^xdebug\.remote_log.*#xdebug\.remote_log=${LOGS_PATH}#;" \
           -e "s#^xdebug\.output_dir.*#xdebug\.output_dir=${LOGS_PATH}#;" \
           -e "s#^xdebug\.profiler_output_dir.*#xdebug\.profiler_output_dir=${LOGS_PATH}#;" \
           -e "s#^date\.timezone.*#date\.timezone=${TIMEZONE}#" \
           "${modroot}/vagrant.ini"
  fi

  if [ ! -f "${modroot}/vagrant.ini" ]; then
    cp "${STUBROOT}/vagrant-cli.ini" \
       "${modroot}/"
  fi
done

phpenmod vagrant
phpenmod -s cli vagrant-cli