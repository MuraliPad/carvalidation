$*** Settings ***
Documentation    Base browser management keywords.
...
...              ╔══════════════════════════════════════════════════════════╗
...              ║  SUPPORTED BROWSERS                                      ║
...              ║    chrome  |  headlesschrome                            ║
...              ║    edge    |  headlessedge                              ║
...              ║    firefox                                              ║
...              ╠══════════════════════════════════════════════════════════╣
...              ║  DRIVER RESOLUTION ORDER (first match wins)             ║
...              ║    1. USE_REMOTE=True       → Selenium Grid             ║
...              ║    2. USE_WEBDRIVER_MANAGER → auto-download driver      ║
...              ║    3. CHROMEDRIVER_PATH /                               ║
...              ║       EDGEDRIVER_PATH /                                 ║
...              ║       FIREFOXDRIVER_PATH set → explicit path            ║
...              ║    4. Everything empty      → System PATH               ║
...              ╠══════════════════════════════════════════════════════════╣
...              ║  CONFIGURE IN global_variables.robot:                   ║
...              ║    ${BROWSER}              chrome                       ║
...              ║    ${CHROMEDRIVER_PATH}    C:/drivers/chromedriver.exe  ║
...              ║    ${EDGEDRIVER_PATH}      C:/drivers/msedgedriver.exe  ║
...              ║    ${FIREFOXDRIVER_PATH}   C:/drivers/geckodriver.exe   ║
...              ║    ${USE_WEBDRIVER_MANAGER}  ${TRUE}                    ║
...              ║                                                          ║
...              ║  OR OVERRIDE AT RUNTIME:                                ║
...              ║    robot --variable BROWSER:edge                        ║
...              ║    robot --variable EDGEDRIVER_PATH:C:/drv/edge.exe     ║
...              ╚══════════════════════════════════════════════════════════╝

Library    SeleniumLibrary
Library    OperatingSystem
Library    Process
Resource   ../config/global_variables.robot

*** Variables ***
# Driver path for Firefox – mirrors chrome/edge pattern in global_variables.robot
${FIREFOXDRIVER_PATH}    ${EMPTY}

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PUBLIC ENTRY POINT
# ════════════════════════════════════════════════════════════════════

Open Browser And Navigate To App
    [Documentation]    Single entry point for all browser/driver combinations.
    ...                Resolves driver, opens the browser, then navigates to BASE_URL.
    ${driver_path}=    _Resolve Driver Path
    _Launch Browser    ${BROWSER}    ${driver_path}
    Set Window Size                  ${WINDOW_WIDTH}    ${WINDOW_HEIGHT}
    Set Selenium Implicit Wait       ${IMPLICIT_WAIT}
    Set Selenium Page Load Timeout   ${PAGE_LOAD_TIMEOUT}
    Go To                            ${BASE_URL}
    Wait For Page To Be Ready
    Log    ✔ ${BROWSER} opened → ${BASE_URL}  (driver: ${driver_path})

Close All Browser Windows
    Close All Browsers

# ════════════════════════════════════════════════════════════════════
# STEP 1 – RESOLVE DRIVER PATH
# Returns the driver executable path as a string, or EMPTY for PATH/Grid.
# ════════════════════════════════════════════════════════════════════

_Resolve Driver Path
    [Documentation]    Works out which driver path to use based on config.
    ...                Returns EMPTY when no explicit path is needed
    ...                (Grid mode or System PATH mode).
    # Remote Grid – no local driver needed
    Return From Keyword If    ${USE_REMOTE}    ${EMPTY}

    # webdriver-manager – auto-download and return path
    Return From Keyword If    ${USE_WEBDRIVER_MANAGER}
    ...    _Download Driver Via WDM    ${BROWSER}

    # Explicit path variables set in global_variables.robot or CLI
    ${lower}=    Convert To Lowercase    ${BROWSER}
    Return From Keyword If
    ...    '${lower}' in ['chrome','headlesschrome'] and '${CHROMEDRIVER_PATH}' != '${EMPTY}'
    ...    ${CHROMEDRIVER_PATH}
    Return From Keyword If
    ...    '${lower}' in ['edge','headlessedge'] and '${EDGEDRIVER_PATH}' != '${EMPTY}'
    ...    ${EDGEDRIVER_PATH}
    Return From Keyword If
    ...    '${lower}' == 'firefox' and '${FIREFOXDRIVER_PATH}' != '${EMPTY}'
    ...    ${FIREFOXDRIVER_PATH}

    # System PATH – SeleniumLibrary finds driver automatically
    [Return]    ${EMPTY}

_Download Driver Via WDM
    [Arguments]    ${browser}
    [Documentation]    Calls webdriver-manager for the given browser and returns
    ...                the downloaded driver path. One Python call per browser type.
    ${lower}=    Convert To Lowercase    ${browser}

    # ── Single switch: map browser → webdriver-manager import + class ──
    ${wdm_import}=    Set Variable If
    ...    '${lower}' in ['chrome','headlesschrome']
    ...        from webdriver_manager.chrome import ChromeDriverManager; print(ChromeDriverManager().install())
    ...    '${lower}' in ['edge','headlessedge']
    ...        from webdriver_manager.microsoft import EdgeChromiumDriverManager; print(EdgeChromiumDriverManager().install())
    ...    '${lower}' == 'firefox'
    ...        from webdriver_manager.firefox import GeckoDriverManager; print(GeckoDriverManager().install())

    Should Not Be Equal    ${wdm_import}    ${None}
    ...    msg=❌ webdriver-manager: unsupported browser "${browser}". Supported: chrome, edge, firefox.

    ${result}=    Run Process    python    -c    ${wdm_import}
    ...    stdout=PIPE    stderr=PIPE
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=❌ webdriver-manager install failed for "${browser}":\n${result.stderr}

    ${path}=    Strip String    ${result.stdout}
    Log    ✔ webdriver-manager resolved: ${path}
    [Return]    ${path}

# ════════════════════════════════════════════════════════════════════
# STEP 2 – LAUNCH BROWSER  (single switch statement)
#
# Dispatches to the correct Open Browser call based on browser name.
# All three modes (Grid / explicit path / System PATH) pass through here.
# driver_path=EMPTY  →  SeleniumLibrary uses System PATH or Grid URL.
# ════════════════════════════════════════════════════════════════════

_Launch Browser
    [Arguments]    ${browser}    ${driver_path}
    [Documentation]    ── SWITCH on browser name ──────────────────────────
    ...
    ...                chrome          → Chrome, headed
    ...                headlesschrome  → Chrome, headless
    ...                edge            → Edge, headed
    ...                headlessedge    → Edge, headless
    ...                firefox         → Firefox, headed
    ...
    ...                driver_path: pass EMPTY to use System PATH / Grid.
    ${lower}=    Convert To Lowercase    ${browser}

    # ── switch ────────────────────────────────────────────────────
    Run Keyword If    '${lower}' == 'chrome'
    ...    _Open Chrome              headed     ${driver_path}
    ...    ELSE IF    '${lower}' == 'headlesschrome'
    ...    _Open Chrome              headless   ${driver_path}
    ...    ELSE IF    '${lower}' == 'edge'
    ...    _Open Edge                headed     ${driver_path}
    ...    ELSE IF    '${lower}' == 'headlessedge'
    ...    _Open Edge                headless   ${driver_path}
    ...    ELSE IF    '${lower}' == 'firefox'
    ...    _Open Firefox                        ${driver_path}
    ...    ELSE IF    ${USE_REMOTE}
    ...    _Open Remote
    ...    ELSE
    ...    Fail
    ...    ❌ Unsupported browser: "${browser}". Use chrome | headlesschrome | edge | headlessedge | firefox

# ════════════════════════════════════════════════════════════════════
# BROWSER IMPLEMENTATIONS  (one keyword per browser family)
# ════════════════════════════════════════════════════════════════════

_Open Chrome
    [Arguments]    ${mode}    ${driver_path}
    [Documentation]    Opens Chrome headed or headless.
    ...                mode: headed | headless
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['ChromeOptions']).ChromeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless\=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --disable-gpu
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Validate Driver File    ${driver_path}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=chrome
    ...    executable_path=${driver_path}
    ...    options=${options}

_Open Edge
    [Arguments]    ${mode}    ${driver_path}
    [Documentation]    Opens Edge headed or headless.
    ...                mode: headed | headless
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['EdgeOptions']).EdgeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless\=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Validate Driver File    ${driver_path}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=edge
    ...    executable_path=${driver_path}
    ...    options=${options}

_Open Firefox
    [Arguments]    ${driver_path}
    [Documentation]    Opens Firefox (headed only – headless via browser profile if needed).
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Validate Driver File    ${driver_path}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=firefox
    ...    executable_path=${driver_path}

_Open Remote
    [Documentation]    Opens a browser on a remote Selenium Grid node.
    ${caps}=    Create Dictionary    browserName=${BROWSER}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=${BROWSER}
    ...    remote_url=${REMOTE_URL}
    ...    desired_capabilities=${caps}
    Log    ✔ Remote browser via Grid: ${REMOTE_URL}

# ════════════════════════════════════════════════════════════════════
# GUARD – validates the driver file exists before attempting to open
# ════════════════════════════════════════════════════════════════════

_Validate Driver File
    [Arguments]    ${path}
    File Should Exist    ${path}
    ...    msg=❌ Driver not found: "${path}"\n \
    ...         Fix: check the path in global_variables.robot, or set USE_WEBDRIVER_MANAGER:${TRUE}

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
    Wait For Condition    return document.readyState == "complete"    timeout=${PAGE_LOAD_TIMEOUT}

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
