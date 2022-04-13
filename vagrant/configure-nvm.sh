#!/bin/bash

echo "INSTALLING NVM"
git clone https://github.com/nvm-sh/nvm.git /opt/nvm
mkdir /usr/local/nvm

pushd /opt/nvm
git checkout `git describe --abbrev=0 --tags`
source /opt/nvm/nvm.sh
popd

export NVM_DIR=/usr/local/nvm
nvm install 'lts/*'

echo "export NVM_DIR=/usr/local/nvm
source /opt/nvm/nvm.sh
if [ -f /usr/local/nvm/alias/default ]; then
  VERSION=\$(cat /usr/local/nvm/alias/default)
  export PATH=\"/usr/local/nvm/versions/node/v\$VERSION/bin:\$PATH\"
fi
" > /etc/profile.d/nvm.sh
chmod a+x /etc/profile.d/nvm.sh

echo "Installing global node.js packages... (please be patient)"