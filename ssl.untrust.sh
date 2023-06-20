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

removeCert "ca.vagrant.crt"
removeCert "edge.sitedirect.local.crt"
removeCert "edge-s1.sitedirect.local.crt"
removeCert "klubb6.local.crt"
removeCert "cdn.klubb6.local.crt"
removeCert "selfdestruct.local.crt"
removeCert "old.rartracker.local.crt"
removeCert "rartracker.local.crt"
removeCert "dopewars.local.crt"

deauthorize
restore
