data "template_file" "vault-startup-script" {
  template = "${file("${format("%s/scripts/startup.sh.tpl", path.module)}")}"

  vars {
    config                = "${data.template_file.vault-config.rendered}"
    service_account_email = "${google_service_account.vault-admin.email}"
    vault_version         = "${var.vault_version}"
    vault_args            = "${var.vault_args}"
  }
}

data "template_file" "vault-config" {
  template = "${file("${format("%s/scripts/config.hcl.tpl", path.module)}")}"

  vars {
    storage_bucket = "${google_storage_bucket.vault.name}"
  }
}

module "vault-server" {
  source                = "github.com/GoogleCloudPlatform/terraform-google-managed-instance-group"
  region                = "${var.region}"
  zone                  = "${var.zone}"
  name                  = "vault-${var.region}"
  machine_type          = "${var.machine_type}"
  compute_image         = "debian-cloud/debian-9"
  service_account_email = "${google_service_account.vault-admin.email}"

  service_account_scopes = [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/devstorage.full_control",
  ]

  size              = 1
  service_port      = "8200"
  service_port_name = "tcp"
  startup_script    = "${data.template_file.vault-startup-script.rendered}"
}

resource "google_storage_bucket" "vault" {
  name     = "${var.storage_bucket}"
  location = "US"

  // delete bucket and contents on destroy.
  force_destroy = "${var.force_destroy_bucket}"
}

resource "google_service_account" "vault-admin" {
  account_id   = "vault-admin"
  display_name = "Vault Admin"
}

resource "google_project_iam_policy" "vault" {
  project     = "${var.project_id}"
  policy_data = "${data.google_iam_policy.vault.policy_data}"
}

data "google_iam_policy" "vault" {
  binding {
    role = "roles/storage.admin"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }

  binding {
    role = "roles/iam.serviceAccountActor"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }

  binding {
    role = "roles/iam.serviceAccountKeyAdmin"

    members = [
      "serviceAccount:${google_service_account.vault-admin.email}",
    ]
  }
}
