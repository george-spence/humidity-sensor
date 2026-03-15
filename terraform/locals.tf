locals {
  # --- SSM Parameter Store - Secrets ---
  secrets = {
    "mqtt/sensor/username" = {
      value       = var.mqtt_sensor_username
      description = "Sensor username for MQTT Mosquitto"
    }
    "mqtt/sensor/password" = {
      value       = var.mqtt_sensor_password
      description = "Sensor password for MQTT Mosquitto"
    }
    "mqtt/telegraf/username" = {
      value       = var.mqtt_telegraf_username
      description = "Telegraf username for MQTT Mosquitto"
    }
    "mqtt/telegraf/password" = {
      value       = var.mqtt_telegraf_password
      description = "Telegraf password for MQTT Mosquitto"
    }
    "timescale/telegraf/username" = {
      value       = var.timescaledb_telegraf_username
      description = "Telegraf username for TimescaleDB"
    }
    "timescale/telegraf/password" = {
      value       = var.timescaledb_telegraf_password
      description = "Telegraf password for TimescaleDB"
    }
    "timescale/grafana/username" = {
      value       = var.timescaledb_grafana_username
      description = "Grafana username for TimescaleDB"
    }
    "timescale/grafana/password" = {
      value       = var.timescaledb_grafana_password
      description = "Grafana password for TimescaleDB"
    }
    "timescale/postgres/password" = {
      value       = var.timescaledb_postgres_password
      description = "Admin password for TimescaleDB"
    }
    "grafana/admin/username" = {
      value       = var.grafana_admin_username
      description = "Grafana admin username"
    }
    "grafana/admin/password" = {
      value       = var.grafana_admin_password
      description = "Grafana admin password"
    }
    "tailscale/auth_key" = {
      value       = var.tailscale_auth_key
      description = "Tailscale ephemeral auth key"
    }
  }

  # --- S3 Objects ---
  upload_directory = "${path.cwd}/config/"
}
