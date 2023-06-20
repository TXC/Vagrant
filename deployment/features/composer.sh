#!/bin/bash

if [ -z "${version}" ]; then
  version="2"
fi;

SETUPPATH="/root/composer-setup.php"
getinstaller() {
  EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
  wget -q -O ${SETUPPATH} https://getcomposer.org/installer
  ACTUAL_SIGNATURE="$(cat ${SETUPPATH} |openssl dgst -sha384 |sed 's/^.* //')"

  if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
      >&2 echo 'ERROR: Invalid installer signature'
      rm composer-setup.php
      exit 1
  fi
}

update() {
  if [[ -f "/usr/local/bin/composer${1}.phar" ]]; then
    /usr/local/bin/composer${1}.phar self-update --no-progress --${1} > /dev/null 2>&1
    return $?
  fi;
  return 1
}

install() {
  getinstaller
  /usr/bin/php ${SETUPPATH} --quiet --install-dir="/usr/local/bin/" --${1}
  mv "/usr/local/bin/composer.phar" "/usr/local/bin/composer${1}.phar"
  ln -s "/usr/local/bin/composer${1}.phar" "/usr/local/bin/composer${1}"
}

for VER in "1" "2"; do
  if update ${VER}; then
    break;
  fi
  install ${VER}
done;

if [ -f ${SETUPPATH} ]; then
  rm ${SETUPPATH}
fi

if [ ! -e "/usr/local/bin/composer.phar" ]; then
  ln -sf "/usr/local/bin/composer${version}.phar" "/usr/local/bin/composer.phar"
fi
if [ ! -e "/usr/local/bin/composer" ]; then
  ln -sf "/usr/local/bin/composer${version}.phar" "/usr/local/bin/composer"
fi
