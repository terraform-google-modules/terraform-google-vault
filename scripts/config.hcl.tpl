listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

storage "gcs" {
  bucket           = "${storage_bucket}"
  credentials_file = "/etc/vault/gcp_credentials.json"
}