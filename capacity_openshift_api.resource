*** Settings ***
Documentation    API Resource: VMware Capacity & OpenShift Endpoints.
...
...              VMware Capacity (Image 4):
...                GET  /api/vmware/capacity/filters   Distinct filter options (incremental)
...                GET  /api/vmware/capacity/stats     Overall stats based on filters
...                GET  /api/vmware/capacity/items     Paginated list based on filters
...
...              OpenShift (Images 4 & 5):
...                GET  /api/openshift/storageclass/capacity    Get Storageclass Capacity
...                GET  /api/openshift/table                    Get Table Rows
...                GET  /api/openshift/vm_inventory_mv          Get VM Inventory MV
...                GET  /api/openshift/vms                      Get Cluster VM Details
...                GET  /api/openshift/nodes                    Get Node Details
...                GET  /api/openshift/cluster_resource_details Get Cluster Resource Details

Library    RequestsLibrary
Library    Collections
Resource   api_client.resource

*** Variables ***
# ── VMware Capacity ───────────────────────────────────────────────
${CAP_API_FILTERS}     /api/vmware/capacity/filters
${CAP_API_STATS}       /api/vmware/capacity/stats
${CAP_API_ITEMS}       /api/vmware/capacity/items

# ── OpenShift ─────────────────────────────────────────────────────
${OCP_API_STORAGE_CAPACITY}       /api/openshift/storageclass/capacity
${OCP_API_TABLE}                  /api/openshift/table
${OCP_API_VM_INVENTORY_MV}        /api/openshift/vm_inventory_mv
${OCP_API_VMS}                    /api/openshift/vms
${OCP_API_NODES}                  /api/openshift/nodes
${OCP_API_CLUSTER_RESOURCES}      /api/openshift/cluster_resource_details

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# VMWARE CAPACITY
# ════════════════════════════════════════════════════════════════════

Get Capacity Filters
    [Documentation]    GET /api/vmware/capacity/filters – distinct incremental filter options.
    ${resp}=    GET Request    ${CAP_API_FILTERS}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get Capacity Stats
    [Arguments]    ${params}=${None}
    [Documentation]    GET /api/vmware/capacity/stats – overall stats based on filters.
    ${resp}=    GET Request    ${CAP_API_STATS}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get Capacity Items
    [Arguments]    ${params}=${None}
    [Documentation]    GET /api/vmware/capacity/items – paginated capacity list.
    ${resp}=    GET Request    ${CAP_API_ITEMS}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get Capacity Item Count From API
    [Documentation]    Returns total count from /api/vmware/capacity/items.
    ${resp}=    Get Capacity Items
    ${json}=    Parse JSON Response    ${resp}
    ${total}=    Run Keyword And Return If
    ...    'total' in $json    Get From Dictionary    ${json}    total
    ${total}=    Run Keyword If    '${total}' == '${None}'
    ...    Get JSON List Length    ${resp}    items
    Log    ✔ API capacity item count: ${total}
    [Return]    ${total}

# ════════════════════════════════════════════════════════════════════
# OPENSHIFT
# ════════════════════════════════════════════════════════════════════

Get OpenShift Storage Capacity
    ${resp}=    GET Request    ${OCP_API_STORAGE_CAPACITY}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get OpenShift Table Rows
    [Arguments]    ${params}=${None}
    ${resp}=    GET Request    ${OCP_API_TABLE}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get OpenShift VM Inventory
    [Arguments]    ${params}=${None}
    ${resp}=    GET Request    ${OCP_API_VM_INVENTORY_MV}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get OpenShift VMs
    [Arguments]    ${params}=${None}
    ${resp}=    GET Request    ${OCP_API_VMS}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get OpenShift Nodes
    [Arguments]    ${params}=${None}
    ${resp}=    GET Request    ${OCP_API_NODES}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get OpenShift Cluster Resource Details
    [Arguments]    ${params}=${None}
    ${resp}=    GET Request    ${OCP_API_CLUSTER_RESOURCES}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}
