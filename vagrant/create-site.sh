#!/usr/bin/bash

ARG_HOST=$1
ARG_DOCROOT=$2
ARG_SSL=$3
ARG_PHPVERSION=$4
ARG_404=$5
COMMONKEY=$(echo $ARG_HOST |openssl dgst -sha384 |sed 's/^.* //'|cut -c1-8)
SSLDays="3650"
PHP_BASEDIR=$(findmnt -n --target $ARG_DOCROOT | head -n 1 | awk '{ print $1 }')

mkdir -p "/etc/apache2/sites-available" "/etc/apache2/sites-enabled" "/vagrant/logs" "/vagrant/logs/php${ARG_PHPVERSION}"

echo "Setting up VHOST \"$ARG_HOST\""

block="  UseCanonicalName Off
  Define PHPSOCKET $COMMONKEY
  Define PHPVERSION $ARG_PHPVERSION
  Define PHPBASEDIR $PHP_BASEDIR
  DocumentRoot $ARG_DOCROOT
  Include includes/*.conf";

if [ -f "$ARG_DOCROOT/$ARG_404" ]; then
  $block+="
  ErrorDocument 404 /$ARG_404";
fi

echo "<VirtualHost *:80>
  ServerName $ARG_HOST:80
" > /etc/apache2/sites-available/$COMMONKEY.conf

if [[ "$ARG_SSL" == "1" ]]; then
  echo "
  Redirect permanent / https://$ARG_HOST/
" >> /etc/apache2/sites-available/$COMMONKEY.conf
fi

echo "$block
</VirtualHost>" >> /etc/apache2/sites-available/$COMMONKEY.conf

if [[ "$ARG_SSL" == "1" ]]; then
  echo "<VirtualHost *:443>
  ServerName $ARG_HOST:443
$block
  <IfModule ssl_module>
    SSLEngine on
    SSLVerifyClient none
    SSLCertificateFile /vagrant/ssl/$ARG_HOST.crt
    SSLCertificateKeyFile /vagrant/ssl/$ARG_HOST.key
  </IfModule>
</VirtualHost>" > /etc/apache2/sites-available/$COMMONKEY-ssl.conf;
fi;

echo "Creating FPM file"
tmpfile=$(mktemp /tmp/fpm_conf.XXXXXX)
block="[$COMMONKEY]
listen = /run/php/$COMMONKEY-%VERSION%.sock

php_admin_value[open_basedir] = \"$PHP_BASEDIR:/tmp\"
php_admin_value[error_log] = /vagrant/logs/php%VERSION%/php-fpm.\$pool.error.log
php_admin_flag[log_errors] = on

include = \"/etc/php/common.conf\"
";
echo "$block" > $tmpfile

for f in /home/vagrant/stubs/*; do
  if [ ! -d "${f}" ]; then
    continue;
  fi;
  dir=${f##*/}
  ver=$(echo ${dir} | cut -c4-)

  sed "s/%VERSION%/$ver/g" $tmpfile > /etc/php/$ver/fpm/pool.d/$COMMONKEY.conf
done

SITES="$COMMONKEY"
if [[ "$ARG_SSL" == "1" ]]; then
  SITES+=" $COMMONKEY-ssl"
fi

a2ensite "$SITES"
