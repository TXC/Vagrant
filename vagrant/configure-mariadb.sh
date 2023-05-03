#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

systemctl stop mysqld.service

echo "CONFIGURING MariaDB"

CONFDIR="/etc/mysql/mariadb.conf.d"
MYCNF="/home/vagrant/.my.cnf"

if [ ! -f "${CONFDIR}/55-vagrant.cnf" ]; then
  cp "${STUBROOT}/mysql/vagrant.cnf" \
    "${CONFDIR}/55-vagrant.cnf"
fi

LOGS_FILE=$(awk -F "=" '/log_error/ {print $2}' "${CONFDIR}/55-vagrant.cnf" |tr -d ' ')
LOGS_PATH=$(dirname "${LOGS_FILE}")
mkdir -p "${LOGS_PATH}"

systemctl start mysqld.service

echo "CHECKING USER SETTINGS IN MariaDB"

if [ ! -f "${MYCNF}" ]; then
  cp "${STUBROOT}/mysql/my.cnf" \
    "${MYCNF}"

  chown vagrant: "${MYCNF}"
  chmod 600 "${MYCNF}"
fi;

MU=$(awk -F "=" '/user/ {print $2}' "${MYCNF}" |tr -d ' ')
MP=$(awk -F "=" '/password/ {print $2}' "${MYCNF}" |tr -d ' ')

echo "SETTING UP '${MU}' USER IN MariaDB"

sql="SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user='${MU}');"
RESULT_VARIABLE="$(sudo mysql -sse "${sql}")";
if [ "$RESULT_VARIABLE" -eq "0" ]; then
  sql="CREATE USER '${MU}'@'%' IDENTIFIED BY '${MP}'; "
  #sql+="CREATE USER '${MU}'@'localhost' IDENTIFIED WITH unix_socket; "
  sql+="flush privileges;"
  sudo mysql -u root -e "${sql}"
fi;
