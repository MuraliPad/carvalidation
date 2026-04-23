*** Settings ***
Documentation    API Base Client – core HTTP request keywords.
...
...              All API resource files import this.
...              Handles: authentication headers, request execution,
...              response validation, and JSON parsing.
...
...              Uses RequestsLibrary (pip install robotframework-requests).
...
...              ┌──────────────────────────────────────────────────────┐
...              │  USAGE IN CHILD RESOURCE FILES                       │
...              │                                                      │
...              │  Resource    api_client.resource                     │
...              │                                                      │
...              │  Then call:                                          │
...              │    Create API Session                                │
...              │    ${resp}=  GET Request  /api/inventory/vms         │
...              │    Response Status Should Be  ${resp}  200           │
...              │    ${data}=  Parse JSON Response  ${resp}            │
...              └──────────────────────────────────────────────────────┘

Library    RequestsLibrary
Library    Collections
Library    String
Library    JSONLibrary
Resource   ../config/global_variables.robot

*** Variables ***
${SESSION_ALIAS}    miox_api

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# SESSION MANAGEMENT
# ════════════════════════════════════════════════════════════════════

Create API Session
    [Documentation]    Creates a named RequestsLibrary session with auth headers.
    ...                Call once per suite in Suite Setup.
    ...                Token passed via global ${API_TOKEN} variable.
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    ...    Accept=application/json
    ...    Authorization=${API_TOKEN}
    Create Session
    ...    alias=${SESSION_ALIAS}
    ...    url=${API_BASE_URL}
    ...    headers=${headers}
    ...    verify=False
    ...    timeout=${API_TIMEOUT}
    Log    ✔ API session created: ${API_BASE_URL}

Delete API Session
    Delete All Sessions
    Log    ✔ API sessions deleted

# ════════════════════════════════════════════════════════════════════
# HTTP REQUEST WRAPPERS
# Each returns the full response object for the caller to assert on.
# ════════════════════════════════════════════════════════════════════

GET Request
    [Arguments]    ${path}    ${params}=${None}    ${expected_status}=200
    [Documentation]    Executes GET ${API_BASE_URL}${path} and returns response.
    ${resp}=    GET On Session
    ...    ${SESSION_ALIAS}
    ...    url=${path}
    ...    params=${params}
    ...    expected_status=${expected_status}
    Log    ► GET ${path}  →  HTTP ${resp.status_code}
    [Return]    ${resp}

POST Request
    [Arguments]    ${path}    ${body}    ${expected_status}=200
    [Documentation]    Executes POST ${API_BASE_URL}${path} with JSON body.
    ${resp}=    POST On Session
    ...    ${SESSION_ALIAS}
    ...    url=${path}
    ...    json=${body}
    ...    expected_status=${expected_status}
    Log    ► POST ${path}  →  HTTP ${resp.status_code}
    [Return]    ${resp}

PUT Request
    [Arguments]    ${path}    ${body}    ${expected_status}=200
    [Documentation]    Executes PUT ${API_BASE_URL}${path} with JSON body.
    ${resp}=    PUT On Session
    ...    ${SESSION_ALIAS}
    ...    url=${path}
    ...    json=${body}
    ...    expected_status=${expected_status}
    Log    ► PUT ${path}  →  HTTP ${resp.status_code}
    [Return]    ${resp}

# ════════════════════════════════════════════════════════════════════
# RESPONSE ASSERTIONS
# ════════════════════════════════════════════════════════════════════

Response Status Should Be
    [Arguments]    ${resp}    ${expected_code}
    Should Be Equal As Integers    ${resp.status_code}    ${expected_code}
    ...    msg=❌ Expected HTTP ${expected_code}, got ${resp.status_code}. Body: ${resp.text[:300]}
    Log    ✔ HTTP ${resp.status_code}

Response Should Be 200
    [Arguments]    ${resp}
    Response Status Should Be    ${resp}    200

Response Should Be 201
    [Arguments]    ${resp}
    Response Status Should Be    ${resp}    201

Response Should Not Be Empty
    [Arguments]    ${resp}
    Should Not Be Empty    ${resp.text}
    ...    msg=❌ Response body is empty for request to ${resp.url}
    Log    ✔ Response body is non-empty

Response Body Should Contain Key
    [Arguments]    ${resp}    ${key}
    ${json}=    Parse JSON Response    ${resp}
    Dictionary Should Contain Key    ${json}    ${key}
    ...    msg=❌ JSON response missing key: "${key}"
    Log    ✔ Response contains key: "${key}"

Response Time Should Be Within
    [Arguments]    ${resp}    ${max_ms}=3000
    ${elapsed_ms}=    Evaluate    ${resp.elapsed.total_seconds()} * 1000
    Should Be True    ${elapsed_ms} <= ${max_ms}
    ...    msg=❌ Response time ${elapsed_ms}ms exceeded threshold ${max_ms}ms
    Log    ✔ Response time: ${elapsed_ms:.0f}ms (threshold: ${max_ms}ms)

# ════════════════════════════════════════════════════════════════════
# JSON PARSING HELPERS
# ════════════════════════════════════════════════════════════════════

Parse JSON Response
    [Arguments]    ${resp}
    [Documentation]    Returns the response body as a Python dict/list.
    ${json}=    Set Variable    ${resp.json()}
    [Return]    ${json}

Get JSON Value
    [Arguments]    ${resp}    ${key}
    [Documentation]    Parses JSON response and returns the value at top-level key.
    ${json}=    Parse JSON Response    ${resp}
    ${value}=   Get From Dictionary    ${json}    ${key}
    [Return]    ${value}

Get JSON List Length
    [Arguments]    ${resp}    ${list_key}=${None}
    [Documentation]    Returns length of a JSON array.
    ...                If list_key is given, navigates to that key first.
    ...                If list_key is empty, treats the root as a list.
    ${json}=    Parse JSON Response    ${resp}
    ${items}=   Run Keyword If    '${list_key}' != '${None}'
    ...    Get From Dictionary    ${json}    ${list_key}
    ...    ELSE    Set Variable    ${json}
    ${count}=   Get Length    ${items}
    [Return]    ${count}

Get JSON Nested Value
    [Arguments]    ${resp}    @{keys}
    [Documentation]    Traverses a nested JSON path using a list of keys.
    ...                E.g.  Get JSON Nested Value  ${resp}  data  total
    ${json}=    Parse JSON Response    ${resp}
    ${node}=    Set Variable    ${json}
    FOR    ${key}    IN    @{keys}
        ${node}=    Get From Dictionary    ${node}    ${key}
    END
    [Return]    ${node}

# ════════════════════════════════════════════════════════════════════
# INTEGRITY COMPARISON HELPERS
# ════════════════════════════════════════════════════════════════════

Counts Should Match Within Tolerance
    [Arguments]    ${api_count}    ${ui_count}    ${tolerance}=${COUNT_TOLERANCE}
    [Documentation]    Asserts api_count and ui_count differ by at most tolerance.
    ...                Default tolerance is 0 (exact match).
    ${diff}=    Evaluate    abs(${api_count} - ${ui_count})
    Should Be True    ${diff} <= ${tolerance}
    ...    msg=❌ Count mismatch: API=${api_count}, UI=${ui_count}, diff=${diff} exceeds tolerance=${tolerance}
    Log    ✔ Count match: API=${api_count} | UI=${ui_count} | diff=${diff}

