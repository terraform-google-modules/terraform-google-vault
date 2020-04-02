#
# Copyright 2020 Google Inc.
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

module "vault" {
  // source = "terraform-google-modules/vault/google"

  source     = "../../"
  project_id = var.project_id
  region     = var.region

  kms_keyring    = var.kms_keyring
  kms_crypto_key = var.kms_crypto_key

  storage_bucket_force_destroy = true
  load_balancing_scheme        = var.load_balancing_scheme
  allow_public_egress          = var.allow_public_egress
}

output "vault_addr" {
  value = module.vault.vault_addr
}
