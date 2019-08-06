#! /usr/bin/env bash
set -xe
set -o pipefail

# Only run the script once
if [ -f ~/.startup-script-complete ]; then
  echo "Startup script already ran, exiting"
  exit 0
fi

# Data
LOCAL_IP="$(curl -sf -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)"

# Allow users to specify an HTTP proxy for egress instead of a NAT
if [ ! -z '${custom_http_proxy}' ]; then
  export http_proxy=${custom_http_proxy}
  export https_proxy=$http_proxy
fi

# Deps
export DEBIAN_FRONTEND=noninteractive
apt-get update -yqq
apt-get upgrade -yqq
apt-get install -yqq jq libcap2-bin logrotate nginx unzip

# Install Stackdriver for logging and monitoring
curl -sSfL https://dl.google.com/cloudagents/install-logging-agent.sh | bash
curl -sSfL https://dl.google.com/cloudagents/install-monitoring-agent.sh | bash

# Download and install Vault
cd /tmp && \
  curl -sLfO "https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip" && \
  unzip "vault_${vault_version}_linux_amd64.zip" && \
  mv vault /usr/local/bin/vault && \
  rm "vault_${vault_version}_linux_amd64.zip"

# Give Vault the ability to run mlock as non-root
/sbin/setcap cap_ipc_lock=+ep /usr/local/bin/vault

# Add Vault user
useradd -d /etc/vault.d -s /bin/false vault

# Vault config
mkdir -p /etc/vault.d
cat <<"EOF" > /etc/vault.d/config.hcl
${config}
EOF
chmod 0600 /etc/vault.d/config.hcl

# Sub in local IP
# $$ is correct here because we are in terraform template
sed -i "s/LOCAL_IP/$${LOCAL_IP}/g" /etc/vault.d/config.hcl

# Service environment
cat <<"EOF" > /etc/vault.d/vault.env
VAULT_ARGS=${vault_args}
EOF
chmod 0600 /etc/vault.d/vault.env

# Download TLS files from GCS
mkdir -p /etc/vault.d/tls
gsutil cp "gs://${vault_tls_bucket}/${vault_ca_cert_filename}" /etc/vault.d/tls/ca.crt
gsutil cp "gs://${vault_tls_bucket}/${vault_tls_cert_filename}" /etc/vault.d/tls/vault.crt
gsutil cp "gs://${vault_tls_bucket}/${vault_tls_key_filename}" /etc/vault.d/tls/vault.key.enc

# Decrypt the Vault private key
base64 --decode < /etc/vault.d/tls/vault.key.enc | gcloud kms decrypt \
  --project="${kms_project}" \
  --location="${kms_location}" \
  --keyring="${kms_keyring}" \
  --key="${kms_crypto_key}" \
  --plaintext-file=/etc/vault.d/tls/vault.key \
  --ciphertext-file=-

# Make sure Vault owns everything
chmod 700 /etc/vault.d/tls
chmod 600 /etc/vault.d/tls/vault.key
chown -R vault:vault /etc/vault.d
rm /etc/vault.d/tls/vault.key.enc

# Make audit files
mkdir -p /var/log/vault
touch /var/log/vault/{audit,server}.log
chmod 0640 /var/log/vault/{audit,server}.log
chown -R vault:adm /var/log/vault

# Systemd service
cat <<"EOF" > /etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/config.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
StandardError=syslog
StandardOutput=syslog
SyslogIdentifier=vault
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
EnvironmentFile=/etc/vault.d/vault.env
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/config.hcl $VAULT_ARGS
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/systemd/system/vault.service
systemctl daemon-reload
systemctl enable vault

# Prevent core dumps - from all attack vectors
cat <<"EOF" > /etc/sysctl.d/50-coredump.conf
kernel.core_pattern=|/bin/false
EOF
sysctl -p /etc/sysctl.d/50-coredump.conf

cat <<"EOF" > /etc/security/limits.conf
* hard core 0
EOF

mkdir -p /etc/systemd/coredump.conf.d
cat <<"EOF" > /etc/systemd/coredump.conf.d/disable.conf
[Coredump]
Storage=none
EOF

cat <<"EOF" >> /etc/sysctl.conf
fs.suid_dumpable = 0
EOF
sysctl -p

cat <<"EOF" > /etc/profile.d/ulimit.sh
ulimit -S -c 0 > /dev/null  2>&1
EOF
source /etc/profile.d/ulimit.sh

# Reload any systemd changes for core dumps
systemctl daemon-reload

# Setup vault env
cat <<"EOF" > /etc/profile.d/vault.sh
export VAULT_ADDR="http://127.0.0.1:${vault_port}"

# Ignore history from any Vault commands
export HISTIGNORE="&:vault*"
EOF
chmod 644 /etc/profile.d/vault.sh
source /etc/profile.d/vault.sh

# Add health-check proxy because target pools don't support HTTPS
cat <<EOF > /etc/nginx/sites-available/default
server {
  listen ${vault_proxy_port};
  location / {
    proxy_pass $VAULT_ADDR/v1/sys/health?uninitcode=200;
  }
}
EOF
systemctl enable nginx
systemctl restart nginx

# Pull Vault data from syslog into a file for fluentd
cat <<"EOF" > /etc/rsyslog.d/vault.conf
#
# Extract Vault logs from syslog
#

# Only include the message (Vault has its own timestamps and data)
template(name="OnlyMsg" type="string" string="%msg:2:$:drop-last-lf%\n")

if ( $programname == "vault" ) then {
  action(type="omfile" file="/var/log/vault/server.log" template="OnlyMsg")
  stop
}
EOF
systemctl restart rsyslog

# Start Stackdriver logging agent and setup the filesystem to be ready to
# receive audit logs
cat <<"EOF" > /etc/google-fluentd/config.d/vaultproject.io.conf
<source>
  @type tail
  format json

  time_type "string"
  time_format "%Y-%m-%dT%H:%M:%S.%N%z"
  keep_time_key true

  path /var/log/vault/audit.log
  pos_file /var/lib/google-fluentd/pos/vault.audit.pos
  read_from_head true
  tag vaultproject.io/audit
</source>

<filter vaultproject.io/audit>
  @type record_transformer
  enable_ruby true
  <record>
    message "$${record.dig('request', 'id') || '-'} $${record.dig('request', 'remote_address') || '-'} $${record.dig('auth', 'display_name') || '-'} $${record.dig('request', 'operation') || '-'} $${record.dig('request', 'path') || '-'}"
    host "#{Socket.gethostname}"
  </record>
</filter>

<source>
  @type tail
  format /^(?<time>[^ ]+) \[(?<severity>[^ ]+)\][ ]+(?<source>[^:]+): (?<message>.*)/

  time_type "string"
  time_format "%Y-%m-%dT%H:%M:%S.%N%z"
  keep_time_key true

  path /var/log/vault/server.log
  pos_file /var/lib/google-fluentd/pos/vault.server.pos
  read_from_head true
  tag vaultproject.io/server
</source>

<filter vaultproject.io/server>
  @type record_transformer
  enable_ruby true
  <record>
    message "$${record['source']}: $${record['message']}"
    severity "$${(record['severity'] || '').downcase}"
    host "#{Socket.gethostname}"
  </record>
</filter>
EOF
systemctl enable google-fluentd
systemctl restart google-fluentd

# Configure logrotate for Vault audit logs
cat <<"EOF" > /etc/logrotate.d/vaultproject.io
/var/log/vault/*.log {
  daily
  rotate 3
  missingok
  compress
  notifempty
  create 0640 vault adm
  sharedscripts
  postrotate
    test -s run/rsyslogd.pid && kill -HUP $(cat /run/rsyslogd.pid)
    true
  endscript
}
EOF

# Start Stackdriver monitoring
curl -sSfLo /opt/stackdriver/collectd/etc/collectd.d/statsd.conf https://raw.githubusercontent.com/Stackdriver/stackdriver-agent-service-configs/master/etc/collectd.d/statsd.conf
systemctl enable stackdriver-agent
systemctl restart stackdriver-agent

# Signal this script has run
touch ~/.startup-script-complete

# Reboot to pick up system-level changes
sudo reboot
