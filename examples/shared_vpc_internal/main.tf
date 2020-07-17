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

module "host_project" {
  source                  = "terraform-google-modules/project-factory/google"
  random_project_id       = true
  name                    = var.host_project_name
  org_id                  = var.organization_id
  folder_id               = var.folder_id
  billing_account         = var.billing_account
  default_service_account = "deprivilege"
}

module "svpc" {
  source          = "terraform-google-modules/network/google"
  project_id      = module.host_project.project_id
  network_name    = var.network_name
  shared_vpc_host = true

  subnets = [
    {
      subnet_name   = "vault"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = var.region
    },
  ]
}

module "service_project" {
  source = "terraform-google-modules/project-factory/google//modules/shared_vpc"

  name              = var.service_project_name
  random_project_id = true

  org_id             = var.organization_id
  folder_id          = var.folder_id
  billing_account    = var.billing_account
  shared_vpc_enabled = true

  shared_vpc         = module.svpc.project_id
  shared_vpc_subnets = module.svpc.subnets_self_links

  activate_apis = [
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]

  disable_services_on_destroy = "false"
}

resource "google_compute_address" "vault_ilb" {
  subnetwork   = module.svpc.subnets_self_links[0]
  name         = "vault-internal"
  address_type = "INTERNAL"
}

resource "google_service_account" "vault-admin" {
  account_id   = var.service_account_name
  display_name = "Vault Admin"
  project      = module.service_project.project_id
}

resource "google_storage_bucket" "vault" {
  project = module.service_project.project_id
  name = "${module.service_project.project_id}-vault-storage"
  location = "US"
  force_destroy = true
}

module "vault_cluster" {
  source = "../../modules/cluster"

  project_id                  = module.service_project.project_id
  host_project_id             = module.host_project.project_id
  subnet                      = module.svpc.subnets_self_links[0]
  ip_address                  = google_compute_address.vault_ilb.address
  vault_storage_bucket        = google_storage_bucket.vault.name
  vault_service_account_email = google_service_account.vault-admin.email
  load_balancing_scheme       = "INTERNAL"
  kms_keyring                 = var.kms_keyring
}
