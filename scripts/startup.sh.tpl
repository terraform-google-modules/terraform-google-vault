#!/bin/bash -xe

apt-get update
apt-get install -y unzip jq

# Download and install Vault
cd /tmp && \
  curl -sLO https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip && \
  unzip vault_${vault_version}_linux_amd64.zip && \
  mv vault /usr/local/bin/vault && \
  rm vault_${vault_version}_linux_amd64.zip

# Vault config
mkdir -p /etc/vault
cat - > /etc/vault/config.hcl <<'EOF'
${config}
EOF
chmod 0600 /etc/vault/config.hcl

# Service account key JSON credentials
gcloud iam service-accounts keys create /etc/vault/gcp_credentials.json \
  --iam-account ${service_account_email}
chmod 0600 /etc/vault/gcp_credentials.json

# Service environment
cat - > /etc/vault/vault.env <<EOF
VAULT_ARGS=${vault_args}
EOF
chmod 0600 /etc/vault/vault.env

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
