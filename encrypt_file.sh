#!/bin/bash -e

# Extract JSON args into shell variables
eval "$(jq -r '@sh "DEST=\(.dest) DATA=\(.data) KEYRING=\(.keyring) KEY=\(.key)"')"

mkdir -p $(dirname "${DEST}")

# Calculate the signature of the input data.
SIG=$(echo -n "${DATA}" | shasum | cut -d ' ' -f1)

# Break if dest file with same signature already exists
[[ -f "${DEST}" && -f "${DEST}.sig" && -z $(diff <(echo -n "$SIG") "${DEST}.sig") ]] && jq -n --arg file "${DEST}" '{"file":$file}' && exit 0

TEMP_FILE="${DEST}.tmp"
echo -n "${DATA}" > ${TEMP_FILE}

gcloud kms encrypt \
  --location=global \
  --keyring=${KEYRING} \
  --key=${KEY} \
  --plaintext-file=${TEMP_FILE} \
  --ciphertext-file=/dev/stdout | base64 > ${DEST}
rm -f ${TEMP_FILE}

echo -n "$SIG" > "${DEST}.sig"

# Output results in JSON format.
jq -n --arg file "${DEST}" '{"file":$file}'