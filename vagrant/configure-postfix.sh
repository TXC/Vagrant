#!/bin/bash

MAILTRAP_USERNAME=$1
MAILTRAP_PASSWORD=$2

POSTFIXCONFIG="/etc/postfix/main.cf"
SASLPASSWD="/etc/postfix/sasl_passwd"

debconf-set-selections <<< "postfix postfix/mailname string vagrant.localhost"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
debconf-set-selections <<< "postfix	postfix/relayhost	string '[smtp.mailtrap.io]:2525'"
apt-get -qqy -o Dpkg::Use-Pty=0 install postfix

echo "CONFIGURING Postfix"

# This will quite verbose

grep -q -F 'smtp_sasl_auth_enable =' $POSTFIXCONFIG
if [ $? -ne 0 ]; then
  echo 'smtp_sasl_auth_enable = yes' >> $POSTFIXCONFIG
else
  sed -i "s/^smtp_sasl_auth_enable = .*/smtp_sasl_auth_enable = yes/" $POSTFIXCONFIG
fi

grep -q -F 'smtp_sasl_mechanism_filter =' $POSTFIXCONFIG
if [ $? -ne 0 ]; then
  echo 'smtp_sasl_mechanism_filter = plain' >> $POSTFIXCONFIG
else
  sed -i "s/^smtp_sasl_mechanism_filter = .*/smtp_sasl_mechanism_filter = plain/" $POSTFIXCONFIG
fi

grep -q -F 'smtp_sasl_security_options =' $POSTFIXCONFIG
if [ $? -ne 0 ]; then
  echo 'smtp_sasl_security_options = noanonymous' >> $POSTFIXCONFIG
else
  sed -i "s/^smtp_sasl_security_options = .*/smtp_sasl_security_options = noanonymous/" $POSTFIXCONFIG
fi

grep -q -F 'smtp_sasl_password_maps =' $POSTFIXCONFIG
if [ $? -ne 0 ]; then
  echo "smtp_sasl_password_maps = hash:$SASLPASSWD" >> $POSTFIXCONFIG
else
  sed -i "s/^smtp_sasl_password_maps = .*/smtp_sasl_password_maps = hash:$SASLPASSWD" $POSTFIXCONFIG
fi

echo "smtp.mailtrap.io $MAILTRAP_USERNAME:$MAILTRAP_PASSWORD" > $SASLPASSWD
postmap $SASLPASSWD
systemctl restart postfix