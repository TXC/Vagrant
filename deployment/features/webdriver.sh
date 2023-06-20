#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

# Install The Chrome Web Driver & Dusk Utilities
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | tee -a /etc/apt/sources.list.d/google-chrome.list

apt-get update

aptinstall libxpm4 libxrender1 libgtk2.0-0 libnss3 libgconf-2-4 chromium-browser xvfb gtk2-engines-pixbuf \
xfonts-cyrillic xfonts-100dpi xfonts-75dpi xfonts-base xfonts-scalable imagemagick x11-apps google-chrome-stable
