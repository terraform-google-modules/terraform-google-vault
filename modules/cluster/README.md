# terraform-google-vault

## Vault cluster submodule

This submodule gives organizations that have tighter controls over separation of duties, the ability deploy only the Vault cluster and Load balancer, but pass the networking, service account and bucket configuration in without the top level module. This enables a few use cases:

1. Shared VPC architechture where Vault lives in a service project that uses a host project's network
2. Strict permissions around which teams control firewall rules within a shared VPC
3. Migration from an existing Vault cluster where the configuration already exists in a GCS bucket
4. If you already have all the networking bits and you don't want Vault to be entirely isolated in its own network

## Usage

```
module "vault_cluster" {
	source = "terraform-google-modules/vault/google//modules/cluster"
	version = "~> 5.0"

	project_id                  = var.project_id
	host_project_id             = var.host_project_id
	subnet                      = var.subnet_self_link
	ip_address                  = google_compute_address.vault_lb.address
	vault_storage_bucket        = google_storage_bucket.vault.name
  vault_service_account_email = google_service_account.vault-admin.email
	...
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| domain | The domain name that will be set in the api_addr. Load Balancer IP used by default | string | `""` | no |
| host\_project\_id | ID of the host project if using Shared VPC | string | `""` | no |
| http\_proxy | HTTP proxy for downloading agents and vault executable on startup. Only necessary if allow_public_egress is false. This is only used on the first startup of the Vault cluster and will NOT set the global HTTP_PROXY environment variable. i.e. If you configure Vault to manage credentials for other services, default HTTP routes will be taken. | string | `""` | no |
| ip\_address | The IP address to assign the forwarding rules to. | string | n/a | yes |
| kms\_crypto\_key | The name of the Cloud KMS Key used for encrypting initial TLS certificates and for configuring Vault auto-unseal. Terraform will create this key. | string | `"vault-init"` | no |
| kms\_keyring | Name of the Cloud KMS KeyRing for asset encryption. Terraform will create this keyring. | string | `"vault"` | no |
| kms\_protection\_level | The protection level to use for the KMS crypto key. | string | `"software"` | no |
| load\_balancing\_scheme | Options are INTERNAL or EXTERNAL. If `EXTERNAL`, the forwarding rule will be of type EXTERNAL and a public IP will be created. If `INTERNAL` the type will be INTERNAL and a random RFC 1918 private IP will be assigned | string | `"EXTERNAL"` | no |
| manage\_tls | Set to `false` if you'd like to manage and upload your own TLS files. See `Managing TLS` for more details | bool | `"true"` | no |
| project\_id | ID of the project in which to create resources and add IAM bindings. | string | n/a | yes |
| region | Region in which to create resources. | string | `"us-east4"` | no |
| service\_account\_project\_additional\_iam\_roles | List of custom IAM roles to add to the project. | list(string) | `<list>` | no |
| service\_account\_project\_iam\_roles | List of IAM roles for the Vault admin service account to function. If you need to add additional roles, update `service_account_project_additional_iam_roles` instead. | list(string) | `<list>` | no |
| service\_account\_storage\_bucket\_iam\_roles | List of IAM roles for the Vault admin service account to have on the storage bucket. | list(string) | `<list>` | no |
| subnet | The self link of the VPC subnetwork for Vault. By default, one will be created for you. | string | n/a | yes |
| tls\_ca\_subject | The `subject` block for the root CA certificate. | object | `<map>` | no |
| tls\_cn | The TLS Common Name for the TLS certificates | string | `"vault.example.net"` | no |
| tls\_dns\_names | List of DNS names added to the Vault server self-signed certificate | list(string) | `<list>` | no |
| tls\_ips | List of IP addresses added to the Vault server self-signed certificate | list(string) | `<list>` | no |
| tls\_ou | The TLS Organizational Unit for the TLS certificate | string | `"IT Security Operations"` | no |
| tls\_save\_ca\_to\_disk | Save the CA public certificate on the local filesystem. The CA is always stored in GCS, but this option also saves it to the filesystem. | bool | `"true"` | no |
| user\_startup\_script | Additional user-provided code injected after Vault is setup | string | `""` | no |
| vault\_args | Additional command line arguments passed to Vault server | string | `""` | no |
| vault\_ca\_cert\_filename | GCS object path within the vault_tls_bucket. This is the root CA certificate. | string | `"ca.crt"` | no |
| vault\_instance\_base\_image | Base operating system image in which to install Vault. This must be a Debian-based system at the moment due to how the metadata startup script runs. | string | `"debian-cloud/debian-9"` | no |
| vault\_instance\_labels | Labels to apply to the Vault instances. | map(string) | `<map>` | no |
| vault\_instance\_metadata | Additional metadata to add to the Vault instances. | map(string) | `<map>` | no |
| vault\_instance\_tags | Additional tags to apply to the instances. Note 'allow-ssh' and 'allow-vault' will be present on all instances. | list(string) | `<list>` | no |
| vault\_log\_level | Log level to run Vault in. See the Vault documentation for valid values. | string | `"warn"` | no |
| vault\_machine\_type | Machine type to use for Vault instances. | string | `"n1-standard-1"` | no |
| vault\_max\_num\_servers | Maximum number of Vault server nodes to run at one time. The group will not autoscale beyond this number. | string | `"7"` | no |
| vault\_min\_num\_servers | Minimum number of Vault server nodes in the autoscaling group. The group will not have less than this number of nodes. | string | `"1"` | no |
| vault\_port | Numeric port on which to run and expose Vault. | string | `"8200"` | no |
| vault\_proxy\_port | Port to expose Vault's health status endpoint on over HTTP on /. This is required for the health checks to verify Vault's status is using an external load balancer. Only the health status endpoint is exposed, and it is only accessible from Google's load balancer addresses. | string | `"58200"` | no |
| vault\_service\_account\_email | Vault service account email | string | n/a | yes |
| vault\_storage\_bucket | Storage bucket name where the backend is configured. This bucket will not be created in this module | string | n/a | yes |
| vault\_tls\_bucket | GCS Bucket override where Vault will expect TLS certificates are stored. | string | `""` | no |
| vault\_tls\_cert\_filename | GCS object path within the vault_tls_bucket. This is the vault server certificate. | string | `"vault.crt"` | no |
| vault\_tls\_disable\_client\_certs | Use client certificates when provided. You may want to disable this if users will not be authenticating to Vault with client certificates. | string | `"false"` | no |
| vault\_tls\_key\_filename | Encrypted and base64 encoded GCS object path within the vault_tls_bucket. This is the Vault TLS private key. | string | `"vault.key.enc"` | no |
| vault\_tls\_kms\_key | Fully qualified name of the KMS key, for example, vault_tls_kms_key = "projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY_NAME". This key should have been used to encrypt the TLS private key if Terraform is not managing TLS. The Vault service account will be granted access to the KMS Decrypter role once it is created so it can pull from this the `vault_tls_bucket` at boot time. This option is required when `manage_tls` is set to false. | string | `""` | no |
| vault\_tls\_kms\_key\_project | Project ID where the KMS key is stored. By default, same as `project_id` | string | `""` | no |
| vault\_tls\_require\_and\_verify\_client\_cert | Always use client certificates. You may want to disable this if users will not be authenticating to Vault with client certificates. | string | `"false"` | no |
| vault\_ui\_enabled | Controls whether the Vault UI is enabled and accessible. | string | `"true"` | no |
| vault\_version | Version of vault to install. This version must be 1.0+ and must be published on the HashiCorp releases service. | string | `"1.1.3"` | no |

## Outputs

| Name | Description |
|------|-------------|
| ca\_cert\_pem | CA certificate used to verify Vault TLS client connections. |
| ca\_key\_pem | Private key for the CA. |
| vault\_addr | Full protocol, address, and port (FQDN) pointing to the Vault load balancer.This is a drop-in to VAULT_ADDR: `export VAULT_ADDR="$(terraform output vault_addr)"`. And then continue to use Vault commands as usual. |
| vault\_lb\_addr | Address of the load balancer without port or protocol information. You probably want to use `vault_addr`. |
| vault\_lb\_port | Port where Vault is exposed on the load balancer. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
