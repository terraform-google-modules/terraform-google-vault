# Vault on GCE Terraform Module

Modular deployment of Vault on Google Compute Engine.

This module is versioned and released on the Terraform module registry. Look for
the tag that corresponds to your version for the correct documentation.

- **Vault HA** - Vault is configured to run in high availability mode with
  Google Cloud Storage. Choose a `vault_min_num_servers` greater than 0 to
  enable HA mode.

- **Production hardened** - Vault is deployed according to applicable parts of
  the [production hardening guide][vault-production-hardening].

    - Traffic is encrypted with end-to-end TLS using self-signed certificates
      which can be generated or supplied (see `Managing TLS` below).

    - Vault is the main process on the VMs, and Vault runs as an unprivileged
      user `(vault:vault)` on the VMs under systemd.

    - Outgoing Vault traffic happens through a restricted NAT gateway through
      dedicated IPs for logging and monitoring. You can further restrict
      outbound access with additional firewall rules.

    - The Vault nodes are not publicly accessible. They _do_ have SSH enabled,
      but require a bastion host on their dedicated network to access. You can
      disable SSH access entirely by setting `ssh_allowed_cidrs` to the empty
      list.

    - Swap is disabled (the default on all GCE VMs), reducing the risk that
      in-memory data will be paged to disk.

    - Core dumps are disabled.

    The following values do not represent Vault's best practices and you may
    wish to change their defaults:

    - Vault is publicly accessible from any IP through the load balancer. To
      limit the list of source IPs that can communicate with Vault nodes, set
      `vault_allowed_cidrs` to a list of CIDR blocks.

    - Auditing is not enabled by default, because an initial bootstrap requires
      you to initialize the Vault. Everything is pre-configured for when you're
      ready to enable audit logging, but it cannot be enabled before Vault is
      initialized.

  - **Auto-unseal** - Vault is automatically unsealed using the built-in Vault
    1.0+ auto-unsealing mechanisms for Google Cloud KMS. The Vault servers are
    **not** automatically initialized, providing a clear separation.

  - **Isolation** - The Vault nodes are not exposed publicly. They live in a
    private subnet with a dedicated NAT gateway.

  - **Audit logging** - The system is setup to accept Vault audit logs with a
    single configuration command. Vault audit logs are not enabled by default
    because you have to initialize the system first.


## Usage

1. Add the module definition to your Terraform configurations:

    ```hcl
    module "vault" {
      source         = "terraform-google-modules/vault/google"
      project_id     = var.project_id
      region         = var.region
      kms_keyring    = var.kms_keyring
      kms_crypto_key = var.kms_crypto_key
    }
    ```

    Make sure you are using version pinning to avoid unexpected changes when the
    module is updated.

1. Execute Terraform:

    ```
    $ terraform apply
    ```

1. Configure your local Vault binary to communicate with the Vault server:

    ```
    $ export VAULT_ADDR="$(terraform output vault_addr)"
    $ export VAULT_CACERT="$(pwd)/ca.crt"
    ```

1. Wait for Vault to start. Here's a script or you can wait ~2 minutes.

    ```
    (while [[ $count -lt 60 && "$(vault status 2>&1)" =~ "connection refused" ]]; do ((count=count+1)) ; echo "$(date) $count: Waiting for Vault to start..." ; sleep 2; done && [[ $count -lt 60 ]])
    [[ $? -ne 0 ]] && echo "ERROR: Error waiting for Vault to start" && exit 1
    ```

1. Initialize the Vault cluster, generating the initial root token and unseal
keys:

    ```
    $ vault operator init \
        -recovery-shares 5 \
        -recovery-threshold 3
    ```

    The Vault servers will automatically unseal using the Google Cloud KMS key
    created earlier. The recovery shares are to be given to operators to unseal
    the Vault nodes in case Cloud KMS is unavailable in a disaster recovery.
    They can also be used to generate a new root token. Distribute these keys to
    trusted people on your team (like people who will be on-call and responsible
    for maintaining Vault).

    The output will look like this:

    ```
    Recovery Key 1: 2EWrT/YVlYE54EwvKaH3JzOGmq8AVJJkVFQDni8MYC+T
    Recovery Key 2: 6WCNGKN+dU43APJuGEVvIG6bAHA6tsth5ZR8/bJWi60/
    Recovery Key 3: XC1vSb/GfH35zTK4UkAR7okJWaRjnGrP75aQX0xByKfV
    Recovery Key 4: ZSvu2hWWmd4ECEIHj/FShxxCw7Wd2KbkLRsDm30f2tu3
    Recovery Key 5: T4VBvwRv0pkQLeTC/98JJ+Rj/Zn75bLfmAaFLDQihL9Y

    Initial Root Token: s.kn11NdBhLig2VJ0botgrwq9u
    ```

    **Save this initial root token and do not clear your history. You will need
    this token to continue the tutorial.**

## Managing TLS

If, like many orgs, you manage your own self-signed TLS certificates, you likely will not want them managed by Terraform. Additionally this poses a security risk since the private keys will be stored in plaintext in the `terraform.tfstate` file. To use your own certificates, set `manage_tls = false`. Then before you apply this module, you'll need to have your certificates prepared. An example instantiaion would look like this:

```
module "vault" {
  source  = "terraform-google-modules/vault/google"
  ...

  # Manage our own TLS Certs so the private keys don't
  # end up in Terraform state
  manage_tls        = false
  vault_tls_bucket  = google_storage_bucket.vault_tls.name
  vault_tls_kms_key = google_kms_crypto_key.vault_tls.self_link

  # These are the default values shown here for clarity
  vault_ca_cert_filename  = "ca.crt"
  vault_tls_cert_filename = "vault.crt"
  vault_tls_key_filename  = "vault.key.enc"
}

```

To store your keys, you’ll need to create at minimum the 3 files that are shown above at the root of the TLS bucket specified by `vault_tls_bucket`, but their filenames and paths can be overridden using the `vault_*_filename` variables shown above.

* **CA Certificate.** This file should be the PEM formatted CA certificate that the Vault server certificate is created from
* **Vault Server Certificate.** This file should correspond to the Vault Private Key also stored on the Vault hosts to terminate the TLS connection.
* **Vault Private Key.** As you’ll notice, this key has the .enc file extension denoting it is encrypted. When the Vault host spins up, it will fetch all these certificates and the key and on the key it will use the specified TLS KMS Key to Base64 decode and then decrypt the private key before storing it on the filesystem.

Assuming you have these files locally that have been generated by OpenSSL or some other CA, you can store them with the following commands:


```
gcloud kms encrypt \
  --project=${PROJECT} \
  --key=${KMS_KEY} \
  --plaintext-file=vault.key \
  --ciphertext-file=- | base64 > "vault.key.enc"

for file in vault.key.enc ca.crt vault.crt; do
  gsutil cp $file gs://$TLS_BUCKET/$file
done
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allow\_public\_egress | Whether to create a NAT for external egress. If false, you must also specify an `http_proxy` to download required executables including Vault, Fluentd and Stackdriver | `bool` | `true` | no |
| allow\_ssh | Allow external access to ssh port 22 on the Vault VMs. It is a best practice to set this to false, however it is true by default for the sake of backwards compatibility. | `bool` | `true` | no |
| domain | The domain name that will be set in the api\_addr. Load Balancer IP used by default | `string` | `""` | no |
| http\_proxy | HTTP proxy for downloading agents and vault executable on startup. Only necessary if allow\_public\_egress is false. This is only used on the first startup of the Vault cluster and will NOT set the global HTTP\_PROXY environment variable. i.e. If you configure Vault to manage credentials for other services, default HTTP routes will be taken. | `string` | `""` | no |
| kms\_crypto\_key | The name of the Cloud KMS Key used for encrypting initial TLS certificates and for configuring Vault auto-unseal. Terraform will create this key. | `string` | `"vault-init"` | no |
| kms\_keyring | Name of the Cloud KMS KeyRing for asset encryption. Terraform will create this keyring. | `string` | `"vault"` | no |
| kms\_protection\_level | The protection level to use for the KMS crypto key. | `string` | `"software"` | no |
| load\_balancing\_scheme | Options are INTERNAL or EXTERNAL. If `EXTERNAL`, the forwarding rule will be of type EXTERNAL and a public IP will be created. If `INTERNAL` the type will be INTERNAL and a random RFC 1918 private IP will be assigned | `string` | `"EXTERNAL"` | no |
| manage\_tls | Set to `false` if you'd like to manage and upload your own TLS files. See `Managing TLS` for more details | `bool` | `true` | no |
| network | The self link of the VPC network for Vault. By default, one will be created for you. | `string` | `""` | no |
| network\_subnet\_cidr\_range | CIDR block range for the subnet. | `string` | `"10.127.0.0/20"` | no |
| project\_id | ID of the project in which to create resources and add IAM bindings. | `string` | n/a | yes |
| project\_services | List of services to enable on the project where Vault will run. These services are required in order for this Vault setup to function. | `list(string)` | <pre>[<br>  "cloudkms.googleapis.com",<br>  "cloudresourcemanager.googleapis.com",<br>  "compute.googleapis.com",<br>  "iam.googleapis.com",<br>  "logging.googleapis.com",<br>  "monitoring.googleapis.com"<br>]</pre> | no |
| region | Region in which to create resources. | `string` | `"us-east4"` | no |
| service\_account\_name | Name of the Vault service account. | `string` | `"vault-admin"` | no |
| service\_account\_project\_additional\_iam\_roles | List of custom IAM roles to add to the project. | `list(string)` | `[]` | no |
| service\_account\_project\_iam\_roles | List of IAM roles for the Vault admin service account to function. If you need to add additional roles, update `service_account_project_additional_iam_roles` instead. | `list(string)` | <pre>[<br>  "roles/logging.logWriter",<br>  "roles/monitoring.metricWriter",<br>  "roles/monitoring.viewer"<br>]</pre> | no |
| service\_account\_storage\_bucket\_iam\_roles | List of IAM roles for the Vault admin service account to have on the storage bucket. | `list(string)` | <pre>[<br>  "roles/storage.legacyBucketReader",<br>  "roles/storage.objectAdmin"<br>]</pre> | no |
| service\_label | The service label to set on the internal load balancer. If not empty, this enables internal DNS for internal load balancers. By default, the service label is disabled. This has no effect on external load balancers. | `string` | `null` | no |
| ssh\_allowed\_cidrs | List of CIDR blocks to allow access to SSH into nodes. | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| storage\_bucket\_class | Type of data storage to use. If you change this value, you will also need to choose a storage\_bucket\_location which matches this parameter type | `string` | `"MULTI_REGIONAL"` | no |
| storage\_bucket\_enable\_versioning | Set to true to enable object versioning in the GCS bucket.. You may want to define lifecycle rules if you want a finite number of old versions. | `string` | `false` | no |
| storage\_bucket\_force\_destroy | Set to true to force deletion of backend bucket on `terraform destroy` | `string` | `false` | no |
| storage\_bucket\_lifecycle\_rules | Vault storage lifecycle rules | <pre>list(object({<br>    action = map(object({<br>      type          = string,<br>      storage_class = string<br>    })),<br>    condition = map(object({<br>      age                   = number,<br>      created_before        = string,<br>      with_state            = string,<br>      is_live               = string,<br>      matches_storage_class = string,<br>      num_newer_versions    = number<br>    }))<br>  }))</pre> | `[]` | no |
| storage\_bucket\_location | Location for the Google Cloud Storage bucket in which Vault data will be stored. | `string` | `"us"` | no |
| storage\_bucket\_name | Name of the Google Cloud Storage bucket for the Vault backend storage. This must be globally unique across of of GCP. If left as the empty string, this will default to: '<project-id>-vault-data'. | `string` | `""` | no |
| subnet | The self link of the VPC subnetwork for Vault. By default, one will be created for you. | `string` | `""` | no |
| tls\_ca\_subject | The `subject` block for the root CA certificate. | <pre>object({<br>    common_name         = string,<br>    organization        = string,<br>    organizational_unit = string,<br>    street_address      = list(string),<br>    locality            = string,<br>    province            = string,<br>    country             = string,<br>    postal_code         = string,<br>  })</pre> | <pre>{<br>  "common_name": "Example Inc. Root",<br>  "country": "US",<br>  "locality": "The Intranet",<br>  "organization": "Example, Inc",<br>  "organizational_unit": "Department of Certificate Authority",<br>  "postal_code": "95559-1227",<br>  "province": "CA",<br>  "street_address": [<br>    "123 Example Street"<br>  ]<br>}</pre> | no |
| tls\_cn | The TLS Common Name for the TLS certificates | `string` | `"vault.example.net"` | no |
| tls\_dns\_names | List of DNS names added to the Vault server self-signed certificate | `list(string)` | <pre>[<br>  "vault.example.net"<br>]</pre> | no |
| tls\_ips | List of IP addresses added to the Vault server self-signed certificate | `list(string)` | <pre>[<br>  "127.0.0.1"<br>]</pre> | no |
| tls\_ou | The TLS Organizational Unit for the TLS certificate | `string` | `"IT Security Operations"` | no |
| tls\_save\_ca\_to\_disk | Save the CA public certificate on the local filesystem. The CA is always stored in GCS, but this option also saves it to the filesystem. | `bool` | `true` | no |
| user\_startup\_script | Additional user-provided code injected after Vault is setup | `string` | `""` | no |
| vault\_allowed\_cidrs | List of CIDR blocks to allow access to the Vault nodes. Since the load balancer is a pass-through load balancer, this must also include all IPs from which you will access Vault. The default is unrestricted (any IP address can access Vault). It is recommended that you reduce this to a smaller list. | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| vault\_args | Additional command line arguments passed to Vault server | `string` | `""` | no |
| vault\_ca\_cert\_filename | GCS object path within the vault\_tls\_bucket. This is the root CA certificate. | `string` | `"ca.crt"` | no |
| vault\_instance\_base\_image | Base operating system image in which to install Vault. This must be a Debian-based system at the moment due to how the metadata startup script runs. | `string` | `"debian-cloud/debian-10"` | no |
| vault\_instance\_labels | Labels to apply to the Vault instances. | `map(string)` | `{}` | no |
| vault\_instance\_metadata | Additional metadata to add to the Vault instances. | `map(string)` | `{}` | no |
| vault\_instance\_tags | Additional tags to apply to the instances. Note 'allow-ssh' and 'allow-vault' will be present on all instances. | `list(string)` | `[]` | no |
| vault\_log\_level | Log level to run Vault in. See the Vault documentation for valid values. | `string` | `"warn"` | no |
| vault\_machine\_type | Machine type to use for Vault instances. | `string` | `"e2-standard-2"` | no |
| vault\_max\_num\_servers | Maximum number of Vault server nodes to run at one time. The group will not autoscale beyond this number. | `string` | `"7"` | no |
| vault\_min\_num\_servers | Minimum number of Vault server nodes in the autoscaling group. The group will not have less than this number of nodes. | `string` | `"1"` | no |
| vault\_port | Numeric port on which to run and expose Vault. | `string` | `"8200"` | no |
| vault\_proxy\_port | Port to expose Vault's health status endpoint on over HTTP on /. This is required for the health checks to verify Vault's status is using an external load balancer. Only the health status endpoint is exposed, and it is only accessible from Google's load balancer addresses. | `string` | `"58200"` | no |
| vault\_tls\_bucket | GCS Bucket override where Vault will expect TLS certificates are stored. | `string` | `""` | no |
| vault\_tls\_cert\_filename | GCS object path within the vault\_tls\_bucket. This is the vault server certificate. | `string` | `"vault.crt"` | no |
| vault\_tls\_disable\_client\_certs | Use client certificates when provided. You may want to disable this if users will not be authenticating to Vault with client certificates. | `string` | `false` | no |
| vault\_tls\_key\_filename | Encrypted and base64 encoded GCS object path within the vault\_tls\_bucket. This is the Vault TLS private key. | `string` | `"vault.key.enc"` | no |
| vault\_tls\_kms\_key | Fully qualified name of the KMS key, for example, vault\_tls\_kms\_key = "projects/PROJECT\_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY\_NAME". This key should have been used to encrypt the TLS private key if Terraform is not managing TLS. The Vault service account will be granted access to the KMS Decrypter role once it is created so it can pull from this the `vault_tls_bucket` at boot time. This option is required when `manage_tls` is set to false. | `string` | `""` | no |
| vault\_tls\_kms\_key\_project | Project ID where the KMS key is stored. By default, same as `project_id` | `string` | `""` | no |
| vault\_tls\_require\_and\_verify\_client\_cert | Always use client certificates. You may want to disable this if users will not be authenticating to Vault with client certificates. | `string` | `false` | no |
| vault\_ui\_enabled | Controls whether the Vault UI is enabled and accessible. | `string` | `true` | no |
| vault\_update\_policy\_type | Options are OPPORTUNISTIC or PROACTIVE. If `PROACTIVE`, the instance group manager proactively executes actions in order to bring instances to their target versions | `string` | `"OPPORTUNISTIC"` | no |
| vault\_version | Version of vault to install. This version must be 1.0+ and must be published on the HashiCorp releases service. | `string` | `"1.6.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| ca\_cert\_pem | CA certificate used to verify Vault TLS client connections. |
| ca\_key\_pem | Private key for the CA. |
| service\_account\_email | Email for the vault-admin service account. |
| vault\_addr | Full protocol, address, and port (FQDN) pointing to the Vault load balancer.This is a drop-in to VAULT\_ADDR: `export VAULT_ADDR="$(terraform output vault_addr)"`. And then continue to use Vault commands as usual. |
| vault\_lb\_addr | Address of the load balancer without port or protocol information. You probably want to use `vault_addr`. |
| vault\_lb\_port | Port where Vault is exposed on the load balancer. |
| vault\_nat\_ips | The NAT-ips that the vault nodes will use to communicate with external services. |
| vault\_network | The network in which the Vault cluster resides |
| vault\_storage\_bucket | GCS Bucket Vault is using as a backend/database |
| vault\_subnet | The subnetwork in which the Vault cluster resides |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Additional permissions

The default installation includes the most minimal set of permissions to run
Vault. Certain plugins may require more permissions, which you can grant to the
service account using `service_account_project_additional_iam_roles`:

### GCP auth method

The GCP auth method requires the following additional permissions:

```
roles/iam.serviceAccountKeyAdmin
```

### GCP secrets engine

The GCP secrets engine requires the following additional permissions:

```
roles/iam.serviceAccountKeyAdmin
roles/iam.serviceAccountAdmin
```

### GCP KMS secrets engine

The GCP secrets engine permissions vary. There are examples in the secrets
engine documentation.


## Logs

The Vault server logs will automatically appear in Stackdriver under "GCE VM
Instance" tagged as "vaultproject.io/server".

The Vault audit logs, once enabled, will appear in Stackdriver under "GCE VM
Instance" tagged as "vaultproject.io/audit".


## Sandboxes & Terraform Cloud

When running in a sandbox such as Terraform Cloud, you need to disable
filesystem access. You can do this by setting the following variables:

```terraform
# terraform.tfvars
tls_save_ca_to_disk = false
```


## FAQ

- **I see unhealthy Vault nodes in my load balancer pool!**

    This is the expected behavior. Only the _active_ Vault node is added to the
    load balancer to [prevent redirect loops][vault-redirect-loop]. If that node
    loses leadership, its health check will start failing and a standby node
    will take its place in the load balancer.

- **Can I connect to the Vault nodes directly?**

    Connecting to the vault nodes directly is not recommended, even if on the
    same network. Always connect through the load balancer. You can alter the
    load balancer to be an internal-only load balancer if needed.

[vault-redirect-loop]: https://www.vaultproject.io/docs/concepts/ha.html#behind-load-balancers
[vault-production-hardening]: https://www.vaultproject.io/guides/operations/production.html
[registry-inputs]: https://registry.terraform.io/modules/terraform-google-modules/vault/google?tab=inputs
[registry-outputs]: https://registry.terraform.io/modules/terraform-google-modules/vault/google?tab=outputs
[registry-resources]: https://registry.terraform.io/modules/terraform-google-modules/vault/google?tab=resources
