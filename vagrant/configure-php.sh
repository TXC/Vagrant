#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

#TIMEZONE=$(timedatectl | grep "Time zone" | awk {' print $3 '})

echo "CONFIGURING PHP"

for f in /home/vagrant/stubs/php*; do
  if [ ! -d "${f}" ]; then
    continue;
  fi;

  dir=${f##*/}
  ver=$(echo ${dir} | cut -c4-)
  cp "/home/vagrant/stubs/${dir}/vagrant.ini" "/etc/php/${ver}/mods-available/vagrant.ini"
  sed -i "s/^pm = .*/pm = ondemand/" "/etc/php/${ver}/fpm/pool.d/www.conf"
  sed -i -e "s#^xdebug\.remote_host.*#xdebug\.remote_host=${HOSTIP}#;" \
         -e "s#^xdebug\.client_host.*#xdebug\.client_host=${HOSTIP}#;" \
         -e "s#^xdebug\.remote_log.*#xdebug\.remote_log=${LOGS_PATH}#;" \
         -e "s#^xdebug\.output_dir.*#xdebug\.output_dir=${LOGS_PATH}#;" \
         -e "s#^xdebug\.profiler_output_dir.*#xdebug\.profiler_output_dir=${LOGS_PATH}#;" \
         -e "s#^date\.timezone.*#date\.timezone=${TIMEZONE}#" \
            "/etc/php/${ver}/mods-available/vagrant.ini"

  cp "/home/vagrant/stubs/vagrant-cli.ini" "/etc/php/${ver}/mods-available/"
done

#if [ ! -f "/etc/php/common.conf" ]; then
  cat << 'EOF' > "/etc/php/common.conf"
user = vagrant
group = vagrant

listen.owner = vagrant
listen.group = vagrant

pm = ondemand
pm.start_servers = 0
pm.min_spare_servers = 1
pm.max_spare_servers = 5
pm.max_children = 5
pm.process_idle_timeout = 10s
pm.max_requests = 200

php_admin_value[session.use_strict_mode] = 1
php_admin_value[session.cookie_secure] = 1
php_admin_value[session.gc_maxlifetime] = "3600"
php_admin_value[session.save_handler] = "redis"
php_admin_value[session.save_path] = "tcp://127.0.0.1:6379"
php_admin_value[soap.wsdl_cache_dir] = "tcp://127.0.0.1:6379"

catch_workers_output = yes

php_flag[display_errors] = on

clear_env = no
EOF
#fi

phpenmod vagrant
phpenmod -s cli vagrant-cli