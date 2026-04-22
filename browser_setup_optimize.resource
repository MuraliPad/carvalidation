*** Settings ***
Documentation    Browser setup and teardown keywords.
...
...              Supports two execution modes:
...                LOCAL  – opens Chrome / Edge / Firefox on this machine
...                REMOTE – connects to a Selenium Grid node
...
...              Supported BROWSER values:
...                chrome | headlesschrome | edge | headlessedge | firefox
...
...              Driver path resolution (local mode only):
...                Option 1 – Set CHROMEDRIVER_PATH / EDGEDRIVER_PATH / FIREFOXDRIVER_PATH
...                           in global_variables.robot or pass via --variable at runtime.
...                           e.g. robot --variable CHROMEDRIVER_PATH:C:/drivers/chromedriver.exe
...                Option 2 – Leave path variables empty and put the driver on System PATH.
...                           SeleniumLibrary finds it automatically.

Library     SeleniumLibrary
Library     OperatingSystem
Resource    ../config/global_variables.robot

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PUBLIC ENTRY POINT
# ════════════════════════════════════════════════════════════════════

Open Browser And Navigate To App
    [Documentation]    Opens the browser and navigates to BASE_URL.
    ...                Switches automatically between local and remote mode
    ...                based on the USE_REMOTE variable.
    Run Keyword If    ${USE_REMOTE}
    ...    _Open Remote Browser
    ...    ELSE
    ...    _Open Local Browser
    Set Window Size                 ${WINDOW_WIDTH}    ${WINDOW_HEIGHT}
    Set Selenium Implicit Wait      ${IMPLICIT_WAIT}
    Set Selenium Page Load Timeout  ${PAGE_LOAD_TIMEOUT}
    Go To                           ${BASE_URL}
    Wait For Page To Be Ready
    Log    ✔ Browser ready: ${BROWSER} → ${BASE_URL}

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
# BROWSER IMPLEMENTATIONS
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
    ...                Configure REMOTE_URL in global_variables.robot or pass:
    ...                  robot --variable USE_REMOTE:True
    ...                        --variable REMOTE_URL:http://<host>:4444/wd/hub
    ${caps}=    Create Dictionary    browserName=${BROWSER}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=${BROWSER}
    ...    remote_url=${REMOTE_URL}
    ...    desired_capabilities=${caps}
    Log    ✔ Remote browser connected: ${REMOTE_URL}

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
