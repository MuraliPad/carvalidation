*** Settings ***
Documentation    Browser setup and teardown keywords.
...
...              ── EXECUTION MODES ──────────────────────────────────────
...
...              MODE 1 – LOCAL (default)
...                Opens a fresh browser on this machine.
...                SSO handled via storage.json or cookies.json injection.
...                USE_REMOTE=False
...
...              MODE 2 – REMOTE SELENIUM GRID
...                Connects to a Selenium Grid node via WebDriver.
...                SSO handled via storage.json or cookies.json injection.
...                Execute Javascript and Add Cookie both communicate over
...                WebDriver protocol so injection works identically for
...                local and remote browsers – no extra setup needed.
...                USE_REMOTE=True, REMOTE_URL=http://<host>:4444/wd/hub
...
...              ── SSO LOGIN FLOW ────────────────────────────────────────
...
...              After browser opens, Login Via SSO And Wait For App Shell
...              auto-detects the right strategy:
...                storage.json found → inject localStorage/sessionStorage tokens
...                cookies.json found → inject session cookies
...                neither found      → click SSO button (VDI with Kerberos only)
...
...              ── BROWSER OPEN SWITCH ──────────────────────────────────
...
...              Open Browser And Navigate To App
...                │
...                ├─ USE_REMOTE=True  →  _Open Remote Browser
...                └─ else            →  _Open Local Browser
...
...              ── DRIVER CONFIGURATION ─────────────────────────────────
...
...              Option 1 – Explicit driver path (corp/locked machines):
...                robot --variable CHROMEDRIVER_PATH:C:/drivers/chromedriver.exe
...                robot --variable EDGEDRIVER_PATH:C:/drivers/msedgedriver.exe
...
...              Option 2 – Driver on System PATH (simplest):
...                Add chromedriver.exe to PATH, leave path variables empty.

Library     SeleniumLibrary
Library     OperatingSystem
Resource    ../config/global_variables.robot
Resource    sso_login.resource

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PUBLIC ENTRY POINT
# ════════════════════════════════════════════════════════════════════

Open Browser And Navigate To App
    [Documentation]    Opens the browser (local or remote Grid) and
    ...                navigates to BASE_URL.
    Run Keyword If    ${USE_REMOTE}
    ...    _Open Remote Browser
    ...    ELSE
    ...    _Open Local Browser
    Set Window Size                 ${WINDOW_WIDTH}    ${WINDOW_HEIGHT}
    Set Selenium Implicit Wait      ${IMPLICIT_WAIT}
    Set Selenium Page Load Timeout  ${PAGE_LOAD_TIMEOUT}
    Go To                           ${BASE_URL}
    Wait For Page To Be Ready
    ${log}=    Set Variable    Browser ready: ${BROWSER} - ${BASE_URL}
    Log    ${log}

Close All Browser Windows
    Close All Browsers

# ════════════════════════════════════════════════════════════════════
# MODE 1 – LOCAL BROWSER
# Single switch on BROWSER value.
# driver_path=${EMPTY} → SeleniumLibrary finds driver on System PATH.
# driver_path=<path>   → uses that explicit exe via Selenium 4 Service.
# ════════════════════════════════════════════════════════════════════

_Open Local Browser
    [Documentation]    Opens the correct local browser based on ${BROWSER}.
    ...                Supported values:
    ...                  chrome | headlesschrome | edge | headlessedge | firefox
    ${b}=    Evaluate    $BROWSER.lower()
    Run Keyword If         '${b}' == 'chrome'
    ...    _Open Chrome    headed    ${CHROMEDRIVER_PATH}
    ...    ELSE IF         '${b}' == 'headlesschrome'
    ...    _Open Chrome    headless  ${CHROMEDRIVER_PATH}
    ...    ELSE IF         '${b}' == 'edge'
    ...    _Open Edge      headed    ${EDGEDRIVER_PATH}
    ...    ELSE IF         '${b}' == 'headlessedge'
    ...    _Open Edge      headless  ${EDGEDRIVER_PATH}
    ...    ELSE IF         '${b}' == 'firefox'
    ...    _Open Firefox             ${FIREFOXDRIVER_PATH}
    ...    ELSE
    ...    Fail    Browser "${BROWSER}" not supported. Use: chrome | headlesschrome | edge | headlessedge | firefox

_Open Chrome
    [Arguments]    ${mode}    ${driver_path}
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['ChromeOptions']).ChromeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --disable-gpu
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Launch With Service    chrome    ${driver_path}    ${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=chrome    options=${options}

_Open Edge
    [Arguments]    ${mode}    ${driver_path}
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['EdgeOptions']).EdgeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Launch With Service    edge    ${driver_path}    ${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=edge    options=${options}

_Open Firefox
    [Arguments]    ${driver_path}
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Launch With Service    firefox    ${driver_path}    ${NONE}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=firefox

# ════════════════════════════════════════════════════════════════════
# EXPLICIT DRIVER PATH  (Selenium 4 Service pattern)
# Only called when a driver path variable is set.
# ════════════════════════════════════════════════════════════════════

_Launch With Service
    [Arguments]    ${browser}    ${driver_path}    ${options}
    ${err}=    Set Variable
    ...    Driver not found at "${driver_path}". Check the path in global_variables.robot or pass via --variable.
    File Should Exist    ${driver_path}    msg=${err}
    ${b}=    Evaluate    $browser.lower()
    ${service}=    Run Keyword If    '${b}' == 'chrome'
    ...    Evaluate    __import__('selenium.webdriver.chrome.service', fromlist=['Service']).Service(r'${driver_path}')
    ...    ELSE IF    '${b}' == 'edge'
    ...    Evaluate    __import__('selenium.webdriver.edge.service', fromlist=['Service']).Service(r'${driver_path}')
    ...    ELSE IF    '${b}' == 'firefox'
    ...    Evaluate    __import__('selenium.webdriver.firefox.service', fromlist=['Service']).Service(r'${driver_path}')
    Run Keyword If    $options is not None
    ...    Open Browser    url=${BASE_URL}    browser=${browser}    service=${service}    options=${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=${browser}    service=${service}

# ════════════════════════════════════════════════════════════════════
# MODE 2 – REMOTE SELENIUM GRID
# SSO is handled after browser opens via storage/cookie injection.
# Execute Javascript and Add Cookie both work over WebDriver protocol
# so they reach the remote browser just like a local one.
# ════════════════════════════════════════════════════════════════════

_Open Remote Browser
    [Documentation]    Connects to a Selenium Grid hub.
    ...                After this keyword returns, Login Via SSO And Wait For App Shell
    ...                injects localStorage tokens (storage.json) or session cookies
    ...                (cookies.json) into the remote browser via WebDriver protocol.
    ...
    ...                Configure via --variable or global_variables.robot:
    ...                  USE_REMOTE=True
    ...                  REMOTE_URL=http://<grid-host>:4444/wd/hub
    ${caps}=    Create Dictionary    browserName=${BROWSER}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=${BROWSER}
    ...    remote_url=${REMOTE_URL}
    ...    desired_capabilities=${caps}
    ${log}=    Set Variable    Remote browser connected: ${REMOTE_URL}
    Log    ${log}

# ════════════════════════════════════════════════════════════════════
# NAVIGATION
# ════════════════════════════════════════════════════════════════════

Navigate To URL
    [Arguments]    ${url}
    Go To    ${url}
    Wait For Page To Be Ready

Navigate To Page
    [Arguments]    ${path}
    Go To    ${BASE_URL}${path}
    Wait For Page To Be Ready

Wait For Page To Be Ready
    Wait For Condition
    ...    return document.readyState == "complete"
    ...    timeout=${PAGE_LOAD_TIMEOUT}

Wait For Element And Click
    [Arguments]    ${locator}    ${timeout}=${EXPLICIT_WAIT}
    Wait Until Element Is Visible    ${locator}    timeout=${timeout}
    Click Element                    ${locator}

Wait For Element And Input Text
    [Arguments]    ${locator}    ${text}    ${timeout}=${EXPLICIT_WAIT}
    Wait Until Element Is Visible    ${locator}    timeout=${timeout}
    Clear Element Text               ${locator}
    Input Text                       ${locator}    ${text}

# ════════════════════════════════════════════════════════════════════
# SCREENSHOT & ASSERTIONS
# ════════════════════════════════════════════════════════════════════

Capture Step Screenshot
    [Arguments]    ${step_name}
    ${timestamp}=    Get Time    epoch
    Capture Page Screenshot    ${SCREENSHOT_DIR}/${step_name}_${timestamp}.png

Page Should Contain Text
    [Arguments]    ${text}
    Page Should Contain    ${text}

Element Text Should Be
    [Arguments]    ${locator}    ${expected_text}
    ${actual}=    Get Text    ${locator}
    Should Be Equal As Strings    ${actual.strip()}    ${expected_text}

Element Should Have CSS Class
    [Arguments]    ${locator}    ${css_class}
    ${classes}=    Get Element Attribute    ${locator}    class
    Should Contain    ${classes}    ${css_class}

Current URL Should Contain
    [Arguments]    ${path_fragment}
    ${url}=    Get Location
    Should Contain    ${url}    ${path_fragment}

# ════════════════════════════════════════════════════════════════════
# TEST-LEVEL SETUP / TEARDOWN
# ════════════════════════════════════════════════════════════════════

Open Fresh Browser
    [Documentation]    Opens a fresh browser. Use as Test Setup when
    ...                each test needs its own clean browser session.
    Open Browser And Navigate To App

Close Browser After Test
    [Documentation]    Closes the browser. Captures a screenshot first
    ...                if the test failed, for evidence in the report.
    Run Keyword If Test Failed
    ...    Capture Page Screenshot    ${SCREENSHOT_DIR}/FAILED_${TEST_NAME}_${SUITE_NAME}.png
    Close All Browser Windows

Open Fresh Browser And Login
    [Documentation]    Opens browser then handles SSO login automatically.
    ...
    ...                Works for local AND remote execution:
    ...                  storage.json found → inject localStorage tokens via Execute Javascript
    ...                  cookies.json found → inject session cookies via Add Cookie
    ...                  neither found      → click SSO button (VDI with Kerberos only)
    ...
    ...                Both Execute Javascript and Add Cookie communicate via
    ...                WebDriver protocol so they reach the remote browser
    ...                exactly the same as a local browser.
    Open Browser And Navigate To App
    Login Via SSO And Wait For App Shell

Open Fresh Browser Login And Go To
    [Arguments]    ${nav_keyword}
    [Documentation]    Opens browser, handles SSO, then navigates to a page.
    ...                Pass the sidebar navigation keyword as the argument.
    ...                Example:
    ...                  Test Setup    Open Fresh Browser Login And Go To
    ...                  ...           Navigate To Inventory Via Sidebar
    Open Browser And Navigate To App
    Login Via SSO And Wait For App Shell
    Run Keyword    ${nav_keyword}


Load Base URL
    [Documentation]    Navigate to ${BASE_URL} with renderer-timeout retry
    ...                and verify the app shell has rendered.
    [Arguments]
    ...    ${url}=${BASE_URL}
    ...    ${max_attempts}=3
    ...    ${ready_locator}=tag:body

    # Convert string → int so arithmetic and comparisons work
    ${max_attempts}=    Convert To Integer    ${max_attempts}
    ${last_attempt}=    Evaluate    ${max_attempts} + 1

    FOR    ${attempt}    IN RANGE    1    ${last_attempt}
        TRY
            Log    Loading base URL — attempt ${attempt}/${max_attempts}: ${url}    console=True
            Go To    ${url}
            Wait Until Page Contains Element    ${ready_locator}
            ...    timeout=${PAGE_LOAD_TIMEOUT}
            Wait For Condition
            ...    return document.readyState === 'complete' || document.readyState === 'interactive'
            ...    timeout=${PAGE_LOAD_TIMEOUT}
            Log    ✓ Base URL loaded on attempt ${attempt}    console=True
            RETURN
        EXCEPT    *TimeoutException*    type=GLOB    AS    ${error}
            Log    Renderer timeout on attempt ${attempt}    level=WARN
            IF    ${attempt} == ${max_attempts}
                Capture Page Screenshot
                Fatal Error
                ...    Base URL failed to load after ${max_attempts} attempts: ${url}
                ...    Last error: ${error}
            END
            Execute Javascript    window.stop();
            Sleep    2s
        END
    END
