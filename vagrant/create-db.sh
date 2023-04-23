#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "Missing argument to script."
  echo "Usage: $0 <dbname>"
  return 1;
fi;

DB=$1;

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
#echo "SQL: ${SQL}"
mysql -u root -e "$SQL"
