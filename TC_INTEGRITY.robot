*** Settings ***
Documentation     Suite: UI ↔ API Integrity Tests
...
...               These tests open a real browser AND call the API simultaneously,
...               then compare the two data sources to confirm they are consistent.
...
...               ┌──────────────────────────────────────────────────────────┐
...               │  INTEGRITY TEST PATTERNS USED                           │
...               │                                                          │
...               │  1. COUNT MATCH                                          │
...               │     API total == UI "Showing X of Y" count               │
...               │     e.g. VM count, ESX count                             │
...               │                                                          │
...               │  2. CONFIGURE IN UI → VERIFY VIA API                    │
...               │     Apply filter in UI → API query with same filter      │
...               │     → row counts and key field values must match         │
...               │                                                          │
...               │  3. API DATA PRESENT IN UI TABLE                        │
...               │     First record from API → verify row visible in UI    │
...               │                                                          │
...               │  4. SURVEY SUBMIT IN UI → VERIFY STATUS VIA API         │
...               │     Submit ITSO survey in UI → GET isSurveySubmitted    │
...               │     → API must return is_submitted = true               │
...               └──────────────────────────────────────────────────────────┘
...
...               Tags: integrity  api  ui

Metadata          Module     Integrity – UI ↔ API
Metadata          Priority   P1

Library           RequestsLibrary
Library           SeleniumLibrary
Library           Collections
Library           String

Resource          ../../resources/base/browser_setup.resource
Resource          ../../resources/pages/login_page.resource
Resource          ../../resources/components/sidebar_nav.resource
Resource          ../../resources/pages/inventory_page.resource
Resource          ../../resources/api/api_client.resource
Resource          ../../resources/api/inventory_api.resource
Resource          ../../resources/api/clusters_api.resource
Resource          ../../resources/api/capacity_openshift_api.resource
Resource          ../../resources/api/itso_optimization_api.resource

Suite Setup       Run Keywords
...               Create API Session                     AND
...               Open Browser And Navigate To App       AND
...               Login Via SSO And Wait For App Shell
Suite Teardown    Run Keywords
...               Delete API Session    AND
...               Close All Browser Windows

Test Tags         integrity

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# PRIVATE – UI COUNT EXTRACTION
# ════════════════════════════════════════════════════════════════════

_Get UI Pagination Total Count
    [Documentation]    Reads "Showing X to Y of Z results" from the page and
    ...                returns Z (the total count) as an integer.
    Wait Until Element Is Visible    ${INV_PAGINATION_INFO}    timeout=${EXPLICIT_WAIT}
    ${paging_text}=    Get Text    ${INV_PAGINATION_INFO}
    # e.g. "Showing 1 to 50 of 342 results"  →  extract 342
    ${match}=    Should Match Regexp    ${paging_text}
    ...    Showing\\s+\\d+\\s+to\\s+\\d+\\s+of\\s+(\\d+)\\s+results
    ${total_str}=    Get Regexp Group    ${paging_text}
    ...    Showing\\s+\\d+\\s+to\\s+\\d+\\s+of\\s+(\\d+)\\s+results    1
    ${total}=    Convert To Integer    ${total_str}
    Log    UI pagination total: ${total}
    [Return]    ${total}

_Get UI Visible Row Count
    [Documentation]    Returns the number of tbody rows currently rendered.
    ${rows}=    Get WebElements    ${INV_TABLE_BODY_ROWS}
    ${count}=   Get Length         ${rows}
    [Return]    ${count}

Get Regexp Group
    [Arguments]    ${string}    ${pattern}    ${group}
    [Documentation]    Extracts a capture group from a regex match.
    ${match}=    Evaluate
    ...    __import__('re').search(r'${pattern}', '${string}').group(${group})
    [Return]    ${match}

*** Test Cases ***
# ════════════════════════════════════════════════════════════════════
# TC_INT_COUNT – COUNT MATCH TESTS
# API total count must equal the UI pagination total count
# ════════════════════════════════════════════════════════════════════

TC_INT_COUNT_001 VM Count From API Matches UI Inventory Total
    [Documentation]    INTEGRITY: GET /api/inventory/vms total count
    ...                must equal the "Showing X of Y" total on the
    ...                VM Inventory page within tolerance=${COUNT_TOLERANCE}.
    ...
    ...                Steps:
    ...                  1. Call API → get total VM count
    ...                  2. Navigate UI to VM Inventory view
    ...                  3. Read "Showing X to Y of Z results" → extract Z
    ...                  4. Assert API count == UI count ± tolerance
    [Tags]    smoke    P1    count    vm
    # ── Step 1: API count ──
    ${api_count}=    Get VM Count From API
    Log    API VM count: ${api_count}

    # ── Step 2: UI count ──
    Navigate To Inventory Via Sidebar
    Select Inventory Type    VM
    Verify Table Is Visible
    ${ui_count}=    _Get UI Pagination Total Count

    # ── Step 3: Compare ──
    Counts Should Match Within Tolerance    ${api_count}    ${ui_count}
    Capture Step Screenshot    integrity_vm_count_match

TC_INT_COUNT_002 ESX Host Count From API Matches UI ESX Inventory Total
    [Documentation]    INTEGRITY: GET /api/inventory/esx total count
    ...                must equal the ESX Inventory pagination total in UI.
    [Tags]    smoke    P1    count    esx
    # ── API ──
    ${api_count}=    Get ESX Count From API

    # ── UI ──
    Navigate To Inventory Via Sidebar
    Select Inventory Type    ESX
    Verify Table Is Visible
    ${ui_count}=    _Get UI Pagination Total Count

    # ── Compare ──
    Counts Should Match Within Tolerance    ${api_count}    ${ui_count}
    Capture Step Screenshot    integrity_esx_count_match

TC_INT_COUNT_003 Capacity Item Count From API Matches UI Capacity Page Total
    [Documentation]    INTEGRITY: GET /api/vmware/capacity/items total count
    ...                must match the capacity page table row total.
    [Tags]    regression    P2    count    capacity
    # ── API ──
    ${api_count}=    Get Capacity Item Count From API

    # ── UI ──
    Navigate To Capacity Via Sidebar
    Wait For Page To Be Ready
    ${ui_count}=    _Get UI Pagination Total Count

    # ── Compare ──
    Counts Should Match Within Tolerance    ${api_count}    ${ui_count}
    Capture Step Screenshot    integrity_capacity_count_match

# ════════════════════════════════════════════════════════════════════
# TC_INT_FILTER – CONFIGURE FILTER IN UI → VERIFY VIA API
# Apply a filter in the UI, then call the API with the same filter
# and confirm the result counts match.
# ════════════════════════════════════════════════════════════════════

TC_INT_FILTER_001 Filter By Datacenter In UI Matches API Filtered Count
    [Documentation]    INTEGRITY: Apply Datacenter filter "GB-WGDC" in UI,
    ...                read filtered total, then call API with same filter,
    ...                assert counts match.
    ...
    ...                Steps:
    ...                  1. UI: Navigate to VM Inventory
    ...                  2. UI: Apply Datacenter column filter = GB-WGDC
    ...                  3. UI: Read filtered total from pagination
    ...                  4. API: GET /api/inventory/vms?datacenter=GB-WGDC
    ...                  5. Assert UI total == API total
    [Tags]    regression    P1    filter    vm
    ${test_datacenter}=    Set Variable    GB-WGDC

    # ── UI: apply filter ──
    Navigate To Inventory Via Sidebar
    Select Inventory Type    VM
    Verify Table Is Visible
    Click Column Filter    Datacenter
    # Filter panel opens – type/select the datacenter value
    # (locator may need adjustment once filter panel DOM is inspected)
    ${filter_input}=    Set Variable
    ...    xpath=//*[@role='dialog' or @role='menu' or contains(@class,'filter-panel')]//input
    Wait Until Element Is Visible    ${filter_input}    timeout=5s
    Input Text    ${filter_input}    ${test_datacenter}
    # Confirm / close filter
    Press Key    xpath=//body    \\13
    Wait For Page To Be Ready
    ${ui_filtered_count}=    _Get UI Pagination Total Count
    Log    UI filtered count (Datacenter=${test_datacenter}): ${ui_filtered_count}
    Capture Step Screenshot    integrity_filter_ui_applied

    # ── API: same filter ──
    ${params}=    Create Dictionary    datacenter=${test_datacenter}
    ${resp}=      Get All VMs    params=${params}
    ${json}=      Parse JSON Response    ${resp}
    ${api_filtered_count}=    Get From Dictionary    ${json}    total
    Log    API filtered count (Datacenter=${test_datacenter}): ${api_filtered_count}

    # ── Compare ──
    Counts Should Match Within Tolerance    ${api_filtered_count}    ${ui_filtered_count}
    Capture Step Screenshot    integrity_filter_match

TC_INT_FILTER_002 Filter By Region EMEA In UI Matches API Filtered Count
    [Documentation]    INTEGRITY: Apply Region filter "EMEA" in UI,
    ...                compare filtered count against API with region=EMEA.
    [Tags]    regression    P2    filter    vm
    ${test_region}=    Set Variable    EMEA

    # ── UI ──
    Navigate To Inventory Via Sidebar
    Select Inventory Type    VM
    Click Column Filter    Region
    ${filter_input}=    Set Variable
    ...    xpath=//*[@role='dialog' or @role='menu' or contains(@class,'filter-panel')]//input
    Wait Until Element Is Visible    ${filter_input}    timeout=5s
    Input Text    ${filter_input}    ${test_region}
    Press Key    xpath=//body    \\13
    Wait For Page To Be Ready
    ${ui_filtered_count}=    _Get UI Pagination Total Count
    Capture Step Screenshot    integrity_region_filter_ui

    # ── API ──
    ${params}=    Create Dictionary    region=${test_region}
    ${resp}=      Get All VMs    params=${params}
    ${json}=      Parse JSON Response    ${resp}
    ${api_filtered_count}=    Get From Dictionary    ${json}    total

    # ── Compare ──
    Counts Should Match Within Tolerance    ${api_filtered_count}    ${ui_filtered_count}

# ════════════════════════════════════════════════════════════════════
# TC_INT_DATA – API FIRST RECORD PRESENT IN UI TABLE
# Fetch first record from API, confirm that row is visible in UI table
# ════════════════════════════════════════════════════════════════════

TC_INT_DATA_001 First ESX Host From API Is Visible In UI Table
    [Documentation]    INTEGRITY: Get ESX inventory from API, take the first
    ...                hostname, then verify that hostname appears in the UI table.
    ...
    ...                Steps:
    ...                  1. API: GET /api/inventory/esx → first item hostname
    ...                  2. UI: Navigate to ESX Inventory
    ...                  3. UI: Confirm that hostname is visible in table
    [Tags]    regression    P1    data    esx
    # ── API: get first ESX hostname ──
    ${resp}=    Get ESX Inventory
    ${json}=    Parse JSON Response    ${resp}
    # Handle both {items: [...]} and direct list response shapes
    ${items}=    Run Keyword And Return If
    ...    'items' in $json    Get From Dictionary    ${json}    items
    ${items}=    Run Keyword If    '${items}' == '${None}'
    ...    Set Variable    ${json}
    ${first_host}=    Get From List    ${items}    0
    ${hostname}=      Get From Dictionary    ${first_host}    name
    Log    First ESX hostname from API: ${hostname}

    # ── UI: find that host in the table ──
    Navigate To Inventory Via Sidebar
    Select Inventory Type    ESX
    Verify Table Is Visible
    ${host_in_ui}=    Set Variable
    ...    xpath=//tbody//tr[@data-slot='table-row']//*[contains(normalize-space(text()),'${hostname}')]
    Wait Until Element Is Visible    ${host_in_ui}    timeout=${EXPLICIT_WAIT}
    ...    error=❌ ESX host "${hostname}" returned by API not found in UI table
    Log    ✔ API host "${hostname}" confirmed visible in UI table
    Capture Step Screenshot    integrity_first_esx_in_ui

TC_INT_DATA_002 First VM From API Has Matching Row In UI VM Inventory
    [Documentation]    INTEGRITY: Get VMs from API, take first VM name,
    ...                confirm that row appears in UI VM Inventory table.
    [Tags]    regression    P2    data    vm
    # ── API ──
    ${resp}=      Get All VMs
    ${json}=      Parse JSON Response    ${resp}
    ${items}=     Run Keyword And Return If
    ...    'items' in $json    Get From Dictionary    ${json}    items
    ${items}=     Run Keyword If    '${items}' == '${None}'    Set Variable    ${json}
    ${first_vm}=  Get From List       ${items}    0
    # Try common name keys
    ${vm_name}=   Run Keyword And Return If
    ...    'name' in $first_vm    Get From Dictionary    ${first_vm}    name
    ${vm_name}=   Run Keyword If    '${vm_name}' == '${None}'
    ...    Get From Dictionary    ${first_vm}    vm_name
    Log    First VM from API: ${vm_name}

    # ── UI ──
    Navigate To Inventory Via Sidebar
    Select Inventory Type    VM
    Verify Table Is Visible
    ${vm_in_ui}=    Set Variable
    ...    xpath=//tbody//tr[@data-slot='table-row']//*[contains(normalize-space(text()),'${vm_name}')]
    Wait Until Element Is Visible    ${vm_in_ui}    timeout=${EXPLICIT_WAIT}
    ...    error=❌ VM "${vm_name}" from API not found in UI VM Inventory table
    Log    ✔ API VM "${vm_name}" confirmed in UI table
    Capture Step Screenshot    integrity_first_vm_in_ui

# ════════════════════════════════════════════════════════════════════
# TC_INT_SURVEY – SUBMIT IN UI → VERIFY VIA API
# ════════════════════════════════════════════════════════════════════

TC_INT_SURVEY_001 ITSO Survey Pre-Submit State – API Reflects Not Submitted
    [Documentation]    INTEGRITY: Before any submission in this test run,
    ...                GET /api/itsoSurvey/isSurveySubmitted must return false.
    ...                (Pre-condition check – run before TC_INT_SURVEY_002)
    [Tags]    regression    P2    survey    itso
    Survey Should Not Be Submitted

TC_INT_SURVEY_002 Submit ITSO Survey In UI Then Verify Via API
    [Documentation]    INTEGRITY: Navigate to ITSO Communication page, submit
    ...                the survey form, then call the API to confirm
    ...                isSurveySubmitted = true.
    ...
    ...                Steps:
    ...                  1. API: assert not yet submitted (pre-condition)
    ...                  2. UI: Navigate to ITSO Communication
    ...                  3. UI: Fill in and submit the survey form
    ...                  4. API: GET isSurveySubmitted → must be true
    [Tags]    regression    P1    survey    itso    e2e
    # ── Pre-condition via API ──
    Survey Should Not Be Submitted

    # ── UI: Navigate to ITSO Communication ──
    Click Nav Item    ITSO Communication
    Wait For Page To Be Ready
    Capture Step Screenshot    integrity_itso_page_loaded

    # ── UI: Submit survey ──
    # TODO: Adjust locators once ITSO survey form DOM is inspected
    ${submit_btn}=    Set Variable
    ...    xpath=//button[contains(normalize-space(.),'Submit') or contains(normalize-space(.),'Save')]
    Wait Until Element Is Visible    ${submit_btn}    timeout=${EXPLICIT_WAIT}
    Click Element    ${submit_btn}
    Wait For Page To Be Ready
    Capture Step Screenshot    integrity_itso_submitted

    # ── Post-condition via API ──
    # Small wait for backend to process
    Sleep    2s
    Survey Should Be Submitted
    Log    ✔ INTEGRITY: ITSO survey submitted in UI → confirmed via API

# ════════════════════════════════════════════════════════════════════
# TC_INT_PERF – API RESPONSE TIME WHILE UI IS LOADED
# ════════════════════════════════════════════════════════════════════

TC_INT_PERF_001 VM API Response Time Acceptable During Active UI Session
    [Documentation]    INTEGRITY + PERFORMANCE: While the UI is loaded and
    ...                active, the API should still respond within 3 seconds.
    ...                Detects backend degradation under UI load.
    [Tags]    regression    P2    performance
    Navigate To Inventory Via Sidebar
    Select Inventory Type    VM
    Verify Table Is Visible
    # Make API call while browser session is active
    ${resp}=    Get All VMs
    Response Time Should Be Within    ${resp}    3000
    Log    ✔ API responded within threshold while UI is active

TC_INT_PERF_002 ESX API Response Time Acceptable During Active UI Session
    [Tags]    regression    P2    performance
    Navigate To Inventory Via Sidebar
    Select Inventory Type    ESX
    Verify Table Is Visible
    ${resp}=    Get ESX Inventory
    Response Time Should Be Within    ${resp}    3000
