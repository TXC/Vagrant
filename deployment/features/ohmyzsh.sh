#!/bin/bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

echo "INSTALLING Z-Shell"

aptinstall zsh

backuprestore() {
  local BACKUPFILE="${BACKUP_PATH}/zsh/backup.tar"
  USEBZIP=0
  if aptcheck bzip2 ; then
    USEBZIP=1
  fi;

  if [ "${USEBZIP}" -eq 1 ] && [ -f "${BACKUPFILE}.bz2" ]; then
    echo "Restoring compressed backupfile"
    tar jxf "${BACKUPFILE}.bz2" -C "/home/vagrant/"
  elif [ -f ${BACKUPFILE} ]; then
    echo "Restoring backupfile"
    tar xf "${BACKUPFILE}" -C "/home/vagrant/"
  else
    >&2 echo "No backup found for 'zsh'"
  fi
}

# Install oh-my-zsh
git clone https://github.com/ohmyzsh/ohmyzsh.git /home/vagrant/.oh-my-zsh
cp /home/vagrant/.oh-my-zsh/templates/zshrc.zsh-template /home/vagrant/.zshrc

# Set theme and plugins according to config
if [ -n "${theme}" ]; then
    sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"${theme}\"/" /home/vagrant/.zshrc
fi
if [ -n "${plugins}" ]; then
    sed -i "s/^plugins=.*/plugins=(${plugins})/" /home/vagrant/.zshrc
fi

backuprestore

printf "\nemulate sh -c 'source ~/.bash_aliases'\n" | tee -a /home/vagrant/.zprofile
printf "\nemulate sh -c 'source ~/.profile'\n" | tee -a /home/vagrant/.zprofile
chown -R vagrant:vagrant \
  /home/vagrant/.oh-my-zsh \
  /home/vagrant/.zshrc \
  /home/vagrant/.zprofile
chsh -s /bin/zsh vagrant
