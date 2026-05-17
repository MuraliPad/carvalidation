*** Settings ***
Documentation    Browser setup and teardown keywords.
...
...              ── EXECUTION MODES ──────────────────────────────────────
...
...              MODE 1 – LOCAL (default)
...                Fresh browser, SSO via storage/cookie injection or SSO button.
...                USE_REMOTE=False, USE_CHROME_PROFILE=False
...                SSO auto-detected: storage.json → cookies.json → SSO button
...
...              MODE 2 – CHROME PROFILE
...                Reuses logged-in Chrome profile, SSO already active.
...                USE_CHROME_PROFILE=True, CHROME_PROFILE_DIR=<path>
...                Only works when profile dir is on the same machine as browser.
...
...              MODE 3 – REMOTE SELENIUM GRID
...                Connects to a Grid node. SSO via storage/cookie injection.
...                USE_REMOTE=True, REMOTE_URL=http://<host>:4444/wd/hub
...                Execute Javascript and Add Cookie both work over WebDriver
...                protocol so storage and cookie injection work identically
...                for local and remote browsers – no extra setup needed.
...
...              ── SSO LOGIN DISPATCHER ─────────────────────────────────
...
...              After browser opens, _Handle SSO Login is called:
...                │
...                ├─ USE_CHROME_PROFILE=True  → wait for sidebar (already logged in)
...                └─ else → Login Via SSO And Wait For App Shell
...                               │
...                               ├─ storage.json found → inject localStorage tokens
...                               │    (works for local AND remote via Execute Javascript)
...                               ├─ cookies.json found → inject session cookies
...                               │    (works for local AND remote via Add Cookie)
...                               └─ neither found     → click SSO button (VDI only)
...
...              ── BROWSER OPEN SWITCH ──────────────────────────────────
...
...              Open Browser And Navigate To App
...                │
...                ├─ USE_REMOTE=True        →  _Open Remote Browser
...                ├─ USE_CHROME_PROFILE=True→  _Open Chrome With Profile
...                └─ else                  →  _Open Local Browser
...
...              ── CONFIGURATION ────────────────────────────────────────
...
...              Set in global_variables.robot or pass via --variable:
...                robot --variable USE_CHROME_PROFILE:True
...                      --variable CHROME_PROFILE_DIR:C:/Users/me/AppData/Local/Google/Chrome/User Data
...                      --variable CHROME_PROFILE_NAME:Default
...                      tests\

Library     SeleniumLibrary
Library     OperatingSystem
Resource    ../config/global_variables.robot
Resource    sso_login.resource

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PUBLIC ENTRY POINT
# ════════════════════════════════════════════════════════════════════

Open Browser And Navigate To App
    [Documentation]    Opens the browser and navigates to BASE_URL.
    ...
    ...                Mode switch (checked in order):
    ...                  1. USE_REMOTE=True        → remote Selenium Grid
    ...                  2. USE_CHROME_PROFILE=True → existing Chrome profile (SSO already active)
    ...                  3. else                   → fresh local browser
    Run Keyword If    ${USE_REMOTE}
    ...    _Open Remote Browser
    ...    ELSE IF    ${USE_CHROME_PROFILE}
    ...    _Open Chrome With Profile
    ...    ELSE
    ...    _Open Local Browser
    Set Window Size                 ${WINDOW_WIDTH}    ${WINDOW_HEIGHT}
    Set Selenium Implicit Wait      ${IMPLICIT_WAIT}
    Set Selenium Page Load Timeout  ${PAGE_LOAD_TIMEOUT}
    Go To                           ${BASE_URL}
    Wait For Page To Be Ready
    ${log_browser}=    Set Variable    Browser ready: ${BROWSER} - ${BASE_URL}
    Log    ${log_browser}

Close All Browser Windows
    Close All Browsers

# ════════════════════════════════════════════════════════════════════
# LOCAL BROWSER – single switch on browser name
# ════════════════════════════════════════════════════════════════════

_Open Local Browser
    [Documentation]    Switch on BROWSER value → opens the correct browser.
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
    ...    Fail    Browser "${BROWSER}" not supported. Use: chrome, headlesschrome, edge, headlessedge, firefox

# ════════════════════════════════════════════════════════════════════
# MODE 2 – CHROME PROFILE  (SSO via existing logged-in session)
#
# Opens Chrome pointing at CHROME_PROFILE_DIR/CHROME_PROFILE_NAME.
# That profile already has a valid corporate SSO session, so the
# app loads directly without any SSO prompt or cookie injection.
#
# Requirements:
#   - Chrome must be FULLY CLOSED before running (profile is locked
#     while Chrome is open – open = any Chrome window, including
#     background instances)
#   - The profile directory must be on the machine running robot
#     (your VDI for local runs, the Grid node for remote runs)
#   - Does NOT work on Jenkins or a remote Grid on a different machine
#     because the profile directory does not exist there
#
# Configure in global_variables.robot or pass at CLI:
#   robot --variable USE_CHROME_PROFILE:True
#         --variable CHROME_PROFILE_DIR:C:/Users/me/AppData/Local/Google/Chrome/User Data
#         --variable CHROME_PROFILE_NAME:Default
#         tests\
# ════════════════════════════════════════════════════════════════════

_Open Chrome With Profile
    [Documentation]    Opens Chrome reusing an existing user profile so the
    ...                SSO session is already active. No cookie injection or
    ...                SSO button click is needed.
    ...
    ...                CHROME_PROFILE_DIR  – full path to the Chrome User Data folder
    ...                CHROME_PROFILE_NAME – profile subfolder name (usually "Default")
    ...
    ...                Both variables must be set in global_variables.robot or via --variable.
    ${err_dir}=    Set Variable    CHROME_PROFILE_DIR is not set. Pass via --variable CHROME_PROFILE_DIR:<path>
    ${err_closed}=    Set Variable    Make sure ALL Chrome windows are closed before running with USE_CHROME_PROFILE:True
    Should Not Be Empty    ${CHROME_PROFILE_DIR}    msg=${err_dir}
    # Build Chrome options with the profile arguments
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['ChromeOptions']).ChromeOptions()
    Call Method    ${options}    add_argument    --user-data-dir=${CHROME_PROFILE_DIR}
    Call Method    ${options}    add_argument    --profile-directory=${CHROME_PROFILE_NAME}
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    # Suppress the "Chrome is being controlled by automated software" bar
    # which can sometimes trigger additional SSO challenges on corporate setups
    Call Method    ${options}    add_argument    --disable-blink-features=AutomationControlled
    Call Method    ${options}    add_experimental_option    useAutomationExtension    ${False}
    Call Method    ${options}    add_experimental_option    excludeSwitches    enable-automation
    # Open with explicit driver path if set, otherwise use System PATH
    Run Keyword If    '${CHROMEDRIVER_PATH}' != '${EMPTY}'
    ...    _Launch With Service    chrome    ${CHROMEDRIVER_PATH}    ${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=chrome    options=${options}
    ${log_profile}=    Set Variable    Chrome opened with profile: ${CHROME_PROFILE_DIR}/${CHROME_PROFILE_NAME}
    Log    ${log_profile}

# ════════════════════════════════════════════════════════════════════
# MODE 1 – BROWSER IMPLEMENTATIONS
#
# driver_path = ${EMPTY}  →  uses System PATH  (no extra config needed)
# driver_path = <path>    →  uses that explicit exe file
# ════════════════════════════════════════════════════════════════════

_Open Chrome
    [Arguments]    ${mode}    ${driver_path}
    # Build Chrome options
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['ChromeOptions']).ChromeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --disable-gpu
    # Open browser – with explicit path or via System PATH
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Launch With Service    chrome    ${driver_path}    ${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=chrome    options=${options}

_Open Edge
    [Arguments]    ${mode}    ${driver_path}
    # Build Edge options
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['EdgeOptions']).EdgeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    # Open browser – with explicit path or via System PATH
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Launch With Service    edge    ${driver_path}    ${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=edge    options=${options}

_Open Firefox
    [Arguments]    ${driver_path}
    # Open browser – with explicit path or via System PATH
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Launch With Service    firefox    ${driver_path}    ${NONE}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=firefox

# ════════════════════════════════════════════════════════════════════
# EXPLICIT PATH LAUNCHER  (Selenium 4 Service pattern)
#
# BUG FIX 1: File Should Exist msg= is now a single string variable –
#            multi-line continuation after a named arg caused the
#            "positional argument after named argument" parse error.
#
# BUG FIX 2: The condition '${driver_path}' != '${EMPTY}' in _Open Chrome
#            now correctly guards this keyword so it is ONLY called when
#            a real path string is provided.
# ════════════════════════════════════════════════════════════════════

_Launch With Service
    [Arguments]    ${browser}    ${driver_path}    ${options}
    # Validate the driver file exists – single-line msg to avoid parse error
    ${err}=    Set Variable    Driver not found at "${driver_path}". Set correct path in global_variables.robot or pass --variable CHROMEDRIVER_PATH:<path>
    File Should Exist    ${driver_path}    msg=${err}

    # Build the Selenium 4 Service object for the correct browser
    ${b}=    Evaluate    $browser.lower()
    ${service}=    Run Keyword If    '${b}' == 'chrome'
    ...    Evaluate    __import__('selenium.webdriver.chrome.service', fromlist=['Service']).Service(r'${driver_path}')
    ...    ELSE IF    '${b}' == 'edge'
    ...    Evaluate    __import__('selenium.webdriver.edge.service', fromlist=['Service']).Service(r'${driver_path}')
    ...    ELSE IF    '${b}' == 'firefox'
    ...    Evaluate    __import__('selenium.webdriver.firefox.service', fromlist=['Service']).Service(r'${driver_path}')

    # Open browser – pass options only for Chrome/Edge (Firefox has no options arg here)
    Run Keyword If    $options is not None
    ...    Open Browser    url=${BASE_URL}    browser=${browser}    service=${service}    options=${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=${browser}    service=${service}

# ════════════════════════════════════════════════════════════════════
# REMOTE SELENIUM GRID
# ════════════════════════════════════════════════════════════════════

_Open Remote Browser
    [Documentation]    Connects to a Selenium Grid hub.
    ...
    ...                Two sub-modes controlled by USE_CHROME_PROFILE:
    ...
    ...                USE_CHROME_PROFILE=False (default):
    ...                  Plain remote browser, no profile.
    ...                  SSO handled by cookie injection after browser opens.
    ...                  robot --variable USE_REMOTE:True
    ...                        --variable REMOTE_URL:http://<host>:4444/wd/hub
    ...
    ...                USE_CHROME_PROFILE=True:
    ...                  Remote browser launched WITH your Chrome profile.
    ...                  ONLY works when the Grid node runs on the SAME machine
    ...                  as the profile directory (e.g. Grid on your VDI).
    ...                  The profile has an active SSO session so no cookie
    ...                  injection is needed at all.
    ...                  robot --variable USE_REMOTE:True
    ...                        --variable REMOTE_URL:http://localhost:4444/wd/hub
    ...                        --variable USE_CHROME_PROFILE:True
    ...                        --variable CHROME_PROFILE_DIR:C:/Users/me/AppData/Local/Google/Chrome/User Data
    ...
    ...                Start Grid on your VDI:
    ...                  java -jar selenium-server.jar standalone --port 4444
    Run Keyword If    ${USE_CHROME_PROFILE}
    ...    _Open Remote Browser With Profile
    ...    ELSE
    ...    _Open Remote Browser Plain

_Open Remote Browser Plain
    [Documentation]    Connects to Grid with a plain fresh browser session.
    ...                SSO will be handled by cookie injection afterwards.
    ${caps}=    Create Dictionary    browserName=${BROWSER}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=${BROWSER}
    ...    remote_url=${REMOTE_URL}
    ...    desired_capabilities=${caps}
    ${log_remote}=    Set Variable    Remote browser connected: ${REMOTE_URL}
    Log    ${log_remote}

_Open Remote Browser With Profile
    [Documentation]    Connects to Grid and passes Chrome profile arguments
    ...                so the remote Chrome opens with an existing SSO session.
    ...
    ...                REQUIREMENT: The Grid node must run on the SAME machine
    ...                as CHROME_PROFILE_DIR. If the Grid is on a different
    ...                machine this will fail because the profile path does
    ...                not exist on that machine's filesystem.
    ...
    ...                Typical setup: run Grid on your VDI at localhost:4444,
    ...                point REMOTE_URL at localhost, profile dir on same VDI.
    ${err_dir}=    Set Variable    CHROME_PROFILE_DIR is empty. Set it via --variable CHROME_PROFILE_DIR:<path>
    Should Not Be Empty    ${CHROME_PROFILE_DIR}    msg=${err_dir}
    # Build Chrome options with the profile directory
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['ChromeOptions']).ChromeOptions()
    Call Method    ${options}    add_argument    --user-data-dir=${CHROME_PROFILE_DIR}
    Call Method    ${options}    add_argument    --profile-directory=${CHROME_PROFILE_NAME}
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    # Suppress automation banner that can trigger extra SSO challenges
    Call Method    ${options}    add_argument    --disable-blink-features=AutomationControlled
    Call Method    ${options}    add_experimental_option    useAutomationExtension    ${False}
    Call Method    ${options}    add_experimental_option    excludeSwitches    enable-automation
    # Connect to Grid passing the profile-bearing Chrome options
    ${caps}=    Create Dictionary    browserName=chrome
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=chrome
    ...    remote_url=${REMOTE_URL}
    ...    desired_capabilities=${caps}
    ...    options=${options}
    ${log_profile}=    Set Variable    Remote Chrome opened with profile: ${CHROME_PROFILE_DIR}/${CHROME_PROFILE_NAME}
    Log    ${log_profile}

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
# TEST-LEVEL SETUP / TEARDOWN KEYWORDS
#
# Use these when each test case needs its own fresh browser.
# Reference in test suites as:
#   Test Setup     Open Fresh Browser
#   Test Teardown  Close Browser After Test
#
# VS Suite-level (one browser shared across all tests):
#   Suite Setup    Open Browser And Navigate To App
#   Suite Teardown Close All Browser Windows
# ════════════════════════════════════════════════════════════════════

Open Fresh Browser
    [Documentation]    Opens a brand-new browser instance for a single test.
    ...                Use as Test Setup when each test must start clean.
    Open Browser And Navigate To App

Close Browser After Test
    [Documentation]    Closes the browser after a single test completes.
    ...                Captures a screenshot first if the test failed.
    Run Keyword If Test Failed
    ...    Capture Page Screenshot    ${SCREENSHOT_DIR}/FAILED_${TEST_NAME}_${SUITE_NAME}.png
    Close All Browser Windows

Open Fresh Browser And Login
    [Documentation]    Opens browser, navigates to app, and handles SSO login.
    ...
    ...                Works for ALL execution modes:
    ...
    ...                  LOCAL + storage.json          → storage token injection
    ...                  LOCAL + cookies.json           → cookie injection
    ...                  LOCAL + no file               → SSO button click (VDI only)
    ...                  REMOTE + storage.json          → storage token injection
    ...                                                   (Execute Javascript sends to remote browser)
    ...                  REMOTE + cookies.json          → cookie injection
    ...                                                   (Add Cookie sends to remote browser)
    ...                  REMOTE + USE_CHROME_PROFILE    → profile SSO already active,
    ...                                                   just wait for app shell
    ...                  LOCAL  + USE_CHROME_PROFILE    → profile SSO already active,
    ...                                                   just wait for app shell
    ...
    ...                storage.json and cookies.json are detected automatically
    ...                by Login Via SSO And Wait For App Shell in sso_login.resource.
    ...                No changes needed in test suites when switching modes.
    Open Browser And Navigate To App
    _Handle SSO Login

Open Fresh Browser Login And Go To
    [Arguments]    ${nav_keyword}
    [Documentation]    Opens browser, handles SSO, then navigates to a specific page.
    ...                Works for all modes: local, remote, storage, cookies, profile.
    ...                Pass the navigation keyword name as the argument.
    ...                Example:
    ...                  Test Setup  Open Fresh Browser Login And Go To
    ...                  ...         Navigate To Inventory Via Sidebar
    Open Browser And Navigate To App
    _Handle SSO Login
    Run Keyword    ${nav_keyword}

_Handle SSO Login
    [Documentation]    Central SSO login dispatcher called after the browser opens.
    ...
    ...                ── DECISION TREE ───────────────────────────────────────
    ...
    ...                USE_CHROME_PROFILE=True?
    ...                  YES → profile already has SSO, just wait for sidebar
    ...                  NO  → delegate to Login Via SSO And Wait For App Shell
    ...                          which auto-detects:
    ...                            storage.json → inject localStorage tokens
    ...                            cookies.json → inject session cookies
    ...                            neither      → click SSO button
    ...
    ...                KEY POINT for remote execution:
    ...                  Execute Javascript (storage injection) and Add Cookie
    ...                  (cookie injection) both communicate via WebDriver protocol.
    ...                  They work identically whether the browser is local or
    ...                  on a remote Selenium Grid node. No special handling needed.
    Run Keyword If    ${USE_CHROME_PROFILE}
    ...    _Wait For App Shell After Profile Login
    ...    ELSE
    ...    Login Via SSO And Wait For App Shell

_Wait For App Shell After Profile Login
    [Documentation]    Chrome profile mode only – SSO session is already active
    ...                in the profile so we just wait for the sidebar to appear.
    ...                No token injection or SSO button click needed.
    Wait Until Element Is Visible
    ...    xpath=//*[contains(@class,'sidebar') or contains(@class,'side-nav')]
    ...    timeout=30s
    ...    error=App shell did not load. Check that the Chrome profile has a valid SSO session.
    Log    ✔ App shell loaded via existing Chrome profile session
