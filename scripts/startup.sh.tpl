#!/bin/bash -xe

apt-get update
apt-get install -y unzip jq netcat nginx

# Download and install Vault
cd /tmp && \
  curl -sLO https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip && \
  unzip vault_${vault_version}_linux_amd64.zip && \
  mv vault /usr/local/bin/vault && \
  rm vault_${vault_version}_linux_amd64.zip

# Install Stackdriver for logging
curl -sSL https://dl.google.com/cloudagents/install-logging-agent.sh | bash

# Vault config
mkdir -p /etc/vault
cat - > /etc/vault/config.hcl <<'EOF'
${config}
EOF
chmod 0600 /etc/vault/config.hcl

# Service account key JSON credentials encrypted in GCS.
if [[ ! -f /etc/vault/gcp_credentials.json ]]; then
  gcloud kms decrypt \
    --location global \
    --keyring=${kms_keyring_name} \
    --key=${kms_key_name} \
    --plaintext-file /etc/vault/gcp_credentials.json \
    --ciphertext-file=<(gsutil cat gs://${assets_bucket}/${vault_sa_key} | base64 -d)
  chmod 0600 /etc/vault/gcp_credentials.json
fi

# Service environment
cat - > /etc/vault/vault.env <<EOF
VAULT_ARGS=${vault_args}
EOF
chmod 0600 /etc/vault/vault.env

# TLS key and certs
for tls_file in ${vault_ca_cert} ${vault_tls_key} ${vault_tls_cert}; do
  gcloud kms decrypt \
    --location global \
    --keyring=${kms_keyring_name} \
    --key=${kms_key_name} \
    --plaintext-file /etc/vault/$${tls_file//.encrypted.base64/} \
    --ciphertext-file=<(gsutil cat gs://${assets_bucket}/$${tls_file} | base64 -d)
  chmod 0600 /etc/vault/$${tls_file//.encrypted.base64/}
done

# Systemd service
cat - > /etc/systemd/system/vault.service <<'EOF'
[Service]
EnvironmentFile=/etc/vault/vault.env
ExecStart=
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl $${VAULT_ARGS}
EOF
chmod 0600 /etc/systemd/system/vault.service

systemctl daemon-reload
systemctl enable vault
systemctl start vault

# Setup vault env
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/etc/vault/vault-server.ca.crt.pem
export VAULT_CLIENT_CERT=/etc/vault/vault-server.crt.pem
export VAULT_CLIENT_KEY=/etc/vault/vault-server.key.pem

# Add health-check proxy, GCE doesn't support https health checks.
cat - > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    location / {
        proxy_pass $${VAULT_ADDR}/v1/sys/health?standbyok=true&sealedcode=200;
    }
}
EOF
systemctl enable nginx
systemctl restart nginx

# Wait 30s for Vault to start
(while [[ $count -lt 15 && "$(vault status 2>&1)" =~ "connection refused" ]]; do ((count=count+1)) ; echo "$(date) $count: Waiting for Vault to start..." ; sleep 2; done && [[ $count -lt 15 ]])
[[ $? -ne 0 ]] && echo "ERROR: Error waiting for Vault to start" && exit 1

# Initialize Vault, save encrypted unseal and root keys to Cloud Storage bucket.
if [[ $(vault status) =~ "Sealed: true" ]]; then
  echo "Vault already initialized"
else
  vault init > /tmp/vault_unseal_keys.txt

  gcloud kms encrypt \
    --location=global  \
    --keyring=${kms_keyring_name} \
    --key=${kms_key_name} \
    --plaintext-file=/tmp/vault_unseal_keys.txt \
    --ciphertext-file=/tmp/vault_unseal_keys.txt.encrypted

  gsutil cp /tmp/vault_unseal_keys.txt.encrypted gs://${assets_bucket}
  rm -f /tmp/vault_unseal_keys.txt*
fi

# TODO use variables here
echo "export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/etc/vault/vault-server.ca.crt.pem
export VAULT_CLIENT_CERT=/etc/vault/vault-server.crt.pem
export VAULT_CLIENT_KEY=/etc/vault/vault-server.key.pem" >> /root/.bashrc



# Todo add an IF statement to make monitring install optional
# Installing StatsD Monitroing for Vault
(cd /tmp/ && curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh && bash install-monitoring-agent.sh)
(cd /opt/stackdriver/collectd/etc/collectd.d/ && sudo curl -O https://raw.githubusercontent.com/Stackdriver/stackdriver-agent-service-configs/master/etc/collectd.d/statsd.conf)
service stackdriver-agent restart
