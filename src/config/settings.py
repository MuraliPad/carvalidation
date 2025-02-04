from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
DRIVER_PATH = BASE_DIR/'src'/'drivers'/'chromedriver'
INPUT_PATH = BASE_DIR / 'testdata' / 'car_input.txt'
OUTPUT_PATH = BASE_DIR / 'testdata' / 'car_output.txt'
VALUATION_URL = 'https://motorway.co.uk'