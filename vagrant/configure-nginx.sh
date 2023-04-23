#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

echo "CONFIGURING NGINX"

mkdir -p "${LOGS_PATH}/nginx"
chown -R vagrant: "${LOGS_PATH}"
chown -R vagrant: "/var/log/nginx/*"
mkdir -p /etc/nginx/includes

echo -n "SETTING config..."
sed -i -e "s/^user .*;/user vagrant;/" \
       -e "s#^access_log .*;#access_log ${LOGS_PATH}/nginx/access\.log#" \
       -e "s#^error_log .*;#error_log ${LOGS_PATH}/nginx/error\.log#" \
       /etc/nginx/nginx.conf

if [ ! -f "/etc/nginx/conf.d/modules.conf" ]; then
  cat << 'MODULES' > "/etc/nginx/conf.d/modules.conf"
etag off;

add_header Strict-Transport-Security "max-age=63072000; includeSubDomains";

map $sent_http_content_type $expires {
  default         30s;
  ~text/          1M;
  ~image/         1M;
  ~application/   1M;
  ~font/          1M;
}
MODULES
fi

if [ ! -f "/etc/nginx/conf.d/ssl.conf" ]; then
  cat << 'SSL' > "/etc/nginx/conf.d/ssl.conf"
ssl_session_cache   shared:SSL:10m;
ssl_session_timeout 10m;
ssl_ciphers         HIGH:!MEDIUM:!aNULL:!MD5:!RC4;
SSL
fi

if [ ! -f "/etc/nginx/conf.d/logging.conf" ]; then
  cat << 'LOGGING' > "/etc/nginx/conf.d/logging.conf"
log_format  vhost  '$host:$server_port $remote_addr - $remote_user '
                    '[$time_local] "$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    '"$http_x_forwarded_for" "$gzip_ratio"';

log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" "$http_user_agent" '
                    '"$http_x_forwarded_for" "$gzip_ratio"';

log_format  common  '$remote_addr - $remote_user '
                    '[$time_local] "$request" $status $body_bytes_sent'
                    '"$http_x_forwarded_for" "$gzip_ratio"';
LOGGING
fi

if [ ! -f "/etc/nginx/includes/common.conf" ]; then
  cat << 'HEADERS' | envsubst '$LOGS_PATH' > "/etc/nginx/includes/common.conf"
index index.html;
port_in_redirect off;

#access_log ${LOGS_PATH}/nginx/${server_name}_access.log vhost;
#error_log ${LOGS_PATH}/nginx/${server_name}_error.log error;
HEADERS
fi

if [ ! -f "/etc/nginx/includes/headers.conf" ]; then
  cat << 'HEADERS' > "/etc/nginx/includes/headers.conf"
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "origin" always;
HEADERS
fi

if [ ! -f "/etc/nginx/includes/deflate.conf" ]; then
  cat << 'DEFLATE' > "/etc/nginx/includes/deflate.conf"
location ~\.(log)$ {
  deny all;
  return 403;
}
location ~ \.css\.gz$ {
  add_header Content-Encoding gzip;
  add_header Vary Accept-Encoding;
  add_header Content-Type text/css;
}
location ~ \.js\.gz$ {
  add_header Content-Encoding gzip;
  add_header Vary Accept-Encoding;
  add_header Content-Type text/javascript;
}
DEFLATE
fi

echo "DONE"

if [[ "${HTTPD}" != "nginx" ]]; then
  systemctl disable nginx.service
fi;

systemctl stop nginx.service