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
  lb_scheme       = upper(var.load_balancing_scheme)
  use_internal_lb = local.lb_scheme == "INTERNAL"
  use_external_lb = local.lb_scheme == "EXTERNAL"
  ip_address      = local.use_internal_lb ? google_compute_address.vault_ilb[0].address : google_compute_address.vault[0].address
}

# Configure the Google provider.
provider "google" {
  project = var.project_id
  region  = var.region
}

# This needs to stay here to allow migration from 4.2 to 5.0
provider "tls" {}

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

module "cluster" {
  source                                       = "./modules/cluster"
  ip_address                                   = local.ip_address
  subnet                                       = local.subnet
  service_label                                = var.service_label
  project_id                                   = var.project_id
  region                                       = var.region
  vault_storage_bucket                         = google_storage_bucket.vault.name
  vault_service_account_email                  = google_service_account.vault-admin.email
  service_account_project_additional_iam_roles = var.service_account_project_additional_iam_roles
  service_account_storage_bucket_iam_roles     = var.service_account_storage_bucket_iam_roles
  kms_keyring                                  = var.kms_keyring
  kms_crypto_key                               = var.kms_crypto_key
  kms_protection_level                         = var.kms_protection_level
  load_balancing_scheme                        = var.load_balancing_scheme
  vault_args                                   = var.vault_args
  vault_instance_labels                        = var.vault_instance_labels
  vault_ca_cert_filename                       = var.vault_ca_cert_filename
  vault_instance_metadata                      = var.vault_instance_metadata
  vault_instance_base_image                    = var.vault_instance_base_image
  vault_instance_tags                          = var.vault_instance_tags
  vault_log_level                              = var.vault_log_level
  vault_min_num_servers                        = var.vault_min_num_servers
  vault_machine_type                           = var.vault_machine_type
  vault_max_num_servers                        = var.vault_max_num_servers
  vault_update_policy_type                     = var.vault_update_policy_type
  vault_port                                   = var.vault_port
  vault_proxy_port                             = var.vault_proxy_port
  vault_tls_disable_client_certs               = var.vault_tls_disable_client_certs
  vault_tls_require_and_verify_client_cert     = var.vault_tls_require_and_verify_client_cert
  vault_tls_bucket                             = var.vault_tls_bucket
  vault_tls_kms_key                            = var.vault_tls_kms_key
  vault_tls_kms_key_project                    = var.vault_tls_kms_key_project
  vault_tls_cert_filename                      = var.vault_tls_cert_filename
  vault_tls_key_filename                       = var.vault_tls_key_filename
  vault_ui_enabled                             = var.vault_ui_enabled
  vault_version                                = var.vault_version
  http_proxy                                   = var.http_proxy
  user_startup_script                          = var.user_startup_script
  manage_tls                                   = var.manage_tls
  tls_ca_subject                               = var.tls_ca_subject
  tls_cn                                       = var.tls_cn
  domain                                       = var.domain
  tls_dns_names                                = var.tls_dns_names
  tls_ips                                      = var.tls_ips
  tls_save_ca_to_disk                          = var.tls_save_ca_to_disk
  tls_ou                                       = var.tls_ou
}
