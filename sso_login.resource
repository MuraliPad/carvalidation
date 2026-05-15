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
    ...                SSO prompt. Falls back to direct SSO click if no cookie
    ...                file is present (VDI local run).
    ...
    ...                Cookie file: config/testdata/cookies.json
    ...                Extract cookies from VDI DevTools console (see header).
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
    [Documentation]    Loads the app URL (which may redirect to SSO), then
    ...                injects the saved cookies, then reloads to apply them.
    Log    Injecting SSO cookies from ${COOKIES_FILE}
    # Navigate to the base domain first so cookies can be set
    Go To    ${BASE_URL}
    Sleep    ${ANIMATION_WAIT}
    _Inject Cookies From File    ${COOKIES_FILE}
    # Reload so the app sees the injected cookies
    Reload Page
    Wait For Condition    return document.readyState == "complete"    timeout=30s
    Log    ✔ Cookies injected and page reloaded

_Inject Cookies From File
    [Arguments]    ${cookie_file}
    [Documentation]    Reads cookies.json and adds each cookie to the browser
    ...                via SeleniumLibrary's Add Cookie keyword.
    ${raw}=       Get File         ${cookie_file}
    ${cookies}=   Evaluate         __import__('json').loads($raw)
    FOR    ${cookie}    IN    @{cookies}
        Run Keyword And Ignore Error
        ...    Add Cookie
        ...    ${cookie}[name]
        ...    ${cookie}[value]
        ...    domain=${cookie.get('domain', '')}
        ...    path=${cookie.get('path', '/')}
        ...    secure=${cookie.get('secure', False)}
    END
    ${count}=    Get Length    ${cookies}
    Log    ✔ Injected ${count} cookies into browser

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
    ...                  3. Commit cookies.json to your secure credentials store
    ...                     (never commit to public git)
    ...                  4. Re-run when cookies expire (typically 8-24h)
    ${raw_cookies}=    Get Cookies    as_dict=False
    # Convert selenium cookie objects to plain dicts
    ${cookie_list}=    Evaluate    [
    ...        {'name': c.get('name',''), 'value': c.get('value',''),
    ...         'domain': c.get('domain',''), 'path': c.get('path','/'),
    ...         'secure': c.get('secure', False),
    ...         'httpOnly': c.get('httpOnly', False)}
    ...        for c in $raw_cookies
    ...    ]
    ${json_str}=    Evaluate    __import__('json').dumps($cookie_list, indent=2)
    Create File     ${COOKIES_FILE}    ${json_str}
    ${count}=       Get Length    ${cookie_list}
    Log    ✔ Saved ${count} cookies to ${COOKIES_FILE}
    Log    Re-extract when SSO session expires (typically 8-24 hours)
