#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

echo "CONFIGURING PHP"

if [ ! -f "/etc/php/common.conf" ]; then
  cp "${STUBROOT}/php/vagrant-common.conf" \
    "/etc/php/common.conf"
fi

ALIASES="/home/vagrant/.bash_aliases"

cat <<'EOF' | tee -a /home/vagrant/.bash_aliases
alias xoff='sudo phpdismod -s cli xdebug; unset XDEBUG_MODE XDEBUG_SESSION'
alias xon='sudo phpenmod -s cli xdebug; export XDEBUG_MODE=debug XDEBUG_SESSION=1'
EOF

#   PHP                     XDEBUG  VERSION
# |     | 3.2 | 3.1 | 3.0 | 2.9 | 2.8 | 2.7 | 2.6 | 2.5 | 2.4 |
# |-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
# |     |     |     |     |     |     |     |     |     |     |
# | 8.3 |     |     |     |     |     |     |     |     |     |
# | 8.2 |  X  |  X  |     |     |     |     |     |     |     |
# | 8.1 |  X  |  X  |     |     |     |     |     |     |     |
# | 8.0 |  X  |  X  |  X  |     |     |     |     |     |     |
# | 7.4 |     |  X  |  X  |  X  |  X  |     |     |     |     |
# | 7.3 |     |  X  |  X  |  X  |  X  |  X  |     |     |     |
# | 7.2 |     |  X  |  X  |  X  |  X  |  X  |  X  |     |     |
# | 7.1 |     |     |     |  X  |  X  |  X  |  X  |  X  |     |
# | 7.0 |     |     |     |     |     |  X  |  X  |  X  |  X  |
# | 5.6 |     |     |     |     |     |     |     |  X  |  X  |

for ver in ${PHP_VERSIONS}; do
  poolroot="/etc/php/${ver}/fpm/pool.d"
  modroot="/etc/php/${ver}/mods-available"

  PMC=$(grep -E "^pm = " "${poolroot}/www.conf" | awk '{ print $3 }')
  if [ $PMC != "ondemand" ]; then
    sed -i "s/^pm = .*/pm = ondemand/" "${poolroot}/www.conf"
  fi

  if [ ! -f "${modroot}/vagrant.ini" ]; then
    cp "${STUBROOT}/php/php${ver}/vagrant.ini" \
       "${modroot}/vagrant.ini"

    if [ -z "${idekey}" ]; then
      idekey="PHPSTORM"
    fi
    if [ ${ver} == "5.6" ] || [ ${ver} == "7.0" ] || [ ${ver} == "7.1" ]; then
      sed -i -e "s#^xdebug\.remote_host.*#xdebug\.remote_host = ${HOSTIP}#;" \
             -e "s#^xdebug\.remote_log.*#xdebug\.remote_log = ${LOGS_PATH}/php${ver}/#;" \
             -e "s#^xdebug\.profiler_output_dir.*#xdebug\.profiler_output_dir = ${LOGS_PATH}/php${ver}/#;" \
             -e "s#^xdebug\.idekey.*#xdebug\.idekey = ${idekey}/#;" \
             -e "s#^date\.timezone.*#date\.timezone=${TIMEZONE}#" \
             "${modroot}/vagrant.ini"
    else
      sed -i -e "s#^xdebug\.client_host.*#xdebug\.client_host = ${HOSTIP}#;" \
             -e "s#^xdebug\.output_dir.*#xdebug\.output_dir = ${LOGS_PATH}/php${ver}/#;" \
             -e "s#^xdebug\.idekey.*#xdebug\.idekey = ${idekey}/#;" \
             -e "s#^date\.timezone.*#date\.timezone=${TIMEZONE}#" \
             "${modroot}/vagrant.ini"
    fi
  fi

  PV=$(echo ${ver} | sed 's/\.//')
  grep -q -F "use-php${PV}()" ${ALIASES}
  if [ $? -ne 0 ]; then
    STR="function php${PV}() {\n"
    STR+="  sudo update-alternatives --set php /usr/bin/php${ver}\n"
    STR+="  sudo update-alternatives --set php-config /usr/bin/php-config${ver}\n"
    STR+="  sudo update-alternatives --set phpize /usr/bin/phpize${ver}\n"
    STR+="}\n"
    echo "${STR}" | tee -a /home/vagrant/.bash_aliases
  fi;

  if [ ! -f "${modroot}/vagrant-cli.ini" ]; then
    cp "${STUBROOT}/php/vagrant-cli.ini" \
      "${modroot}/"
  fi
done

phpenmod vagrant
phpenmod -s cli vagrant-cli
