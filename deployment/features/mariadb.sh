#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

if [ -z "${version}" ]; then
  version="10.6"
fi

# Add Maria PPA
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | \
sudo bash -s -- --skip-maxscale --skip-tools --mariadb-server-version=${version}

debconf-set-selections <<< "mariadb-server mysql-server/data-dir select ''"
debconf-set-selections <<< "mariadb-server mysql-server/root_password password secret"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password secret"

mkdir /etc/mysql
touch /etc/mysql/debian.cnf

aptinstall mariadb-server mariadb-client mariadb-common

echo "CONFIGURING MariaDB"

systemctl stop mysqld.service

CONFDIR="/etc/mysql/mariadb.conf.d"
MYCNF="/home/vagrant/.my.cnf"

if [ ! -f "${CONFDIR}/55-vagrant.cnf" ]; then
  cp "${STUBROOT}/mariadb/vagrant.cnf" \
    "${CONFDIR}/55-vagrant.cnf"
fi

LOGS_FILE=$(awk -F "=" '/log_error/ {print $2}' "${CONFDIR}/55-vagrant.cnf" |tr -d ' ')
LOGS_PATH=$(dirname "${LOGS_FILE}")
mkdir -p "${LOGS_PATH}"

systemctl start mysqld.service

mysql_upgrade --user="root" --verbose --force

echo "CHECKING USER SETTINGS IN MariaDB"

if [ ! -f "${MYCNF}" ]; then
  cp "${STUBROOT}/mariadb/my.cnf" \
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
