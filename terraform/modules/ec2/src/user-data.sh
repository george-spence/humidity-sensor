#!/bin/bash
# Script Name   : user-data.sh
# Description   : EC2 initialisation script
# Creation Date : 2026-02-27
# Version       : 1.0

# --- Initial Setup ---
sudo yum update -y
sudo amazon-linux-extras install epel -y  # required for mosquitto
sudo yum install amazon-cloudwatch-agent docker mosquitto -y

# --- Setup EBS Volume ---
# EBS - create a filesystem on the volume only if one doesn't already exist
if ! blkid /dev/nvme1n1; then
  sudo mkfs -t xfs /dev/nvme1n1
fi
sudo mkdir /data
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

# --- Permissions ---
sudo chown -R ec2-user:ec2-user /data
sudo chmod 700 /data/secrets
sudo chmod -R 755 /data/mosquitto
sudo chmod -R 755 /data/telegraf
sudo chmod -R 755 /data/timescaledb
sudo chmod 755 /data/grafana/data
sudo chmod 755 /data/grafana/provisioning
# Grafana runs as uid 472
sudo chown -R 472:472 /data/grafana/data
sudo chown -R 472:472 /data/grafana/provisioning

# --- Retrieve Secrets from SSM ---
# Wait for IMDS to be ready
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
    --output text
}

# Write secrets to files for Docker
# Pipe to /dev/null to prevent secrets going to stout (and then into CloudWatch Logs)
get_secret "/humidity-sensor/prod/mqtt/telegraf/password"   | sudo tee /data/secrets/mqtt_password_telegraf.txt > /dev/null
get_secret "/humidity-sensor/prod/mqtt/telegraf/username"   | sudo tee /data/secrets/mqtt_username_telegraf.txt > /dev/null
get_secret "/humidity-sensor/prod/timescale/telegraf/password" | sudo tee /data/secrets/db_password_telegraf.txt > /dev/null
get_secret "/humidity-sensor/prod/timescale/telegraf/username" | sudo tee /data/secrets/db_username_telegraf.txt > /dev/null
get_secret "/humidity-sensor/prod/timescale/grafana/password"  | sudo tee /data/secrets/db_password_grafana.txt > /dev/null
get_secret "/humidity-sensor/prod/timescale/grafana/username"  | sudo tee /data/secrets/db_username_grafana.txt > /dev/null
get_secret "/humidity-sensor/prod/grafana/admin/password"   | sudo tee /data/secrets/grafana_admin_password.txt > /dev/null
get_secret "/humidity-sensor/prod/grafana/admin/username"   | sudo tee /data/secrets/grafana_admin_username.txt > /dev/null
get_secret "/humidity-sensor/prod/tailscale/auth_key"       | sudo tee /data/secrets/tailscale_auth_key.txt > /dev/null

# Lock down secrets after writing
sudo chown -R root:root /data/secrets  # make ssm-user the owner
sudo chmod 600 /data/secrets/*

# --- Generate Mosquitto Password File ---
# Create pwfile with hashed passwords
MQTT_SENSOR_USER=$(get_secret "/mqtt/sensor/username")
MQTT_SENSOR_PASS=$(get_secret "/mqtt/sensor/password")
MQTT_TELEGRAF_USER=$(get_secret "/mqtt/telegraf/username")
MQTT_TELEGRAF_PASS=$(get_secret "/mqtt/telegraf/password")

# Create empty pwfile and add users
sudo mosquitto_passwd -b -c /data/mosquitto/config/pwfile "$MQTT_SENSOR_USER" "$MQTT_SENSOR_PASS"
sudo mosquitto_passwd -b /data/mosquitto/config/pwfile "$MQTT_TELEGRAF_USER" "$MQTT_TELEGRAF_PASS"

# Lock down the pwfile
sudo chown ssm-user:ssm-user /data/mosquitto/config/pwfile
sudo chmod 600 /data/mosquitto/config/pwfile

# --- Retrieve Config Files from S3 ---
aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/cloudwatch-agent-config.json \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  --region ${REGION}

aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/mosquitto.conf \
  /data/mosquitto/config/mosquitto.conf \
  --region ${REGION}

aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/telegraf.conf \
  /data/telegraf/telegraf.conf \
  --region ${REGION}

aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/docker-compose.yml \
  /data/docker-compose.yml \
  --region ${REGION}

# --- Setup CloudWatch Logs Agent ---
aws s3 cp s3://${S3_CONFIG_BUCKET_NAME}/cloudwatch-agent-config.json \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  --region ${REGION}
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# --- Setup Docker ---
sudo service docker start
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# --- Install Docker Compose ---
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) \
  -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose

# --- Run docker-compose ---
cd /data && docker-compose up -d

# --- Configure Tailscale ---