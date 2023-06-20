#!/usr/bin/env bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

if [ -z "$1" ]; then
  echo "Missing argument to script."
  echo "Usage: $0 <dbname>"
  exit 1;
fi;

DB=$1;


backuprestore() {
  local BACKUPFILE="${BACKUP_PATH}/mysql/backup.${DB}.sql"
  USEBZIP=0
  if aptcheck bzip2 ; then
    USEBZIP=1
    BACKUPFILE+=".bz2"
  fi;

  if [ "${USEBZIP}" -eq 1 ] && [ -f ${BACKUPFILE} ]; then
    echo "Importing compressed backupfile"
    bzip2 -dc "${BACKUPFILE}" | mysql -u root "${DB}"
  elif [ -f ${BACKUPFILE} ]; then
    echo "Importing backupfile"
    mysql -u root ${DB} < "${BACKUPFILE}"
  else
    >&2 echo "No backup found for '${DB}'"
  fi
}

echo "CREATING DATABASE \"${DB}\""
SQL="CREATE DATABASE IF NOT EXISTS $DB; "

LIST=(
  "'vagrant'@'%'"
  "'vagrant'@'localhost'"
)

for i in "${LIST[@]}"; do
  KEY=$(echo ${i//\@/ } | awk '{ print $1 }')
  VAL=$(echo ${i//\@/ } | awk '{ print $2 }')

  qry="SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user=${KEY} AND host=${VAL});"
  RESULT="$(sudo mysql -sse "${qry}")";
  if [ "$RESULT" -eq "1" ]; then
    SQL+="GRANT ALL PRIVILEGES ON $DB.* TO ${i}";
  fi
done
echo "SQL: ${SQL}"
mysql -u root -e "$SQL"

backuprestore ${DB}
