*** Settings ***
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
...              ║  NOTE: String library is intentionally NOT imported.    ║
...              ║  All lowercase conversion uses Python Evaluate inline   ║
...              ║  to avoid any keyword routing ambiguity.                ║
...              ╚══════════════════════════════════════════════════════════╝

# ── INTENTIONALLY NO "Library    String" ─────────────────────────────────────
# Using Evaluate + Python .lower() directly avoids the String library routing
# the "Convert To Lower Case" keyword and showing up in logs incorrectly.
Library    SeleniumLibrary
Library    OperatingSystem
Library    Process
Resource   ../config/global_variables.robot

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PUBLIC ENTRY POINT
# ════════════════════════════════════════════════════════════════════

Open Browser And Navigate To App
    [Documentation]    Single entry point. Resolves driver path, opens the
    ...                correct browser, then navigates to BASE_URL.
    ${driver_path}=    _Resolve Driver Path
    _Launch Browser    ${BROWSER}    ${driver_path}
    Set Window Size                  ${WINDOW_WIDTH}    ${WINDOW_HEIGHT}
    Set Selenium Implicit Wait       ${IMPLICIT_WAIT}
    Set Selenium Page Load Timeout   ${PAGE_LOAD_TIMEOUT}
    Go To                            ${BASE_URL}
    Wait For Page To Be Ready
    Log    ✔ ${BROWSER} opened → ${BASE_URL}

Close All Browser Windows
    Close All Browsers

# ════════════════════════════════════════════════════════════════════
# STEP 1 – RESOLVE DRIVER PATH
#
# Pure logic — no browser is opened here.
# Returns the resolved driver path string, or ${EMPTY} for System PATH.
# Uses Python .lower() via Evaluate — NO String library dependency.
# ════════════════════════════════════════════════════════════════════

_Resolve Driver Path
    # ── Remote Grid: no local driver needed ──────────────────────────
    Return From Keyword If    ${USE_REMOTE}    ${EMPTY}

    # ── webdriver-manager: auto-download ─────────────────────────────
    ${wdm_path}=    Run Keyword If    ${USE_WEBDRIVER_MANAGER}
    ...    _Download Driver Via WDM    ${BROWSER}
    Return From Keyword If    ${USE_WEBDRIVER_MANAGER}    ${wdm_path}

    # ── Explicit path: use Python .lower() for case-safe comparison ──
    # Evaluate returns a plain Python string – no String library needed.
    ${b}=    Evaluate    $BROWSER.lower()

    Return From Keyword If
    ...    '${b}' in ['chrome', 'headlesschrome'] and '${CHROMEDRIVER_PATH}' != ''
    ...    ${CHROMEDRIVER_PATH}

    Return From Keyword If
    ...    '${b}' in ['edge', 'headlessedge'] and '${EDGEDRIVER_PATH}' != ''
    ...    ${EDGEDRIVER_PATH}

    Return From Keyword If
    ...    '${b}' == 'firefox' and '${FIREFOXDRIVER_PATH}' != ''
    ...    ${FIREFOXDRIVER_PATH}

    # ── System PATH fallback ──────────────────────────────────────────
    Log    No explicit driver path set – using System PATH
    [Return]    ${EMPTY}

# ════════════════════════════════════════════════════════════════════
# WEBDRIVER-MANAGER DOWNLOAD
# One Python subprocess call per browser type – no String library.
# ════════════════════════════════════════════════════════════════════

_Download Driver Via WDM
    [Arguments]    ${browser}
    ${b}=    Evaluate    $browser.lower()

    # ── switch: map browser name → WDM one-liner ─────────────────────
    ${wdm_cmd}=    Set Variable If
    ...    '${b}' in ['chrome', 'headlesschrome']
    ...        from webdriver_manager.chrome import ChromeDriverManager; print(ChromeDriverManager().install())
    ...    '${b}' in ['edge', 'headlessedge']
    ...        from webdriver_manager.microsoft import EdgeChromiumDriverManager; print(EdgeChromiumDriverManager().install())
    ...    '${b}' == 'firefox'
    ...        from webdriver_manager.firefox import GeckoDriverManager; print(GeckoDriverManager().install())
    ...    ${None}

    Should Not Be Equal    ${wdm_cmd}    ${None}
    ...    msg=webdriver-manager: unsupported browser "${browser}". Use chrome | edge | firefox.

    ${result}=    Run Process    python    -c    ${wdm_cmd}    stdout=PIPE    stderr=PIPE
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=webdriver-manager failed for "${browser}":\n${result.stderr}

    ${path}=    Evaluate    $result.stdout.strip()
    Log    ✔ webdriver-manager path: ${path}
    [Return]    ${path}

# ════════════════════════════════════════════════════════════════════
# STEP 2 – LAUNCH BROWSER  ← THE SINGLE SWITCH STATEMENT
#
# All three driver modes (Grid / explicit path / System PATH) flow here.
# driver_path=${EMPTY}  →  SeleniumLibrary uses System PATH automatically.
# driver_path=<path>    →  passed to the Service object (Selenium 4+).
#
# Uses Python .lower() via Evaluate — NO String library dependency.
# ════════════════════════════════════════════════════════════════════

_Launch Browser
    [Arguments]    ${browser}    ${driver_path}
    ${b}=    Evaluate    $browser.lower()

    # ── switch ────────────────────────────────────────────────────────
    Run Keyword If         '${b}' == 'chrome'
    ...    _Open Chrome    headed    ${driver_path}
    ...    ELSE IF         '${b}' == 'headlesschrome'
    ...    _Open Chrome    headless  ${driver_path}
    ...    ELSE IF         '${b}' == 'edge'
    ...    _Open Edge      headed    ${driver_path}
    ...    ELSE IF         '${b}' == 'headlessedge'
    ...    _Open Edge      headless  ${driver_path}
    ...    ELSE IF         '${b}' == 'firefox'
    ...    _Open Firefox             ${driver_path}
    ...    ELSE IF         ${USE_REMOTE}
    ...    _Open Remote
    ...    ELSE
    ...    Fail    ❌ Unknown browser: "${browser}". Use chrome | headlesschrome | edge | headlessedge | firefox

# ════════════════════════════════════════════════════════════════════
# BROWSER IMPLEMENTATIONS – one keyword per family
#
# driver_path handling (Selenium 4 compatible):
#   ${EMPTY}  → no Service passed → SeleniumLibrary uses System PATH
#   <path>    → ChromeService / EdgeService / FirefoxService created
#               via Evaluate and passed as service= argument
# ════════════════════════════════════════════════════════════════════

_Open Chrome
    [Arguments]    ${mode}    ${driver_path}
    # Build options
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['ChromeOptions']).ChromeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --disable-gpu

    # Build service only when an explicit path is provided
    ${service}=    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Build Chrome Service    ${driver_path}

    # Open browser – service=None is ignored by SeleniumLibrary
    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    Open Browser    url=${BASE_URL}    browser=chrome
    ...    service=${service}    options=${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=chrome
    ...    options=${options}

_Open Edge
    [Arguments]    ${mode}    ${driver_path}
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['EdgeOptions']).EdgeOptions()
    Run Keyword If    '${mode}' == 'headless'
    ...    Call Method    ${options}    add_argument    --headless=new
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage

    ${service}=    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Build Edge Service    ${driver_path}

    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    Open Browser    url=${BASE_URL}    browser=edge
    ...    service=${service}    options=${options}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=edge
    ...    options=${options}

_Open Firefox
    [Arguments]    ${driver_path}
    ${service}=    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    _Build Firefox Service    ${driver_path}

    Run Keyword If    '${driver_path}' != '${EMPTY}'
    ...    Open Browser    url=${BASE_URL}    browser=firefox    service=${service}
    ...    ELSE
    ...    Open Browser    url=${BASE_URL}    browser=firefox

_Open Remote
    ${caps}=    Create Dictionary    browserName=${BROWSER}
    Open Browser
    ...    url=${BASE_URL}
    ...    browser=${BROWSER}
    ...    remote_url=${REMOTE_URL}
    ...    desired_capabilities=${caps}
    Log    ✔ Remote browser via Grid: ${REMOTE_URL}

# ════════════════════════════════════════════════════════════════════
# SERVICE BUILDERS – Selenium 4 compatible
# Uses selenium.webdriver.chrome/edge/firefox.service.Service
# which accepts executable_path as first positional argument.
# ════════════════════════════════════════════════════════════════════

_Build Chrome Service
    [Arguments]    ${driver_path}
    File Should Exist    ${driver_path}
    ...    msg=❌ chromedriver not found at: "${driver_path}"
    ${service}=    Evaluate
    ...    __import__('selenium.webdriver.chrome.service', fromlist=['Service']).Service(executable_path=r'${driver_path}')
    [Return]    ${service}

_Build Edge Service
    [Arguments]    ${driver_path}
    File Should Exist    ${driver_path}
    ...    msg=❌ msedgedriver not found at: "${driver_path}"
    ${service}=    Evaluate
    ...    __import__('selenium.webdriver.edge.service', fromlist=['Service']).Service(executable_path=r'${driver_path}')
    [Return]    ${service}

_Build Firefox Service
    [Arguments]    ${driver_path}
    File Should Exist    ${driver_path}
    ...    msg=❌ geckodriver not found at: "${driver_path}"
    ${service}=    Evaluate
    ...    __import__('selenium.webdriver.firefox.service', fromlist=['Service']).Service(executable_path=r'${driver_path}')
    [Return]    ${service}

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
