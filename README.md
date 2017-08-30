# Vault on GCE Terraform Module

Modular deployment of Vault on Compute Engine

## Usage

```ruby
module "vault" {
  source = "github.com/GoogleCloudPlatform/terrform-google-vault"
  project_id           = "${var.project_id}"
  region               = "${var.region}"
  zone                 = "${var.zone}"
  storage_bucket       = "${var.storage_bucket}"
}
```

### Input variables

- `project_id` (required): The project ID to add the IAM bindings for the service account to.
- `region` (required): The region to create the instance in.
- `zone` (required): The zone to create the instance in.
- `network` (optional): The network to deploy to. Default is `default`.
- `subnetwork` (optional): The subnetwork to deploy to. Default is `default`.
- `machine_type` (optional): The machine type for the instance. Default is `n1-standard-1`
- `vault_args` (optional): Additional command line arguments passed to vault server. 
- `force_destroy_bucket` (optional): Set to true to force deletion of backend bucket on terraform destroy. Default is `false`.

### Output variables 

None

## Resources created

- [`module.vault-server`](https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group): The Vault server managed instance group module.
- [`google_storage_bucket.vault`](https://www.terraform.io/docs/providers/google/r/storage_bucket.html): The Cloud Storage bucket for Vault storage.
- [`google_service_account.vault-admin`](https://www.terraform.io/docs/providers/google/r/google_service_account.html): The service account for the Vault instance.
- [`google_project_iam_policy.vault`](https://www.terraform.io/docs/providers/google/r/google_project_iam_policy.html): The IAM policy bindings for the Vault service account.  