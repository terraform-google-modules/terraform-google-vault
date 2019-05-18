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
locals {
  ips = [
    "${var.tls_ips}",
    "${google_compute_address.vault.address}",
  ]
}

resource "null_resource" "vault-tls" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-tls-certs.sh"
    environment = {
      # Set to 0 for testing certificate creation locally without uploading
      ENCRYPT_AND_UPLOAD   = "1"
      PROJECT              = "${var.project_id}"
      CN                   = "${var.tls_cn}"
      OU                   = "${var.tls_ou}"
      ORG                  = "${lookup(var.tls_ca_subject, "organization")}"
      COUNTRY              = "${lookup(var.tls_ca_subject, "country")}"
      STATE                = "${lookup(var.tls_ca_subject, "province")}"
      LOCALITY             = "${lookup(var.tls_ca_subject, "locality")}"
      BUCKET               = "${local.vault_tls_bucket}"
      DOMAINS              = "${join(",", var.tls_dns_names)}"
      IPS                  = "${join(",", local.ips)}"
      KMS_KEYRING          = "${google_kms_key_ring.vault.name}"
      KMS_LOCATION         = "${google_kms_key_ring.vault.location}"
      KMS_KEY              = "${google_kms_crypto_key.vault-init.name}"
    }
  }
  depends_on = ["google_storage_bucket.vault"]
}

resource "null_resource" "pull-ca-cert" {
  provisioner "local-exec" {
    # For backwards compatibility, if users already have a ca.crt in their directory,
    # we want to make sure to keep it since it's not tracked by VCS
    command = "gsutil cp gs://${local.vault_tls_bucket}/${var.vault_ca_cert_filename} vault-ca.crt"
  }
  depends_on = ["null_resource.vault-tls"]
}
