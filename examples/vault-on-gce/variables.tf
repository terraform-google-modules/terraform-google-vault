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
  type        = string
  description = "Project ID in which to deploy"
}

variable "region" {
  type        = string
  default     = "us-east4"
  description = "Region in which to deploy"
}

variable "kms_keyring" {
  type        = string
  default     = "vault"
  description = "Name of the GCP KMS keyring"
}

variable "kms_crypto_key" {
  type        = string
  default     = "vault-init"
  description = "Name of the GCP KMS crypto key"
}

variable "load_balancing_scheme" {
  type        = string
  default     = "EXTERNAL"
  description = "e.g. [INTERNAL|EXTERNAL]. Scheme of the load balancer"
}

variable "allow_public_egress" {
  type        = bool
  default     = true
  description = "Whether to create a NAT for external egress. If false, you must also specify an http_proxy to download required executables including Vault, Fluentd and Stackdriver"
}


