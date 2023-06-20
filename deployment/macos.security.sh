#!/bin/bash

if [ -z "${FULLPATH}" ]; then
  >&2 echo "FULLPATH not set, unable to continue!";
  return 1;
fi

if [ -z "${DIRECTORY}" ]; then
  >&2 echo "DIRECTORY not set, using defaults!";
  DIRECTORY=$(dirname ${FULLPATH})
fi

if [ -z "${SSL_ROOT_PATH}" ]; then
  >&2 echo "SSL_ROOT_PATH not set, using defaults!";
  SSL_ROOT_PATH="${DIRECTORY}/ssl"
fi

if [ -z "${KEYCHAIN}" ]; then
  >&2 echo "KEYCHAIN not set, using defaults!";
  KEYCHAIN="/Library/Keychains/System.keychain";
fi

if [ -z "${HASH}" ]; then
  >&2 echo "HASH not set, using defaults!";
  HASH="SHA-256"
fi

getCommonName () {
  openssl x509 -noout -subject -in "${SSL_ROOT_PATH}/${1}" -nameopt multiline | \
  grep commonName | \
  awk '{ print $3 }'
}

backup() {
  echo "Backing up trust-settings..."
  sudo security authorizationdb read com.apple.trust-settings.admin > ./security.plist
}
restore() {
  echo "Restoring trust-settings..."
  sudo security authorizationdb write com.apple.trust-settings.admin < ./security.plist
  retVal=$?
  if [ $retVal -eq 0 ]; then
    rm ./security.plist
  fi;
}
authorize() {
  echo "Authorizing write permissions..."
  sudo security authorizationdb write com.apple.trust-settings.admin allow
}
deauthorize() {
  echo "Deauthorizing write permissions..."
  sudo security authorizationdb remove com.apple.trust-settings.admin
}

findCertByName () {
  local RES=$(security find-certificate -c "${1}" -a -Z | grep ${HASH})
  if [ -z "${RES}" ]; then
    return 1;
  fi;
  return 0;
}
findCertByEmail () {
  local RES=$(security find-certificate -e "${1}@${FULLHOST}" -a -Z | grep ${HASH})
  if [ -z "${RES}" ]; then
    return 1;
  fi;
  return 0;
}
# Bitwise Manipulation On Result
# Bit 0 = Match by name
# Bit 1 = Match by *.name
# Bit 2 = Match by email
findCert () {
  local NAME=$(getCommonName ${1})
  local RET=0
  if findCertByName "${NAME}"; then
    RET=$(((1 << 0) | $RET))
  fi
  if findCertByName "*.${NAME}"; then
    RET=$(((1 << 1) | $RET))
  fi
  if findCertByEmail "${NAME}"; then
    RET=$(((1 << 2) | $RET))
  fi;
  echo "${RET}";
  #return 0
}

addCert () {
  sudo security add-trusted-cert -d -r "${2}" -k "${KEYCHAIN}" "${SSL_ROOT_PATH}/${1}"
}
checkAddCert () {
  local TYPE="trustAsRoot";
  if [ ! -z "${2}" ]; then 
    TYPE=${2};
  fi;

  if [ $(findCert "${1}") -eq 0 ]; then
    echo "Cert not found, adding!";
    addCert "${1}" "${TYPE}"
  fi;
  return 0;
}

removeCertByName () {
  security delete-certificate -t -c "${1}" "${KEYCHAIN}"
}
removeCertByEmail () {
  security find-certificate -e "${1}@${FULLHOST}" -a -Z | \
    grep ${HASH} | \
    sudo awk -v KC="${KEYCHAIN}" \
    'NF>0 { system("sudo security delete-certificate -t -Z \""$NF"\" \""KC"\"") }'
}
# Bitwise Read On Result
# Bit 0 = Match by name
# Bit 1 = Match by *.name
# Bit 2 = Match by email
removeCert () {
  local NAME=$(getCommonName ${1})
  local RET=$(findCert "${1}")

  while [ "${RET}" -gt 0 ]; do
    if [ $(($RET & 1)) -gt 0 ]; then
        removeCertByName "${NAME}";
        RET=$(($RET & ~(1 << 0)))
    fi
    if [ $(($RET & 2)) -gt 0 ]; then
        removeCertByName "*.${NAME}";
        RET=$(($RET & ~(1 << 1)))
    fi
    if [ $(($RET & 4)) -gt 0 ]; then
        removeCertByEmail "${NAME}";
        RET=$(($RET & ~(1 << 2)))
    fi;
  done;
}
