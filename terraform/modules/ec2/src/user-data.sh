#!/bin/bash
# Script Name   : user-data.sh
# Description   : EC2 initialisation script
# Creation Date : 2026-02-27
# Version       : 1.1

# --- Initial Setup ---
sudo yum update -y
sudo amazon-linux-extras install epel -y  # required for mosquitto
sudo yum install amazon-cloudwatch-agent docker mosquitto -y

# --- Setup EBS Volume ---
# Create a filesystem on the volume only if one doesn't already exist
if ! blkid /dev/nvme1n1; then
  sudo mkfs -t xfs /dev/nvme1n1
fi
sudo mkdir -p /data
sudo mount /dev/nvme1n1 /data

# Ensure mount survives reboot
grep -q '/dev/nvme1n1' /etc/fstab || \
  echo "/dev/nvme1n1 /data xfs defaults,nofail 0 2" | \
  sudo tee -a /etc/fstab

# --- Create Directory Structure ---
sudo mkdir -p \
  /data/secrets \
  /data/mosquitto/config \
  /data/mosquitto/data \
  /data/mosquitto/log \
  /data/telegraf \
  /data/timescaledb/data \
  /data/timescaledb/init \
  /data/grafana/data \
  /data/grafana/provisioning

# --- Retrieve Secrets from SSM ---
# Wait for IMDS/IAM credentials to be ready
until aws sts get-caller-identity --region ${REGION} > /dev/null 2>&1; do
  echo "Waiting for IMDS..."
  sleep 2
done

get_secret() {
  aws ssm get-parameter \
    --name "$1" \
    --with-decryption \
    --region ${REGION} \
    --query "Parameter.Value" \
    --output text | tr -d '\n'
}

SSM_PREFIX="/${PROJECT_NAME}/${ENVIRONMENT}"

# Write secrets to files for Docker Compose secrets mounts.
# Redirect to /dev/null to prevent values reaching CloudWatch Logs.
get_secret "$SSM_PREFIX/mqtt/telegraf/password"      | sudo tee /data/secrets/mqtt_password_telegraf.txt   > /dev/null
get_secret "$SSM_PREFIX/mqtt/telegraf/username"      | sudo tee /data/secrets/mqtt_username_telegraf.txt   > /dev/null
get_secret "$SSM_PREFIX/timescale/telegraf/password" | sudo tee /data/secrets/db_password_telegraf.txt     > /dev/null
get_secret "$SSM_PREFIX/timescale/telegraf/username" | sudo tee /data/secrets/db_username_telegraf.txt     > /dev/null
get_secret "$SSM_PREFIX/timescale/grafana/password"  | sudo tee /data/secrets/db_password_grafana.txt      > /dev/null
get_secret "$SSM_PREFIX/timescale/grafana/username"  | sudo tee /data/secrets/db_username_grafana.txt      > /dev/null
get_secret "$SSM_PREFIX/timescale/postgres/password" | sudo tee /data/secrets/db_password_postgres.txt     > /dev/null
get_secret "$SSM_PREFIX/grafana/admin/password"      | sudo tee /data/secrets/grafana_admin_password.txt   > /dev/null
get_secret "$SSM_PREFIX/grafana/admin/username"      | sudo tee /data/secrets/grafana_admin_username.txt   > /dev/null

# Write the Tailscale auth key to .env so docker-compose can inject it
# into the Tailscale container as TS_AUTHKEY.
TAILNET_KEY=$(get_secret "$SSM_PREFIX/tailscale/tailnet_key")
echo "TAILNET_KEY=$TAILNET_KEY" | sudo tee /data/.env > /dev/null
sudo chmod 600 /data/.env
unset TAILNET_KEY

# --- Generate Mosquitto Password File ---
MQTT_SENSOR_USER=$(get_secret "$SSM_PREFIX/mqtt/sensor/username")
MQTT_SENSOR_PASS=$(get_secret "$SSM_PREFIX/mqtt/sensor/password")
MQTT_TELEGRAF_USER=$(get_secret "$SSM_PREFIX/mqtt/telegraf/username")
MQTT_TELEGRAF_PASS=$(get_secret "$SSM_PREFIX/mqtt/telegraf/password")

sudo touch /data/mosquitto/config/pwfile
sudo mosquitto_passwd -c -b /data/mosquitto/config/pwfile "$MQTT_SENSOR_USER" "$MQTT_SENSOR_PASS"
sudo mosquitto_passwd -b    /data/mosquitto/config/pwfile "$MQTT_TELEGRAF_USER" "$MQTT_TELEGRAF_PASS"
sudo chown 1883:1883 /data/mosquitto/config/pwfile
sudo chmod 0700 /data/mosquitto/config/pwfile

unset MQTT_SENSOR_USER MQTT_SENSOR_PASS MQTT_TELEGRAF_USER MQTT_TELEGRAF_PASS

# --- Retrieve Config Files from S3 ---
aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/mosquitto.conf \
  /data/mosquitto/config/mosquitto.conf --region ${REGION}

aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/telegraf.conf \
  /data/telegraf/telegraf.conf --region ${REGION}

aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/docker-compose.yml \
  /data/docker-compose.yml --region ${REGION}

aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/timescale-config.sh \
  /data/timescaledb/init/timescale-config.sh --region ${REGION}

# --- Setup CloudWatch Logs Agent ---
aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/cloudwatch-agent-config.json \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json --region ${REGION}
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# --- Configure Permissions ---
sudo chown -R 472:472 /data/grafana/data
sudo chown -R 472:472 /data/grafana/provisioning

# --- Setup Docker ---
sudo service docker start
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# --- Install Docker Compose ---
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose

# --- Run docker-compose ---
# .env in /data supplies TAILNET_KEY for the Tailscale container
cd /data && docker-compose up -d