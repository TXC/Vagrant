#!/bin/bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

if [ -d "/opt/emscripten" ]; then
  echo "UPDATING EMSCRIPTEN"
  pushd /opt/emscripten
  git checkout main
  git pull
  popd
else
  echo "INSTALLING EMSCRIPTEN"
  git clone https://github.com/emscripten-core/emsdk.git /opt/emscripten

  echo 'export EMSDK_QUIET=1' > /etc/profile.d/emscripten.sh
  echo 'source "/opt/emscripten/emsdk_env.sh"' >> /etc/profile.d/emscripten.sh
  chmod a+x /etc/profile.d/emscripten.sh
fi;

pushd /opt/emscripten

/bin/sh /opt/emscripten/emsdk install latest
/bin/sh /opt/emscripten/emsdk activate latest
#source /opt/emscripten/emsdk_env.sh
popd
