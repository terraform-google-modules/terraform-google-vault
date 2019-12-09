#
# Copyright 2018 Google Inc.
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

variable project_id {
  type        = "string"
  description = "Project ID in which to deploy"
}

variable region {
  type        = "string"
  default     = "us-east4"
  description = "Region in which to deploy"
}

variable kms_location {
  type        = "string"
  default     = "us-east4"
  description = "Location for the KMS keyring"
}

variable kms_keyring {
  type        = "string"
  default     = "vault"
  description = "Name of the GCP KMS keyring"
}

variable kms_crypto_key {
  type        = "string"
  default     = "vault-init"
  description = "Name of the GCP KMS crypto key"
}

module "vault" {
  // source = "terraform-google-modules/vault/google"

  source     = "../../"
  project_id = var.project_id
  region     = var.region

  kms_keyring    = var.kms_keyring
  kms_crypto_key = var.kms_crypto_key

  storage_bucket_force_destroy = true
}
