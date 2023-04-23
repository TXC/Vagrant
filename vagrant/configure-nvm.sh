#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

if [ -d "/opt/nvm" ]; then
  echo "UPDATING NVM"
  pushd /opt/nvm
  git checkout master
  git pull
  popd
else
  echo "INSTALLING NVM"
  git clone https://github.com/nvm-sh/nvm.git /opt/nvm
  mkdir /usr/local/nvm

  echo "export NVM_DIR=/usr/local/nvm
source /opt/nvm/nvm.sh
if [ -f /usr/local/nvm/alias/default ]; then
  VERSION=\$(cat /usr/local/nvm/alias/default)
  export PATH=\"/usr/local/nvm/versions/node/v\$VERSION/bin:\$PATH\"
fi
" > /etc/profile.d/nvm.sh
  chmod a+x /etc/profile.d/nvm.sh
fi;

pushd /opt/nvm
git checkout `git describe --abbrev=0 --tags`
source /opt/nvm/nvm.sh
popd

export NVM_DIR=/usr/local/nvm
nvm install 'lts/*'

echo "Installing global node.js packages... (please be patient)"