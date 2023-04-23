#!/usr/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

export ARG_HOST=$1
export ARG_DOCROOT=$2
export ARG_SSL=$3
export ARG_PHPVERSION=$4
export ARG_404=$5

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  echo "Missing argument to script."
  echo "Usage: $0 <hostname> <docroot> <use ssl [0 or 1]> <php version> [<404 path, relative to docroot>]"
  return 1;
fi;

export COMMONKEY=$(echo $ARG_HOST |openssl dgst -sha384 |sed 's/^.* //'|cut -c1-8)
export PHP_BASEDIR=$(findmnt -n --target $ARG_DOCROOT | head -n 1 | awk '{ print $1 }')

SUBST="\$ARG_HOST \$ARG_DOCROOT \$ARG_SSL \$ARG_PHPVERSION \$ARG_404 "
SUBST+="\$COMMONKEY \$PHP_BASEDIR \$ADDITIONAL \$HTTP_PORT"

mkdir -p "${LOGS_PATH}/php${ARG_PHPVERSION}" \
         "${SITE_PATH}/php" \
         "${SITE_PATH}/apache2" \
         "${SITE_PATH}/nginx"

enablesite () {
    ln -sf "${SITE_PATH}/nginx/${1}.conf" \
          "/etc/apache2/sites-enabled/${1}.conf";

    ln -sf "${SITE_PATH}/nginx/${1}.conf" \
          "/etc/nginx/sites-enabled/${1}.conf";
}

create_apache_site () {
  export HTTP_PORT=$1

  if [[ "$HTTP_PORT" == "80" ]]; then
    CFG="${SITE_PATH}/apache2/$COMMONKEY.conf";
  else
    CFG="${SITE_PATH}/apache2/$COMMONKEY-ssl.conf";
  fi

  if [ -f "${CFG}" ]; then
    return 0
  fi;

  read -r -d '' VHOST <<'VHOST'
<VirtualHost *:${HTTP_PORT}>
  UseCanonicalName Off
  ServerName ${ARG_HOST}:${HTTP_PORT}
  DocumentRoot ${ARG_DOCROOT}
  ${ADDITIONAL}
  Include includes/*.conf
</VirtualHost>
VHOST

  export ADDITIONAL=""
  if [ ! -z "$ARG_PHPVERSION" ]; then
    ADDITIONAL+="
  Define PHPSOCKET ${COMMONKEY}
  Define PHPVERSION ${ARG_PHPVERSION}
  Define PHPBASEDIR ${PHP_BASEDIR}"
  fi;

  if [ ! -z "$ARG_404" ] && [ -f "$ARG_DOCROOT/$ARG_404" ]; then
    ADDITIONAL+="
  ErrorDocument 404 /${ARG_404}"
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "80" ]]; then
    ADDITIONAL+="
  Redirect permanent / https://${ARG_HOST}/"
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "443" ]]; then
    ADDITIONAL+="
  <IfModule ssl_module>
    SSLEngine on
    SSLVerifyClient none
    SSLCertificateFile ${SSL_PATH}/${ARG_HOST}.crt
    SSLCertificateKeyFile ${SSL_PATH}/${ARG_HOST}.key
  </IfModule>"
  fi;

  echo "$VHOST" | envsubst > $CFG
  touch "${LOGS_PATH}/apache2/${COMMONKEY}_access.log" \
        "${LOGS_PATH}/apache2/${COMMONKEY}_error.log"
}

create_nginx_site () {
  export HTTP_PORT=$1

  if [[ "$HTTP_PORT" == "80" ]]; then
    CFG="${SITE_PATH}/nginx/${COMMONKEY}.conf";
  else
    CFG="${SITE_PATH}/nginx/${COMMONKEY}-ssl.conf";
  fi

  if [ -f "${CFG}" ]; then
    return 0
  fi;

  read -r -d '' VHOST <<'VHOST'
server {
  listen ${HTTP_PORT};
  listen [::]:${HTTP_PORT};
  server_name ${ARG_HOST};
  root ${ARG_DOCROOT};
  access_log ${LOGS_PATH}/nginx/${COMMONKEY}_access.log vhost;
  error_log ${LOGS_PATH}/nginx/${COMMONKEY}_error.log error;
  ${ADDITIONAL}
  include includes/*.conf;
}
VHOST

  export ADDITIONAL=""
  if [ ! -z "$ARG_PHPVERSION" ]; then
    ADDITIONAL+="
  location / {
    index index.php;
    try_files \${uri} /index.php\${is_args}\${args};
  }

  location ~ \.php$ {
    fastcgi_split_path_info ^(.+?\.php)(/.*)$;
    try_files \${fastcgi_script_name} =404;
    set \${path_info} \${fastcgi_path_info};
    #fastcgi_param PATH_INFO \${path_info};

    #fastcgi_pass ${PHPSOCKET};
    fastcgi_index index.php;
    fastcgi_pass unix:/var/run/php/${COMMONKEY}-${ARG_PHPVERSION}.sock;
    include fastcgi.conf;
    fastcgi_param SCRIPT_FILENAME \${realpath_root}\${fastcgi_script_name};
    fastcgi_param PATH_INFO \${fastcgi_path_info};
  }"
  fi;

  if [ ! -z "$ARG_404" ] && [ -f "$ARG_DOCROOT/$ARG_404" ]; then
    $ADDITIONAL+="
  error_page 404 /${ARG_404};"
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "80" ]]; then
    ADDITIONAL+="
  return 301 https://${ARG_HOST}/\$request_uri;"
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "443" ]]; then
    ADDITIONAL+="
  ssl_certificate     ${SSL_PATH}/${ARG_HOST}.crt;
  ssl_certificate_key ${SSL_PATH}/${ARG_HOST}.key;
  ssl_verify_client   off;"
    HTTP_PORT+=' ssl http2'
  fi;

  echo "$VHOST" | envsubst '$COMMONKEY $HTTP_PORT $LOGS_PATH $ARG_HOST $ARG_DOCROOT $ARG_PHPVERSION $ARG_404 $ADDITIONAL' > $CFG
  touch "${LOGS_PATH}/nginx/${COMMONKEY}_access.log" \
        "${LOGS_PATH}/nginx/${COMMONKEY}_error.log"
}

create_phpfpm () {
  read -r -d '' CONF <<'CONF'
[${COMMONKEY}]
listen = /run/php/${COMMONKEY}-${VERSION}.sock
php_admin_value[open_basedir] = "${PHP_BASEDIR}:/tmp"
php_admin_value[error_log] = ${LOGS_PATH}/php${VERSION}/php-fpm.$pool.error.log
php_admin_flag[log_errors] = on

include = "/etc/php/common.conf"
CONF

  for f in /home/vagrant/stubs/*; do
    if [ ! -d "${f}" ]; then
      continue;
    fi;
    dir=${f##*/}
    export VERSION=$(echo ${dir} | cut -c4-)

    CFG="/etc/php/$VERSION/fpm/pool.d/$COMMONKEY.conf"
    #CFG="${SITE_PATH}/php/${COMMONKEY}.conf";
    if [ ! -f "${CFG}" ]; then
      echo "$CONF" | envsubst '$COMMONKEY $LOGS_PATH $PHP_BASEDIR $VERSION' > $CFG
    fi
  done
}

echo "Creating PHP-FPM file for ${COMMONKEY}"
create_phpfpm

echo "Creating HTTP Site files for ${COMMONKEY}"
create_apache_site 80
create_nginx_site 80

enablesite "$COMMONKEY"

if [[ "$ARG_SSL" == "1" ]]; then
  echo "Creating HTTPS Site files for ${COMMONKEY}"

  create_apache_site 443
  create_nginx_site 443

  enablesite "$COMMONKEY-ssl"
fi;
