#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

if [ -z "${MAILTRAP_USERNAME}" ] || [ -z "${MAILTRAP_PASSWORD}" ]; then
  echo "Mailtrap Username and/or Password is not configured."
  echo "Skipping configuration..."
  return 0;
fi;

POSTFIXCONFIG="/etc/postfix/main.cf"
SASLPASSWD="/etc/postfix/sasl_passwd"

debconf-set-selections <<< "postfix postfix/mailname string vagrant.localhost"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
debconf-set-selections <<< "postfix	postfix/relayhost	string '[smtp.mailtrap.io]:2525'"
apt-get -qqy -o Dpkg::Use-Pty=0 install postfix

echo "CONFIGURING Postfix"

LIST=(
  "smtp_sasl_auth_enable = yes"
  "smtp_sasl_mechanism_filter = plain"
  "smtp_sasl_security_options = noanonymous"
  "smtp_sasl_password_maps = hash\:${SASLPASSWD}"
)

for i in "${LIST[@]}"; do
  KEY=$(echo $i | awk '{ print $1 }')
  VAL=$(echo $i | awk '{ print $3 }')

  echo "Checking: ${KEY}"

  grep -q -F "${KEY} =" $POSTFIXCONFIG
  if [ $? -ne 0 ]; then
    sed -i "s#^${KEY} = .*#${KEY} = ${VAL}#" $POSTFIXCONFIG
  else
    echo "${KEY} = ${VAL}" >> $POSTFIXCONFIG
  fi
done

echo "smtp.mailtrap.io $MAILTRAP_USERNAME:$MAILTRAP_PASSWORD" > $SASLPASSWD
postmap $SASLPASSWD
systemctl restart postfix