#!/usr/bin/env bash

if [ ! -f "/vagrant/.vagrant/config.sh" ]; then
  echo "Missing config file!" >&2
  exit 1;
fi;

source /vagrant/.vagrant/config.sh

export SSL_DAYS=${days}
if [ -z "${SSL_DAYS}" ]; then
  SSL_DAYS="3650"
fi;

echo "INSTALLING openssl"
aptinstall openssl

echo "CONFIGURING openssl"

# Path to the custom BASE config.
export PATH_BASE_CNF="${SSL_PATH}/base.${HOSTNAME}.cnf"

# Path to the custom Root CA certificate.
export PATH_ROOT_CNF="${SSL_PATH}/ca.${HOSTNAME}.cnf"
export PATH_ROOT_CRT="${SSL_PATH}/ca.${HOSTNAME}.crt"
export PATH_ROOT_KEY="${SSL_PATH}/ca.${HOSTNAME}.key"

# Uncomment the global 'copy_extentions' OpenSSL option to ensure the SANs are copied into the certificate.
if grep -E "^copy_extensions" "/etc/ssl/openssl.cnf" ; then
    sed -i '/^copy_extensions\ =\ copy/ s/./#&/' "/etc/ssl/openssl.cnf" || >&2 echo "Unable to modify OpenSSL config"
fi;

if [ ! -f $PATH_BASE_CNF ]; then
  echo "Generate Base Certificate Config"
  cat "${STUBROOT}/openssl/base.cnf" | envsubst > "${PATH_BASE_CNF}"
fi
export BASE=$(cat ${PATH_BASE_CNF})

# Only generate the root certificate when there isn't one already there.
if [ ! -f $PATH_ROOT_CNF ] || \
  [ ! -f $PATH_ROOT_KEY ] || \
  [ ! -f $PATH_ROOT_CRT ]
then
  echo "Generating Root CA Certificate for ${HOSTNAME}"
  # Generate an OpenSSL configuration file specifically for this certificate.
  cat "${STUBROOT}/openssl/root.cnf" | envsubst > "${PATH_ROOT_CNF}"

  # Finally, generate the private key and certificate.
  openssl genrsa -out "${PATH_ROOT_KEY}" 4096
  openssl req -config "${PATH_ROOT_CNF}" \
    -key "${PATH_ROOT_KEY}" \
    -x509 \
    -new \
    -extensions v3_ca \
    -days ${SSL_DAYS} \
    -sha256 \
    -out "${PATH_ROOT_CRT}"
fi

# Symlink ca to local certificate storage and run update command
ln -sf "${PATH_ROOT_CRT}" "/usr/local/share/ca-certificates/" || echo "Unable to link" 1>&2
update-ca-certificates || echo "Unable to update" 1>&2
