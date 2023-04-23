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

if [ ! -f "/etc/apache2/conf-available/vagrant.conf" ]; then
  cat << 'VAGRANT' > "/etc/apache2/conf-available/vagrant.conf"
FileETag None

<Directory "/var/www">
  Options -Indexes
</Directory>

<Files ~"\.log$">
  Order allow,deny
  Deny from all
</Files>
VAGRANT
fi;

if [ ! -f "/etc/apache2/conf-available/itk.conf" ]; then
  cat <<'ITK' > "/etc/apache2/conf-available/itk.conf"
<IfModule mpm_itk_module>
  AssignUserId vagrant vagrant
</IfModule>
ITK
fi

if [ ! -f "/etc/apache2/conf-available/modules.conf" ]; then
  cat <<'MODULES' > "/etc/apache2/conf-available/modules.conf"
<IfModule headers_module>
  Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
  RequestHeader set "X-Forwarded-Proto" expr=%{REQUEST_SCHEME}
  ProxyPreserveHost On
</IfModule>

<IfModule expires_module>
  ExpiresActive on
  ExpiresDefault "access plus 30 seconds"
  ExpiresByType image/gif "access plus 1 months"
  ExpiresByType image/jpg "access plus 1 months"
  ExpiresByType image/jpeg "access plus 1 months"
  ExpiresByType image/png "access plus 1 months"
  ExpiresByType text/js "access plus 1 months"
  ExpiresByType text/javascript "access plus 1 months"

  ExpiresByType application/javascript "access plus 1 months"
  ExpiresByType text/css "access plus 1 months"
  ExpiresByType font/woff2 "access plus 1 months"
  ExpiresByType application/font-woff2 "access plus 1 months"
  ExpiresByType application/x-font-woff "access plus 1 months"
  ExpiresByType application/font-woff "access plus 1 months"
  ExpiresByType image/svg+xml "access plus 1 months"
</IfModule>

<IfModule mime_module>
  AddEncoding gzip .gz
  <IfModule rewrite_module>
    RewriteEngine On
    RewriteRule \.css\.gz$ - [T=text/css,E=no-gzip:1,E=is_gzip:1]
    RewriteRule \.js\.gz$ - [T=text/javascript,E=no-gzip:1,E=is_gzip:1]
    <IfModule headers_module>
      Header append Vary Accept-Encoding
      Header set Content-Encoding "gzip" env=is_gzip
    </IfModule>
  </IfModule>
</IfModule>

<IfModule proxy_module>
  ProxyTimeout 3600
  TimeOut 3600
  KeepAliveTimeout 3600
</IfModule>

<IfModule http2_module>
  Protocols h2 h2c http/1.1
  H2Upgrade on
</IfModule>
MODULES
fi

if [ ! -f "/etc/apache2/includes/logging.conf" ]; then
  cat <<'LOGGING' > "/etc/apache2/includes/logging.conf"
LogFormat "%v:%p %h %l %u %t \"%r\" %>s %B \"%{Referer}i\" \"%{User-Agent}i\"" h2_vhost_combined
LogFormat "%h %l %u %t \"%r\" %>s %B \"%{Referer}i\" \"%{User-Agent}i\"" h2_combined
LogFormat "%h %l %u %t \"%r\" %>s %B\" h2_common

ErrorLog ${APACHE_LOG_DIR}/${PHPSOCKET}_error.log
CustomLog ${APACHE_LOG_DIR}/${PHPSOCKET}_access.log h2_vhost_combined
LOGGING
fi

if [ ! -f "/etc/apache2/includes/php.conf" ]; then
  cat <<'PHP' > "/etc/apache2/includes/php.conf"
<IfModule php5_module>
  <IfDefine PHPBASEDIR>
    php_admin_value open_basedir "${PHPBASEDIR}:/tmp"
  </IfDefine>
  <IfDefine !PHPBASEDIR>
    php_admin_value open_basedir "%{DOCUMENT_ROOT}:/tmp"
  </IfDefine>
  php_admin_value session.save_handler = "redis"
  php_admin_value session.save_path = "tcp://127.0.0.1:6379"
</IfModule>

<IfModule php7_module>
  <IfDefine PHPBASEDIR>
    php_admin_value open_basedir "${PHPBASEDIR}:/tmp"
  </IfDefine>
  <IfDefine !PHPBASEDIR>
    php_admin_value open_basedir "%{DOCUMENT_ROOT}:/tmp"
  </IfDefine>
    php_admin_value session.save_handler = "redis"
    php_admin_value session.save_path = "tcp://127.0.0.1:6379"
</IfModule>

<IfModule fastcgi_module>
  TimeOut 3600
  KeepAliveTimeout 3600

  <Directory /usr/lib/cgi-bin>
    Require all granted
  </Directory>
  AddHandler php-fcgi .php
  Action php-fcgi /php-fcgi
  Alias /php-fcgi /usr/lib/cgi-bin/php-fcgi-${PHPSOCKET}-%{SERVER_PORT}
  <IfDefine PHPVERSION>
    FastCgiExternalServer /usr/lib/cgi-bin/php-fcgi-${PHPSOCKET}-%{SERVER_PORT} -socket /run/php/${PHPSOCKET}-${PHPVERSION}.sock -pass-header Authorization -idle-timeout 30000 -flush
  </IfDefine>
  <IfDefine !PHPVERSION>
    FastCgiExternalServer /usr/lib/cgi-bin/php-fcgi-${PHPSOCKET}-%{SERVER_PORT} -socket /run/php/${PHPSOCKET}-8.1.sock -pass-header Authorization -idle-timeout 30000 -flush
  </IfDefine>
</IfModule>

<IfModule proxy_fcgi_module>
  <FilesMatch "\.php$">
    <IfDefine PHPVERSION>
      SetHandler "proxy:unix:/run/php/${PHPSOCKET}-${PHPVERSION}.sock|fcgi://localhost"
    </IfDefine>
    <IfDefine !PHPVERSION>
      SetHandler "proxy:unix:/run/php/${PHPSOCKET}-8.1.sock|fcgi://localhost"
    </IfDefine>
  </FilesMatch>
</IfModule>

# We need to Unset these variables everytime, since they leak!
Undefine PHPSOCKET
Undefine PHPVERSION
Undefine PHPBASEDIR
PHP
fi

if [ ! -f "/etc/apache2/includes/vhost.conf" ]; then
  cat <<'VHOST' > "/etc/apache2/includes/vhost.conf"
<Directory />
  Options -Indexes
  AllowOverride All
</Directory>
<Directory %{DOCUMENT_ROOT}>
  Options -Indexes
  AllowOverride All
  Order allow,deny
  allow from all
  Require all granted
</Directory>
Options -Includes
VHOST
fi

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
