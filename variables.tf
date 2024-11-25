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


#
#
# Project
# --------------------
variable "project_id" {
  type = string

  description = "ID of the project in which to create resources and add IAM bindings."

}

variable "project_services" {
  type = list(string)

  default = [
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]

  description = "List of services to enable on the project where Vault will run. These services are required in order for this Vault setup to function."
}

variable "region" {
  type    = string
  default = "us-east4"

  description = "Region in which to create resources."

}

#
#
# GCS
# --------------------

variable "storage_bucket_name" {
  type    = string
  default = ""

  description = "Name of the Google Cloud Storage bucket for the Vault backend storage. This must be globally unique across of of GCP. If left as the empty string, this will default to: '<project-id>-vault-data'."
}

variable "storage_bucket_location" {
  type    = string
  default = "us"

  description = "Location for the Google Cloud Storage bucket in which Vault data will be stored."

}

variable "storage_bucket_class" {
  type    = string
  default = "MULTI_REGIONAL"

  description = "Type of data storage to use. If you change this value, you will also need to choose a storage_bucket_location which matches this parameter type"
}

variable "storage_bucket_enable_versioning" {
  type    = string
  default = false

  description = "Set to true to enable object versioning in the GCS bucket.. You may want to define lifecycle rules if you want a finite number of old versions."

}

variable "storage_bucket_lifecycle_rules" {
  type = list(object({
    action = map(object({
      type          = string,
      storage_class = string
    })),
    condition = map(object({
      age                   = number,
      created_before        = string,
      with_state            = string,
      is_live               = string,
      matches_storage_class = string,
      num_newer_versions    = number
    }))
  }))

  default = []

  description = "Vault storage lifecycle rules"
}

variable "storage_bucket_force_destroy" {
  type    = string
  default = false

  description = "Set to true to force deletion of backend bucket on `terraform destroy`"
}

#
#
# IAM
# --------------------

variable "service_account_name" {
  type    = string
  default = "vault-admin"

  description = "Name of the Vault service account."

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

#
#
# Networking
# --------------------

variable "host_project_id" {
  type        = string
  default     = ""
  description = "The project id of the shared VPC host project, when deploying into a shared VPC"
}

variable "network" {
  type        = string
  default     = ""
  description = "The self link of the VPC network for Vault. By default, one will be created for you."
}

variable "subnet" {
  type        = string
  default     = ""
  description = "The self link of the VPC subnetwork for Vault. By default, one will be created for you."
}

variable "service_label" {
  type        = string
  description = "The service label to set on the internal load balancer. If not empty, this enables internal DNS for internal load balancers. By default, the service label is disabled. This has no effect on external load balancers."
  default     = null
}

variable "allow_public_egress" {
  type    = bool
  default = true

  description = "Whether to create a NAT for external egress. If false, you must also specify an `http_proxy` to download required executables including Vault, Fluentd and Stackdriver"
}

variable "network_subnet_cidr_range" {
  type    = string
  default = "10.127.0.0/20"

  description = "CIDR block range for the subnet."
}

variable "http_proxy" {
  type    = string
  default = ""

  description = "HTTP proxy for downloading agents and vault executable on startup. Only necessary if allow_public_egress is false. This is only used on the first startup of the Vault cluster and will NOT set the global HTTP_PROXY environment variable. i.e. If you configure Vault to manage credentials for other services, default HTTP routes will be taken."
}

#TODO: Evaluate https://www.terraform.io/docs/configuration/variables.html#custom-validation-rules when prod ready
variable "load_balancing_scheme" {
  type    = string
  default = "EXTERNAL"

  description = "Options are INTERNAL or EXTERNAL. If `EXTERNAL`, the forwarding rule will be of type EXTERNAL and a public IP will be created. If `INTERNAL` the type will be INTERNAL and a random RFC 1918 private IP will be assigned"
}

#
#
# SSH
# --------------------

variable "allow_ssh" {
  type        = bool
  default     = true
  description = "Allow external access to ssh port 22 on the Vault VMs. It is a best practice to set this to false, however it is true by default for the sake of backwards compatibility."
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]

  description = "List of CIDR blocks to allow access to SSH into nodes."

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
  type        = string
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

variable "tls_save_ca_to_disk_filename" {
  type    = string
  default = "ca.crt"

  description = "The filename or full path to save the CA public certificate on the local filesystem. Ony applicable if `tls_save_ca_to_disk` is set to `true`."
}

variable "tls_ou" {
  description = "The TLS Organizational Unit for the TLS certificate"
  type        = string
  default     = "IT Security Operations"
}


#
#
# Vault
# --------------------

variable "vault_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]

  description = "List of CIDR blocks to allow access to the Vault nodes. Since the load balancer is a pass-through load balancer, this must also include all IPs from which you will access Vault. The default is unrestricted (any IP address can access Vault). It is recommended that you reduce this to a smaller list."
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
  default = "debian-cloud/debian-11"

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
  default = "e2-standard-2"

  description = "Machine type to use for Vault instances."

}

variable "vault_max_num_servers" {
  type    = string
  default = "7"

  description = "Maximum number of Vault server nodes to run at one time. The group will not autoscale beyond this number."
}


variable "vault_update_policy_type" {
  type        = string
  default     = "OPPORTUNISTIC"
  description = "Options are OPPORTUNISTIC or PROACTIVE. If `PROACTIVE`, the instance group manager proactively executes actions in order to bring instances to their target versions"
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
  default = "1.6.0"

  description = "Version of vault to install. This version must be 1.0+ and must be published on the HashiCorp releases service."

}

variable "user_startup_script" {
  type    = string
  default = ""

  description = "Additional user-provided code injected after Vault is setup"
}

variable "user_vault_config" {
  type    = string
  default = ""

  description = "Additional user-provided vault config added at the end of standard vault config"
}
