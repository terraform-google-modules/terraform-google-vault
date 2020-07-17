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
      "startup-script"                   = data.template_file.vault-startup-script.rendered
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
    request_path = "/v1/sys/health?uninitcode=200"
  }
}

resource "google_compute_region_backend_service" "vault_internal" {
  count         = local.use_internal_lb ? 1 : 0
  project       = var.project_id
  name          = "vault-backend-service"
  region        = var.region
  health_checks = ["${google_compute_health_check.vault_internal[0].self_link}"]

  backend {
    group = google_compute_region_instance_group_manager.vault.instance_group
  }
}

# Forward internal traffic to the backend service
resource "google_compute_forwarding_rule" "vault_internal" {
  count   = local.use_internal_lb ? 1 : 0

  project               = var.project_id
  name                  = "vault-internal"
  region                = var.region
  ip_protocol           = "TCP"
  ip_address            = var.ip_address
  load_balancing_scheme = local.lb_scheme
  network_tier          = "PREMIUM"
  allow_global_access   = true
  subnetwork            = var.subnet

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
  project = var.project_id

  name   = "vault-igm"
  region = var.region

  base_instance_name = "vault-${var.region}"
  wait_for_instances = false

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
