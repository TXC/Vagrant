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

  tmpfile=$(mktemp /tmp/apache2.XXXXXX)

  cat "${STUBROOT}/apache2/vhosts/vhost-start.conf" >> $tmpfile

  if [ ! -z "$ARG_PHPVERSION" ]; then
    cat "${STUBROOT}/apache2/vhosts/vhost-php.conf" >> $tmpfile
  fi;

  if [ ! -z "$ARG_404" ] && [ -f "$ARG_DOCROOT/$ARG_404" ]; then
    cat "${STUBROOT}/apache2/vhosts/vhost-404.conf" >> $tmpfile
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "80" ]]; then
    cat "${STUBROOT}/apache2/vhosts/vhost-non-ssl.conf" >> $tmpfile
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "443" ]]; then
    cat "${STUBROOT}/apache2/vhosts/vhost-ssl.conf" >> $tmpfile
  fi;
  cat "${STUBROOT}/apache2/vhosts/vhost-start.conf" >> $tmpfile

  cat $tmpfile | envsubst > $CFG
  rm $tmpfile
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

  tmpfile=$(mktemp /tmp/nginx.XXXXXX)

  cat "${STUBROOT}/nginx/vhosts/vhost-start.conf" >> $tmpfile

  if [ ! -z "$ARG_PHPVERSION" ]; then
    cat "${STUBROOT}/nginx/vhosts/vhost-php.conf" >> $tmpfile
  fi;

  if [ ! -z "$ARG_404" ] && [ -f "$ARG_DOCROOT/$ARG_404" ]; then
    cat "${STUBROOT}/nginx/vhosts/vhost-404.conf" >> $tmpfile
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "80" ]]; then
    cat "${STUBROOT}/nginx/vhosts/vhost-non-ssl.conf" >> $tmpfile
  fi

  if [[ "$ARG_SSL" == "1" ]] && [[ "$HTTP_PORT" == "443" ]]; then
    cat "${STUBROOT}/nginx/vhosts/vhost-ssl.conf" >> $tmpfile
    HTTP_PORT+=' ssl http2'
  fi;
  cat "${STUBROOT}/nginx/vhosts/vhost-start.conf" >> $tmpfile

  cat $tmpfile | envsubst \
  '$COMMONKEY $HTTP_PORT $LOGS_PATH $ARG_HOST $ARG_DOCROOT $ARG_PHPVERSION $ARG_404 $ADDITIONAL' \
  > $CFG

  rm $tmpfile
  touch "${LOGS_PATH}/nginx/${COMMONKEY}_access.log" \
        "${LOGS_PATH}/nginx/${COMMONKEY}_error.log"
}

create_phpfpm () {
  CONF=$(cat "${STUBROOT}/vagrant-fpm-pool.conf")

  for f in ${STUBROOT}/*; do
    if [ ! -d "${f}" ]; then
      continue;
    fi;
    dir=${f##*/}
    export VERSION=$(echo ${dir} | cut -c4-)

    poolroot="/etc/php/${VERSION}/fpm/pool.d"
    modroot="/etc/php/${VERSION}/mods-available"

    CFG="${poolroot}/$COMMONKEY.conf"
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
