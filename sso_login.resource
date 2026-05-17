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
# Path to saved SSO session cookies file (Strategy 1 – cookie injection)
${COOKIES_FILE}             ${CURDIR}/../../config/testdata/cookies.json

# Path to saved localStorage/sessionStorage file (Strategy 1b – storage injection)
${STORAGE_FILE}             ${CURDIR}/../../config/testdata/storage.json

# Chrome user profile directory (Strategy 2)
# Windows: C:/Users/<you>/AppData/Local/Google/Chrome/User Data
${CHROME_PROFILE_DIR}       ${EMPTY}
${CHROME_PROFILE_NAME}      Default

# localStorage key names the app uses for auth token.
# Run in DevTools Console after login: Object.keys(localStorage)
# to find the exact key names your app uses.
# Common values: token, access_token, authToken, id_token, user
# Set as a comma-separated list if multiple keys need injecting:
#   ${STORAGE_TOKEN_KEYS}    token,user,refresh_token
${STORAGE_TOKEN_KEYS}       token

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# STRATEGY 1 – COOKIE INJECTION  (recommended)
#
# Use this as your Login Via SSO And Wait For App Shell replacement.
# Inject saved cookies so the browser has a valid SSO session.
# ════════════════════════════════════════════════════════════════════

Login Via SSO And Wait For App Shell
    [Documentation]    Handles SSO login using the best available method.
    ...
    ...                Detection order (first match wins):
    ...                  1. storage.json exists → inject localStorage/sessionStorage tokens
    ...                     (use when app stores auth in Local Storage not cookies)
    ...                  2. cookies.json exists → inject session cookies
    ...                     (use when app stores auth in cookies)
    ...                  3. Neither file found  → click SSO button
    ...                     (works on VDI with active Kerberos ticket)
    ...
    ...                To set up storage injection (your app uses Local Storage):
    ...                  robot scripts/extract_storage.robot
    ...
    ...                To set up cookie injection:
    ...                  robot scripts/extract_cookies.robot
    ${has_storage}=    Run Keyword And Return Status
    ...    File Should Exist    ${STORAGE_FILE}
    ${has_cookies}=    Run Keyword And Return Status
    ...    File Should Exist    ${COOKIES_FILE}

    Run Keyword If    ${has_storage}
    ...    _Login Via Storage Injection
    ...    ELSE IF    ${has_cookies}
    ...    _Login Via Cookie Injection
    ...    ELSE
    ...    _Login Via SSO Button Click

    # Wait for sidebar to confirm the app shell has loaded
    Wait Until Element Is Visible
    ...    xpath=//*[contains(@class,'sidebar') or contains(@class,'side-nav')]
    ...    timeout=30s
    ...    error=App shell did not load. Check storage.json/cookies.json freshness or SSO flow.

_Login Via Storage Injection
    [Documentation]    Navigates to BASE_URL, injects localStorage and
    ...                sessionStorage tokens from storage.json, then reloads
    ...                so the app picks up the injected auth tokens.
    ${log_msg}=    Set Variable    Injecting storage tokens from ${STORAGE_FILE}
    Log    ${log_msg}
    Go To    ${BASE_URL}
    Sleep    ${ANIMATION_WAIT}
    Inject Storage Tokens
    Log    ✔ Storage tokens injected and page reloaded

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
        # Use cookie domain if present, fall back to BASE_URL hostname.
        # Strip leading dot – SeleniumLibrary adds it back automatically.
        ${raw_domain}=    Evaluate    $cookie.get('domain','')
        ${base_host}=     Evaluate    __import__('urllib.parse',fromlist=['urlparse']).urlparse($BASE_URL).hostname
        ${domain}=        Evaluate    $raw_domain.lstrip('.') if $raw_domain else $base_host
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
# STRATEGY 1b – LOCAL STORAGE / SESSION STORAGE INJECTION
#
# Use when the app stores the auth token in localStorage or
# sessionStorage instead of cookies (Application tab Cookies empty
# but token visible under Local Storage or Session Storage).
#
# How it works:
#   1. After manual SSO login, call Extract And Save Storage
#   2. Saved to config/testdata/storage.json
#   3. On next run, Login Via SSO And Wait For App Shell detects
#      storage.json and injects the tokens via Execute Javascript
#      before navigating to the app
#
# Find your token key in DevTools Console after login:
#   Object.keys(localStorage)   → e.g. ["token", "user", "theme"]
#   Object.keys(sessionStorage)  → e.g. ["session_id"]
# Then set ${STORAGE_TOKEN_KEYS} in global_variables.robot
# ════════════════════════════════════════════════════════════════════

Extract And Save Storage
    [Documentation]    Saves localStorage and sessionStorage contents to
    ...                storage.json after SSO login.
    ...                Run ONCE on your VDI after logging in via SSO.
    ...                Re-run when the token expires (typically 8-24h).
    # Read all localStorage entries via JavaScript
    ${ls_keys_raw}=    Execute Javascript    return Object.keys(localStorage)
    ${storage_data}=   Create Dictionary
    ...    localStorage=${EMPTY}
    ...    sessionStorage=${EMPTY}

    # Collect localStorage
    ${ls_dict}=    Create Dictionary
    FOR    ${key}    IN    @{ls_keys_raw}
        ${val}=    Execute Javascript    return localStorage.getItem('${key}')
        Set To Dictionary    ${ls_dict}    ${key}=${val}
    END
    Set To Dictionary    ${storage_data}    localStorage=${ls_dict}

    # Collect sessionStorage
    ${ss_keys_raw}=    Execute Javascript    return Object.keys(sessionStorage)
    ${ss_dict}=    Create Dictionary
    FOR    ${key}    IN    @{ss_keys_raw}
        ${val}=    Execute Javascript    return sessionStorage.getItem('${key}')
        Set To Dictionary    ${ss_dict}    ${key}=${val}
    END
    Set To Dictionary    ${storage_data}    sessionStorage=${ss_dict}

    # Write to JSON file
    ${json_str}=    Evaluate    __import__('json').dumps($storage_data, indent=2)
    Create File    ${STORAGE_FILE}    ${json_str}

    ${ls_count}=    Get Length    ${ls_keys_raw}
    ${ss_count}=    Get Length    ${ss_keys_raw}
    ${log_msg}=    Set Variable    Saved ${ls_count} localStorage + ${ss_count} sessionStorage entries to ${STORAGE_FILE}
    Log    ${log_msg}
    Log    Re-extract when SSO session expires (typically 8-24 hours)

Inject Storage Tokens
    [Documentation]    Reads storage.json and injects all saved localStorage
    ...                and sessionStorage entries into the browser via JS.
    ...                Then reloads so the app picks up the injected tokens.
    ...
    ...                FIX: Uses JSON.stringify on the Python side to safely
    ...                pass token values that contain quotes, dots, equals signs
    ...                and other special characters (JWT tokens contain all of
    ...                these). Direct string interpolation into JS breaks on
    ...                any token with a single quote or backslash in it.
    ${err}=    Set Variable    storage.json not found at ${STORAGE_FILE}. Run scripts/extract_storage.robot first.
    File Should Exist    ${STORAGE_FILE}    msg=${err}

    ${raw}=     Get File    ${STORAGE_FILE}
    ${data}=    Evaluate    __import__('json').loads($raw)

    # Inject localStorage entries.
    # Pass key and value via JSON.stringify so special characters in JWT
    # tokens (dots, equals, quotes) do not break the JavaScript string.
    ${ls_data}=    Get From Dictionary    ${data}    localStorage
    FOR    ${key}    ${value}    IN    &{ls_data}
        # Safely encode key and value as JSON strings before passing to JS
        ${safe_key}=      Evaluate    __import__('json').dumps($key)
        ${safe_value}=    Evaluate    __import__('json').dumps($value)
        Execute Javascript    localStorage.setItem(${safe_key}, ${safe_value})
    END

    # Inject sessionStorage entries using the same safe pattern
    ${ss_data}=    Get From Dictionary    ${data}    sessionStorage
    FOR    ${key}    ${value}    IN    &{ss_data}
        ${safe_key}=      Evaluate    __import__('json').dumps($key)
        ${safe_value}=    Evaluate    __import__('json').dumps($value)
        Execute Javascript    sessionStorage.setItem(${safe_key}, ${safe_value})
    END

    # Reload so the app reads the injected tokens from storage
    Reload Page
    Wait For Condition    return document.readyState == "complete"    timeout=30s
    Log    ✔ localStorage and sessionStorage injected, page reloaded

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
    ...                FIX: Uses Get Cookies as_dict=True which returns proper
    ...                Python dicts with all fields populated. Previous version
    ...                used as_dict=False which returns Selenium cookie objects
    ...                where .get() fails silently giving empty values.
    ...
    ...                Usage:
    ...                  1. Manually open the browser and log in via SSO
    ...                  2. Call this keyword (e.g. from a one-off robot script)
    ...                  3. Store cookies.json in a secure location
    ...                  4. Re-run when cookies expire (typically 8-24h)
    # Use CDP Network.getAllCookies to capture ALL cookies including
    # HttpOnly ones. document.cookie and Get Cookies cannot read HttpOnly
    # cookies because the browser blocks JavaScript access to them.
    # CDP bypasses this restriction by talking directly to the browser engine.
    ${cdp_result}=    Execute Cdp Command
    ...    Network.getAllCookies
    ...    {}
    ${all_cookies}=    Get From Dictionary    ${cdp_result}    cookies

    # Filter to cookies relevant to this domain only
    ${base_host}=    Evaluate
    ...    __import__('urllib.parse', fromlist=['urlparse']).urlparse($BASE_URL).hostname
    ${py_expr}=    Set Variable
    ...    [c for c in $all_cookies if $base_host in c.get('domain','') or c.get('domain','').lstrip('.') in $base_host]
    ${site_cookies}=    Evaluate    ${py_expr}

    # Build clean list with only the fields needed for injection
    ${cookie_list}=    Create List
    FOR    ${cookie}    IN    @{site_cookies}
        ${entry}=    Create Dictionary
        ...    name=${cookie}[name]
        ...    value=${cookie}[value]
        ...    domain=${cookie}[domain]
        ...    path=${cookie}[path]
        ...    secure=${cookie.get('secure', False)}
        ...    httpOnly=${cookie.get('httpOnly', False)}
        Append To List    ${cookie_list}    ${entry}
    END

    ${json_str}=    Evaluate    __import__('json').dumps($cookie_list, indent=2)
    Create File    ${COOKIES_FILE}    ${json_str}
    ${count}=      Get Length    ${cookie_list}
    ${log_saved}=  Set Variable    Saved ${count} cookies (including HttpOnly) to ${COOKIES_FILE}
    Log    ${log_saved}
    Log    Re-extract when SSO session expires (typically 8-24 hours)
