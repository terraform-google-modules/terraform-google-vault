# Run Vault in HA mode. Even if there's only one Vault node, it doesn't hurt to
# have this set.
api_addr = "${api_addr}"
cluster_addr = "https://LOCAL_IP:8201"

# Set debugging level
log_level = "${vault_log_level}"

# Enable the UI
ui = ${vault_ui_enabled == "true" ? true : false}

# Enable plugin directory
plugin_directory = "/etc/vault.d/plugins"

# Enable auto-unsealing with Google Cloud KMS
seal "gcpckms" {
  project    = "${kms_project}"
  region     = "${kms_location}"
  key_ring   = "${kms_keyring}"
  crypto_key = "${kms_crypto_key}"
}

# Enable HA backend storage with GCS
storage "gcs" {
  bucket     = "${storage_bucket}"
  ha_enabled = "true"
}

# Create local non-TLS listener
listener "tcp" {
  address     = "127.0.0.1:${vault_port}"
  tls_disable = 1
}

# Create an mTLS listener on the load balancer
listener "tcp" {
  address            = "${lb_ip}:${vault_port}"
  tls_cert_file      = "/etc/vault.d/tls/vault.crt"
  tls_key_file       = "/etc/vault.d/tls/vault.key"
  tls_client_ca_file = "/etc/vault.d/tls/ca.crt"

  tls_disable_client_certs           = "${vault_tls_disable_client_certs}"
  tls_require_and_verify_client_cert = "${vault_tls_require_and_verify_client_cert}"
}

# Create an mTLS listener locally. Client's shouldn't talk to Vault directly,
# but not all clients are well-behaved. This is also needed so the nodes can
# communicate with eachother.
listener "tcp" {
  address            = "LOCAL_IP:${vault_port}"
  tls_cert_file      = "/etc/vault.d/tls/vault.crt"
  tls_key_file       = "/etc/vault.d/tls/vault.key"
  tls_client_ca_file = "/etc/vault.d/tls/ca.crt"

  tls_disable_client_certs           = "${vault_tls_disable_client_certs}"
  tls_require_and_verify_client_cert = "${vault_tls_require_and_verify_client_cert}"
}

# Send data to statsd (Stackdriver monitoring)
telemetry {
  statsd_address   = "127.0.0.1:8125"
  disable_hostname = true
}
