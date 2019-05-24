#
# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# This file contains the steps to create and sign TLS self-signed certs for
# Vault.
#

# Generate a self-sign TLS certificate that will act as the root CA.
resource "tls_private_key" "root" {
  count = "${local.manage_tls}"

  algorithm = "RSA"
  rsa_bits  = "2048"
}

# Sign ourselves
resource "tls_self_signed_cert" "root" {
  count = "${local.manage_tls}"

  key_algorithm   = "${tls_private_key.root.algorithm}"
  private_key_pem = "${tls_private_key.root.private_key_pem}"

  subject = ["${var.tls_ca_subject}"]

  validity_period_hours = 26280
  early_renewal_hours   = 8760
  is_ca_certificate     = true

  allowed_uses = ["cert_signing"]
}

# Save the root CA locally for TLS verification
resource "local_file" "root" {
  count = "${local.manage_tls}"

  filename = "ca.crt"
  content  = "${tls_self_signed_cert.root.cert_pem}"
}

# Vault server key
resource "tls_private_key" "vault-server" {
  count = "${local.manage_tls}"

  algorithm = "RSA"
  rsa_bits  = "2048"
}

# Create the request to sign the cert with our CA
resource "tls_cert_request" "vault-server" {
  count = "${local.manage_tls}"

  key_algorithm   = "${tls_private_key.vault-server.algorithm}"
  private_key_pem = "${tls_private_key.vault-server.private_key_pem}"

  dns_names = ["${var.tls_dns_names}"]

  ip_addresses = [
    "${google_compute_address.vault.address}",
    "${var.tls_ips}",
  ]

  subject {
    common_name         = "${var.tls_cn}"
    organization        = "${lookup(var.tls_ca_subject, "organization")}"
    organizational_unit = "${var.tls_ou}"
  }
}

# Sign the cert
resource "tls_locally_signed_cert" "vault-server" {
  count = "${local.manage_tls}"

  cert_request_pem   = "${tls_cert_request.vault-server.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses = ["server_auth"]
}

# Encrypt server key with GCP KMS
data "external" "vault-tls-key-encrypted" {
  count = "${local.manage_tls}"

  program = ["${path.module}/scripts/gcpkms-encrypt.sh"]

  query = {
    root     = "${path.module}"
    data     = "${tls_private_key.vault-server.private_key_pem}"
    project  = "${var.project_id}"
    location = "${google_kms_key_ring.vault.location}"
    keyring  = "${google_kms_key_ring.vault.name}"
    key      = "${google_kms_crypto_key.vault-init.name}"
  }

  depends_on = ["google_kms_crypto_key.vault-init"]
}

resource "google_storage_bucket_object" "vault-private-key" {
  count = "${local.manage_tls}"

  name    = "${var.vault_tls_key_filename}"
  content = "${data.external.vault-tls-key-encrypted.result["ciphertext"]}"
  bucket  = "${local.vault_tls_bucket}"

  depends_on = ["google_storage_bucket.vault"]
}

resource "google_storage_bucket_object" "vault-server-cert" {
  count = "${local.manage_tls}"

  name    = "${var.vault_tls_cert_filename}"
  content = "${tls_locally_signed_cert.vault-server.cert_pem}"
  bucket  = "${local.vault_tls_bucket}"

  depends_on = ["google_storage_bucket.vault"]
}

resource "google_storage_bucket_object" "vault-ca-cert" {
  count = "${local.manage_tls}"

  name    = "${var.vault_ca_cert_filename}"
  content = "${tls_self_signed_cert.root.cert_pem}"
  bucket  = "${local.vault_tls_bucket}"

  depends_on = ["google_storage_bucket.vault"]
}
