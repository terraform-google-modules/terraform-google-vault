/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

data "template_file" "vault-startup-script" {
  template = "${file("${format("%s/scripts/startup.sh.tpl", path.module)}")}"

  vars {
    environment           = "${var.environment}"
    config                = "${data.template_file.vault-config.rendered}"
    service_account_email = "${google_service_account.vault-admin.email}"
    vault_version         = "${var.vault_version}"
    vault_args            = "${var.vault_args}"
    assets_bucket         = "${google_storage_bucket.vault-assets.name}"
    kms_keyring_name      = "${var.kms_keyring_name}"
    kms_key_name          = "${var.kms_key_name}"
    vault_sa_key          = "${google_storage_bucket_object.vault-sa-key.name}"
    vault_ca_cert         = "${google_storage_bucket_object.vault-ca-cert.name}"
    vault_tls_key         = "${google_storage_bucket_object.vault-tls-key.name}"
    vault_tls_cert        = "${google_storage_bucket_object.vault-tls-cert.name}"
  }
}

data "template_file" "vault-config" {
  template = "${file("${format("%s/scripts/config.hcl.tpl", path.module)}")}"

  vars {
    storage_bucket = "${google_storage_bucket.vault.name}"
    environment    = "${var.environment}"
  }
}

module "vault-server" {
  source                = "GoogleCloudPlatform/managed-instance-group/google"
  version               = "1.1.13"
  http_health_check     = false
  region                = "${var.region}"
  zone                  = "${var.zone}"
  name                  = "vault-${var.environment}-${var.region}"
  machine_type          = "${var.machine_type}"
  compute_image         = "debian-cloud/debian-9"
  service_account_email = "${google_service_account.vault-admin.email}"

  service_account_scopes = [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/devstorage.full_control",
  ]

  size              = 1
  service_port      = "80"
  service_port_name = "hc"
  startup_script    = "${data.template_file.vault-startup-script.rendered}"
}

resource "google_storage_bucket" "vault" {
  name     = "${var.storage_bucket}"
  location = "US"

  // delete bucket and contents on destroy.
  force_destroy = "${var.force_destroy_bucket}"
}

resource "google_storage_bucket" "vault-assets" {
  name     = "${var.storage_bucket}-assets"
  location = "US"

  // delete bucket and contents on destroy.
  force_destroy = "${var.force_destroy_bucket}"
}

resource "google_service_account" "vault-admin" {
  account_id   = "${var.service_account_name}"
  display_name = "${var.service_account_description}"
}

resource "google_service_account_key" "vault-admin" {
  service_account_id = "${google_service_account.vault-admin.id}"
  public_key_type = "TYPE_X509_PEM_FILE"
  private_key_type = "TYPE_GOOGLE_CREDENTIALS_FILE"
}

// Encrypt the SA key with KMS.
data "external" "sa-key-encrypted" {
  program = ["${path.module}/encrypt_file.sh"]

  query = {
    dest    = "vault_sa_key-${var.environment}.json.encrypted.base64"
    data    = "${google_service_account_key.vault-admin.private_key}"
    keyring = "${var.kms_keyring_name}"
    key     = "${var.kms_key_name}"
    b64in   = "true"
  }
}

// Upload the service account key to the assets bucket.
resource "google_storage_bucket_object" "vault-sa-key" {
  name         = "vault_sa_key-${var.environment}.json.encrypted.base64"
  content      = "${file(data.external.sa-key-encrypted.result["file"])}"
  content_type = "application/octet-stream"
  bucket       = "${google_storage_bucket.vault-assets.name}"
  
  provisioner "local-exec" {
    when    = "destroy"
    command = "rm -f vault_sa_key-${var.environment}.json*"
    interpreter = ["sh", "-c"]
  }
}

resource "google_project_iam_policy" "vault" {
  project     = "${var.project_id}"
  policy_data = "${data.google_iam_policy.vault.policy_data}"
}

data "google_iam_policy" "vault" {
  binding {
    role = "roles/storage.admin"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }

  binding {
    role = "roles/iam.serviceAccountActor"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }

  binding {
    role = "roles/iam.serviceAccountKeyAdmin"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }

  binding {
    role = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }

  binding {
    role = "roles/logging.logWriter"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }
}

// TLS resources

// Root CA key
resource "tls_private_key" "root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

// Root CA cert
resource "tls_self_signed_cert" "root" {
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.root.private_key_pem}"

  validity_period_hours = 26280
  early_renewal_hours   = 8760

  is_ca_certificate = true

  allowed_uses = ["cert_signing"]

  subject = ["${var.tls_ca_subject}"]
}

// Vault server key
resource "tls_private_key" "vault-server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

// Vault server cert request
resource "tls_cert_request" "vault-server" {
  key_algorithm   = "${tls_private_key.vault-server.algorithm}"
  private_key_pem = "${tls_private_key.vault-server.private_key_pem}"

  dns_names    = ["${var.tls_dns_names}"]
  ip_addresses = ["${var.tls_ips}"]

  subject {
    common_name         = "${var.tls_cn}"
    organization        = "${lookup(var.tls_ca_subject, "organization")}"
    organizational_unit = "${var.tls_ou}"
  }
}

// Vault server self signed cert
resource "tls_locally_signed_cert" "vault-server" {
  cert_request_pem = "${tls_cert_request.vault-server.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 17520
  early_renewal_hours   = 8760

  allowed_uses = ["server_auth"]
}

// Encrypt the CA cert.
data "external" "vault-ca-cert-encrypted" {
  program = ["${path.module}/encrypt_file.sh"]

  query = {
    dest    = "certs/${var.environment}/vault-server-${var.environment}.ca.crt.pem.encrypted.base64"
    data    = "${tls_self_signed_cert.root.cert_pem}"
    keyring = "${var.kms_keyring_name}"
    key     = "${var.kms_key_name}"
  }
}

// Upload the CA cert to the assets bucket.
resource "google_storage_bucket_object" "vault-ca-cert" {
  name         = "vault-server-${var.environment}.ca.crt.pem.encrypted.base64"
  content      = "${file(data.external.vault-ca-cert-encrypted.result["file"])}"
  content_type = "application/octet-stream"
  bucket       = "${google_storage_bucket.vault-assets.name}"
  
  provisioner "local-exec" {
    when    = "destroy"
    command = "rm -f certs/${var.environment}/vault-server-${var.environment}.ca.crt.pem*"
    interpreter = ["sh", "-c"]
  }
}

// Encrypt the server key.
data "external" "vault-tls-key-encrypted" {
  program = ["${path.module}/encrypt_file.sh"]

  query = {
    dest    = "certs/${var.environment}/vault-server-${var.environment}.key.pem.encrypted.base64"
    data    = "${tls_private_key.vault-server.private_key_pem}"
    keyring = "${var.kms_keyring_name}"
    key     = "${var.kms_key_name}"
  }
}

// Upload the server key to the assets bucket.
resource "google_storage_bucket_object" "vault-tls-key" {
  name         = "vault-server-${var.environment}.key.pem.encrypted.base64"
  content      = "${file(data.external.vault-tls-key-encrypted.result["file"])}"
  content_type = "application/octet-stream"
  bucket       = "${google_storage_bucket.vault-assets.name}"
  
  provisioner "local-exec" {
    when    = "destroy"
    command = "rm -f certs/${var.environment}/vault-server-${var.environment}.key.pem*"
    interpreter = ["sh", "-c"]
  }
}

// Encrypt the server cert.
data "external" "vault-tls-cert-encrypted" {
  program = ["${path.module}/encrypt_file.sh"]

  query = {
    dest    = "certs/${var.environment}/vault-server-${var.environment}.crt.pem.encrypted.base64"
    data    = "${tls_locally_signed_cert.vault-server.cert_pem}"
    keyring = "${var.kms_keyring_name}"
    key     = "${var.kms_key_name}"
  }
}

// Upload the server key to the assets bucket.
resource "google_storage_bucket_object" "vault-tls-cert" {
  name         = "vault-server-${var.environment}.crt.pem.encrypted.base64"
  content      = "${file(data.external.vault-tls-cert-encrypted.result["file"])}"
  content_type = "application/octet-stream"
  bucket       = "${google_storage_bucket.vault-assets.name}"
  
  provisioner "local-exec" {
    when    = "destroy"
    command = "rm -f certs/${var.environment}/vault-server-${var.environment}.crt.pem*"
    interpreter = ["sh", "-c"]
  }
}
