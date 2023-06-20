#!/usr/bin/env bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /vagrant/.vagrant/config.sh

set -f

if [ -z "$1" ]; then
  echo "Missing argument to script."
  echo "Usage: $0 <hostname>"
  exit 1;
fi;

export ARG_HOST=$1

if [ -L /usr/local/sbin/create_cert ]; then
    ln -sf "/vagrant/deployment/create-certificate.sh" "/usr/local/sbin/create_cert";
fi

# Path to the custom BASE config.
export PATH_BASE_CNF="${SSL_PATH}/base.${HOSTNAME}.cnf"

# Path to the custom Root CA certificate.
export PATH_ROOT_CRT="${SSL_PATH}/ca.${HOSTNAME}.crt"
export PATH_ROOT_KEY="${SSL_PATH}/ca.${HOSTNAME}.key"

# Path to the custom site certificate.
export PATH_CNF="${SSL_PATH}/$ARG_HOST.cnf"
export PATH_CRT="${SSL_PATH}/$ARG_HOST.crt"
export PATH_CSR="${SSL_PATH}/$ARG_HOST.csr"
export PATH_KEY="${SSL_PATH}/$ARG_HOST.key"


# Only generate a certificate if there isn't one already there.
if [ ! -f $PATH_CNF ] || \
   [ ! -f $PATH_KEY ] || \
   [ ! -f $PATH_CRT ]
then
  echo "Generating Certificate for ${ARG_HOST}"

  if [ ! -f $PATH_BASE_CNF ]; then
    echo "Generate Base Certificate Config"
    cat "${STUBROOT}/openssl/base.cnf" | envsubst > "${PATH_BASE_CNF}"
  fi
  export BASE=$(cat ${PATH_BASE_CNF})

  # Generate an OpenSSL configuration file specifically for this certificate.
  cat "${STUBROOT}/openssl/cert.cnf" | envsubst > "${PATH_CNF}"

  SSL_DAYS=$(grep "default_days" "${PATH_CNF}" | awk '{ print $3 }')

  # Finally, generate the private key and certificate signed with the $(HOSTNAME) Root CA.
  openssl genrsa -out "${PATH_KEY}" 2048

  openssl req -config "${PATH_CNF}" \
    -key "${PATH_KEY}" \
    -new -sha256 \
    -out "${PATH_CSR}"

  openssl x509 -req -extfile "${PATH_CNF}" \
    -extensions server_cert \
    -days ${SSL_DAYS} \
    -sha256 \
    -in "${PATH_CSR}" \
    -CA "${PATH_ROOT_CRT}" \
    -CAkey "${PATH_ROOT_KEY}" \
    -CAcreateserial \
    -out "${PATH_CRT}"

fi
