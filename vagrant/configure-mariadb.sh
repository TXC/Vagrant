#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

systemctl stop mysqld.service

echo "CONFIGURING MariaDB"

# sql_mode               = 'NO_UNSIGNED_SUBTRACTION,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'

cat <<'CONF' > /etc/mysql/mariadb.conf.d/55-vagrant.cnf
[mysqld]
bind-address            = 0.0.0.0

sql_mode                = 'NO_UNSIGNED_SUBTRACTION,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'

max_allowed_packet      = 16M
thread_stack            = 192K
thread_cache_size       = 8

innodb_buffer_pool_size = 1024M
key_buffer_size         = 256M
query_cache_limit       = 2M
query_cache_size        = 128M
query_cache_type        = 1  # Just means ON

log_error = /var/log/mysql/error.log
CONF

systemctl start mysqld.service

sql="SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user='vagrant');"
RESULT_VARIABLE="$(sudo mysql -sse "${sql}")";
echo "RESULT_VARIABLE: ${RESULT_VARIABLE}"
if [ "$RESULT_VARIABLE" -eq "0" ]; then
  sql="CREATE USER 'vagrant'@'%' IDENTIFIED BY 'vagrant'; "
  #sql+="CREATE USER 'vagrant'@'localhost' IDENTIFIED WITH unix_socket; "
  sql+="flush privileges;"
  sudo mysql -u root -e "${sql}"
fi;

MYCNF="/home/vagrant/.my.cnf"
if [ ! -f "${MYCNF}" ]; then
  cat <<'MYCNF' > "${MYCNF}"
[client]
user=vagrant
password=vagrant
MYCNF
  chown vagrant: "${MYCNF}"
  chmod 600 "${MYCNF}"
fi;