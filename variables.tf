/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable project_id {
  description = "The project ID to add the IAM bindings for the service account to"
}

variable storage_bucket {
  description = "Name of the GCS bucket for the Vault backend storage"
}

variable network {
  description = "The network to deploy to"
  default     = "default"
}

variable subnetwork {
  description = "The subnetwork to deploy to"
  default     = "default"
}

variable region {
  description = "The region to create the instance in."
}

variable zone {
  description = "The zone to create the instance in."
}

variable machine_type {
  description = "The machine type for the instance"
  default     = "n1-standard-1"
}

variable vault_version {
  description = "The version of vault to install."
  default     = "0.9.0"
}

variable vault_args {
  description = "Additional command line arguments passed to vault server"
  default     = ""
}

variable force_destroy_bucket {
  description = "Set to true to force deletion of backend bucket on terraform destroy"
  default     = false
}

variable kms_keyring_name {
  description = "The name of the Cloud KMS KeyRing for asset encryption"
}

variable kms_key_name {
  description = "The name of the Cloud KMS Key used for asset encryption/decryption"
  default     = "vault-init"
}

variable tls_ca_subject {
  description = "The `subject` block for the root CA certificate."
  type        = "map"

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

variable tls_dns_names {
  description = "List of DNS names added to the Vault server self-signed certificate"
  type        = "list"
  default     = ["vault.example.net"]
}

variable tls_ips {
  description = "List of IP addresses added to the Vault server self-signed certificate"
  type        = "list"
  default     = ["127.0.0.1"]
}

variable tls_cn {
  description = "The TLS Common Name for the TLS certificates"
  default     = "vault.example.net"
}

variable tls_ou {
  description = "The TLS Organizational Unit for the TLS certificate"
  default     = "IT Security Operations"
}
