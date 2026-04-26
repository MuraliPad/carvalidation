*** Settings ***
Documentation    API Auth Resource – Bearer token generation and session setup.
...
...              Credentials are loaded from:
...                config/testdata/user_details.json
...
...              JSON file format:
...                {
...                  "name":       "Test User",
...                  "email":      "testuser@test.com",
...                  "employeeID": "682828"
...                }
...
...              Auth flow:
...                1. Read and parse user_details.json
...                2. POST credentials to /api/auth/token
...                3. Parse "access_token" from response
...                4. Prefix with "Bearer " → stored as ${API_TOKEN}
...                5. Create main API session with Authorization header
...
...              Usage in every API / integrity test suite:
...                Suite Setup    Authenticate And Create Session
...                Suite Teardown Delete API Session

Library    RequestsLibrary
Library    Collections
Library    OperatingSystem
Resource   ../config/global_variables.robot
Resource   api_client.resource

*** Variables ***
# Path to user credentials JSON file.
# Uses ${CURDIR} so it resolves correctly regardless of where robot is run from.
${USER_DETAILS_FILE}      ${CURDIR}/../../config/testdata/user_details.json

# Temporary session alias used only during token fetch – closed immediately after.
${AUTH_SESSION_ALIAS}     miox_auth

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PUBLIC ENTRY POINT
# ════════════════════════════════════════════════════════════════════

Authenticate And Create Session
    [Documentation]    Full auth flow in one keyword – call as Suite Setup.
    ...
    ...                Steps:
    ...                  1. Load credentials from user_details.json
    ...                  2. POST to /api/auth/token → get access_token
    ...                  3. Set suite variable: ${API_TOKEN} = "Bearer <token>"
    ...                  4. Create main API session with Authorization header
    ${token}=    Fetch Bearer Token
    Set Suite Variable    ${API_TOKEN}    Bearer ${token}
    Create Authenticated Session    ${API_TOKEN}
    Log    ✔ Authenticated. Session ready with Bearer token.

# ════════════════════════════════════════════════════════════════════
# STEP 1 – LOAD CREDENTIALS FROM JSON
# ════════════════════════════════════════════════════════════════════

_Load User Details
    [Documentation]    Reads config/testdata/user_details.json and returns
    ...                the parsed content as a Python dictionary.
    ...
    ...                Fails with a clear message if the file is missing
    ...                or the JSON is malformed.
    # Confirm the file exists before attempting to read
    ${err}=    Set Variable
    ...    user_details.json not found at: "${USER_DETAILS_FILE}". Create the file at config/testdata/user_details.json
    File Should Exist    ${USER_DETAILS_FILE}    msg=${err}

    # Read the file content
    ${raw}=    Get File    ${USER_DETAILS_FILE}

    # Parse JSON using Python's built-in json module
    ${user}=    Evaluate    __import__('json').loads($raw)

    # Validate all required keys are present
    Dictionary Should Contain Key    ${user}    name
    ...    msg=user_details.json is missing required key: "name"
    Dictionary Should Contain Key    ${user}    email
    ...    msg=user_details.json is missing required key: "email"
    Dictionary Should Contain Key    ${user}    employeeID
    ...    msg=user_details.json is missing required key: "employeeID"

    Log    ✔ Loaded user_details.json: name=${user}[name] email=${user}[email]
    [Return]    ${user}

# ════════════════════════════════════════════════════════════════════
# STEP 2 – FETCH TOKEN
# ════════════════════════════════════════════════════════════════════

Fetch Bearer Token
    [Documentation]    Loads user_details.json, POSTs to /api/auth/token,
    ...                and returns the raw access_token string.
    # Load credentials from JSON file
    ${credentials}=    _Load User Details

    # Open a temporary session with no auth header
    _Create Auth Session

    # POST credentials exactly as loaded from JSON – no field mapping needed
    ${resp}=    POST On Session
    ...    alias=${AUTH_SESSION_ALIAS}
    ...    url=${AUTH_TOKEN_PATH}
    ...    json=${credentials}
    ...    expected_status=200

    # Parse and validate the token from the response
    ${token}=    _Parse Access Token    ${resp}

    # Close the temporary session
    _Delete Auth Session

    Log    ✔ Bearer token obtained (first 20 chars): ${token[:20]}...
    [Return]    ${token}

# ════════════════════════════════════════════════════════════════════
# STEP 3 – PARSE TOKEN FROM RESPONSE
# ════════════════════════════════════════════════════════════════════

_Parse Access Token
    [Arguments]    ${resp}
    [Documentation]    Parses the access_token from the auth response body.
    ...
    ...                Expected response shape:
    ...                  { "access_token": "xxxxxx", "token_type": "bearer" }
    ${json}=    Evaluate    $resp.json()

    # Validate expected keys exist
    Dictionary Should Contain Key    ${json}    access_token
    ...    msg=Auth response missing "access_token". Body: ${resp.text[:300]}
    Dictionary Should Contain Key    ${json}    token_type
    ...    msg=Auth response missing "token_type". Body: ${resp.text[:300]}

    # Validate token_type = bearer (case-insensitive)
    ${token_type}=    Evaluate    $json['token_type'].lower()
    Should Be Equal As Strings    ${token_type}    bearer
    ...    msg=Expected token_type "bearer", got "${token_type}"

    # Extract and return the raw token value
    ${token}=    Get From Dictionary    ${json}    access_token
    Should Not Be Empty    ${token}
    ...    msg=access_token is empty in auth response
    [Return]    ${token}

# ════════════════════════════════════════════════════════════════════
# STEP 4 – CREATE AUTHENTICATED SESSION
# ════════════════════════════════════════════════════════════════════

Create Authenticated Session
    [Arguments]    ${bearer_token}
    [Documentation]    Creates the main RequestsLibrary session with the
    ...                Authorization header set to the Bearer token.
    ...                This session is used by all GET/POST/PUT keywords
    ...                in api_client.resource.
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    ...    Accept=application/json
    ...    Authorization=${bearer_token}
    Create Session
    ...    alias=${SESSION_ALIAS}
    ...    url=${API_BASE_URL}
    ...    headers=${headers}
    ...    verify=False
    ...    timeout=${API_TIMEOUT}
    Log    ✔ Authenticated API session created → ${API_BASE_URL}

# ════════════════════════════════════════════════════════════════════
# PRIVATE – TEMPO:qRARY SESSION FOR TOKEN REQUEST
# ════════════════════════════════════════════════════════════════════

_Create Auth Session
    [Documentation]    Opens a temporary session with no Authorization header.
    ...                Used only for the POST /api/auth/token call.
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    ...    Accept=application/json
    Create Session
    ...    alias=${AUTH_SESSION_ALIAS}
    ...    url=${API_BASE_URL}
    ...    headers=${headers}
    ...    verify=False
    ...    timeout=${API_TIMEOUT}

_Delete Auth Session
    [Documentation]    Closes the temporary auth session after token is obtained.
    Run Keyword And Ignore Error    Delete Session    ${AUTH_SESSION_ALIAS}

# ════════════════════════════════════════════════════════════════════
# TOKEN VALIDATION HELPER
# ════════════════════════════════════════════════════════════════════

Verify Token Is Set
    [Documentation]    Sanity check that ${API_TOKEN} is populated and formatted.
    ...                Call after Suite Setup if you want an explicit assertion.
    Should Not Be Empty    ${API_TOKEN}
    ...    msg=API_TOKEN is empty. Was Authenticate And Create Session called in Suite Setup?
    Should Start With    ${API_TOKEN}    Bearer
    ...    msg=API_TOKEN does not start with "Bearer ". Got: ${API_TOKEN[:30]}
    Log    ✔ API_TOKEN is set and correctly formatted
