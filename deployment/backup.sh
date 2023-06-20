#!/usr/bin/env bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  >&2 echo "Missing config file!"
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

USEBZIP=0
if aptcheck bzip2 ; then
  USEBZIP=1
fi;

backup_database() {
  if ! aptcheck mysql-client* && ! aptcheck mariadb-client* ; then
    >&2 echo "Missing 'mysql-client' and/or 'mariadb-client' for backup!"
    return 0;
  fi;

  mkdir -p "${BACKUP_PATH}/mysql"
  DATABASES=`mysql -u root -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`
  for DB in $DATABASES; do
    if [[ "$DB" != "information_schema" ]] && \
      [[ "$DB" != "performance_schema" ]] && \
      [[ "$DB" != "sys" ]] && \
      [[ "$DB" != "mysql" ]] && \
      [[ "$DB" != _* ]]
    then
      BACKUPFILE="${BACKUP_PATH}/mysql/backup.${DB}.sql"
      echo "Dumping database: ${DB}"
      if [ "${USEBZIP}" -eq 1 ]; then
        mysqldump -u root --routines --databases ${DB} | bzip2 -cq9 > "${BACKUPFILE}.bz2"
      else
        mysqldump -u root --routines --databases ${DB} > "${BACKUPFILE}"
      fi
    fi
  done

  #sha1sum ${BACKUP_PATH}/mysql/backup.* > ${SHA1_FILE}
}

backup_zsh() {
  if ! aptcheck zsh; then
    >&2 echo "Missing 'zsh' for backup!"
    return 0;
  fi;

  mkdir -p "${BACKUP_PATH}/zsh"

  local BACKUPFILE="${BACKUP_PATH}/zsh/backup.tar"

  TAR_ARGS="cf"
  if [ "${USEBZIP}" -eq 1 ]; then
    BACKUPFILE+=".bz2"
    TAR_ARGS="cjf"
  fi

  echo "Backing up 'zsh'..."
  tar ${TAR_ARGS} \
      "${BACKUPFILE}" \
      --exclude-vcs \
      -C "/home/vagrant/" \
      ./.fonts \
      ./.zshrc \
      ./.oh-my-zsh/custom
}

backup_database
backup_zsh
