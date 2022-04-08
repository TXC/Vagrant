#!/bin/bash

VERSIONPARAM="1";

if [[ "$1" == "2" ]]; then
  VERSIONPARAM="2"
fi;

EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
wget -q -O ./composer-setup.php https://getcomposer.org/installer
ACTUAL_SIGNATURE="$(cat ./composer-setup.php |openssl dgst -sha384 |sed 's/^.* //')"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
    >&2 echo 'ERROR: Invalid installer signature'
    rm composer-setup.php
    exit 1
fi

for VER in "1" "2"; do
  if [[ -f "/usr/local/bin/composer$VER.phar" ]]; then
    /usr/local/bin/composer.phar self-update --no-progress --$VER > /dev/null 2>&1
    break;
  fi;

  /usr/bin/php composer-setup.php --quiet --install-dir="/usr/local/bin/" --$VER
  mv "/usr/local/bin/composer.phar" "/usr/local/bin/composer$VER.phar"
  ln -s "/usr/local/bin/composer$VER.phar" "/usr/local/bin/composer$VER"
done;
rm composer-setup.php


ln -sf "/usr/local/bin/composer$VERSIONPARAM.phar" "/usr/local/bin/composer.phar"
ln -sf "/usr/local/bin/composer$VERSIONPARAM.phar" "/usr/local/bin/composer"
