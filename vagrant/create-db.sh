#!/usr/bin/env bash

DB=$1;
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB";
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $DB.* TO 'vagrant'@'%';"
