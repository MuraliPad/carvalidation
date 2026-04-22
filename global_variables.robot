*** Settings ***
Documentation    Global configuration variables for MiO-X test suite.
...
...              ── QUICK START ─────────────────────────────────────────
...              Default (System PATH, Chrome):
...                robot tests\
...
...              Explicit driver path:
...                robot --variable CHROMEDRIVER_PATH:C:/drivers/chromedriver.exe tests\
...                robot --variable BROWSER:edge --variable EDGEDRIVER_PATH:C:/drivers/msedgedriver.exe tests\
...
...              Auto-download driver:
...                robot --variable USE_WEBDRIVER_MANAGER:True tests\
...
...              Remote Grid:
...                robot --variable USE_REMOTE:True --variable REMOTE_URL:http://grid:4444/wd/hub tests\

*** Variables ***
# ── Environment ────────────────────────────────────────────────────────────────
${ENV}                      dev
${BASE_URL}                 
${BROWSER}                  chrome

# ── Driver Paths ───────────────────────────────────────────────────────────────
# Leave as ${EMPTY} to use System PATH (Option 3 – simplest).
# Set a path to use explicit driver (Option 1 – corp/locked machines).
# Windows path examples (use forward slashes):
#   ${CHROMEDRIVER_PATH}     C:/WebDrivers/chromedriver.exe
#   ${EDGEDRIVER_PATH}       C:/WebDrivers/msedgedriver.exe
#   ${FIREFOXDRIVER_PATH}    C:/WebDrivers/geckodriver.exe
${CHROMEDRIVER_PATH}        ${EMPTY}
${EDGEDRIVER_PATH}          ${EMPTY}
${FIREFOXDRIVER_PATH}       ${EMPTY}

# ── Auto-download Driver ───────────────────────────────────────────────────────
# Set True to have webdriver-manager download the correct driver automatically.
# Requires: pip install webdriver-manager
# Requires internet access on the test machine.
${USE_WEBDRIVER_MANAGER}    ${FALSE}

# ── Selenium Grid ──────────────────────────────────────────────────────────────
${USE_REMOTE}               ${FALSE}
${REMOTE_URL}               http://localhost:4444/wd/hub

# ── Timeouts ───────────────────────────────────────────────────────────────────
${IMPLICIT_WAIT}            10s
${EXPLICIT_WAIT}            15s
${PAGE_LOAD_TIMEOUT}        30s
${ANIMATION_WAIT}           0.5s

# ── Viewport ───────────────────────────────────────────────────────────────────
${WINDOW_WIDTH}             1920
${WINDOW_HEIGHT}            1080

# ── Screenshot directory ───────────────────────────────────────────────────────
${SCREENSHOT_DIR}           ${CURDIR}/../results/screenshots

# ── Test Data ──────────────────────────────────────────────────────────────────
${TEST_USERNAME}            ${EMPTY}
${TEST_PASSWORD}            ${EMPTY}

# ── API Layer ──────────────────────────────────────────────────────────────────
${API_BASE_URL}             
${API_TOKEN}                ${EMPTY}
${API_TIMEOUT}              30s
${API_CONNECT_TIMEOUT}      10s

# ── Integrity Check ────────────────────────────────────────────────────────────
${COUNT_TOLERANCE}          0
