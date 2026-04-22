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
...                1. CHROMEDRIVER_PATH / EDGEDRIVER_PATH / FIREFOXDRIVER_PATH set
...                   → uses that explicit path (recommended on corp machines)
...                2. Path variables left empty
...                   → SeleniumLibrary finds the driver from System PATH

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
    [Documentation]    Resolves driver path then opens the correct local browser.
    ...                Switch: chrome | headlesschrome | edge | headlessedge | firefox
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
    ...    Fail
    ...    ❌ Unknown browser: "${BROWSER}". Use chrome | headlesschrome | edge | headlessedge | firefox

# ════════════════════════════════════════════════════════════════════
# BROWSER IMPLEMENTATIONS
# Each keyword accepts:
#   mode        – headed | headless  (Chrome and Edge only)
#   driver_path – full path to driver exe, or ${EMPTY} for System PATH
# ════════════════════════════════════════════════════════════════════

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
    ...    _Open With Explicit Path    chrome    ${driver_path}    ${options}
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
    ...    _Open With Explicit Path    edge    ${driver_path}    ${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=edge    options=${options}

_Open Firefox
    [Arguments]    ${driver_path}
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Open With Explicit Path    firefox    ${driver_path}    ${None}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=firefox

# ════════════════════════════════════════════════════════════════════
# EXPLICIT DRIVER PATH HELPER  (Selenium 4 Service pattern)
# ════════════════════════════════════════════════════════════════════

_Open With Explicit Path
    [Arguments]    ${browser}    ${driver_path}    ${options}
    [Documentation]    Validates the driver file exists then opens the browser
    ...                using a Selenium 4 Service object so the driver path
    ...                is passed correctly (executable_path is deprecated in Se4).
    File Should Exist    ${driver_path}
    ...    msg=❌ Driver not found: "${driver_path}"\n
    ...    Download manually and set the correct path in global_variables.robot\n
    ...    Chrome: https://googlechromelabs.github.io/chrome-for-testing/\n
    ...    Edge:   https://developer.microsoft.com/microsoft-edge/tools/webdriver/

    ${b}=    Evaluate    $browser.lower()
    ${service}=    Run Keyword If    '${b}' == 'chrome'
    ...    Evaluate
    ...    __import__('selenium.webdriver.chrome.service', fromlist=['Service']).Service(executable_path=r'${driver_path}')
    ...    ELSE IF    '${b}' == 'edge'
    ...    Evaluate
    ...    __import__('selenium.webdriver.edge.service', fromlist=['Service']).Service(executable_path=r'${driver_path}')
    ...    ELSE IF    '${b}' == 'firefox'
    ...    Evaluate
    ...    __import__('selenium.webdriver.firefox.service', fromlist=['Service']).Service(executable_path=r'${driver_path}')

    Run Keyword If    ${options} is not None
    ...    Open Browser    url=${BASE_URL}    browser=${browser}
    ...    service=${service}    options=${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=${browser}
    ...    service=${service}

# ════════════════════════════════════════════════════════════════════
# REMOTE SELENIUM GRID
# ════════════════════════════════════════════════════════════════════

_Open Remote Browser
    [Documentation]    Connects to a Selenium Grid hub.
    ...                Set REMOTE_URL to your grid endpoint, e.g:
    ...                  http://<grid-host>:4444/wd/hub
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
