*** Settings ***
Documentation    Environment configuration resource.
...
...              Resolves BASE_URL and API_BASE_URL from a single ENV variable.
...              All environment URLs are defined here in one place.
...
...              ── USAGE ────────────────────────────────────────────────
...
...              Call as Test Setup or Suite Setup:
...                Test Setup     Resolve Environment URLs
...                Suite Setup    Resolve Environment URLs
...
...              Override ENV at the command line:
...                robot --variable ENV:dev   tests\    ← default
...                robot --variable ENV:sit   tests\
...                robot --variable ENV:uat   tests\
...                robot --variable ENV:prod  tests\
...
...              Or combine with other variables:
...                robot --variable ENV:uat
...                      --variable BROWSER:edge
...                      --variable CHROMEDRIVER_PATH:C:/drivers/chromedriver.exe
...                      tests\
...
...              ── ENVIRONMENT MAP ──────────────────────────────────────
...
...                ENV   UI (BASE_URL)                           API (API_BASE_URL)
...                dev   miox-dev.ikp1001rnp.cloud.uk.hsbc      miox-backend-dev.ikp1001rnp.cloud.uk.hsbc
...                sit   miox-sit.ikp1001rnp.cloud.uk.hsbc      miox-backend-sit.ikp1001rnp.cloud.uk.hsbc
...                uat   miox-uat.ikp1001rnp.cloud.uk.hsbc      miox-backend-uat.ikp1001rnp.cloud.uk.hsbc
...                prod  miox.ikp1001rnp.cloud.uk.hsbc          miox-backend.ikp1001rnp.cloud.uk.hsbc
...
...              ── HOW IT WORKS ─────────────────────────────────────────
...
...              Resolve Environment URLs reads ${ENV}, looks it up in the
...              URL dictionary, then calls Set Suite Variable to set
...              ${BASE_URL} and ${API_BASE_URL} for the current suite.
...              All subsequent keywords in the suite use the resolved URLs.

Library    Collections
Resource   global_variables.robot

*** Variables ***
# ── Environment URL map ────────────────────────────────────────────────────────
# Add new environments here only. No changes needed anywhere else.
# Format: ENV_KEY = { ui: <url>, api: <url> }
#
# UI URL  → used by SeleniumLibrary (Open Browser, Go To)
# API URL → used by RequestsLibrary (Create Session)

&{ENV_DEV}
...    ui=https://miox-dev.ikp1001rnp.cloud.uk.hsbc
...    api=https://miox-backend-dev.ikp1001rnp.cloud.uk.hsbc

&{ENV_SIT}
...    ui=https://miox-sit.ikp1001rnp.cloud.uk.hsbc
...    api=https://miox-backend-sit.ikp1001rnp.cloud.uk.hsbc

&{ENV_UAT}
...    ui=https://miox-uat.ikp1001rnp.cloud.uk.hsbc
...    api=https://miox-backend-uat.ikp1001rnp.cloud.uk.hsbc

&{ENV_PROD}
...    ui=https://miox.ikp1001rnp.cloud.uk.hsbc
...    api=https://miox-backend.ikp1001rnp.cloud.uk.hsbc

# Master lookup: maps ENV value → URL dictionary
&{ENV_MAP}
...    dev=${ENV_DEV}
...    sit=${ENV_SIT}
...    uat=${ENV_UAT}
...    prod=${ENV_PROD}

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PUBLIC ENTRY POINT – use as Test Setup or Suite Setup
# ════════════════════════════════════════════════════════════════════

Resolve Environment URLs
    [Documentation]    Resolves BASE_URL and API_BASE_URL from the ${ENV} variable
    ...                and sets them as suite-level variables so every keyword
    ...                in the suite picks up the correct environment.
    ...
    ...                Call as Test Setup or Suite Setup:
    ...                  Test Setup     Resolve Environment URLs
    ...                  Suite Setup    Resolve Environment URLs
    ...
    ...                Then use normally:
    ...                  robot --variable ENV:uat tests\
    # Normalise to lowercase so DEV / Dev / dev all work
    ${env_key}=    Evaluate    $ENV.lower()

    # Fail immediately with a clear message if the ENV value is not recognised
    ${valid_envs}=    Get Dictionary Keys    ${ENV_MAP}
    ${is_valid}=      Run Keyword And Return Status
    ...               Dictionary Should Contain Key    ${ENV_MAP}    ${env_key}
    Run Keyword If    not ${is_valid}
    ...    Fail
    ...    Unknown ENV: "${ENV}". Valid values are: ${valid_envs}. Pass via --variable ENV:<value>

    # Look up the URL pair for this environment
    ${urls}=    Get From Dictionary    ${ENV_MAP}    ${env_key}

    # Set suite-level variables – visible to all keywords in the suite
    Set Suite Variable    ${BASE_URL}       ${urls}[ui]
    Set Suite Variable    ${API_BASE_URL}   ${urls}[api]

    Log    ✔ ENV=${ENV} resolved
    Log    ✔ BASE_URL     = ${BASE_URL}
    Log    ✔ API_BASE_URL = ${API_BASE_URL}

# ════════════════════════════════════════════════════════════════════
# HELPER – read the current resolved URLs (useful for assertions)
# ════════════════════════════════════════════════════════════════════

Get Current UI URL
    [Documentation]    Returns the resolved BASE_URL for the current suite.
    [Return]    ${BASE_URL}

Get Current API URL
    [Documentation]    Returns the resolved API_BASE_URL for the current suite.
    [Return]    ${API_BASE_URL}

Log Environment Info
    [Documentation]    Logs a summary of the active environment.
    ...                Useful at the start of a suite to confirm which
    ...                environment the tests are running against.
    Log    ══════════════════════════════════════════
    Log    Environment : ${ENV}
    Log    UI URL      : ${BASE_URL}
    Log    API URL     : ${API_BASE_URL}
    Log    Browser     : ${BROWSER}
    Log    Remote Grid : ${USE_REMOTE}
    Log    ══════════════════════════════════════════
