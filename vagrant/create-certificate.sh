#!/usr/bin/env bash

if [ ! -f "/root/vagrant_conf.sh" ]; then
  echo "Missing config file!" >&2
  return 1;
fi;

source /root/vagrant_conf.sh

set -f

if [ -z "$1" ]; then
  echo "Missing argument to script."
  echo "Usage: $0 <hostname>"
  return 1;
fi;

export ARG_HOST=$1
export COMMONKEY=$(echo ARG_HOST |openssl dgst -sha384 |sed 's/^.* //'|cut -c1-8)

if [ -z "${SSL_DAYS}" ]; then
  # Certicate valid
  export SSL_DAYS="3650"
fi

if [ -z "${SSL_PATH}" ]; then
  # Certicate location
  export SSL_PATH="/vagrant/ssl"
fi

if [ -z "${SSL_DAYS}" ]; then
  # Root CA Certicate name
  export SSL_HOST="$(hostname)"
fi

# Path to the custom BASE config.
export PATH_BASE_CNF="${SSL_PATH}/base.${SSL_HOST}.cnf"

# Path to the custom Root CA certificate.
export PATH_ROOT_CNF="${SSL_PATH}/ca.${SSL_HOST}.cnf"
export PATH_ROOT_CRT="${SSL_PATH}/ca.${SSL_HOST}.crt"
export PATH_ROOT_KEY="${SSL_PATH}/ca.${SSL_HOST}.key"

# Path to the custom site certificate.
export PATH_CNF="${SSL_PATH}/$ARG_HOST.cnf"
export PATH_CRT="${SSL_PATH}/$ARG_HOST.crt"
export PATH_CSR="${SSL_PATH}/$ARG_HOST.csr"
export PATH_KEY="${SSL_PATH}/$ARG_HOST.key"

if [ ! -f $PATH_BASE_CNF ]; then
  echo "Generate Base Certificate Config"
  cat "${STUBROOT}/openssl/base.cnf" | envsubst > "${PATH_BASE_CNF}"
fi
export BASE=$(cat ${PATH_BASE_CNF})

# Only generate the root certificate when there isn't one already there.
if [ ! -f $PATH_ROOT_CNF ] || [ ! -f $PATH_ROOT_KEY ] || [ ! -f $PATH_ROOT_CRT ]; then
  echo "Generating Root CA Certificate for ${SSL_HOST}"
  # Generate an OpenSSL configuration file specifically for this certificate.
  cat "${STUBROOT}/openssl/root.cnf" | envsubst > "${PATH_ROOT_CNF}"

  # Finally, generate the private key and certificate.
  openssl genrsa -out "${PATH_ROOT_KEY}" 4096 2>/dev/null || echo "Unable to generate RSA for ${SSL_HOST}"
  openssl req -config "${PATH_ROOT_CNF}" \
    -key "${PATH_ROOT_KEY}" \
    -x509 \
    -new \
    -extensions v3_ca \
    -days ${SSL_DAYS} \
    -sha256 \
    -out "${PATH_ROOT_CRT}" 2>/dev/null || echo "Unable to generate CSR for ${SSL_HOST}"

  # Symlink ca to local certificate storage and run update command
  ln -sf "${PATH_ROOT_CRT}" "/usr/local/share/ca-certificates/" || echo "Unable to link"
  update-ca-certificates || echo "Unable to update"
fi

# Only generate a certificate if there isn't one already there.
if [ ! -f $PATH_CNF ] || [ ! -f $PATH_KEY ] || [ ! -f $PATH_CRT ]; then
  echo "Generating Certificate for ${ARG_HOST}"

  # Uncomment the global 'copy_extentions' OpenSSL option to ensure the SANs are copied into the certificate.
  if grep -E "^copy_extensions" "/etc/ssl/openssl.cnf" ; then
    sed -i '/^copy_extensions\ =\ copy/ s/./#&/' "/etc/ssl/openssl.cnf" || echo "Unable to modify OpenSSL config"
  fi;

  # Generate an OpenSSL configuration file specifically for this certificate.
  cat "${STUBROOT}/openssl/cert.cnf" | envsubst > "${PATH_CNF}"

  # Finally, generate the private key and certificate signed with the $(SSL_HOST) Root CA.
  openssl genrsa -out "${PATH_KEY}" 2048 2>/dev/null || echo "Unable to generate RSA for ${ARG_HOST}"
  openssl req -config "${PATH_CNF}" \
    -key "${PATH_KEY}" \
    -new -sha256 \
    -out "${PATH_CSR}" 2>/dev/null || echo "Unable to generate CSR for ${ARG_HOST}"
  openssl x509 -req -extfile "${PATH_CNF}" \
    -extensions server_cert \
    -days ${SSL_DAYS} \
    -sha256 \
    -in "${PATH_CSR}" \
    -CA "${PATH_ROOT_CRT}" \
    -CAkey "${PATH_ROOT_KEY}" \
    -CAcreateserial \
    -out "${PATH_CRT}" 2>/dev/null || echo "Unable to generate x509 for ${ARG_HOST}"
fi