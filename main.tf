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
  # Allow the user to specify a custom bucket name, default to project-id prefix
  storage_bucket_name = "${var.storage_bucket_name != "" ? var.storage_bucket_name : "${var.project_id}-vault-data"}"
}

# Configure the Google provider, locking to the 2.0 series.
provider "google" {
  version = "~> 2.0"
  project = "${var.project_id}"
  region  = "${var.region}"
}

# Enable required services on the project
resource "google_project_service" "service" {
  count   = "${length(var.project_services)}"
  project = "${var.project_id}"

  service = "${element(var.project_services, count.index)}"

  # Do not disable the service on destroy. This may be a shared project, and
  # we might not "own" the services we enable.
  disable_on_destroy = false
}

# Create the storage bucket for where Vault data will be stored. This is a
# multi-regional storage bucket so it has the highest level of availability.
resource "google_storage_bucket" "vault" {
  project = "${var.project_id}"

  name          = "${local.storage_bucket_name}"
  location      = "${upper(var.storage_bucket_location)}"
  storage_class = "MULTI_REGIONAL"
  force_destroy = "${var.storage_bucket_force_destroy}"

  depends_on = ["google_project_service.service"]
}

# Create the vault-admin service account.
resource "google_service_account" "vault-admin" {
  account_id   = "${var.service_account_name}"
  display_name = "Vault Admin"

  depends_on = ["google_project_service.service"]
}

# Give project-level IAM permissions to the service account.
resource "google_project_iam_member" "project-iam" {
  count   = "${length(var.service_account_project_iam_roles)}"
  project = "${var.project_id}"
  role    = "${element(var.service_account_project_iam_roles, count.index)}"
  member  = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = ["google_project_service.service"]
}

# Give additional project-level IAM permissions to the service account.
resource "google_project_iam_member" "additional-project-iam" {
  count   = "${length(var.service_account_project_additional_iam_roles)}"
  project = "${var.project_id}"
  role    = "${element(var.service_account_project_additional_iam_roles, count.index)}"
  member  = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = ["google_project_service.service"]
}

# Give bucket-level permissions to the service account.
resource "google_storage_bucket_iam_member" "vault" {
  count  = "${length(var.service_account_storage_bucket_iam_roles)}"
  bucket = "${google_storage_bucket.vault.name}"
  role   = "${element(var.service_account_storage_bucket_iam_roles, count.index)}"
  member = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = ["google_project_service.service"]
}

# Give kms cryptokey-level permissions to the service account.
resource "google_kms_crypto_key_iam_member" "ck-iam" {
  crypto_key_id = "${google_kms_crypto_key.vault-init.self_link}"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vault-admin.email}"

  depends_on = ["google_project_service.service"]
}

# Create the KMS key ring
resource "google_kms_key_ring" "vault" {
  name     = "${var.kms_keyring}"
  location = "${var.region}"
  project  = "${var.project_id}"

  depends_on = ["google_project_service.service"]
}

# Create the crypto key for encrypting init keys
resource "google_kms_crypto_key" "vault-init" {
  name            = "${var.kms_crypto_key}"
  key_ring        = "${google_kms_key_ring.vault.id}"
  rotation_period = "604800s"

  version_template {
    algorithm        = "google_symmetric_encryption"
    protection_level = "${upper(var.kms_protection_level)}"
  }
}

# Compile the startup script. This script installs and configures Vault and all
# dependencies.
data "template_file" "vault-startup-script" {
  template = "${file("${path.module}/scripts/startup.sh.tpl")}"

  vars {
    config                = "${data.template_file.vault-config.rendered}"
    service_account_email = "${google_service_account.vault-admin.email}"

    vault_args       = "${var.vault_args}"
    vault_port       = "${var.vault_port}"
    vault_proxy_port = "${var.vault_proxy_port}"
    vault_version    = "${var.vault_version}"

    vault_ca_cert  = "ca.crt=${data.external.vault-ca-cert-encrypted.result["ciphertext"]}"
    vault_tls_key  = "vault.key=${data.external.vault-tls-key-encrypted.result["ciphertext"]}"
    vault_tls_cert = "vault.crt=${data.external.vault-tls-cert-encrypted.result["ciphertext"]}"

    kms_project    = "${var.project_id}"
    kms_location   = "${google_kms_key_ring.vault.location}"
    kms_keyring    = "${google_kms_key_ring.vault.name}"
    kms_crypto_key = "${google_kms_crypto_key.vault-init.name}"
  }
}

# Compile the Vault configuration.
data "template_file" "vault-config" {
  template = "${file("${format("%s/scripts/config.hcl.tpl", path.module)}")}"

  vars {
    kms_project    = "${var.project_id}"
    kms_location   = "${google_kms_key_ring.vault.location}"
    kms_keyring    = "${google_kms_key_ring.vault.name}"
    kms_crypto_key = "${google_kms_crypto_key.vault-init.name}"

    lb_ip          = "${google_compute_address.vault.address}"
    storage_bucket = "${google_storage_bucket.vault.name}"

    vault_log_level                = "${var.vault_log_level}"
    vault_port                     = "${var.vault_port}"
    vault_tls_disable_client_certs = "${var.vault_tls_disable_client_certs}"
    vault_ui_enabled               = "${var.vault_ui_enabled}"
  }
}
