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

data "google_compute_network" "vault" {
  name    = var.network_name
  project = var.host_project_id
}

data "google_compute_subnetwork" "vault" {
  name    = var.subnet_name
  project = var.host_project_id
  region  = var.region
}

resource "google_compute_address" "vault_ilb" {
  project      = var.service_project_id
  region       = var.region
  subnetwork   = data.google_compute_subnetwork.vault.self_link
  name         = "vault-internal"
  address_type = "INTERNAL"
}

resource "google_service_account" "vault-admin" {
  project      = var.service_project_id
  account_id   = var.service_account_name
  display_name = "Vault Admin"
}

resource "google_storage_bucket" "vault" {
  project       = var.service_project_id
  name          = "${var.service_project_id}-vault-storage"
  location      = "US"
  force_destroy = true
}

module "vault_cluster" {
  source = "../../modules/cluster"

  project_id                  = var.service_project_id
  host_project_id             = var.host_project_id
  subnet                      = data.google_compute_subnetwork.vault.self_link
  ip_address                  = google_compute_address.vault_ilb.address
  vault_storage_bucket        = google_storage_bucket.vault.name
  vault_service_account_email = google_service_account.vault-admin.email
  load_balancing_scheme       = "INTERNAL"
  kms_keyring                 = var.kms_keyring
  region                      = var.region
}
