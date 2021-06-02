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

# Compile the startup script. This script installs and configures Vault and all
# dependencies.
data "template_file" "vault-startup-script" {
  template = file("${path.module}/templates/startup.sh.tpl")

  vars = {
    config                  = data.template_file.vault-config.rendered
    custom_http_proxy       = var.http_proxy
    service_account_email   = var.vault_service_account_email
    internal_lb             = local.use_internal_lb
    vault_args              = var.vault_args
    vault_port              = var.vault_port
    vault_proxy_port        = var.vault_proxy_port
    vault_version           = var.vault_version
    vault_tls_bucket        = local.vault_tls_bucket
    kms_keyring             = var.vault_tls_kms_keyring
    location                = var.vault_tls_kms_location
    vault_ca_cert_filename  = var.vault_ca_cert_filename
    vault_tls_key_filename  = var.vault_tls_key_filename
    vault_tls_cert_filename = var.vault_tls_cert_filename
    kms_project             = var.vault_tls_kms_key_project == "" ? var.project_id : var.vault_tls_kms_key_project
    kms_crypto_key          = local.vault_tls_kms_key
    user_startup_script     = var.user_startup_script
    vault_tls_kms_key_name  = var.vault_tls_kms_key_name
  }
}

# Compile the Vault configuration.
data "template_file" "vault-config" {
  template = file(format("%s/templates/config.hcl.tpl", path.module))

  vars = {
    kms_project                              = var.project_id
    kms_location                             = google_kms_key_ring.vault.location
    kms_keyring                              = google_kms_key_ring.vault.name
    kms_crypto_key                           = google_kms_crypto_key.vault-init.name
    lb_ip                                    = local.lb_ip
    api_addr                                 = local.api_addr
    storage_bucket                           = var.vault_storage_bucket
    vault_log_level                          = var.vault_log_level
    vault_port                               = var.vault_port
    vault_proxy_port                         = var.vault_proxy_port
    vault_tls_disable_client_certs           = var.vault_tls_disable_client_certs
    vault_tls_require_and_verify_client_cert = var.vault_tls_require_and_verify_client_cert
    vault_ui_enabled                         = var.vault_ui_enabled
  }
}
