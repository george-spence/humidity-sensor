#!/bin/bash
set -e

# Create users
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" <<-EOSQL
    CREATE USER telegraf WITH PASSWORD '$(cat /run/secrets/db_password_telegraf)';
    CREATE USER grafana WITH PASSWORD '$(cat /run/secrets/db_password_grafana)';
EOSQL

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS timescaledb;

    CREATE TABLE sensor_readings (
        time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
        temperature DOUBLE PRECISION,
        humidity DOUBLE PRECISION
    );

    SELECT create_hypertable('sensor_readings', 'time');

    GRANT CONNECT ON DATABASE sensors_db TO telegraf;
    GRANT USAGE ON SCHEMA public TO telegraf;
    GRANT INSERT ON sensor_readings TO telegraf;

    GRANT CONNECT ON DATABASE sensors_db TO grafana;
    GRANT USAGE ON SCHEMA public TO grafana;
    GRANT INSERT ON sensor_readings TO grafana;
EOSQL