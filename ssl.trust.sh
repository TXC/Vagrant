#!/bin/bash

FULLPATH=$(realpath $0)
DIRECTORY=$(dirname ${FULLPATH})
SSL_ROOT_PATH="${DIRECTORY}/ssl"
KEYCHAIN="/Library/Keychains/System.keychain"
#HASH="SHA-1"
HASH="SHA-256"

source ./deployment/macos.security.sh

backup
authorize

checkAddCert "ca.vagrant.crt" "trustRoot"
checkAddCert "edge.sitedirect.local.crt"
checkAddCert "edge-s1.sitedirect.local.crt"
checkAddCert "klubb6.local.crt"
checkAddCert "cdn.klubb6.local.crt"
checkAddCert "selfdestruct.local.crt"
checkAddCert "old.rartracker.local.crt"
checkAddCert "rartracker.local.crt"
checkAddCert "dopewars.local.crt"

deauthorize
restore
