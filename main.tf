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

locals {
  vault_tls_bucket  = var.vault_tls_bucket != "" ? var.vault_tls_bucket : local.storage_bucket_name
  default_kms_key   = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.kms_keyring}/cryptoKeys/${var.kms_crypto_key}"
  vault_tls_kms_key = var.vault_tls_kms_key != "" ? var.vault_tls_kms_key : local.default_kms_key
  lb_ip             = local.use_external_lb ? google_compute_forwarding_rule.external[0].ip_address : google_compute_address.vault_ilb[0].address
  api_addr          = var.domain != "" ? "https://${var.domain}:${var.vault_port}" : "https://${local.lb_ip}:${var.vault_port}"
}

# Configure the Google provider, locking to the 2.0 series.
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required services on the project
resource "google_project_service" "service" {
  for_each = toset(var.project_services)
  project  = var.project_id

  service = each.key

  # Do not disable the service on destroy. This may be a shared project, and
  # we might not "own" the services we enable.
  disable_on_destroy = false
}

# Create the vault-admin service account.
resource "google_service_account" "vault-admin" {
  account_id   = var.service_account_name
  display_name = "Vault Admin"
  project      = var.project_id

  depends_on = [google_project_service.service]
}

# Give project-level IAM permissions to the service account.
resource "google_project_iam_member" "project-iam" {
  for_each = toset(var.service_account_project_iam_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = [google_project_service.service]
}

# Give additional project-level IAM permissions to the service account.
resource "google_project_iam_member" "additional-project-iam" {
  for_each = toset(var.service_account_project_additional_iam_roles)
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = [google_project_service.service]
}

# Give bucket-level permissions to the service account.
resource "google_storage_bucket_iam_member" "vault" {
  for_each = toset(var.service_account_storage_bucket_iam_roles)
  bucket   = google_storage_bucket.vault.name
  role     = each.key
  member   = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = [google_project_service.service]
}

# Give kms cryptokey-level permissions to the service account.
resource "google_kms_crypto_key_iam_member" "ck-iam" {
  crypto_key_id = google_kms_crypto_key.vault-init.self_link
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = [google_project_service.service]
}

resource "google_kms_crypto_key_iam_member" "tls-ck-iam" {
  count = var.manage_tls == false ? 1 : 0

  crypto_key_id = var.vault_tls_kms_key
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "serviceAccount:${google_service_account.vault-admin.email}"
}

resource "google_storage_bucket_iam_member" "tls-bucket-iam" {
  count = var.manage_tls == false ? 1 : 0

  bucket = var.vault_tls_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.vault-admin.email}"
}

# Create the KMS key ring
resource "google_kms_key_ring" "vault" {
  name     = var.kms_keyring
  location = var.region
  project  = var.project_id

  depends_on = [google_project_service.service]
}

# Create the crypto key for encrypting init keys
resource "google_kms_crypto_key" "vault-init" {
  name            = var.kms_crypto_key
  key_ring        = google_kms_key_ring.vault.id
  rotation_period = "604800s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = upper(var.kms_protection_level)
  }
}

# Compile the startup script. This script installs and configures Vault and all
# dependencies.
data "template_file" "vault-startup-script" {
  template = file("${path.module}/scripts/startup.sh.tpl")

  vars = {
    config                  = data.template_file.vault-config.rendered
    custom_http_proxy       = var.http_proxy
    service_account_email   = google_service_account.vault-admin.email
    internal_lb             = local.use_internal_lb
    vault_args              = var.vault_args
    vault_port              = var.vault_port
    vault_proxy_port        = var.vault_proxy_port
    vault_version           = var.vault_version
    vault_tls_bucket        = local.vault_tls_bucket
    vault_ca_cert_filename  = var.vault_ca_cert_filename
    vault_tls_key_filename  = var.vault_tls_key_filename
    vault_tls_cert_filename = var.vault_tls_cert_filename
    kms_project             = var.vault_tls_kms_key_project == "" ? var.project_id : var.vault_tls_kms_key_project
    kms_crypto_key          = local.vault_tls_kms_key
    user_startup_script     = var.user_startup_script
  }
}

# Compile the Vault configuration.
data "template_file" "vault-config" {
  template = file(format("%s/scripts/config.hcl.tpl", path.module))

  vars = {
    kms_project                              = var.project_id
    kms_location                             = google_kms_key_ring.vault.location
    kms_keyring                              = google_kms_key_ring.vault.name
    kms_crypto_key                           = google_kms_crypto_key.vault-init.name
    lb_ip                                    = local.lb_ip
    api_addr                                 = local.api_addr
    storage_bucket                           = google_storage_bucket.vault.name
    vault_log_level                          = var.vault_log_level
    vault_port                               = var.vault_port
    vault_tls_disable_client_certs           = var.vault_tls_disable_client_certs
    vault_tls_require_and_verify_client_cert = var.vault_tls_require_and_verify_client_cert
    vault_ui_enabled                         = var.vault_ui_enabled
  }
}
