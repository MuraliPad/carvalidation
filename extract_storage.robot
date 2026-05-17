*** Settings ***
Documentation    One-off utility: Extract and save localStorage / sessionStorage.
...
...              Use this when the app stores auth tokens in Local Storage or
...              Session Storage instead of cookies (Application tab shows empty
...              Cookies but token visible under Local Storage or Session Storage).
...
...              HOW TO USE:
...                1. Run this script – Chrome opens automatically:
...                     robot scripts/extract_storage.robot
...                2. Click "Sign In using SSO" and complete corporate login
...                3. Once the app sidebar appears, the script saves storage
...                4. Re-run when token expires (typically 8-24 hours)
...
...              OUTPUT: config/testdata/storage.json
...              FORMAT:
...                {
...                  "localStorage":   { "token": "eyJ...", "user": "{...}" },
...                  "sessionStorage": { "session_id": "abc123" }
...                }
...
...              The storage.json is automatically used by:
...                Login Via SSO And Wait For App Shell
...              on all subsequent test runs.

Resource    ../resources/base/browser_setup.resource
Resource    ../resources/base/sso_login.resource
Resource    ../config/env_config.resource
Resource    ../config/global_variables.robot

Suite Setup       Run Keywords
...               Resolve Environment URLs    AND
...               Open Browser And Navigate To App
Suite Teardown    Close All Browser Windows

*** Test Cases ***
Extract SSO Storage Tokens
    [Documentation]    Waits for SSO login, then saves all localStorage
    ...                and sessionStorage entries to storage.json.
    [Tags]    utility    storage-extract

    # Wait for SSO login page and click
    Wait Until Element Is Visible
    ...    xpath=//button[contains(.,'Sign In using SSO')] | //a[contains(.,'Sign In using SSO')]
    ...    timeout=15s
    Click Element
    ...    xpath=//button[contains(.,'Sign In using SSO')] | //a[contains(.,'Sign In using SSO')]

    # Wait for full login - sidebar confirms app has loaded
    Wait Until Element Is Visible
    ...    xpath=//*[contains(@class,'sidebar') or contains(@class,'side-nav')]
    ...    timeout=120s
    ...    error=SSO login timed out. Complete corporate login in the browser window.

    Log    ✔ SSO login complete. Reading storage...

    # Show what keys are available - helps confirm the right token key
    ${ls_keys}=    Execute Javascript    return Object.keys(localStorage)
    ${ss_keys}=    Execute Javascript    return Object.keys(sessionStorage)
    ${log_ls}=     Set Variable    localStorage keys found: ${ls_keys}
    ${log_ss}=     Set Variable    sessionStorage keys found: ${ss_keys}
    Log    ${log_ls}
    Log    ${log_ss}

    # Save all storage to file
    Extract And Save Storage

    Log    ✔ storage.json saved to ${STORAGE_FILE}
    Log    This file will be used automatically by Login Via SSO And Wait For App Shell
    Log    Re-run this script when SSO session expires (typically 8-24 hours)
