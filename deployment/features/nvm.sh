#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

export NVM_DIR="/usr/local/nvm"

if [ -d "/opt/nvm" ]; then
  echo "UPDATING NVM"
  pushd /opt/nvm
  #git checkout `git describe --abbrev=0 --tags` > /dev/null 2>&1
  git checkout master
  git pull
  source /opt/nvm/nvm.sh
  popd
else
  echo "INSTALLING NVM"
  git clone https://github.com/nvm-sh/nvm.git /opt/nvm
  mkdir /usr/local/nvm

  if [ -d "/etc/profile.d" ]; then
    echo "export NVM_DIR=\"${NVM_DIR}\"
#export NVM_SYMLINK_CURRENT=\"true\"
source /opt/nvm/nvm.sh
if [ -f /usr/local/nvm/alias/default ]; then
  VERSION=\$(cat /usr/local/nvm/alias/default)
  export PATH=\"/usr/local/nvm/versions/node/v\$VERSION/bin:\$PATH\"
fi
" > /etc/profile.d/nvm.sh
    chmod a+x /etc/profile.d/nvm.sh
  fi;
  if [ -d "/etc/zsh" ]; then
    echo "
#export NVM_SYMLINK_CURRENT=\"true\"
export NVM_DIR=\"${NVM_DIR}\"
source /opt/nvm/nvm.sh
if [ -f /usr/local/nvm/alias/default ]; then
  VERSION=\$(cat /usr/local/nvm/alias/default)
  export PATH=\"/usr/local/nvm/versions/node/v\$VERSION/bin:\$PATH\"
fi
" | tee -a /etc/zsh/zprofile
  fi;
fi;

if [ ! -d ${NVM_DIR} ]; then
  mkdir -p ${NVM_DIR}
fi;

if [ ! -f ${NVM_DIR}/default-packages ]; then
  echo "yarn" | tee -a ${NVM_DIR}/default-packages
fi;

if [ -z "${version}" ]; then
  version="lts/*"
fi;

echo "Installing global node.js & packages... (please be patient)"

nvm install "${version}"

