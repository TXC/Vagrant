#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

aptinstall python3 python3-pip build-essential make ant libidn12 cmake

if [ -d "/opt/emscripten" ]; then
  echo "UPDATING EMSCRIPTEN"
  pushd /opt/emscripten
  git checkout main
  git pull
  popd
else
  echo "INSTALLING EMSCRIPTEN"
  git clone https://github.com/emscripten-core/emsdk.git /opt/emscripten

  echo 'export EMSDK_QUIET=1' | tee /etc/profile.d/emscripten.sh
  echo 'source "/opt/emscripten/emsdk_env.sh"' | tee -a /etc/profile.d/emscripten.sh
  chmod a+x /etc/profile.d/emscripten.sh
fi;

pushd /opt/emscripten

/bin/sh /opt/emscripten/emsdk install latest
/bin/sh /opt/emscripten/emsdk activate latest
#source /opt/emscripten/emsdk_env.sh
popd
