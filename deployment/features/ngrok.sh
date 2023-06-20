#!/usr/bin/env bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

if [[ "${CODENAME}" == "bionic" ]] || \
  [[ "${CODENAME}" == "cosmic" ]] || \
  [[ "${CODENAME}" == "disco" ]] || \
  [[ "${CODENAME}" == "eoan" ]]
then
  NGROKDIST="buster"
elif [[ "${CODENAME}" == "focal" ]] || \
    [[ "${CODENAME}" == "groovy" ]] || \
    [[ "${CODENAME}" == "hirsute" ]] || \
    [[ "${CODENAME}" == "impish" ]]
then
  NGROKDIST="bullseye"
elif [[ "${CODENAME}" == "jammy" ]] || \
    [[ "${CODENAME}" == "kinetic" ]]
then
  NGROKDIST="bookworm"
fi


apt-key adv --fetch-keys 'https://ngrok-agent.s3.amazonaws.com/ngrok.asc' > /dev/null 2>&1
add-apt-repository -yn "deb https://ngrok-agent.s3.amazonaws.com ${NGROKDIST} main"
apt-get update
apt install ngrok 


PATH_NGROK="/home/vagrant/.config/ngrok"
PATH_CONFIG="${PATH_NGROK}/ngrok.yml"

# Only create a ngrok config file if there isn't one already there.
if [ ! -f $PATH_CONFIG ]; then
  mkdir -p $PATH_NGROK
  touch $PATH_CONFIG

  if [ ! -z "${api_key}" ]; then 
    echo "api_key: ${api_key}" | tee -a $PATH_CONFIG
  fi

  if [ ! -z "${authtoken}" ]; then
    echo "authtoken: ${authtoken}" | tee -a $PATH_CONFIG
  fi

  echo "web_addr: ${HOSTIP}:4040" | tee -a $PATH_CONFIG

  chown -R vagrant: /home/vagrant/.config
fi
