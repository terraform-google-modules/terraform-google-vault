# HashiCorp Vault on Compute Engine

This example shows how to run a highly-available HashiCorp Vault cluster on
Google Compute Engine.


## Setup environment

1. [Install Terraform][install-terraform] locally or in
[Cloud Shell][cloud-shell].

1. [Install Vault][install-vault] locally or in [Cloud Shell][cloud-shell]. You
only need to install the `vault` binary - you do not need to start a Vault
server locally or configure anything.

1. [Install `gcloud`][install-sdk] for your platform.

1. Authenticate the local SDK:

    ```
    $ gcloud auth login
    ```

1. Create a new project or use an existing project. Save the ID for use

    ```
    $ export GOOGLE_CLOUD_PROJECT="my-project-id"
    ```

1. Enable the Compute Engine API (Terraform will enable other required ones):

    ```
    $ gcloud services enable --project "${GOOGLE_CLOUD_PROJECT}" \
        compute.googleapis.com
    ```

1. Create a `terraform.tfvars` file in the current working directory with your
configuration data:

    ```
    project_id = "..."
    ```

## Deploy Vault

1. Download required providers:

    ```
    $ terraform init
    ```

1. Plan the changes:

    ```
    $ terraform plan
    ```

1. Assuming no errors, apply:

    ```
    $ terraform apply
    ```

After about 5 minutes, you will have a fully-provisioned Vault cluster. Note
that Terraform will return _before_ the instances are finished provisioning.
Vault is installed and configured via a startup script.


## Setup Vault communication

1. Configure your local Vault binary to communicate with the Vault server:

    ```
    $ export VAULT_ADDR="$(terraform output -module=vault vault_addr)"
    $ export VAULT_CACERT="$(pwd)/ca.crt"
    ```

1. Verify Vault is available:

    ```
    $ vault status
    ```

    > If you see an error or "i/o timeout" or "connection refused", the Vault
    servers may not have finished provisioning. Wait a few minutes and try
    again.


## Initialize Vault

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

1. Verify Vault is initialized:

    ```
    $ vault operator init -status
    ```

    The command will exit successfully if Vault is initialized.

1. Verify Vault is unsealed:

    ```
    $ vault status
    ```

    The command will include "Sealed: false".

1. Login with that initial root token:

    ```
    $ vault login
    Token (will be hidden): (paste token here)
    ```


## Configure Stackdriver audit logs

1. Configure Vault to send its audit logs to [Stackdriver][stackdriver]

    ```
    $ vault audit enable file file_path=/var/log/vault/audit.log
    ```

    Audit logs will now appear in Stackdriver for all requests and responses to
    Vault. Note the path `/var/log/vault/audit.log` refers to a path on the
    _Vault node_ itself. This path is not configurable.


## Explore

- [Create GCP service accounts](https://www.vaultproject.io/docs/secrets/gcp/index.html)
- [Use Cloud KMS in Vault](https://www.vaultproject.io/docs/secrets/gcpkms/index.html)
- [Auth to Vault with service accounts](https://www.vaultproject.io/docs/auth/gcp.html)
- [GCS storage backend](https://www.vaultproject.io/docs/configuration/storage/google-cloud-storage.html)
- [Spanner storage backend](https://www.vaultproject.io/docs/configuration/storage/google-cloud-spanner.html)


## Cleaning up

1. Destroy the infrastructure:

    ```
    $ terraform destroy
    ```

    Note: Cloud KMS keys cannot be destroyed. If you destroy and try to
    re-create it, you will need to change the names of the Cloud KMS keys or the
    subsequent `terraform apply` will fail with a "resource already exists"
    error.

1. Unset Vault configuration variables:

    ```
    $ unset VAULT_ADDR VAULT_CACERT
    ```


[cloud-kms]: https://cloud.google.com/kms/
[cloud-shell]: https://cloud.google.com/shell/
[install-sdk]: https://cloud.google.com/sdk/install
[install-vault]: https://learn.hashicorp.com/vault/getting-started/install
[install-terraform]: https://learn.hashicorp.com/terraform/getting-started/install
[stackdriver]: https://cloud.google.com/stackdriver/
