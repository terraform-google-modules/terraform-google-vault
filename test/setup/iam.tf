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
  required_roles = [
    "roles/iam.serviceAccountUser",
    "roles/compute.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
    "roles/billing.projectManager",
  ]

  required_folder_roles = [
    "roles/owner",
    "roles/resourcemanager.projectCreator",
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.folderIamAdmin",
    "roles/billing.projectManager",
    "roles/compute.xpnAdmin"
  ]
}

resource "google_service_account" "ci_account" {
  project      = module.project_ci.project_id
  account_id   = "ci-account"
  display_name = "ci-account"
}

resource "google_project_iam_member" "ci_account" {
  for_each = toset(local.required_roles)

  project = module.project_ci.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.ci_account.email}"
}

resource "google_service_account_key" "ci_account" {
  service_account_id = google_service_account.ci_account.id
}

resource "google_folder_iam_member" "int_test_folder" {
  for_each = toset(local.required_folder_roles)

  folder = var.folder_id
  role   = each.value
  member = "serviceAccount:${google_service_account.ci_account.email}"
}


resource "google_billing_account_iam_member" "billing_admin" {
  billing_account_id = var.billing_account
  role               = "roles/billing.admin"
  member             = "serviceAccount:${google_service_account.ci_account.email}"
}
