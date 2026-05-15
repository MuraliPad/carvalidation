*** Settings ***
Documentation    SSO Login Strategies for Remote/Jenkins Execution.
...
...              The application uses corporate SSO which works on your VDI
...              because the browser already holds a valid session. When tests
...              run remotely (Jenkins, Selenium Grid, headless) there is no
...              existing session, so SSO must be handled differently.
...
...              ── FOUR STRATEGIES ─────────────────────────────────────
...
...              STRATEGY 1 – Cookie injection (RECOMMENDED for HSBC VDI)
...                Extract cookies from a live VDI session once, save to
...                config/testdata/cookies.json, inject into the test browser.
...                The browser sees a valid session → no SSO prompt.
...                Use keyword: Login Via SSO And Wait For App Shell
...
...              STRATEGY 2 – Chrome profile reuse
...                Point Chrome at a user-data-dir where you are already
...                logged in. The profile carries the session cookies.
...                Use keyword: Open Browser With Existing Chrome Profile
...
...              STRATEGY 3 – API token only (Jenkins / headless CI)
...                Skip the UI login entirely. API tests use a Bearer token
...                from auth_api.resource. UI tests are excluded from the run.
...                Use tag: robot --exclude requires_sso tests\
...
...              STRATEGY 4 – Selenium Grid on VDI
...                Run a Selenium Grid node on your VDI. Jenkins points
...                REMOTE_URL at it. The VDI browser handles SSO normally.
...                Set: USE_REMOTE=True, REMOTE_URL=http://<vdi-ip>:4444/wd/hub
...
...              ── HOW TO EXTRACT COOKIES (one time setup) ──────────────
...              Run this in your browser DevTools console after logging in:
...                copy(JSON.stringify(document.cookie.split(';').map(c => {
...                  const [name, ...v] = c.trim().split('=');
...                  return { name, value: v.join('='),
...                           domain: location.hostname, path: '/' };
...                }), null, 2))
...              Paste into config/testdata/cookies.json

Library     SeleniumLibrary
Library     OperatingSystem
Library     Collections
Resource    ../config/global_variables.robot
Resource    ../config/env_config.resource

*** Variables ***
# Path to the saved SSO session cookies file
${COOKIES_FILE}         ${CURDIR}/../../config/testdata/cookies.json

# Path to Chrome user profile directory (Strategy 2)
# Windows example: C:/Users/<you>/AppData/Local/Google/Chrome/User Data
${CHROME_PROFILE_DIR}   ${EMPTY}

# Chrome profile name inside the user data dir (usually "Default")
${CHROME_PROFILE_NAME}  Default

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# STRATEGY 1 – COOKIE INJECTION  (recommended)
#
# Use this as your Login Via SSO And Wait For App Shell replacement.
# Inject saved cookies so the browser has a valid SSO session.
# ════════════════════════════════════════════════════════════════════

Login Via SSO And Wait For App Shell
    [Documentation]    Injects saved SSO cookies into the browser so the app
    ...                sees an authenticated session without going through the
    ...                SSO prompt.
    ...
    ...                Works for BOTH local and remote browser execution:
    ...                  Local:  cookies.json read from VDI, injected into local Chrome
    ...                  Remote: cookies.json read from VDI (file stays on VDI),
    ...                          injected into the remote browser via WebDriver protocol.
    ...                          SeleniumLibrary's Add Cookie sends commands to whichever
    ...                          browser the WebDriver session is connected to.
    ...
    ...                Falls back to SSO button click if no cookies.json found.
    ...                Cookie file: config/testdata/cookies.json
    ${has_cookies}=    Run Keyword And Return Status
    ...    File Should Exist    ${COOKIES_FILE}
    Run Keyword If    ${has_cookies}
    ...    _Login Via Cookie Injection
    ...    ELSE
    ...    _Login Via SSO Button Click
    # Wait for the sidebar to confirm the app shell has loaded
    Wait Until Element Is Visible
    ...    xpath=//*[contains(@class,'sidebar') or contains(@class,'side-nav')]
    ...    timeout=30s
    ...    error=App shell did not load after SSO. Check cookie freshness or SSO button flow.

_Login Via Cookie Injection
    [Documentation]    Injects SSO cookies into the currently open browser session.
    ...
    ...                Works identically for local and remote browsers:
    ...                  1. Navigate to BASE_URL (browser opens on local or Grid node)
    ...                  2. Read cookies.json from the VDI filesystem (file stays on VDI)
    ...                  3. Call Add Cookie for each entry (WebDriver sends to the browser,
    ...                     whether that browser is local or on a remote Grid node)
    ...                  4. Reload page so the browser sees the injected session cookies
    ${log_msg}=    Set Variable    Injecting SSO cookies from ${COOKIES_FILE}
    Log    ${log_msg}
    # Navigate to the base domain first – cookies can only be set for the current domain
    Go To    ${BASE_URL}
    Sleep    ${ANIMATION_WAIT}
    _Inject Cookies From File    ${COOKIES_FILE}
    # Reload so the server sees the injected session cookies in the request headers
    Reload Page
    Wait For Condition    return document.readyState == "complete"    timeout=30s
    Log    ✔ Cookies injected and page reloaded

_Inject Cookies From File
    [Arguments]    ${cookie_file}
    [Documentation]    Reads cookies.json from the VDI and sends each cookie
    ...                to the browser via Add Cookie (WebDriver protocol).
    ...                The file is always read from the machine running robot
    ...                (your VDI). The cookies are sent to whichever browser
    ...                the WebDriver session is connected to – local or remote.
    ...
    ...                Domain handling:
    ...                  Corporate SSO cookies often use a leading dot domain
    ...                  like ".cloud.uk.hsbc". We strip the leading dot when
    ...                  calling Add Cookie because SeleniumLibrary adds it back,
    ...                  and passing a double-dot domain causes the cookie to be
    ...                  rejected by the browser silently.
    ${raw}=      Get File    ${cookie_file}
    ${cookies}=  Evaluate    __import__('json').loads($raw)
    ${injected}=    Set Variable    ${0}
    FOR    ${cookie}    IN    @{cookies}
        # Skip template/comment entries that have no real value
        ${is_real}=    Run Keyword And Return Status
        ...    Should Not Contain    ${cookie}[name]    _comment
        Continue For Loop If    not ${is_real}
        # Strip leading dot from domain – SeleniumLibrary handles it
        ${domain}=    Evaluate
        ...    $cookie.get('domain','').lstrip('.')
        ${status}=    Run Keyword And Ignore Error
        ...    Add Cookie
        ...    ${cookie}[name]
        ...    ${cookie}[value]
        ...    domain=${domain}
        ...    path=${cookie.get('path', '/')}
        ...    secure=${cookie.get('secure', False)}
        ${injected}=    Evaluate    ${injected} + 1
    END
    ${log_count}=    Set Variable    Injected ${injected} cookies into browser session
    Log    ${log_count}

_Login Via SSO Button Click
    [Documentation]    Standard SSO button click. Works on VDI where the
    ...                corporate browser already has a valid Kerberos/SAML ticket.
    ...                Will NOT work headlessly or on Jenkins without a session.
    Log    No cookies.json found – attempting SSO button click (VDI only)
    Wait Until Element Is Visible
    ...    xpath=//button[contains(normalize-space(.),'Sign In using SSO')] | //a[contains(normalize-space(.),'Sign In using SSO')]
    ...    timeout=15s
    Click Element
    ...    xpath=//button[contains(normalize-space(.),'Sign In using SSO')] | //a[contains(normalize-space(.),'Sign In using SSO')]
    Wait For Condition    return document.readyState == "complete"    timeout=30s

# ════════════════════════════════════════════════════════════════════
# STRATEGY 2 – CHROME PROFILE REUSE
#
# Use when running locally on the same machine where you are already
# logged in to Chrome. The profile carries your live session cookies.
# ════════════════════════════════════════════════════════════════════

Open Browser With Existing Chrome Profile
    [Documentation]    Opens Chrome with a specific user profile directory
    ...                so the existing SSO session is available.
    ...
    ...                Set CHROME_PROFILE_DIR in global_variables.robot or pass:
    ...                  robot --variable CHROME_PROFILE_DIR:"C:/Users/me/AppData/Local/Google/Chrome/User Data"
    ...
    ...                NOTE: Chrome must be fully closed before using this keyword.
    ...                You cannot reuse a profile while Chrome is already open.
    Should Not Be Empty    ${CHROME_PROFILE_DIR}
    ...    msg=CHROME_PROFILE_DIR is not set. Set it in global_variables.robot or via --variable.
    ${options}=    Evaluate
    ...    __import__('selenium.webdriver', fromlist=['ChromeOptions']).ChromeOptions()
    Call Method    ${options}    add_argument    --user-data-dir=${CHROME_PROFILE_DIR}
    Call Method    ${options}    add_argument    --profile-directory=${CHROME_PROFILE_NAME}
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    # Disable automation flags that can trigger extra SSO challenges
    Call Method    ${options}    add_argument    --disable-blink-features=AutomationControlled
    Call Method    ${options}    add_experimental_option    useAutomationExtension    ${False}
    Call Method    ${options}    add_experimental_option    excludeSwitches    enable-automation
    Open Browser    url=${BASE_URL}    browser=chrome    options=${options}
    Set Window Size    ${WINDOW_WIDTH}    ${WINDOW_HEIGHT}
    Set Selenium Implicit Wait      ${IMPLICIT_WAIT}
    Set Selenium Page Load Timeout  ${PAGE_LOAD_TIMEOUT}
    Log    ✔ Chrome opened with profile: ${CHROME_PROFILE_DIR}/${CHROME_PROFILE_NAME}

# ════════════════════════════════════════════════════════════════════
# STRATEGY 3 – API ONLY (Jenkins / headless)
#
# No browser opened. All test suites tagged requires_sso are skipped.
# API tests use the Bearer token from auth_api.resource.
# Run with: robot --exclude requires_sso tests\
# ════════════════════════════════════════════════════════════════════

Skip If No SSO Session
    [Documentation]    Skips the current test if running in headless/CI mode
    ...                where no SSO session is available.
    ...                Tag UI tests that need SSO with: [Tags]    requires_sso
    ${ci_mode}=    Get Environment Variable    CI    default=false
    Run Keyword If    '${ci_mode}' == 'true'
    ...    Skip    Skipping SSO-required test in CI/headless mode (CI=true)

# ════════════════════════════════════════════════════════════════════
# STRATEGY 4 – SELENIUM GRID ON VDI
#
# No code changes needed. Set USE_REMOTE=True and REMOTE_URL to your
# VDI's Grid hub. The browser on the VDI handles SSO automatically
# because it runs in the corporate domain.
#
# Start the Grid on your VDI:
#   java -jar selenium-server.jar standalone --port 4444
#
# Run from Jenkins:
#   robot --variable USE_REMOTE:True
#         --variable REMOTE_URL:http://<vdi-ip>:4444/wd/hub
#         tests\
# ════════════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════════════
# COOKIE EXTRACTION HELPER
#
# Run this keyword ONCE on your VDI after manual SSO login to save
# the session cookies to cookies.json for future automated runs.
# ════════════════════════════════════════════════════════════════════

Extract And Save Session Cookies
    [Documentation]    Saves all current browser cookies to cookies.json.
    ...                Run this ONCE on your VDI after manually logging in
    ...                through SSO. The saved cookies are then used by
    ...                Login Via SSO And Wait For App Shell in all future runs.
    ...
    ...                Usage:
    ...                  1. Manually open the browser and log in via SSO
    ...                  2. Call this keyword (e.g. from a one-off robot script)
    ...                  3. Store cookies.json in a secure location
    ...                     (never commit to public git)
    ...                  4. Re-run when cookies expire (typically 8-24h)
    # Get cookies as a list of dicts directly – avoids multi-line Evaluate
    ${raw_cookies}=    Get Cookies    as_dict=False
    # Build the Python expression as a single string variable first.
    # Multi-line Evaluate expressions are split by Robot into multiple
    # arguments causing "expected 1 to 3 arguments, got N" errors.
    ${py_expr}=    Set Variable
    ...    [{'name': c.get('name',''), 'value': c.get('value',''), 'domain': c.get('domain',''), 'path': c.get('path','/'), 'secure': c.get('secure',False), 'httpOnly': c.get('httpOnly',False)} for c in $raw_cookies]
    ${cookie_list}=    Evaluate    ${py_expr}
    ${json_str}=    Evaluate    __import__('json').dumps($cookie_list, indent=2)
    Create File    ${COOKIES_FILE}    ${json_str}
    ${count}=      Get Length    ${cookie_list}
    ${log_saved}=  Set Variable    Saved ${count} cookies to ${COOKIES_FILE}
    Log    ${log_saved}
    Log    Re-extract when SSO session expires (typically 8-24 hours)
