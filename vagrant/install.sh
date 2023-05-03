#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

CODENAME=$(lsb_release -c | awk '{ print $2 }')
RELEASE=$(lsb_release -r | awk '{ print $2 }')
DEBIAN_FRONTEND="noninteractive"
TZ=$TIMEZONE

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

aptupdate () {
  apt-get -qq -o Dpkg::Use-Pty=0 update > /dev/null 2>&1
}

apt-get -qqy -o Dpkg::Use-Pty=0 install ca-certificates software-properties-common dirmngr apt-transport-https > /dev/null 2>&1

apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' > /dev/null 2>&1
add-apt-repository -yn "deb [arch=amd64,arm64,ppc64el] http://mirror.terrahost.no/mariadb/repo/10.6/ubuntu ${CODENAME} main"

add-apt-repository ppa:ondrej/php -yn
add-apt-repository ppa:ondrej/apache2 -yn
add-apt-repository ppa:ondrej/nginx -yn

debconf-set-selections <<< "mariadb-server-10.6 mariadb-server-10.6/postrm_remove_databases boolean false"

PACKAGES="apache2 nginx sqlite3 redis memcached libmemcached-tools mariadb-server mariadb-client "
PACKAGES+="mariadb-common gettext openssl bzip2 "
#PACKAGES+="python3 python3-pip build-essential make ant libidn12 cmake "

if [ ! -z "${NGROK}" ]; then
  apt-key adv --fetch-keys 'https://ngrok-agent.s3.amazonaws.com/ngrok.asc' > /dev/null 2>&1
#  add-apt-repository -yn "deb https://ngrok-agent.s3.amazonaws.com ${CODENAME} main"
  add-apt-repository -yn "deb https://ngrok-agent.s3.amazonaws.com buster main"

  PACKAGES+="ngrok "
fi;

if [ ! -z "${DOTNET}" ]; then
  dpkg -s "packages-microsoft-prod" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    wget https://packages.microsoft.com/config/ubuntu/${RELEASE}/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm /tmp/packages-microsoft-prod.deb
  fi;

  echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1" > /etc/profile.d/dotnet_telemetry.sh
  PACKAGES+="dotnet-sdk-${DOTNET} "
fi;

for f in /home/vagrant/stubs/php/*/packages.txt; do
  PACKAGES+="$(sed 's/#.*//' ${f} | tr '\n' ' ') "
done

aptupdate

echo $PACKAGES | xargs apt-get -qqy -o Dpkg::Use-Pty=0 install

rm -rf /var/cache/apt/*
