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

variable "project_id" {
  type = string

  description = "ID of the project in which to create resources and add IAM bindings."
}

variable "host_project_id" {
  type    = string
  default = ""

  description = "ID of the host project if using Shared VPC"
}

variable "region" {
  type    = string
  default = "us-east4"

  description = "Region in which to create resources."
}

variable "subnet" {
  type        = string
  description = "The self link of the VPC subnetwork for Vault. By default, one will be created for you."
}

variable "ip_address" {
  type        = string
  description = "The IP address to assign the forwarding rules to."
}

variable "vault_storage_bucket" {
  type        = string
  description = "Storage bucket name where the backend is configured. This bucket will not be created in this module"
}

variable "vault_service_account_email" {
  type        = string
  description = "Vault service account email"
}

variable "service_account_project_iam_roles" {
  type = list(string)

  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ]

  description = "List of IAM roles for the Vault admin service account to function. If you need to add additional roles, update `service_account_project_additional_iam_roles` instead."
}

variable "service_account_project_additional_iam_roles" {
  type    = list(string)
  default = []

  description = "List of custom IAM roles to add to the project."
}

variable "service_account_storage_bucket_iam_roles" {
  type = list(string)

  default = [
    "roles/storage.legacyBucketReader",
    "roles/storage.objectAdmin",
  ]

  description = "List of IAM roles for the Vault admin service account to have on the storage bucket."
}

#
#
# KMS
# --------------------

variable "kms_keyring" {
  type    = string
  default = "vault"

  description = "Name of the Cloud KMS KeyRing for asset encryption. Terraform will create this keyring."

}

variable "kms_crypto_key" {
  type    = string
  default = "vault-init"

  description = "The name of the Cloud KMS Key used for encrypting initial TLS certificates and for configuring Vault auto-unseal. Terraform will create this key."
}

variable "kms_protection_level" {
  type    = string
  default = "software"

  description = "The protection level to use for the KMS crypto key."
}


#TODO: Evaluate https://www.terraform.io/docs/configuration/variables.html#custom-validation-rules when prod ready
variable "load_balancing_scheme" {
  type    = string
  default = "EXTERNAL"

  description = "Options are INTERNAL or EXTERNAL. If `EXTERNAL`, the forwarding rule will be of type EXTERNAL and a public IP will be created. If `INTERNAL` the type will be INTERNAL and a random RFC 1918 private IP will be assigned"
}

variable "vault_args" {
  type    = string
  default = ""

  description = "Additional command line arguments passed to Vault server"
}

variable "vault_instance_labels" {
  type    = map(string)
  default = {}

  description = "Labels to apply to the Vault instances."
}

variable "vault_ca_cert_filename" {
  type    = string
  default = "ca.crt"

  description = "GCS object path within the vault_tls_bucket. This is the root CA certificate."
}

variable "vault_instance_metadata" {
  type    = map(string)
  default = {}

  description = "Additional metadata to add to the Vault instances."
}

variable "vault_instance_base_image" {
  type    = string
  default = "debian-cloud/debian-9"

  description = "Base operating system image in which to install Vault. This must be a Debian-based system at the moment due to how the metadata startup script runs."
}

variable "vault_instance_tags" {
  type    = list(string)
  default = []

  description = "Additional tags to apply to the instances. Note 'allow-ssh' and 'allow-vault' will be present on all instances."
}

variable "vault_log_level" {
  type    = string
  default = "warn"

  description = "Log level to run Vault in. See the Vault documentation for valid values."
}

variable "vault_min_num_servers" {
  type    = string
  default = "1"

  description = "Minimum number of Vault server nodes in the autoscaling group. The group will not have less than this number of nodes."
}

variable "vault_machine_type" {
  type    = string
  default = "n1-standard-1"

  description = "Machine type to use for Vault instances."

}

variable "vault_max_num_servers" {
  type    = string
  default = "7"

  description = "Maximum number of Vault server nodes to run at one time. The group will not autoscale beyond this number."
}

variable "vault_port" {
  type    = string
  default = "8200"

  description = "Numeric port on which to run and expose Vault."
}

variable "vault_proxy_port" {
  type    = string
  default = "58200"

  description = "Port to expose Vault's health status endpoint on over HTTP on /. This is required for the health checks to verify Vault's status is using an external load balancer. Only the health status endpoint is exposed, and it is only accessible from Google's load balancer addresses."
}

variable "vault_tls_disable_client_certs" {
  type    = string
  default = false

  description = "Use client certificates when provided. You may want to disable this if users will not be authenticating to Vault with client certificates."
}

variable "vault_tls_require_and_verify_client_cert" {
  type    = string
  default = false

  description = "Always use client certificates. You may want to disable this if users will not be authenticating to Vault with client certificates."
}

variable "vault_tls_bucket" {
  type    = string
  default = ""

  description = "GCS Bucket override where Vault will expect TLS certificates are stored."
}

variable "vault_tls_kms_key" {
  type    = string
  default = ""

  description = "Fully qualified name of the KMS key, for example, vault_tls_kms_key = \"projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY_NAME\". This key should have been used to encrypt the TLS private key if Terraform is not managing TLS. The Vault service account will be granted access to the KMS Decrypter role once it is created so it can pull from this the `vault_tls_bucket` at boot time. This option is required when `manage_tls` is set to false."
}

variable "vault_tls_kms_key_project" {
  type    = string
  default = ""

  description = "Project ID where the KMS key is stored. By default, same as `project_id`"
}

variable "vault_tls_cert_filename" {
  type    = string
  default = "vault.crt"

  description = "GCS object path within the vault_tls_bucket. This is the vault server certificate."

}

variable "vault_tls_key_filename" {
  type    = string
  default = "vault.key.enc"

  description = "Encrypted and base64 encoded GCS object path within the vault_tls_bucket. This is the Vault TLS private key."
}

variable "vault_ui_enabled" {
  type    = string
  default = true

  description = "Controls whether the Vault UI is enabled and accessible."
}

variable "vault_version" {
  type    = string
  default = "1.1.3"

  description = "Version of vault to install. This version must be 1.0+ and must be published on the HashiCorp releases service."

}

variable "http_proxy" {
  type    = string
  default = ""

  description = "HTTP proxy for downloading agents and vault executable on startup. Only necessary if allow_public_egress is false. This is only used on the first startup of the Vault cluster and will NOT set the global HTTP_PROXY environment variable. i.e. If you configure Vault to manage credentials for other services, default HTTP routes will be taken."
}

variable "user_startup_script" {
  type    = string
  default = ""

  description = "Additional user-provided code injected after Vault is setup"
}

#
#
# TLS
# --------------------

variable "manage_tls" {
  type    = bool
  default = true

  description = "Set to `false` if you'd like to manage and upload your own TLS files. See `Managing TLS` for more details"

}

variable "tls_ca_subject" {
  description = "The `subject` block for the root CA certificate."
  type = object({
    common_name         = string,
    organization        = string,
    organizational_unit = string,
    street_address      = list(string),
    locality            = string,
    province            = string,
    country             = string,
    postal_code         = string,
  })

  default = {
    common_name         = "Example Inc. Root"
    organization        = "Example, Inc"
    organizational_unit = "Department of Certificate Authority"
    street_address      = ["123 Example Street"]
    locality            = "The Intranet"
    province            = "CA"
    country             = "US"
    postal_code         = "95559-1227"
  }
}

variable "tls_cn" {
  description = "The TLS Common Name for the TLS certificates"
  default     = "vault.example.net"
}

variable "domain" {
  description = "The domain name that will be set in the api_addr. Load Balancer IP used by default"
  type        = string
  default     = ""
}
variable "tls_dns_names" {
  description = "List of DNS names added to the Vault server self-signed certificate"
  type        = list(string)
  default     = ["vault.example.net"]
}

variable "tls_ips" {
  description = "List of IP addresses added to the Vault server self-signed certificate"
  type        = list(string)
  default     = ["127.0.0.1"]
}

variable "tls_save_ca_to_disk" {
  type    = bool
  default = true

  description = "Save the CA public certificate on the local filesystem. The CA is always stored in GCS, but this option also saves it to the filesystem."
}

variable "tls_ou" {
  description = "The TLS Organizational Unit for the TLS certificate"
  default     = "IT Security Operations"
}
