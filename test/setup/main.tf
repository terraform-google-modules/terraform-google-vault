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

resource "random_id" "name" {
  byte_length = 2
}

locals {
  apis = [
    "cloudkms.googleapis.com",
    "admin.googleapis.com",
    "appengine.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "oslogin.googleapis.com",
    "serviceusage.googleapis.com",
    "billingbudgets.googleapis.com",
    "pubsub.googleapis.com",
  ]
}

module "project_ci" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name                        = "ci-vault-module"
  random_project_id           = true
  org_id                      = var.org_id
  folder_id                   = var.folder_id
  billing_account             = var.billing_account
  disable_services_on_destroy = false
  default_service_account     = "keep"
  activate_apis               = local.apis
}

module "svpc" {
  source          = "terraform-google-modules/network/google"
  version         = "~> 10.0"
  project_id      = module.project_ci.project_id
  network_name    = var.network_name
  shared_vpc_host = true

  subnets = [
    {
      subnet_name   = "vault"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = var.subnet_region
    },
  ]
}

module "service_project_ci" {
  source  = "terraform-google-modules/project-factory/google//modules/svpc_service_project"
  version = "~> 18.0"

  name              = "ci-vault-svpc-service"
  random_project_id = true

  org_id          = var.org_id
  folder_id       = var.folder_id
  billing_account = var.billing_account

  shared_vpc         = module.svpc.project_id
  shared_vpc_subnets = module.svpc.subnets_self_links

  activate_apis               = local.apis
  disable_services_on_destroy = false
  default_service_account     = "keep"
}

resource "google_compute_firewall" "allow-health-check" {
  name    = "allow-health-check-${random_id.name.hex}"
  network = module.svpc.network_name
  project = module.svpc.project_id

  description = "Allow health check probes for instance groups"

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }
}

// Cloud Nat
module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 5.0"
  project_id = module.svpc.project_id
  network    = module.svpc.network_name
  region     = var.subnet_region
  name       = "cloud-nat-${var.subnet_region}-${random_id.name.hex}"
  router     = "cloud-nat-${var.subnet_region}-${random_id.name.hex}"

  create_router = true
}
