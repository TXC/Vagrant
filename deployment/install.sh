#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /vagrant/.vagrant/config.sh

DEBIAN_FRONTEND="noninteractive"
TZ=$TIMEZONE

TZONE=(${TIMEZONE//\// })
debconf-set-selections <<< "tzdata tzdata/Areas select ${TZONE[0]}"
debconf-set-selections <<< "tzdata tzdata/Zones/${TZONE[0]} select ${TZONE[1]}"
debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}.${DOMAIN}"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

#0.pool.ntp.org 1.pool.ntp.org 0.fr.pool.ntp.org
#sed -i "s/^bind .*/bind 127.0.0.1 ::1 $HOSTIP/" /etc/redis/redis.conf

sed -i -e "s/^#NTP=/NTP=0\.pool\.ntp\.org\ 1\.pool\.ntp\.org/" \
       -E -e "s/^#(FallbackNTP=.*)/\1/" \
       -E -e "s/^#(RootDistanceMaxSec=.*)/\1/" \
       -E -e "s/^#(PollIntervalMinSec=.*)/\1/" \
       -E -e "s/^#(PollIntervalMaxSec=.*)/\1/" \
       /etc/systemd/timesyncd.conf

timedatectl set-timezone $TIMEZONE

echo "PATCHING"

touch /home/vagrant/.bash_aliases
chown vagrant:vagrant /home/vagrant/.bash_aliases

MULTIPATH="blacklist {
  devnode \"^(ram|raw|loop|fd|md|dm-|sr|scd|st|sda)[0-9]*\"
}"
echo "${MULTIPATH}" | tee -a /etc/multipath.conf

systemctl restart multipath-tools.service

add-apt-repository ppa:ondrej/php -yn

echo "UPDATING MACHINE"

aptupdate
aptupgrade

PACKAGES="ca-certificates software-properties-common postfix dirmngr apt-transport-https gettext bzip2"

echo "INSTALLING PACKAGES"

PACKAGES+=" "
for VERSION in ${PHP_VERSIONS}; do
  f="/vagrant/vagrant/stubs/php/php${VERSION}/packages.txt"
  PACKAGES+="$(sed 's/#.*//' ${f} | tr '\n' ' ') "
done
#echo $PACKAGES | xargs aptinstall
echo $PACKAGES | xargs apt-get -qqy -o Dpkg::Use-Pty=0 install

rm -rf /var/cache/apt/*
