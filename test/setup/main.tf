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
  version = "~> 8.0"

  name                        = "ci-vault-module"
  random_project_id           = true
  org_id                      = var.org_id
  folder_id                   = var.folder_id
  billing_account             = var.billing_account
  skip_gcloud_download        = true
  disable_services_on_destroy = false
  default_service_account     = "keep"
  activate_apis               = local.apis
}

module "svpc" {
  source          = "terraform-google-modules/network/google"
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
  source = "terraform-google-modules/project-factory/google//modules/shared_vpc"

  name              = "ci-vault-svpc-service"
  random_project_id = true

  org_id             = var.org_id
  folder_id          = var.folder_id
  billing_account    = var.billing_account
  shared_vpc_enabled = true

  shared_vpc         = module.svpc.project_id
  shared_vpc_subnets = module.svpc.subnets_self_links

  activate_apis               = local.apis
  skip_gcloud_download        = true
  disable_services_on_destroy = false
  default_service_account     = "keep"
}
