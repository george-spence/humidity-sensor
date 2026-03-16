# humidity-sensor
A small homelab project exploring a near-real-time streaming pipeline for temperature and humidity data collected from a Raspberry Pi with Adafruit BME280 sensor. This project was built as a proof of concept and learning exercise. This README documents the initial local implementation. A cloud-hosted version (AWS + Terraform) is planned as a follow-up iteration.

Desired analytics insights included:
* Explore house temperature and humidity across the course of a day
* Investigate the rate of house cooling once heating was turned off in the evening
* Quick lookup of internal temperature and rate of heating

## Architecture 🔩
<img width="576" height="191" alt="pipeline_schematic drawio" src="https://github.com/user-attachments/assets/1ace2d61-1e2f-4c5d-b250-02559c810812" />

1. **Sensor publisher (Raspberry Pi)**: Python script reads BME280 every _N_ minutes (CLI arg, default 1 minute), publishes to MQTT topic (default `sensors/indoor`)
2. **MQTT broker**: Mosquitto in Docker on an old laptop
3. **Ingestion**: Telegraf subscribes, tags and writes to TimescaleDB
4. **Storage**: TimescaleDB in Docker (persistent volume)
5. **Visualisation**: Grafana in Docker (dashboard screenshop)

## Dashboard Example🖥️
<img width="2214" height="1328" alt="image" src="https://github.com/user-attachments/assets/b2244e91-a5b4-4399-86b3-3a70df0871af" />

## Configuration ⚙️
High-level setup steps:
* Clone the repo onto:
  * the Raspberry Pi (sensor publisher)
  * the host system running Docker (broker, DB, Grafana)
* Configure Mosquitto users, passwords and topic permissions
* Create TimescaleDB tables (expected columns: `time`, `temperature`, `humidity`)
* Configure Telegraf MQTT input and TimescaleDb output
* Create and import Grafana dashboards with desired visualisations

Key configuration options:
* MQTT topic: `sensors/indoor`
* Sampling interval: configurable via Python script CLI argument
* Broker credentials: stored locally and in .env on Pi (no secrets committed)
* Warning logging is stored on the Pi

## Limitations of the Current Design ⚠️
This implementation is intentionally simple and has several known limitations:
* MQTT broker, database and Grafana require a local laptop to remain online
* Grafana is only accessible within the local network
* Logs and metrics are fragmented across the laptop and Raspberry Pi
* No TLS encryption on MQTT as this is a LAN-only setup

## Future Plans 🔮
Planned improvements include:
* Migrating the pipeline to AWS using Terraform
* Eliminating the always-on local laptop dependency
* Private, remote access to Grafana
* Centralised logging and monitoring
* Improved MQTT security (TLS, stronger isolation)
* Tracking and visualising rate of evening temperature drop (with detailed statistics0
* Adding `sensors/outdoor` topic, with an outdoor sensor to allow temperature differential to be calculated. This will require an enclosure and modifications to the Pi.
* Retrieving weather forecasts/ historic data from an open AI to enrich the dashboard
* Improve the documentation in the repository, especially on setup and pre-requisites

# Debugging
## Mosquitto
* Check that the broker and related permissions are functioning correctly
* Setup subscriber:
`mosquitto_sub -h localhost -p 1883 -t 'test/auth' -u 'YOUR_USER' -P 'YOUR_PASS' -v`

* Publish to a test topic:
`docker exec mosquitto mosquitto_pub -h localhost -p 1883 -t 'test/auth' -m 'hello mqtt' -u 'YOUR_USER' -P 'YOUR_PASS'`

## Telegraf
* Ensure correct permissions are available and that no files are locked down
* Ensure there are no newline characters at end of passwords

## TimescaleDB
* Check that table has been created successfully with correct schema
* Ensure that all secrets have been bound and added correctly

## Integration Testing
* Send a test message:
`docker exec mosquitto mosquitto_pub -h localhost -p 1883 -t 'sensors/indoor' -m '{"ts": 1773692061945, "temperature": 25.0, "humidity": 50.0}' -u 'YOUR_USER' -P 'YOUR_PASS'`