# Vault on GCE Terraform Module

Modular deployment of Vault on Google Compute Engine.

This module is versioned and released on the Terraform module registry. Look for
the tag that corresponds to your version for the correct documentation.

- **Vault HA** - Vault is configured to run in high availability mode with
  Google Cloud Storage. Choose a `vault_min_num_servers` greater than 0 to
  enable HA mode.

- **Production hardened** - Vault is deployed according to applicable parts of
  the [production hardening guide][vault-production-hardening].

    - Traffic is encrypted with end-to-end TLS using self-signed certificates.

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


## Inputs

See the [inputs on the Terraform module registry][registry-inputs]. Be sure to
choose the version that corresponds to the version of the module you are using
locally.


## Outputs

See the [outputs on the Terraform module registry][registry-outputs]. Be sure to
choose the version that corresponds to the version of the module you are using
locally.


## Resources

See the [resources in the Terraform module registry][registry-resources]. Be
sure to choose the version that corresponds to the version of the module you are
using locally.


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


## Local security

- **Encrypted TLS data is stored locally.** This Terraform module generates
  self-signed TLS certificates. The certificates are encrypted with Google Cloud
  KMS and the encrypted text is cached locally on disk in the `kms/` folder.
  Even though the data is encrypted, you should secure this folder (it is
  automatically ignored from source control).


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
    same network. Always connect through the load balance. You can alter the
    load balancer to be an internal-only load balancer if needed.

[vault-redirect-loop]: https://www.vaultproject.io/docs/concepts/ha.html#behind-load-balancers
[vault-production-hardening]: https://www.vaultproject.io/guides/operations/production.html
[registry-inputs]: https://registry.terraform.io/modules/terraform-google-modules/vault/google?tab=inputs
[registry-outputs]: https://registry.terraform.io/modules/terraform-google-modules/vault/google?tab=outputs
[registry-resources]: https://registry.terraform.io/modules/terraform-google-modules/vault/google?tab=resources
