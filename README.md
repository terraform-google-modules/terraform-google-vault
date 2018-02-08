# Vault on GCE Terraform Module

Modular deployment of Vault on Compute Engine.

Unseal keys are generated when the instance first starts and stored encrypted using Cloud KMS in a separate Cloud Storage bucket for later retrival and Vault unsealing. 

This module also creates a TLS CA and certificates for the Vault server. The generated certificates are encrypyed using Cloud KMS and stored in a separate Cloud Storage bucket.

## Usage

```ruby
module "vault" {
  source = "github.com/GoogleCloudPlatform/terraform-google-vault"
  project_id           = "${var.project_id}"
  region               = "${var.region}"
  zone                 = "${var.zone}"
  storage_bucket       = "${var.storage_bucket}"
  kms_keyring_name     = "${var.kms_keyring_name}"
}
```

### Input variables

- `project_id` (required): The project ID to add the IAM bindings for the service account to.
- `region` (required): The region to create the instance in.
- `zone` (required): The zone to create the instance in.
- `kms_keyring_name` (required): The name of the Cloud KMS KeyRing for asset encryption.
- `kms_key_name`: (optional): The name of the Cloud KMS Key used for asset encryption/decryption. Default is `vault-init`.
- `network` (optional): The network to deploy to. Default is `default`.
- `subnetwork` (optional): The subnetwork to deploy to. Default is `default`.
- `machine_type` (optional): The machine type for the instance. Default is `n1-standard-1`
- `vault_args` (optional): Additional command line arguments passed to vault server. 
- `force_destroy_bucket` (optional): Set to true to force deletion of backend bucket on terraform destroy. Default is `false`.
- `tls_ca_subject` (optional): The `subject` block for the root CA certificate.
- `tls_dns_names` (optional): List of DNS names added to the Vault server self-signed certificate. Default is `["vault.example.net"]`.
- `tls_ips` (optional): List of IP addresses added to the Vault server self-signed certificate. Default is `["127.0.0.1"]`.
- `tls_cn` (optional): The TLS Common Name for the TLS certificates. Default is `vault.example.net`.
- `tls_ou` (optional): The TLS Organizational Unit for the TLS certificate. Default is `IT Security Operations`.

### Output variables 

- `instance_group`: Link to the `instance_group` property of the instance group manager resource.
- `ca_private_key_algorithm`: The root CA algorithm for generating client certs.
- `ca_private_key_pem`: The root CA key pem for generating client certs.
- `ca_cert_pem`: The root CA cert pem for generating client certs.

## Resources created

- [`module.vault-server`](https://github.com/GoogleCloudPlatform/terraform-google-managed-instance-group): The Vault server managed instance group module.
- [`google_storage_bucket.vault`](https://www.terraform.io/docs/providers/google/r/storage_bucket.html): The Cloud Storage bucket for Vault storage.
- [`google_storage_bucket.vault-assets`](https://www.terraform.io/docs/providers/google/r/storage_bucket.html): The Cloud Storage bucket for Vault unseal key and TLS certificate storage.
- [`google_service_account.vault-admin`](https://www.terraform.io/docs/providers/google/r/google_service_account.html): The service account for the Vault instance.
- [`google_project_iam_policy.vault`](https://www.terraform.io/docs/providers/google/r/google_project_iam_policy.html): The IAM policy bindings for the Vault service account.  
