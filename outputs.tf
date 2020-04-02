#
# Copyright 2017 Google Inc.
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

output "ca_cert_pem" {
  value     = tls_self_signed_cert.root.*.cert_pem
  sensitive = true

  description = <<EOF
CA certificate used to verify Vault TLS client connections.
EOF

}

output "ca_key_pem" {
  value     = tls_private_key.root.*.private_key_pem
  sensitive = true

  description = <<EOF
Private key for the CA.
EOF

}

output "service_account_email" {
  value = google_service_account.vault-admin.email

  description = <<EOF
Email for the vault-admin service account.
EOF

}

output "vault_addr" {
  value = "https://${local.lb_ip}:${var.vault_port}"

  description = <<EOF
Full protocol, address, and port (FQDN) pointing to the Vault load balancer.
This is a drop-in to VAULT_ADDR:

    export VAULT_ADDR="$(terraform output vault_addr)"

And then continue to use Vault commands as usual.
EOF

}

output "vault_lb_addr" {
  value = local.lb_ip

  description = <<EOF
Address of the load balancer without port or protocol information. You probably
want to use `vault_addr`.
EOF

}

output "vault_lb_port" {
  value = var.vault_port

  description = <<EOF
Port where Vault is exposed on the load balancer.
EOF

}

output "vault_storage_bucket" {
  value = google_storage_bucket.vault.name

  description = <<EOF
GCS Bucket Vault is using as a backend/database
EOF

}

output "vault_network" {
  value       = local.network
  description = "The network in which the Vault cluster resides"
}

output "vault_subnet" {
  value       = local.subnet
  description = "The subnetwork in which the Vault cluster resides"
}

output "vault_nat_ips" {
  value       = google_compute_address.vault-nat.*.address
  description = "The NAT-ips that the vault nodes will use to communicate with external services."
}