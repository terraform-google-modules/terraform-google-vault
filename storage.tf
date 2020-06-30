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
  # Allow the user to specify a custom bucket name, default to project-id prefix
  storage_bucket_name = var.storage_bucket_name != "" ? var.storage_bucket_name : "${var.project_id}-vault-data"
}

# Create the storage bucket for where Vault data will be stored. This is a
# multi-regional storage bucket so it has the highest level of availability.
resource "google_storage_bucket" "vault" {
  project = var.project_id

  name          = local.storage_bucket_name
  location      = upper(var.storage_bucket_location)
  storage_class = upper(var.storage_bucket_class)

  versioning {
    enabled = var.storage_bucket_enable_versioning
  }

  dynamic "lifecycle_rule" {
    for_each = var.storage_bucket_lifecycle_rules

    content {
      action {
        type          = contains(keys(lifecycle_rule.value.action), "type") ? lifecycle_rule.value.action.type : null
        storage_class = contains(keys(lifecycle_rule.value.action), "storage_class") ? lifecycle_rule.value.action.storage_class : null
      }

      condition {
        age                   = contains(keys(lifecycle_rule.value.condition), "age") ? lifecycle_rule.value.condition.age : null
        created_before        = contains(keys(lifecycle_rule.value.condition), "created_before") ? lifecycle_rule.value.condition.created_before : null
        with_state            = contains(keys(lifecycle_rule.value.condition), "with_state") ? lifecycle_rule.value.condition.with_state : null
        is_live               = contains(keys(lifecycle_rule.value.condition), "is_live") ? lifecycle_rule.value.condition.is_live : null
        matches_storage_class = contains(keys(lifecycle_rule.value.condition), "matches_storage_class") ? lifecycle_rule.value.condition.matches_storage_class : null
        num_newer_versions    = contains(keys(lifecycle_rule.value.condition), "num_newer_versions") ? lifecycle_rule.value.condition.num_newer_versions : null
      }
    }
  }

  force_destroy = var.storage_bucket_force_destroy

  depends_on = [google_project_service.service]
}
