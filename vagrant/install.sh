#!/bin/bash

HOSTIP=$1
TIMEZONE=$2
CODENAME=$(lsb_release -c | awk '{ print $2 }')

TZONE=(${TIMEZONE//\// })
debconf-set-selections <<< "tzdata tzdata/Areas select ${TZONE[0]}"
debconf-set-selections <<< "tzdata tzdata/Zones/${TZONE[0]} select ${TZONE[1]}"
timedatectl set-timezone $TIMEZONE

echo "PATCHING"

echo "blacklist {
  devnode \"^(ram|raw|loop|fd|md|dm-|sr|scd|st|sda)[0-9]*\"
}" >> /etc/multipath.conf
systemctl restart multipath-tools.service

echo "INSTALLING PACKAGES"

apt-get -qq -o Dpkg::Use-Pty=0 update > /dev/null 2>&1
apt-get -qqy -o Dpkg::Use-Pty=0 install ca-certificates software-properties-common dirmngr apt-transport-https > /dev/null 2>&1
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' > /dev/null 2>&1
apt-key adv --fetch-keys 'https://ngrok-agent.s3.amazonaws.com/ngrok.asc' > /dev/null 2>&1

add-apt-repository -yn "deb [arch=amd64,arm64,ppc64el] http://mirror.terrahost.no/mariadb/repo/10.6/ubuntu ${CODENAME} main"
#add-apt-repository -yn "deb https://ngrok-agent.s3.amazonaws.com ${CODENAME} main"
add-apt-repository -yn "deb https://ngrok-agent.s3.amazonaws.com buster main"
add-apt-repository ppa:ondrej/php -yn
add-apt-repository ppa:ondrej/apache2 -yn

debconf-set-selections <<< "mariadb-server-10.6 mariadb-server-10.6/postrm_remove_databases boolean false"

apt-get -qq -o Dpkg::Use-Pty=0 update > /dev/null 2>&1

PACKAGES="apache2 sqlite3 redis memcached libmemcached-tools "
PACKAGES+="mariadb-server mariadb-client mariadb-common openssl "
PACKAGES+="gettext ngrok"

for f in /home/vagrant/stubs/*/packages.txt; do
  PACKAGES+=" $(sed 's/#.*//' ${f} | tr '\n' ' ')"
done

echo $PACKAGES | xargs apt-get -qqy -o Dpkg::Use-Pty=0 install

rm -rf /var/cache/apt/*
