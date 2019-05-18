#! /usr/bin/env bash
set -xe
set -o pipefail

# NOTE: In production, most organizations will have their own method of generating,
# accessing and rotating TLS certificates and keys. This program gives a sane way of
# creating a self signed cert as a default. For more configuration, you can point Vault
# to your own bucket with your own certificates that are already generateed. However,
# this assumes the private key for Vault is encrypted client side with a KMS key. The vault
# server will not only need access to the bucket but also decrypt permissions on that key.

# Needs the following environment variables to function. These are passed in from terraform
# variables
#
# PROJECT: Project ID
# BUCKET: Bucket name where TLS files should be stored
# LB_IP: IP address of the internal load balancer from variables
# KMS_KEYRING: Google KMS keyring name
# KMS_LOCATION: Google KMS key location
# KMS_KEY: Google KMS key
# COUNTRY: 2 letter country code
# STATE: 2 letter state code
# LOCALITY: City name
# CN: Server cert CN
# OU: Organizational Unit
# ORG: Organization
# IPS: Comma-separated list of alternate IPs
# DOMAINS: Comma-separated list of alternate domains
# ENCRYPT_AND_UPLOAD: 1 or 0. If unset this will not encrypt or upload, leaving the files behind for analysis or manual upload.

# Make sure that we don't ever overwrite keys or certs
if [ $ENCRYPT_AND_UPLOAD -eq 1 ]; then
  for file in root.key.enc vault.key.enc ca.crt vault.crt; do
    if gsutil -q stat gs://$BUCKET/$file; then
      echo "Refusing to overwrite existing certificate or key files"
      exit 1
    fi
  done
fi

# Create temporary working directory and enter it
TMPDIR=/tmp/vault-tls-$RANDOM
mkdir $TMPDIR && pushd $TMPDIR

# Construct SAN Entry in config
cat << EOF > openssl.cnf
[req]
distinguished_name = dn
req_extensions = extensions
prompt = no

[dn]
C = $COUNTRY
ST = $STATE
L = $LOCALITY
O  = $ORG
OU = $OU
CN = $CN

[extensions]
subjectAltName=@san
basicConstraints=critical,CA:TRUE
extendedKeyUsage=serverAuth

[san]
EOF

count=1
echo $DOMAINS | sed -n 1'p' | tr ',' '\n' | while read dns; do
  echo "DNS.$count = $dns" >> openssl.cnf
  let count=count+1
done

count=1
echo $IPS | sed -n 1'p' | tr ',' '\n' | while read ip; do
  echo "IP.$count = $ip" >> openssl.cnf
  let count=count+1
done

# Create and self-sign root CA
openssl genrsa -out root.key 4096

# NOTE: In production, it is recommended to add a password to this certificate
openssl req -x509 -new -nodes \
  -key root.key \
  -days 1024 \
  -out ca.crt \
  -sha256 \
  -config openssl.cnf \
  -extensions extensions

# Create a CSR for the Vault server cert with extension for LB IP address
openssl genrsa -out vault.key 4096
openssl req -new -sha256 \
  -key vault.key \
  -config openssl.cnf \
  -out vault.csr

# Create the server cert with the CSR
openssl x509 -sha256 -req \
  -in vault.csr \
  -CA ca.crt \
  -CAkey root.key \
  -CAcreateserial \
  -days 365 \
  -extensions extensions \
  -extfile <(cat openssl.cnf | sed 's/CA:TRUE/CA:FALSE/') \
  -out vault.crt

# Use this flag for debug purposes to test out, and upload certs manually
if [ $ENCRYPT_AND_UPLOAD -eq 1 ]; then
  # Encrypt Private Keys
  for file in root.key vault.key; do
    gcloud kms encrypt \
      --project=${PROJECT} \
      --location=${KMS_LOCATION} \
      --keyring=${KMS_KEYRING} \
      --key=${KMS_KEY} \
      --plaintext-file=$file \
      --ciphertext-file="${file}.enc"
  done

  # Upload keys and certs
  for file in root.key.enc vault.key.enc ca.crt vault.crt; do
    gsutil cp $file gs://$BUCKET/$file
  done

  # Clean up
  popd
  rm -rf $TMPDIR
else
  echo "Not encrypting or uploading. Certs stored at $TMPDIR"
fi
