listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault/vault-server-${environment}.crt.pem"
  tls_key_file = "/etc/vault/vault-server-${environment}.key.pem"
  tls_client_ca_file = "/etc/vault/vault-server-${environment}.ca.crt.pem"
}

storage "gcs" {
  bucket           = "${storage_bucket}"
  credentials_file = "/etc/vault/gcp_credentials.json"
}

ui = true
