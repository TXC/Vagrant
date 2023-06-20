#!/usr/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

export ARG_HOST=$1
export ARG_DOCROOT=$2
export ARG_SSL=$3
export ARG_PHPVERSION=$4
export ARG_404=$5

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  echo "Missing argument to script."
  echo "Usage: $0 <hostname> <docroot> <use ssl [0 or 1]> <php version> [<404 path, relative to docroot>]"
  exit 1;
fi;

if [ -L /usr/local/sbin/create_site ]; then
    ln -sf "/vagrant/deployment/create-site.sh" "/usr/local/sbin/create_site";
fi

export COMMONKEY=$(echo $ARG_HOST |openssl dgst -sha384 |sed 's/^.* //'|cut -c1-8)
export PHP_BASEDIR=$(findmnt -n --target $ARG_DOCROOT | head -n 1 | awk '{ print $1 }')

mkdir -p "${LOGS_PATH}/php${ARG_PHPVERSION}" \

create_site() {
  if [ -f /etc/apache2/apache2.conf ]; then
    mkdir -p "${SITE_PATH}/apache2"
    echo "* Creating HTTP Apache2 file for ${COMMONKEY}"
    create_apache_site 80
    if [[ "${ARG_SSL}" == "1" ]]; then
      echo "* Creating HTTPS Apache2 file for ${COMMONKEY}"
      create_apache_site 443
    fi
  fi

  if [ -f /etc/nginx/nginx.conf ]; then
    mkdir -p "${SITE_PATH}/nginx"
    echo "* Creating HTTP Nginx file for ${COMMONKEY}"
    create_nginx_site 80
    if [[ "${ARG_SSL}" == "1" ]]; then
      echo "* Creating HTTPS Nginx file for ${COMMONKEY}"
      create_nginx_site 443
    fi
  fi
}

create_apache_site () {
  export HTTP_PORT=$1

  if [[ "${HTTP_PORT}" == "80" ]]; then
    CFG="${SITE_PATH}/apache2/${COMMONKEY}.conf";
  else
    CFG="${SITE_PATH}/apache2/${COMMONKEY}-ssl.conf";
  fi
  FILE=$(basename ${CFG})

  tmpfile=$(mktemp /tmp/apache2.XXXXXX)

  cat "${STUBROOT}/apache2/vhost/vhost-start.conf" | tee -a $tmpfile

  if [ ! -z "${ARG_PHPVERSION}" ]; then
    cat "${STUBROOT}/apache2/vhost/vhost-php.conf" | tee -a $tmpfile
  fi;

  if [ ! -z "${ARG_404}" ] && [ -f "${ARG_DOCROOT}/${ARG_404}" ]; then
    cat "${STUBROOT}/apache2/vhost/vhost-404.conf" | tee -a $tmpfile
  fi

  if [[ "${ARG_SSL}" == "1" ]] && [[ "${HTTP_PORT}" == "80" ]]; then
    cat "${STUBROOT}/apache2/vhost/vhost-redirect-ssl.conf" | tee -a $tmpfile
  elif [[ "${ARG_SSL}" == "1" ]] && [[ "${HTTP_PORT}" == "443" ]]; then
    cat "${STUBROOT}/apache2/vhost/vhost-ssl.conf" | tee -a $tmpfile
  else
    cat "${STUBROOT}/apache2/vhost/vhost-non-ssl.conf" | tee -a $tmpfile
  fi;
  cat "${STUBROOT}/apache2/vhost/vhost-end.conf" | tee -a $tmpfile

  cat $tmpfile | envsubst | tee $CFG
  rm $tmpfile
  touch "${LOGS_PATH}/apache2/${COMMONKEY}_access.log" \
        "${LOGS_PATH}/apache2/${COMMONKEY}_error.log"

  ln -sf $CFG "/etc/apache2/sites-enabled/${FILE}";
}

create_nginx_site () {
  export HTTP_PORT=$1

  if [[ "${HTTP_PORT}" == "80" ]]; then
    CFG="${SITE_PATH}/nginx/${COMMONKEY}.conf";
  else
    CFG="${SITE_PATH}/nginx/${COMMONKEY}-ssl.conf";
  fi
  FILE=$(basename ${CFG})

  tmpfile=$(mktemp /tmp/nginx.XXXXXX)

  cat "${STUBROOT}/nginx/vhost/vhost-start.conf" | tee -a $tmpfile

  if [ ! -z "${ARG_PHPVERSION}" ]; then
    cat "${STUBROOT}/nginx/vhost/vhost-php.conf" | tee -a $tmpfile
  fi;

  if [ ! -z "${ARG_404}" ] && [ -f "${ARG_DOCROOT}/${ARG_404}" ]; then
    cat "${STUBROOT}/nginx/vhost/vhost-404.conf" | tee -a $tmpfile
  fi

  if [[ "${ARG_SSL}" == "1" ]] && [[ "${HTTP_PORT}" == "80" ]]; then
    cat "${STUBROOT}/nginx/vhost/vhost-redirect-ssl.conf" | tee -a $tmpfile
  elif [[ "${ARG_SSL}" == "1" ]] && [[ "${HTTP_PORT}" == "443" ]]; then
    cat "${STUBROOT}/nginx/vhost/vhost-ssl.conf" | tee -a $tmpfile
    HTTP_PORT+=' ssl http2'
  else
    cat "${STUBROOT}/nginx/vhost/vhost-non-ssl.conf" | tee -a $tmpfile
  fi;
  cat "${STUBROOT}/nginx/vhost/vhost-end.conf" | tee -a $tmpfile

  cat $tmpfile | envsubst \
  '$COMMONKEY $HTTP_PORT $LOGS_PATH $ARG_HOST $ARG_DOCROOT $ARG_PHPVERSION $ARG_404 $SSL_PATH' \
  | tee $CFG

  rm $tmpfile
  touch "${LOGS_PATH}/nginx/${COMMONKEY}_access.log" \
        "${LOGS_PATH}/nginx/${COMMONKEY}_error.log"

  ln -sf $CFG "/etc/nginx/sites-enabled/${FILE}";
}

create_phpfpm () {
  CONF=$(cat "${STUBROOT}/php/vagrant-fpm-pool.conf")
  poolroot="${SITE_PATH}/php"
  if [ ! -d "${poolroot}" ]; then
    mkdir -p "${poolroot}"
  fi

  #for VERSION in ${PHP_VERSIONS}; do
  #  export VERSION
  #  echo "Creating PHP-FPM Config for PHP${VERSION}"
  #  CFG="${poolroot}/${COMMONKEY}-${VERSION}.conf"
  #  echo "$CONF" | envsubst '$COMMONKEY $LOGS_PATH $PHP_BASEDIR $VERSION' | tee $CFG
  #
  #  ln -sf "${CFG}" "/etc/php/${VERSION}/fpm/pool.d/${COMMONKEY}.conf";
  #done

  export VERSION="${ARG_PHPVERSION}"
  echo "Creating PHP-FPM Config for PHP${VERSION}"
  CFG="${poolroot}/${COMMONKEY}.conf"
  echo "$CONF" | envsubst '$COMMONKEY $LOGS_PATH $PHP_BASEDIR $VERSION' | tee $CFG
  ln -sf "${CFG}" "/etc/php/${VERSION}/fpm/pool.d/${COMMONKEY}.conf";
}

echo "Creating PHP-FPM file for ${COMMONKEY}"
create_phpfpm

echo "Creating Site files for ${COMMONKEY}"
create_site
