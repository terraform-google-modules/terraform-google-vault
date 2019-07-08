locals {
  # Allow the user to specify a custom bucket name, default to project-id prefix
  storage_bucket_name = "${var.storage_bucket_name != "" ? var.storage_bucket_name : "${var.project_id}-vault-data"}"
}

# Create the storage bucket for where Vault data will be stored. This is a
# multi-regional storage bucket so it has the highest level of availability.
resource "google_storage_bucket" "vault" {
  project = "${var.project_id}"

  name          = "${local.storage_bucket_name}"
  location      = "${upper(var.storage_bucket_location)}"
  storage_class = "MULTI_REGIONAL"

  versioning {
    enabled = "${var.storage_versioning}"
  }

  lifecycle_rule = "${var.storage_lifecycle_rule}"

  force_destroy = "${var.storage_bucket_force_destroy}"

  depends_on = ["google_project_service.service"]
}
