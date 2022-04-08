#!/bin/bash

HOSTIP=$1

echo "CONFIGURING APACHE"

mkdir -p /vagrant/logs
chown -R vagrant: /vagrant/logs

sed -i "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=vagrant/" /etc/apache2/envvars
sed -i "s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=vagrant/" /etc/apache2/envvars

block="FileETag None

<Directory \"/var/www\">
  Options -Indexes
</Directory>

<Files ~\"\.log\$\">
  Order allow,deny
  Deny from all
</Files>
";
echo "$block" > /etc/apache2/conf-available/vagrant.conf

mkdir -p /etc/apache2/includes
block="<IfModule mpm_itk_module>
    AssignUserId vagrant vagrant
</IfModule>
";
echo "$block" > /etc/apache2/includes/itk.conf

block="LogFormat \"%v:%p %h %l %u %t \\\"%r\\\" %>s %B \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\" h2_vhost_combined
LogFormat \"%h %l %u %t \\\"%r\\\" %>s %B \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\" h2_combined
LogFormat \"%h %l %u %t \\\"%r\\\" %>s %B\" h2_common

ErrorLog \${APACHE_LOG_DIR}/\${PHPSOCKET}_error.log
CustomLog \${APACHE_LOG_DIR}/\${PHPSOCKET}_access.log h2_vhost_combined
";
echo "$block" > /etc/apache2/includes/logging.conf

block="<IfModule headers_module>
    Header always set Strict-Transport-Security \"max-age=63072000; includeSubDomains\"
</IfModule>

<IfModule expires_module>
    ExpiresActive on
    ExpiresDefault \"access plus 30 seconds\"
    ExpiresByType image/gif \"access plus 1 months\"
    ExpiresByType image/jpg \"access plus 1 months\"
    ExpiresByType image/jpeg \"access plus 1 months\"
    ExpiresByType image/png \"access plus 1 months\"
    ExpiresByType text/js \"access plus 1 months\"
    ExpiresByType text/javascript \"access plus 1 months\"

    ExpiresByType application/javascript \"access plus 1 months\"
    ExpiresByType text/css \"access plus 1 months\"
    ExpiresByType font/woff2 \"access plus 1 months\"
    ExpiresByType application/font-woff2 \"access plus 1 months\"
    ExpiresByType application/x-font-woff \"access plus 1 months\"
    ExpiresByType application/font-woff \"access plus 1 months\"
    ExpiresByType image/svg+xml \"access plus 1 months\"
</IfModule>

#<IfModule deflate_module>
#    <IfModule filter_module>
#        AddType image/svg+xml .svg
#        AddOutputFilterByType DEFLATE image/svg+xml
#    </IfModule>
##    SetOutputFilter DEFLATE
##    SetEnvIfNoCase Request_URI \"\.(?:gif|jpe?g|png)$\" no-gzip
#    Header append Vary User-Agent
#    DeflateCompressionLevel 9
#</IfModule>

<IfModule mime_module>
    AddEncoding gzip .gz
    <IfModule rewrite_module>
        RewriteEngine On
        RewriteRule \.css\.gz$ - [T=text/css,E=no-gzip:1,E=is_gzip:1]
        RewriteRule \.js\.gz$ - [T=text/javascript,E=no-gzip:1,E=is_gzip:1]
        <IfModule headers_module>
            Header append Vary Accept-Encoding
            Header set Content-Encoding \"gzip\" env=is_gzip
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
";
echo "$block" > /etc/apache2/includes/modules.conf

block="<IfModule php5_module>
    php_admin_value open_basedir \"%{DOCUMENT_ROOT}:/tmp\"
    php_admin_value session.save_handler = \"redis\"
    php_admin_value session.save_path = \"tcp://127.0.0.1:6379\"
    #php_admin_value session.save_path \"/var/lib/php/sessions/\"
</IfModule>

<IfModule php7_module>
    php_admin_value open_basedir \"%{DOCUMENT_ROOT}:/tmp\"
    php_admin_value session.save_handler = \"redis\"
    php_admin_value session.save_path = \"tcp://127.0.0.1:6379\"
    #php_admin_value session.save_path \"/var/lib/php/sessions/\"
</IfModule>

<IfModule fastcgi_module>
    TimeOut 3600
    KeepAliveTimeout 3600

    <Directory /usr/lib/cgi-bin>
        Require all granted
    </Directory>
    AddHandler php-fcgi .php
    Action php-fcgi /php-fcgi
    Alias /php-fcgi /usr/lib/cgi-bin/php-fcgi-\${PHPSOCKET}-%{SERVER_PORT}
    <IfDefine PHPVERSION>
        FastCgiExternalServer /usr/lib/cgi-bin/php-fcgi-\${PHPSOCKET}-%{SERVER_PORT} -socket /run/php/\${PHPSOCKET}-\${PHPVERSION}.sock -pass-header Authorization -idle-timeout 30000 -flush
    </IfDefine>
    <IfDefine !PHPVERSION>
        FastCgiExternalServer /usr/lib/cgi-bin/php-fcgi-\${PHPSOCKET}-%{SERVER_PORT} -socket /run/php/\${PHPSOCKET}-7.4.sock -pass-header Authorization -idle-timeout 30000 -flush
    </IfDefine>
</IfModule>

<IfModule proxy_fcgi_module>
    <FilesMatch \"\.php$\">
        <IfDefine PHPVERSION>
            SetHandler \"proxy:unix:/run/php/\${PHPSOCKET}-\${PHPVERSION}.sock|fcgi://localhost\"
        </IfDefine>
        <IfDefine !PHPVERSION>
            SetHandler \"proxy:unix:/run/php/\${PHPSOCKET}-7.4.sock|fcgi://localhost\"
        </IfDefine>
    </FilesMatch>
</IfModule>

# We need to Unset these variables everytime, since they leak!
Undefine PHPSOCKET
Undefine PHPVERSION
";
echo "$block" > /etc/apache2/includes/php.conf

sed -i "s/SSLCipherSuite.*/SSLCipherSuite HIGH:!MEDIUM:!aNULL:!MD5:!RC4/" "/etc/apache2/mods-available/ssl.conf"
sed -i "s/SSLProtocol.*/SSLProtocol -ALL +TLSv1.2 +TLSv1.3/" "/etc/apache2/mods-available/ssl.conf"

a2enconf vagrant
a2dismod mpm_event mpm_prefork mpm_worker
a2enmod actions cgid expires headers mpm_event http2 proxy_fcgi rewrite ssl
