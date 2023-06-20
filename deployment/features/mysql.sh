#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

if [ -z "${version}" ]; then
  version="8.0"
fi

# Add MySQL
SOURCES_FILE="/etc/apt/sources.list.d/mysql-${MYSQL_VERSION}.list"
echo "deb http://repo.mysql.com/apt/ubuntu/ ${CODENAME} mysql-${MYSQL_VERSION}" > ${SOURCES_FILE}

debconf-set-selections <<< "mysql-server mysql-server/data-dir select ''"
debconf-set-selections <<< "mysql-server mysql-server/root_password password secret"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password secret"
debconf-set-selections <<< "mysql-server-${MYSQL_VERSION} mysql-server-${MYSQL_VERSION}/postrm_remove_databases boolean false"

mkdir /etc/mysql
touch /etc/mysql/debian.cnf

apt-get -o Dpkg::Options::="--force-confnew" install -y mysql-server mysql-client mysql-common

systemctl stop mysqld.service

echo "CONFIGURING MySQL"

CONFDIR="/etc/mysql/mysql.conf.d"
MYCNF="/home/vagrant/.my.cnf"

if [ ! -f "${CONFDIR}/55-vagrant.cnf" ]; then
  cp "${STUBROOT}/mysql/vagrant.cnf" \
    "${CONFDIR}/55-vagrant.cnf"
fi

LOGS_FILE=$(awk -F "=" '/log_error/ {print $2}' "${CONFDIR}/55-vagrant.cnf" |tr -d ' ')
LOGS_PATH=$(dirname "${LOGS_FILE}")
mkdir -p "${LOGS_PATH}"

systemctl start mysqld.service

mysql_upgrade --user="root" --verbose --force

echo "CHECKING USER SETTINGS IN MySQL"

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
