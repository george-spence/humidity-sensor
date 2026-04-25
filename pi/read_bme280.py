import board
import time
import json
import argparse
import os
import logging
from typing import TypedDict, Required, NotRequired, Optional

from dotenv import load_dotenv
from adafruit_bme280 import basic as BME280
import paho.mqtt.publish as publish


# --- Setup Logging ---
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logger.propagate = False  # avoid duplicate logs


# --- Types ---
class AuthParameter(TypedDict, total=False):
    username: Required[str]
    password: NotRequired[str]


class SensorReading(TypedDict):
    ts: float
    temperature: float
    humidity: float


# --- Declare Functions ---
def configure_logging(debug: bool, log_file: str = "warnings.log") -> None:
    """
    Configure logging so that:
    - warnings and above always go to a file
    - stdout logging only happens when debug=True
    """
    # Clear any existing handlers (if configure_logging is called more than once)
    logger.handlers.clear()

    fmt = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    # File handler: WARNING and above only
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.WARNING)
    file_handler.setFormatter(fmt)
    logger.addHandler(file_handler)

    # Stdout handler: only when debug=True
    if debug:
        stream_handler = logging.StreamHandler()
        stream_handler.setLevel(logging.INFO)
        stream_handler.setFormatter(fmt)
        logger.addHandler(stream_handler)


def print_reading(bme280: BME280.Adafruit_BME280_I2C) -> None:
    """Print current BME280 sensor readings for debugging."""
    logger.info("Temperature: %0.1f C", bme280.temperature)
    logger.info("Humidity: %0.1f %%", bme280.relative_humidity)
    logger.info("Pressure: %0.1f hPa", bme280.pressure)
    logger.info("Altitude: %0.2f meters", bme280.altitude)


def get_sensor_reading(bme280: BME280.Adafruit_BME280_I2C) -> SensorReading:
    """
    Get current sensor readings.

    Args:
        bme280: BME280 sensor instance

    Returns:
        Dictionary containing timestamp, temperature, and humidity
    """
    return {
        "ts": time.time() * 1000,  # unix time in ms
        "temperature": bme280.temperature,
        "humidity": bme280.relative_humidity,
    }


def publish_single_reading(
    bme280: BME280.Adafruit_BME280_I2C,
    auth: AuthParameter,
    hostname: str = "localhost",
    port: int = 1883,
    topic: str = "sensors/indoor",
    qos: int = 1,
) -> None:
    """
    Publish a single MQTT message with sensor readings.

    Args:
        bme280: BME280 sensor instance
        auth: Authentication parameters containing username and password
        hostname: MQTT broker address
        port: MQTT broker port
        topic: MQTT topic to publish to

    Raises:
        RuntimeError: If MQTT publish fails
    """
    try:
        reading = get_sensor_reading(bme280)
        payload = json.dumps(reading)

        publish.single(
            topic=topic, payload=payload, port=port, hostname=hostname, auth=auth, qos=qos,
        )
        logger.info("Published to %s: %s", topic, payload)
    except Exception as e:
        logger.error("Failed to publish reading: %s", e)
        raise RuntimeError(f"MQTT publish failed: {e}") from e


def publish_readings(
    auth: AuthParameter,
    bme280: BME280.Adafruit_BME280_I2C,
    hostname: str = "localhost",
    port: int = 1883,
    freq: int = 1,
    topic: str = "sensors/indoor",
    max_iterations: Optional[int] = None,
    debug: bool = False,
    log_file: str = "warnings.log",
) -> None:
    """
    Continuously publish MQTT messages with sensor readings.

    auth: Authentication parameters
        bme280: BME280 sensor instance
        hostname: MQTT broker address
        port: MQTT broker port
        freq: Number of messages to publish per minute (1-60)
        topic: MQTT topic to publish to
        max_iterations: Maximum number of readings to publish (None for infinite)
        debug: log to stdout
        log_file: filename for logger warnings

    Raises:
        ValueError: If freq is invalid
    """
    configure_logging(debug=debug, log_file=log_file)

    if freq < 1 or freq > 60:
        raise ValueError("Frequency must be between 1 and 60 messages per minute")

    sleep_interval = 60 / freq
    iteration = 0
    qos = 1

    logger.info("Starting to publish readings every %.1f seconds", sleep_interval)

    try:
        while max_iterations is None or iteration < max_iterations:
            try:
                if debug:
                    print_reading(bme280)
                publish_single_reading(bme280, auth, hostname, port, topic, qos)
            except RuntimeError as e:
                logger.error("Error in iteration %d: %s", iteration, e)
                # continue despite errors

            iteration += 1
            time.sleep(sleep_interval)
    except KeyboardInterrupt:
        logger.info("Shutting down gracefully...")


def load_auth_from_env() -> AuthParameter:
    """
    Load MQTT authentication from environment variables.

    Returns:
        Authentication parameters dictionary

    Raises:
        ValueError: If required environment variables are missing
    """
    load_dotenv()
    mqtt_user = os.getenv("MQTT_USER")
    mqtt_password = os.getenv("MQTT_PASSWORD")

    if not mqtt_user or not mqtt_password:
        raise ValueError(
            "MQTT authentication parameters not defined in '.env'. "
            "Both 'MQTT_USER' and 'MQTT_PASSWORD' must be defined."
        )

    return {"username": mqtt_user, "password": mqtt_password}


def init_sensor() -> BME280.Adafruit_BME280_I2C:
    """
    Initialize BME280 sensor.

    Returns:
        Initialized BME280 sensor instance

    Raises:
        RuntimeError: If sensor initialization fails
    """
    try:
        i2c = board.I2C()
        bme280 = BME280.Adafruit_BME280_I2C(i2c)
        bme280.sea_level_pressure = 1013.25
        logger.info("BME280 sensor initialized successfully")
        return bme280
    except Exception as e:
        logger.error("Failed to initialize sensor: %s", e)
        raise RuntimeError(f"Sensor initialization failed: {e}") from e


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Publish BME280 sensor readings to MQTT broker"
    )
    parser.add_argument("--freq", type=int, default=1)
    parser.add_argument("--hostname", type=str, default="localhost")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--topic", type=str, default="sensors/indoor")
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable stdout logging (INFO+) and extra sensor reading prints",
    )
    parser.add_argument(
        "--log-file",
        type=str,
        default="warnings.log",
        help="File path for WARNING+ logs (default: warnings.log)",
    )
    return parser.parse_args()


def main() -> None:
    """Main entry point."""
    args = parse_args()

    try:
        auth_params = load_auth_from_env()
        bme280 = init_sensor()

        publish_readings(
            bme280=bme280,
            hostname=args.hostname,
            freq=args.freq,
            auth=auth_params,
            port=args.port,
            topic=args.topic,
            debug=args.debug,
            log_file=args.log_file,
        )
    except (ValueError, RuntimeError) as e:
        logger.error("Failed to start: %s", e)
        raise


if __name__ == "__main__":
    main()
