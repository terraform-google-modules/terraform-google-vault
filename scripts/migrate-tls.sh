# ./scripts/migrate-tls.sh
set -x

PROJECT="${PROJECT:-$(terraform state show google_storage_bucket.vault | grep -e "^project" | cut -f2 -d'=' | tr -d ' ')}"
BUCKET="${BUCKET:-$(terraform state show google_storage_bucket.vault | grep -e "^name" | cut -f2 -d'=' | tr -d ' ')}"
KEYRING="${KEYRING:-$(terraform state show google_kms_key_ring.vault | grep -e "^name" | cut -f2 -d'=' | tr -d ' ')}"
LOCATION="${LOCATION:-$(terraform state show google_kms_key_ring.vault | grep -e "^location" | cut -f2 -d'=' | tr -d ' ')}"
KMS_KEY="${KMS_KEY:-$(terraform state show google_kms_crypto_key.vault-init | grep -e "^name" | cut -f2 -d'=' | tr -d ' ')}"
KMS_DIR=".terraform/kms"

if [ -z PROJECT ] || [ -z BUCKET ] || [ -z KEYRING ] || [ -z LOCATION ] || [ -z KMS_KEY ]; then
  echo "You must have PROJECT, BUCKET, KEYRING, LOCATION, and KMS_KEY defined"
  echo "as environment variables since at least one cannot be found in your statefile"
  exit 1
fi

if [ ! -d $KMS_DIR ]; then
  # This also makes sure we know where the user is running the script
  echo "No existing keys in .terraform/kms"
  exit 1
fi

mkdir -p migration
# XXX: gcloud kms decrypt doesn't seem to honor \n when certs are piped to stdout
# thus openssl fails, so saving to a temp file seems to work better
TMP_FILE=migration/tmp
for f in $(ls $KMS_DIR); do
  # First we need to decrypt the values in the kms directory to put them in the right place
  cat $KMS_DIR/$f | base64 --decode | gcloud kms decrypt \
    --project=${PROJECT} \
    --location=${LOCATION} \
    --keyring=${KEYRING} \
    --key=${KMS_KEY} \
    --plaintext-file=$TMP_FILE \
    --ciphertext-file=-
  if cat $TMP_FILE | grep 'BEGIN CERTIFICATE'; then
    # Either Vault or Root Cert
    if cat $TMP_FILE | openssl x509 -text -noout | grep 'CA:TRUE'; then
      # Now we know this is ca.crt
      cat $TMP_FILE > migration/ca.crt
    else
      # This is the vault.crt
      cat $TMP_FILE > migration/vault.crt
    fi
  elif cat $TMP_FILE | grep 'BEGIN RSA PRIVATE KEY'; then
    # Now we have the private key for vault
    cat $TMP_FILE | gcloud kms encrypt \
      --project=${PROJECT} \
      --location=${LOCATION} \
      --keyring=${KEYRING} \
      --key=${KMS_KEY} \
      --plaintext-file=- \
      --ciphertext-file=migration/vault.key.enc
  fi
done
rm $TMP_FILE
gsutil cp migration/vault.key.enc migration/vault.crt migration/ca.crt gs://$BUCKET/
rm -rf migration
