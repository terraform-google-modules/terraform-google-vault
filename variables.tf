#
# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
#
# Project
# --------------------
variable "project_id" {
  type = string

  description = <<EOF
ID of the project in which to create resources and add IAM bindings.
EOF

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

  description = <<EOF
List of services to enable on the project where Vault will run. These services
are required in order for this Vault setup to function.

To disable, set to the empty list []. You may want to disable this if the
services have already been enabled and the current user does not have permission
to enable new services.
EOF

}

variable "region" {
  type    = string
  default = "us-east4"

  description = <<EOF
Region in which to create resources.
EOF

}

#
#
# GCS
# --------------------

variable "storage_bucket_name" {
  type    = string
  default = ""

  description = <<EOF
Name of the Google Cloud Storage bucket for the Vault backend storage. This must
be globally unique across of of GCP. If left as the empty string, this will
default to: "<project-id>-vault-data".
EOF

}

variable "storage_bucket_location" {
  type    = string
  default = "us"

  description = <<EOF
Location for the Google Cloud Storage bucket in which Vault data will be stored.
EOF

}

variable "storage_bucket_class" {
  type    = string
  default = "MULTI_REGIONAL"

  description = <<EOF
Type of data storage to use. If you change this value, you will also need to
choose a storage_bucket_location which matches this parameter type.
EOF

}

variable "storage_bucket_enable_versioning" {
  type    = string
  default = false

  description = <<EOF
Set to true to enable object versioning in the GCS bucket.. You may want to
define lifecycle rules if you want a finite number of old versions.
EOF

}

variable "storage_bucket_lifecycle_rules" {
  type = list(object({
    action    = map(any)
    condition = map(any)
  }))

  default = []

  description = <<EOF
If you enable versioning, you may want to expire old versions to configure
a specific retention. Please, check the documentation for the map keys you
should use.

This is specified as a list of objects:

    storage_lifecycle_rules = [
      {
        action = {
          type = "Delete"
        }

        conditions = {
          age     = 60
          is_live = false
        }
      }
    ]
EOF

}

variable "storage_bucket_force_destroy" {
  type    = string
  default = false

  description = <<EOF
Set to true to force deletion of backend bucket on `terraform destroy`.
EOF

}

#
#
# IAM
# --------------------

variable "service_account_name" {
  type    = string
  default = "vault-admin"

  description = <<EOF
Name of the Vault service account.
EOF

}

variable "service_account_project_iam_roles" {
  type = list(string)

  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ]

  description = <<EOF
List of IAM roles for the Vault admin service account to function. If you need
to add additional roles, update `service_account_project_additional_iam_roles`
instead.
EOF

}

variable "service_account_project_additional_iam_roles" {
  type    = list(string)
  default = []

  description = <<EOF
List of custom IAM roles to add to the project.
EOF

}

variable "service_account_storage_bucket_iam_roles" {
  type = list(string)

  default = [
    "roles/storage.legacyBucketReader",
    "roles/storage.objectAdmin",
  ]

  description = <<EOF
List of IAM roles for the Vault admin service account to have on the storage
bucket.
EOF

}

#
#
# KMS
# --------------------

variable "kms_keyring" {
  type    = string
  default = "vault"

  description = <<EOF
Name of the Cloud KMS KeyRing for asset encryption. Terraform will create this
keyring.
EOF

}

variable "kms_crypto_key" {
  type    = string
  default = "vault-init"

  description = <<EOF
The name of the Cloud KMS Key used for encrypting initial TLS certificates and
for configuring Vault auto-unseal. Terraform will create this key.
EOF

}

variable "kms_protection_level" {
  type    = string
  default = "software"

  description = <<EOF
The protection level to use for the KMS crypto key.
EOF

}

#
#
# Networking
# --------------------

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

variable "allow_public_egress" {
  type    = bool
  default = true

  description = <<EOF
Whether to create a NAT for external egress. If false, you must also specify an http_proxy to download required
executables including Vault, Fluentd and Stackdriver
EOF
}

variable "network_subnet_cidr_range" {
  type    = string
  default = "10.127.0.0/20"

  description = <<EOF
CIDR block range for the subnet.
EOF

}

variable "http_proxy" {
  type    = string
  default = ""

  description = <<EOF
HTTP proxy for downloading agents and vault executable on startup. Only necessary if allow_public_egress is false.
This is only used on the first startup of the Vault cluster and will NOT set the global HTTP_PROXY environment variable.
i.e. If you configure Vault to manage credentials for other services, default HTTP routes will be taken.
EOF
}

#TODO: Evaluate https://www.terraform.io/docs/configuration/variables.html#custom-validation-rules when prod ready
variable "load_balancing_scheme" {
  type    = string
  default = "EXTERNAL"

  description = <<EOF
Options are INTERNAL or EXTERNAL.
If "EXTERNAL", the forwarding rule will be of type EXTERNAL and a public IP will be created.
If "INTERNAL", the type will be INTERNAL and a random RFC 1918 private IP will be assigned
EOF
}

#
#
# SSH
# --------------------

variable "allow_ssh" {
  type        = bool
  default     = true
  description = <<EOF
Allow external access to ssh port 22 on the Vault VMs. It is a best practice to set this to false,
however it is true by default for the sake of backwards compatibility.
EOF
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]

  description = <<EOF
List of CIDR blocks to allow access to SSH into nodes.
EOF

}

#
#
# TLS
# --------------------

variable "manage_tls" {
  type    = bool
  default = true

  description = <<EOF
Set to "false" if you'd like to manage and upload your own TLS files, if you do not want this module
to generate them. By default this module expects the following files at the root of the bucket, but these
can be overriden:
- `ca.crt`: Root CA public certificate
- `vault.crt`: Vault server public certificate, signed by the ca.crt
- `vault.key.enc` Vault server certificate private key, encrypted with the kms key provided and base64 encoded.
EOF

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

  description = <<EOF
Save the CA public certificate on the local filesystem. The CA is always stored
in GCS, but this option also saves it to the filesystem.
EOF
}

variable "tls_ou" {
  description = "The TLS Organizational Unit for the TLS certificate"
  default     = "IT Security Operations"
}


#
#
# Vault
# --------------------

variable "vault_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]

  description = <<EOF
List of CIDR blocks to allow access to the Vault nodes. Since the load balancer
is a pass-through load balancer, this must also include all IPs from which you
will access Vault. The default is unrestricted (any IP address can access
Vault). It is recommended that you reduce this to a smaller list.

To disable, set to the empty list []. Even if disabled, internal rules will
still allow the health checker to probe the nodes for health.
EOF

}

variable "vault_args" {
  type    = string
  default = ""

  description = <<EOF
Additional command line arguments passed to Vault server/
EOF

}

variable "vault_instance_labels" {
  type    = map(string)
  default = {}

  description = <<EOF
Labels to apply to the Vault instances.
EOF

}

variable "vault_ca_cert_filename" {
  type    = string
  default = "ca.crt"

  description = <<EOF
GCS object path within the vault_tls_bucket. This is the root CA certificate.
EOF

}

variable "vault_instance_metadata" {
  type    = map(string)
  default = {}

  description = <<EOF
Additional metadata to add to the Vault instances.
EOF

}

variable "vault_instance_base_image" {
  type    = string
  default = "debian-cloud/debian-9"

  description = <<EOF
Base operating system image in which to install Vault. This must be a
Debian-based system at the moment due to how the metadata startup script
runs.
EOF
}

variable "vault_instance_tags" {
  type    = list(string)
  default = []

  description = <<EOF
Additional tags to apply to the instances. Note "allow-ssh" and "allow-vault"
will be present on all instances.
EOF

}

variable "vault_log_level" {
  type    = string
  default = "warn"

  description = <<EOF
Log level to run Vault in. See the Vault documentation for valid values.
EOF

}

variable "vault_min_num_servers" {
  type    = string
  default = "1"

  description = <<EOF
Minimum number of Vault server nodes in the autoscaling group. The group will
not have less than this number of nodes.
EOF

}

variable "vault_machine_type" {
  type    = string
  default = "n1-standard-1"

  description = <<EOF
Machine type to use for Vault instances.
EOF

}

variable "vault_max_num_servers" {
  type    = string
  default = "7"

  description = <<EOF
Maximum number of Vault server nodes to run at one time. The group will not
autoscale beyond this number.
EOF

}

variable "vault_port" {
  type    = string
  default = "8200"

  description = <<EOF
Numeric port on which to run and expose Vault. This should be a high-numbered
port, since Vault does not run as a root user and therefore cannot bind to
privledged ports like 80 or 443. The default is 8200, the standard Vault port.
EOF

}

variable "vault_proxy_port" {
  type    = string
  default = "58200"

  description = <<EOF
Port to expose Vault's health status endpoint on over HTTP on /. This is
required for the health checks to verify Vault's status. Only the health status
endpoint is exposed, and it is only accessible from Google's load balancer
addresses.
EOF

}

variable "vault_tls_disable_client_certs" {
  type    = string
  default = false

  description = <<EOF
Use client certificates when provided. You may want to disable this if users will
not be authenticating to Vault with client certificates.
EOF

}

variable "vault_tls_require_and_verify_client_cert" {
  type    = string
  default = false

  description = <<EOF
Always use client certificates. You may want to disable this if users will
not be authenticating to Vault with client certificates.
EOF

}

variable "vault_tls_bucket" {
  type    = string
  default = ""

  description = <<EOF
GCS Bucket override where Vault will expect TLS certificates are stored.
EOF

}

variable "vault_tls_kms_key" {
  type    = string
  default = ""

  description = <<EOF
Fully qualified name of the KMS key, for example,
vault_tls_kms_key = "projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY_NAME"
This key should have been used to encrypt the TLS private key if Terraform is
not managing TLS. The Vault service account will be granted access to the KMS Decrypter
role once it is created so it can pull from this the `vault_tls_bucket` at boot time. This
option is required when `manage_tls` is set to false.
EOF
}

variable "vault_tls_kms_key_project" {
  type    = string
  default = ""

  description = <<EOF
Project ID where the KMS key is stored. By default, same as `project_id`
EOF
}

variable "vault_tls_cert_filename" {
  type    = string
  default = "vault.crt"

  description = <<EOF
GCS object path within the vault_tls_bucket. This is the vault server certificate.
EOF

}

variable "vault_tls_key_filename" {
  type    = string
  default = "vault.key.enc"

  description = <<EOF
Encrypted and base64 encoded GCS object path within the vault_tls_bucket. This is the Vault TLS private key.
EOF

}

variable "vault_ui_enabled" {
  type    = string
  default = true

  description = <<EOF
Controls whether the Vault UI is enabled and accessible.
EOF

}

variable "vault_version" {
  type    = string
  default = "1.1.3"

  description = <<EOF
Version of vault to install. This version must be 1.0+ and must be published on
the HashiCorp releases service.
EOF

}

variable "user_startup_script" {
  type = string
  default = ""

  description = <<EOF
Additional user-provided code injected after Vault is setup
EOF
}
