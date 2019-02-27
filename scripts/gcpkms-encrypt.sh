#! /usr/bin/env bash
set -xe
set -o pipefail

#
# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# This script is designed to be called from a terraform `external` data source.
# Arguments are passed as JSON and evaluated as bash variables.
# The output format is JSON.
#


# Extract args into shell variables
eval "$(jq -r '@sh "ROOT=\(.root) DATA=\(.data) PROJECT=\(.project) LOCATION=\(.location) KEYRING=\(.keyring) KEY=\(.key)"')"

# If no root or data was given, error
[[ "${ROOT}" == "null" ]] && echo "Missing ROOT!" && exit 1
[[ "${DATA}" == "null" ]] && echo "Missing DATA!" && exit 1

# Calculate the md5 of the data - used to lookup
SIG=$(echo -n "${DATA}|${PROJECT}|${LOCATION}|${KEYRING}|${KEY}" | md5 | cut -d ' ' -f1)

# Create the kms/ directory
KMS_DIR="${ROOT}/.terraform/kms"
mkdir -p "${KMS_DIR}"

# If the signature file does not exist, encrypt the ciphertext
if [ ! -f "${KMS_DIR}/${SIG}" ]; then
  RESULT="$(echo "${DATA}" | gcloud kms encrypt \
    --project=${PROJECT} \
    --location=${LOCATION} \
    --keyring=${KEYRING} \
    --key=${KEY} \
    --plaintext-file=- \
    --ciphertext-file=- \
    | base64)"
  echo "${RESULT}" > "${KMS_DIR}/${SIG}"
fi

# Get the ciphertext
CIPHERTEXT="$(cat "${KMS_DIR}/${SIG}")"

# Output results in JSON format.
jq -n --arg ciphertext "${CIPHERTEXT}" '{"ciphertext": $ciphertext}'
