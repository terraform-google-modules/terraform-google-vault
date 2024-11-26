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
#
# This file contains the actual Vault server definitions
#

# Template for creating Vault nodes
locals {
  lb_scheme         = upper(var.load_balancing_scheme)
  use_internal_lb   = local.lb_scheme == "INTERNAL"
  use_external_lb   = local.lb_scheme == "EXTERNAL"
  vault_tls_bucket  = var.vault_tls_bucket != "" ? var.vault_tls_bucket : var.vault_storage_bucket
  default_kms_key   = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.kms_keyring}/cryptoKeys/${var.kms_crypto_key}"
  vault_tls_kms_key = var.vault_tls_kms_key != "" ? var.vault_tls_kms_key : local.default_kms_key
  api_addr          = var.domain != "" ? "https://${var.domain}:${var.vault_port}" : "https://${local.lb_ip}:${var.vault_port}"
  host_project      = var.host_project_id != "" ? var.host_project_id : var.project_id
  lb_ip             = local.use_external_lb ? google_compute_forwarding_rule.external[0].ip_address : var.ip_address
  # LB and Autohealing health checks have different behavior.  The load
  # balancer shouldn't route traffic to a secondary vault instance, but it
  # should consider the instance healthy for autohealing purposes.
  # See: https://www.vaultproject.io/api-docs/system/health
  hc_workload_request_path = "/v1/sys/health?uninitcode=200"
  hc_autoheal_request_path = "/v1/sys/health?uninitcode=200&standbyok=true"
  # Default to all zones in the region unless zones were provided.
  zones = length(var.zones) > 0 ? var.zones : data.google_compute_zones.available.names
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_instance_template" "vault" {
  project     = var.project_id
  region      = var.region
  name_prefix = "vault-"

  machine_type = var.vault_machine_type

  tags = concat(["allow-ssh", "allow-vault"], var.vault_instance_tags)

  labels = var.vault_instance_labels

  network_interface {
    subnetwork         = var.subnet
    subnetwork_project = local.host_project
  }

  disk {
    source_image = var.vault_instance_base_image
    type         = "PERSISTENT"
    disk_type    = "pd-ssd"
    mode         = "READ_WRITE"
    boot         = true
  }

  service_account {
    email  = var.vault_service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = merge(
    var.vault_instance_metadata,
    {
      "google-compute-enable-virtio-rng" = "true"
      # Render the startup script. This script installs and configures
      # Vault and all dependencies.
      "startup-script" = templatefile("${path.module}/templates/startup.sh.tpl",
        {
          custom_http_proxy       = var.http_proxy
          service_account_email   = var.vault_service_account_email
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
          # Render the Vault configuration.
          config = templatefile("${path.module}/templates/config.hcl.tpl",
            {
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
              user_vault_config                        = var.user_vault_config
          })
      })
    },
  )

  lifecycle {
    create_before_destroy = true
  }

}

############################
## Internal Load Balancer ##
############################

resource "google_compute_health_check" "vault_internal" {
  count   = local.use_internal_lb ? 1 : 0
  project = var.project_id
  name    = "vault-health-internal"

  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  https_health_check {
    port         = var.vault_port
    request_path = local.hc_workload_request_path
  }
}

resource "google_compute_region_backend_service" "vault_internal" {
  count         = local.use_internal_lb ? 1 : 0
  project       = var.project_id
  name          = "vault-backend-service"
  region        = var.region
  health_checks = [google_compute_health_check.vault_internal[0].self_link]

  backend {
    group          = google_compute_region_instance_group_manager.vault.instance_group
    balancing_mode = "CONNECTION"
  }
}

# Forward internal traffic to the backend service
resource "google_compute_forwarding_rule" "vault_internal" {
  count = local.use_internal_lb ? 1 : 0

  project               = var.project_id
  name                  = "vault-internal"
  region                = var.region
  ip_protocol           = "TCP"
  ip_address            = var.ip_address
  load_balancing_scheme = local.lb_scheme
  network_tier          = "PREMIUM"
  allow_global_access   = true
  subnetwork            = var.subnet
  service_label         = var.service_label

  backend_service = google_compute_region_backend_service.vault_internal[0].self_link
  ports           = [var.vault_port]
}

############################
## External Load Balancer ##
############################

# This legacy health check is required because the target pool requires an HTTP
# health check.
resource "google_compute_http_health_check" "vault" {
  count   = local.use_external_lb ? 1 : 0
  project = var.project_id
  name    = "vault-health-legacy"

  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
  port                = var.vault_proxy_port
  request_path        = local.hc_workload_request_path
}


resource "google_compute_target_pool" "vault" {
  count   = local.use_external_lb ? 1 : 0
  project = var.project_id

  name   = "vault-tp"
  region = var.region

  health_checks = [google_compute_http_health_check.vault[0].name]
}

# Forward external traffic to the target pool
resource "google_compute_forwarding_rule" "external" {
  count   = local.use_external_lb ? 1 : 0
  project = var.project_id

  name                  = "vault-external"
  region                = var.region
  ip_address            = var.ip_address
  ip_protocol           = "TCP"
  load_balancing_scheme = local.lb_scheme
  network_tier          = "PREMIUM"

  target     = google_compute_target_pool.vault[0].self_link
  port_range = var.vault_port
}



# Vault instance group manager
resource "google_compute_region_instance_group_manager" "vault" {
  provider = google-beta
  project  = var.project_id

  name   = "vault-igm"
  region = var.region

  base_instance_name = "vault-${var.region}"
  wait_for_instances = false

  auto_healing_policies {
    health_check      = google_compute_health_check.autoheal.id
    initial_delay_sec = var.hc_initial_delay_secs
  }

  update_policy {
    type                  = var.vault_update_policy_type
    minimal_action        = "REPLACE"
    max_unavailable_fixed = length(local.zones)
    min_ready_sec         = var.min_ready_sec
  }

  target_pools = local.use_external_lb ? [google_compute_target_pool.vault[0].self_link] : []

  named_port {
    name = "vault-http"
    port = var.vault_port
  }

  version {
    instance_template = google_compute_instance_template.vault.self_link
  }
}

# Autoscaling policies for vault
resource "google_compute_region_autoscaler" "vault" {
  project = var.project_id

  name   = "vault-as"
  region = var.region
  target = google_compute_region_instance_group_manager.vault.self_link

  autoscaling_policy {
    min_replicas    = var.vault_min_num_servers
    max_replicas    = var.vault_max_num_servers
    cooldown_period = 300

    cpu_utilization {
      target = 0.8
    }
  }

}

# Auto-healing
resource "google_compute_health_check" "autoheal" {
  project = var.project_id
  name    = "vault-health-autoheal"

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 1
  unhealthy_threshold = 2

  https_health_check {
    port         = var.vault_port
    request_path = local.hc_autoheal_request_path
  }
}
