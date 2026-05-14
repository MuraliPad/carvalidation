*** Settings ***
Documentation    One-off utility: Extract and save SSO session cookies.
...
...              Run this script ONCE on your VDI after manually logging
...              in to the application through SSO. It saves all session
...              cookies to config/testdata/cookies.json which is then
...              used by all automated test runs.
...
...              HOW TO USE:
...                1. Manually open Chrome and log in to MiO-X via SSO
...                2. Run this script (do not close Chrome):
...                     robot scripts/extract_cookies.robot
...                3. Cookies saved to config/testdata/cookies.json
...                4. Store cookies.json in your Jenkins credentials
...                   or a secure location (never commit to public git)
...                5. Re-run this script when cookies expire (8-24 hours)
...
...              Jenkins setup:
...                Store cookies.json as a Jenkins Secret File credential.
...                In your Jenkinsfile, copy it to config/testdata/ before
...                running the test suite.

Resource    ../resources/base/browser_setup.resource
Resource    ../resources/base/sso_login.resource
Resource    ../config/env_config.resource

Suite Setup    Run Keywords
...    Resolve Environment URLs    AND
...    Open Browser And Navigate To App

Suite Teardown    Close All Browser Windows

*** Test Cases ***
Extract SSO Session Cookies From Active Browser
    [Documentation]    Navigates to the app, waits for you to confirm
    ...                you are logged in, then extracts and saves cookies.
    [Tags]    utility    cookie-extract
    # Click SSO button and wait for the app shell to load
    Wait Until Element Is Visible
    ...    xpath=//button[contains(.,'Sign In using SSO')] | //a[contains(.,'Sign In using SSO')]
    ...    timeout=15s
    Click Element
    ...    xpath=//button[contains(.,'Sign In using SSO')] | //a[contains(.,'Sign In using SSO')]
    # Wait for full login to complete (sidebar appears)
    Wait Until Element Is Visible
    ...    xpath=//*[contains(@class,'sidebar') or contains(@class,'side-nav')]
    ...    timeout=60s
    ...    error=Login timed out. Make sure SSO completed successfully.
    Log    ✔ Logged in via SSO. Extracting cookies...
    # Save cookies to file
    Extract And Save Session Cookies
    Log    ✔ Done. cookies.json saved to ${COOKIES_FILE}
    Log    Store this file in Jenkins credentials or a secure location.
