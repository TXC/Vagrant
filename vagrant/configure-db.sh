#!/bin/bash

HOSTIP=$1

systemctl stop mysqld.service

echo "CONFIGURING DB"

# sql_mode               = 'NO_UNSIGNED_SUBTRACTION,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'

block="[mysqld]
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
";
echo "$block" > /etc/mysql/mariadb.conf.d/55-vagrant.cnf

systemctl start mysqld.service

RESULT_VARIABLE="$(sudo mysql -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user='vagrant');")";
if [ "$RESULT_VARIABLE" -ne "1" ]; then
  sudo mysql -u root -e "CREATE USER 'vagrant'@'%' IDENTIFIED BY 'vagrant';"
fi;
