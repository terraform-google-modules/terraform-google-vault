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

locals {
  service_account_member = "serviceAccount:${var.vault_service_account_email}"
}

# Give project-level IAM permissions to the service account.
resource "google_project_iam_member" "project-iam" {
  for_each = toset(var.service_account_project_iam_roles)
  project  = var.project_id
  role     = each.value
  member   = local.service_account_member
}

# Give additional project-level IAM permissions to the service account.
resource "google_project_iam_member" "additional-project-iam" {
  for_each = toset(var.service_account_project_additional_iam_roles)
  project  = var.project_id
  role     = each.key
  member   = local.service_account_member
}

# Give bucket-level permissions to the service account.
resource "google_storage_bucket_iam_member" "vault" {
  for_each = toset(var.service_account_storage_bucket_iam_roles)
  bucket   = var.vault_storage_bucket
  role     = each.key
  member   = local.service_account_member
}

# Give kms cryptokey-level permissions to the service account.
resource "google_kms_crypto_key_iam_member" "ck-iam" {
  crypto_key_id = google_kms_crypto_key.vault-init.self_link
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = local.service_account_member
}

resource "google_kms_crypto_key_iam_member" "tls-ck-iam" {
  count = var.manage_tls == false ? 1 : 0

  crypto_key_id = var.vault_tls_kms_key
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = local.service_account_member
}

resource "google_storage_bucket_iam_member" "tls-bucket-iam" {
  count = var.manage_tls == false ? 1 : 0

  bucket = var.vault_tls_bucket
  role   = "roles/storage.objectViewer"
  member = local.service_account_member
}
