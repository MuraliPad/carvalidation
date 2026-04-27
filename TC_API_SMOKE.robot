*** Settings ***
Documentation     Suite: API Smoke Tests – Auth Validation + Endpoint Health Checks
...
...               Execution order:
...                 1. TC_AUTH_* – validates the full auth flow first
...                    (JSON file load → token fetch → token format → session)
...                 2. TC_API_*  – endpoint health checks using the live token
...
...               Auth flow (Suite Setup):
...                 Reads config/testdata/user_details.json
...                 → POST /api/auth/token
...                 → parses access_token
...                 → creates session with Authorization: Bearer <token>
...
...               Run all API tests:
...                 robot --include api tests\api\
...
...               Run auth tests only:
...                 robot --include auth tests\api\
...
...               Run endpoint health only:
...                 robot --include health tests\api\
...
...               Requires: pip install robotframework-requests

Metadata          Module      API – Auth + Endpoint Health
Metadata          Priority    P1

Library           RequestsLibrary
Resource          ../../resources/api/auth_api.resource
Resource          ../../resources/api/api_client.resource
Resource          ../../resources/api/inventory_api.resource
Resource          ../../resources/api/migration_api.resource
Resource          ../../resources/api/clusters_api.resource
Resource          ../../resources/api/capacity_openshift_api.resource
Resource          ../../resources/api/itso_optimization_api.resource

Suite Setup       Authenticate And Create Session
Suite Teardown    Delete API Session
Test Tags         api

# ════════════════════════════════════════════════════════════════════
# TC_AUTH – Authentication Flow Validation
#
# These tests validate the full auth pipeline:
#   user_details.json → POST /api/auth/token → Bearer token → session
#
# Run these FIRST before any endpoint tests.
# If TC_AUTH_001 fails, all downstream tests will also fail.
# ════════════════════════════════════════════════════════════════════
*** Test Cases ***
TC_AUTH_001 User Details JSON File Exists And Is Readable
    [Documentation]    Confirms config/testdata/user_details.json exists
    ...                and can be read. This is the credentials source for
    ...                all API authentication in this framework.
    [Tags]    auth    smoke    P1
    File Should Exist    ${USER_DETAILS_FILE}
    ...    msg=user_details.json not found at ${USER_DETAILS_FILE}. Create it at config/testdata/user_details.json
    ${raw}=    Get File    ${USER_DETAILS_FILE}
    Should Not Be Empty    ${raw}
    ...    msg=user_details.json is empty. It must contain name, email and employeeID.
    Log    ✔ user_details.json found and readable

TC_AUTH_002 User Details JSON Contains All Required Fields
    [Documentation]    Parses user_details.json and asserts that all three
    ...                required fields are present and non-empty:
    ...                  name, email, employeeID
    [Tags]    auth    smoke    P1
    ${raw}=       Get File    ${USER_DETAILS_FILE}
    ${user}=      Evaluate    __import__('json').loads($raw)
    Dictionary Should Contain Key    ${user}    name
    ...    msg=user_details.json missing required field: "name"
    Dictionary Should Contain Key    ${user}    email
    ...    msg=user_details.json missing required field: "email"
    Dictionary Should Contain Key    ${user}    employeeID
    ...    msg=user_details.json missing required field: "employeeID"
    Should Not Be Empty    ${user}[name]
    ...    msg=user_details.json field "name" is empty
    Should Not Be Empty    ${user}[email]
    ...    msg=user_details.json field "email" is empty
    Should Not Be Empty    ${user}[employeeID]
    ...    msg=user_details.json field "employeeID" is empty
    Log    ✔ All required fields present: name=${user}[name] email=${user}[email] employeeID=${user}[employeeID]

TC_AUTH_003 POST /api/auth/token Returns HTTP 200
    [Documentation]    Sends the credentials from user_details.json to
    ...                POST /api/auth/token and asserts HTTP 200 is returned.
    [Tags]    auth    smoke    P1
    ${credentials}=    _Load User Details
    _Create Auth Session
    ${resp}=    POST On Session
    ...    alias=${AUTH_SESSION_ALIAS}
    ...    url=${AUTH_TOKEN_PATH}
    ...    json=${credentials}
    ...    expected_status=200
    _Delete Auth Session
    Log    ✔ POST ${AUTH_TOKEN_PATH} → HTTP ${resp.status_code}

TC_AUTH_004 Auth Response Contains access_token Field
    [Documentation]    Asserts the auth response body contains the
    ...                "access_token" field.
    [Tags]    auth    smoke    P1
    ${credentials}=    _Load User Details
    _Create Auth Session
    ${resp}=    POST On Session
    ...    alias=${AUTH_SESSION_ALIAS}
    ...    url=${AUTH_TOKEN_PATH}
    ...    json=${credentials}
    ...    expected_status=200
    _Delete Auth Session
    ${json}=    Evaluate    $resp.json()
    Dictionary Should Contain Key    ${json}    access_token
    ...    msg=Auth response missing "access_token". Body: ${resp.text[:300]}
    Log    ✔ "access_token" key present in auth response

TC_AUTH_005 Auth Response Contains token_type Field Equal To bearer
    [Documentation]    Asserts the auth response body contains
    ...                "token_type": "bearer" (case-insensitive).
    [Tags]    auth    smoke    P1
    ${credentials}=    _Load User Details
    _Create Auth Session
    ${resp}=    POST On Session
    ...    alias=${AUTH_SESSION_ALIAS}
    ...    url=${AUTH_TOKEN_PATH}
    ...    json=${credentials}
    ...    expected_status=200
    _Delete Auth Session
    ${json}=         Evaluate    $resp.json()
    ${token_type}=   Evaluate    $json['token_type'].lower()
    Should Be Equal As Strings    ${token_type}    bearer
    ...    msg=Expected token_type "bearer", got "${token_type}"
    Log    ✔ token_type = "${token_type}"

TC_AUTH_006 Access Token Value Is Not Empty
    [Documentation]    Asserts the parsed access_token is a non-empty string.
    [Tags]    auth    smoke    P1
    ${credentials}=    _Load User Details
    _Create Auth Session
    ${resp}=    POST On Session
    ...    alias=${AUTH_SESSION_ALIAS}
    ...    url=${AUTH_TOKEN_PATH}
    ...    json=${credentials}
    ...    expected_status=200
    _Delete Auth Session
    ${json}=     Evaluate    $resp.json()
    ${token}=    Get From Dictionary    ${json}    access_token
    Should Not Be Empty    ${token}
    ...    msg=access_token is present but empty in auth response
    Log    ✔ access_token is non-empty (first 20 chars): ${token[:20]}...

TC_AUTH_007 Suite Variable API_TOKEN Is Set And Formatted As Bearer Token
    [Documentation]    Asserts the suite-level ${API_TOKEN} variable was
    ...                populated by Suite Setup and has the correct format:
    ...                "Bearer <token>" – this is what gets sent in the
    ...                Authorization header of every API request.
    [Tags]    auth    smoke    P1
    Verify Token Is Set
    Log    ✔ ${API_TOKEN[:30]}... (truncated)

TC_AUTH_008 Auth Token Is Accepted By A Protected Endpoint
    [Documentation]    End-to-end auth validation: uses the Bearer token
    ...                obtained in Suite Setup to call a protected endpoint
    ...                and asserts HTTP 200 (not 401 Unauthorized).
    ...                Proves the token is valid and the session is working.
    [Tags]    auth    smoke    P1
    ${resp}=    Get All VMs
    Response Should Be 200    ${resp}
    Log    ✔ Protected endpoint accepted Bearer token → HTTP 200

# ════════════════════════════════════════════════════════════════════
# TC_API_INV – Inventory Endpoints
# ════════════════════════════════════════════════════════════════════

TC_API_INV_001 GET /api/inventory/vms Returns 200
    [Documentation]    GET /api/inventory/vms → HTTP 200 + non-empty body.
    [Tags]    health    smoke    P1    inventory
    ${resp}=    Get All VMs
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_INV_002 GET /api/inventory/vms Response Time Is Acceptable
    [Documentation]    Response must arrive within 3000ms.
    [Tags]    health    smoke    P2    inventory    performance
    ${resp}=    Get All VMs
    Response Time Should Be Within    ${resp}    3000

TC_API_INV_003 GET /api/inventory/vms/filters Returns 200
    [Tags]    health    smoke    P1    inventory
    ${resp}=    Get VM Filter Options
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_INV_004 GET /api/inventory/migration-categories Returns 200
    [Tags]    health    smoke    P1    inventory
    ${resp}=    Get Migration Categories
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_INV_005 GET /api/inventory/country-vm-summary Returns 200
    [Tags]    health    smoke    P1    inventory
    ${resp}=    Get Country VM Summary
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_INV_006 GET /api/inventory/esx Returns 200
    [Tags]    health    smoke    P1    inventory
    ${resp}=    Get ESX Inventory
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

# ════════════════════════════════════════════════════════════════════
# TC_API_MIG – Migration Endpoints
# ════════════════════════════════════════════════════════════════════

TC_API_MIG_001 GET /api/migration/ansible-job-status Returns 200
    [Tags]    health    smoke    P1    migration
    ${resp}=    Get Ansible Job Status
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_MIG_002 GET /api/migration/ansible-job-logs Returns 200
    [Tags]    health    smoke    P2    migration
    ${resp}=    Get Ansible Job Logs
    Response Should Be 200          ${resp}

# ════════════════════════════════════════════════════════════════════
# TC_API_CLU – Cluster Endpoints
# ════════════════════════════════════════════════════════════════════

TC_API_CLU_001 GET /api/clusters/acm Returns 200
    [Tags]    health    smoke    P1    clusters
    ${resp}=    Get ACM Clusters
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_CLU_002 GET /api/countries Returns 200
    [Tags]    health    smoke    P1    clusters
    ${resp}=    Get All Countries
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_CLU_003 GET /api/clusters/vmbuild Returns 200
    [Tags]    health    smoke    P2    clusters
    ${resp}=    Get Clusters For Vmbuild
    Response Should Be 200          ${resp}

TC_API_CLU_004 GET /api/clusters/vm_check Returns 200
    [Tags]    health    smoke    P2    clusters
    ${resp}=    Get Cluster VM List
    Response Should Be 200          ${resp}

# ════════════════════════════════════════════════════════════════════
# TC_API_CAP – VMware Capacity Endpoints
# ════════════════════════════════════════════════════════════════════

TC_API_CAP_001 GET /api/vmware/capacity/filters Returns 200
    [Tags]    health    smoke    P1    capacity
    ${resp}=    Get Capacity Filters
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_CAP_002 GET /api/vmware/capacity/stats Returns 200
    [Tags]    health    smoke    P1    capacity
    ${resp}=    Get Capacity Stats
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_CAP_003 GET /api/vmware/capacity/items Returns 200
    [Tags]    health    smoke    P1    capacity
    ${resp}=    Get Capacity Items
    Response Should Be 200          ${resp}

# ════════════════════════════════════════════════════════════════════
# TC_API_OCP – OpenShift Endpoints
# ════════════════════════════════════════════════════════════════════

TC_API_OCP_001 GET /api/openshift/storageclass/capacity Returns 200
    [Tags]    health    smoke    P1    openshift
    ${resp}=    Get OpenShift Storage Capacity
    Response Should Be 200          ${resp}

TC_API_OCP_002 GET /api/openshift/table Returns 200
    [Tags]    health    smoke    P1    openshift
    ${resp}=    Get OpenShift Table Rows
    Response Should Be 200          ${resp}

TC_API_OCP_003 GET /api/openshift/vms Returns 200
    [Tags]    health    smoke    P2    openshift
    ${resp}=    Get OpenShift VMs
    Response Should Be 200          ${resp}

TC_API_OCP_004 GET /api/openshift/nodes Returns 200
    [Tags]    health    smoke    P2    openshift
    ${resp}=    Get OpenShift Nodes
    Response Should Be 200          ${resp}

# ════════════════════════════════════════════════════════════════════
# TC_API_ITSO – ITSO Survey Endpoints
# ════════════════════════════════════════════════════════════════════

TC_API_ITSO_001 GET /api/itsoSurvey/getServicesUnderITSO Returns 200
    [Tags]    health    smoke    P1    itso
    ${resp}=    Get Services Under ITSO
    Response Should Be 200          ${resp}
    Response Should Not Be Empty    ${resp}

TC_API_ITSO_002 GET /api/itsoSurvey/isSurveySubmitted Returns 200
    [Tags]    health    smoke    P1    itso
    ${resp}=    Get Survey Submission Status
    Response Should Be 200          ${resp}

TC_API_ITSO_003 GET /api/itsoSurvey/prepopulate Returns 200
    [Tags]    health    smoke    P2    itso
    ${resp}=    Get Prepopulate Data
    Response Should Be 200          ${resp}

TC_API_ITSO_004 GET /api/getCommHistory Returns 200
    [Tags]    health    smoke    P2    itso
    ${resp}=    Get Communication History
    Response Should Be 200          ${resp}
