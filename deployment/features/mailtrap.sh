#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

if [ -z "${username}" ] || [ -z "${password}" ]; then
  echo "Mailtrap Username and/or Password is not configured."
  echo "Skipping configuration..."
  exit 0;
fi;

if [ -z "${hostname}" ]; then
  hostname="smtp.mailtrap.io"
fi;

debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}.${DOMAIN}"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Satellite system'"
debconf-set-selections <<< "postfix	postfix/relayhost	string '[${hostname}]:2525'"
if ! aptcheck postfix; then
  aptinstall postfix
else
  dpkg-reconfigure postfix
fi

echo "CONFIGURING Mailtrap"

POSTFIXCONFIG="/etc/postfix/main.cf"
SASLPASSWD="/etc/postfix/sasl_passwd"

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
    echo "${KEY} = ${VAL}" | tee -a $POSTFIXCONFIG
  fi
done

echo "${hostname} ${username}:${password}" | tee $SASLPASSWD
postmap $SASLPASSWD
systemctl restart postfix
