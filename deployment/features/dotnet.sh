#!/usr/bin/env bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

if [ -z "${version}" ]; then
  version="7.0"
fi

dpkg -s "packages-microsoft-prod" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  FP="/tmp/packages-microsoft-prod.deb"
  wget https://packages.microsoft.com/config/ubuntu/${RELEASE}/packages-microsoft-prod.deb \
    -O "${FP}"
  dpkg -i "${FP}"
  rm "${FP}"
fi;

echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1" > /etc/profile.d/dotnet_telemetry.sh

apt install dotnet-sdk-${version}
