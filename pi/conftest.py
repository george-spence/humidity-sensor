import sys
from unittest.mock import MagicMock

# Mock hardware modules before any test imports
sys.modules['board'] = MagicMock()
sys.modules['adafruit_bme280'] = MagicMock()
sys.modules['adafruit_bme280.basic'] = MagicMock()