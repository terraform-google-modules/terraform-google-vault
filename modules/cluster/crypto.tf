/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# Create the KMS key ring
resource "google_kms_key_ring" "vault" {
  name     = var.kms_keyring
  location = var.region
  project  = var.project_id
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

#
# TLS self-signed certs for Vault.
#

provider "tls" {
  version = "~> 2.1.1"
}

locals {
  manage_tls_count          = var.manage_tls ? 1 : 0
  tls_save_ca_to_disk_count = var.tls_save_ca_to_disk ? 1 : 0
}

# Generate a self-sign TLS certificate that will act as the root CA.
resource "tls_private_key" "root" {
  count = local.manage_tls_count

  algorithm = "RSA"
  rsa_bits  = "2048"
}

# Sign ourselves
resource "tls_self_signed_cert" "root" {
  count = local.manage_tls_count

  key_algorithm   = tls_private_key.root[0].algorithm
  private_key_pem = tls_private_key.root[0].private_key_pem

  subject {
    common_name         = var.tls_ca_subject.common_name
    country             = var.tls_ca_subject.country
    locality            = var.tls_ca_subject.locality
    organization        = var.tls_ca_subject.organization
    organizational_unit = var.tls_ca_subject.organizational_unit
    postal_code         = var.tls_ca_subject.postal_code
    province            = var.tls_ca_subject.province
    street_address      = var.tls_ca_subject.street_address
  }

  validity_period_hours = 26280
  early_renewal_hours   = 8760
  is_ca_certificate     = true

  allowed_uses = ["cert_signing"]
}

# Save the root CA locally for TLS verification
resource "local_file" "root" {
  count = min(local.manage_tls_count, local.tls_save_ca_to_disk_count)

  filename = "ca.crt"
  content  = tls_self_signed_cert.root[0].cert_pem
}

# Vault server key
resource "tls_private_key" "vault-server" {
  count = local.manage_tls_count

  algorithm = "RSA"
  rsa_bits  = "2048"
}

# Create the request to sign the cert with our CA
resource "tls_cert_request" "vault-server" {
  count = local.manage_tls_count

  key_algorithm   = tls_private_key.vault-server[0].algorithm
  private_key_pem = tls_private_key.vault-server[0].private_key_pem

  dns_names = var.tls_dns_names

  ip_addresses = concat([local.lb_ip], var.tls_ips)

  subject {
    common_name         = var.tls_cn
    organization        = var.tls_ca_subject["organization"]
    organizational_unit = var.tls_ou
  }
}

# Sign the cert
resource "tls_locally_signed_cert" "vault-server" {
  count = local.manage_tls_count

  cert_request_pem   = tls_cert_request.vault-server[0].cert_request_pem
  ca_key_algorithm   = tls_private_key.root[0].algorithm
  ca_private_key_pem = tls_private_key.root[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root[0].cert_pem

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses = ["server_auth"]
}

# Encrypt server key with GCP KMS
resource "google_kms_secret_ciphertext" "vault-tls-key-encrypted" {
  count = local.manage_tls_count

  crypto_key = google_kms_crypto_key.vault-init.self_link
  plaintext  = tls_private_key.vault-server[0].private_key_pem
}

resource "google_storage_bucket_object" "vault-private-key" {
  count = local.manage_tls_count

  name    = var.vault_tls_key_filename
  content = google_kms_secret_ciphertext.vault-tls-key-encrypted[0].ciphertext
  bucket  = local.vault_tls_bucket

  # Ciphertext changes on each invocation, so ignore changes
  lifecycle {
    ignore_changes = [
      content,
    ]
  }
}

resource "google_storage_bucket_object" "vault-server-cert" {
  count = local.manage_tls_count

  name    = var.vault_tls_cert_filename
  content = tls_locally_signed_cert.vault-server[0].cert_pem
  bucket  = local.vault_tls_bucket
}

resource "google_storage_bucket_object" "vault-ca-cert" {
  count = local.manage_tls_count

  name    = var.vault_ca_cert_filename
  content = tls_self_signed_cert.root[0].cert_pem
  bucket  = local.vault_tls_bucket
}
