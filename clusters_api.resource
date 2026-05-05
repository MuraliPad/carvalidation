*** Settings ***
Documentation    API Resource: Clusters & Countries Endpoints.
...
...              Endpoints visible in Swagger (Image 3):
...                POST  /api/clusters/register                      Register Cluster
...                GET   /api/clusters/acm                           List ACM Clusters
...                PUT   /api/clusters/overview/{cluster_name}       Update Cluster Overview
...                GET   /api/countries                              List Countries
...                GET   /api/countries/{country_code}               Get Country
...                GET   /api/clusters/vmbuild                       Get Clusters For Vmbuild
...                PUT   /api/clusters/update_node_inventory         Update Node Inventory
...                GET   /api/clusters/vm_check                      List Cluster VMs

Library    RequestsLibrary
Library    Collections
Resource   api_client.resource

*** Variables ***
${CLUSTER_API_REGISTER}              /api/clusters/register
${CLUSTER_API_ACM}                   /api/clusters/acm
${CLUSTER_API_OVERVIEW}              /api/clusters/overview
${CLUSTER_API_VMBUILD}               /api/clusters/vmbuild
${CLUSTER_API_UPDATE_NODE}           /api/clusters/update_node_inventory
${CLUSTER_API_VM_CHECK}              /api/clusters/vm_check
${COUNTRIES_API}                     /api/countries

*** Keywords ***
# ════════════════════════════════════════════════════════════════════
# POST /api/clusters/register
# ════════════════════════════════════════════════════════════════════

Register Cluster
    [Arguments]    ${body}
    [Documentation]    POST /api/clusters/register with cluster registration payload.
    ${resp}=    POST Request    ${CLUSTER_API_REGISTER}    body=${body}    expected_status=200
    [Return]    ${resp}

# ════════════════════════════════════════════════════════════════════
# GET /api/clusters/acm
# ════════════════════════════════════════════════════════════════════

Get ACM Clusters
    [Documentation]    GET /api/clusters/acm – returns ACM cluster list.
    ${resp}=    GET Request    ${CLUSTER_API_ACM}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get ACM Cluster Count From API
    ${resp}=    Get ACM Clusters
    ${count}=   Get JSON List Length    ${resp}    items
    Log    ✔ API ACM cluster count: ${count}
    [Return]    ${count}

# ════════════════════════════════════════════════════════════════════
# PUT /api/clusters/overview/{cluster_name}
# ════════════════════════════════════════════════════════════════════

Update Cluster Overview
    [Arguments]    ${cluster_name}    ${body}
    [Documentation]    PUT /api/clusters/overview/{cluster_name}.
    ${resp}=    PUT Request    ${CLUSTER_API_OVERVIEW}/${cluster_name}    body=${body}
    [Return]    ${resp}

# ════════════════════════════════════════════════════════════════════
# GET /api/countries  and  GET /api/countries/{country_code}
# ════════════════════════════════════════════════════════════════════

Get All Countries
    ${resp}=    GET Request    ${COUNTRIES_API}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

Get Country By Code
    [Arguments]    ${country_code}
    ${resp}=    GET Request    ${COUNTRIES_API}/${country_code}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

# ════════════════════════════════════════════════════════════════════
# GET /api/clusters/vm_check
# ════════════════════════════════════════════════════════════════════

Get Cluster VM List
    [Arguments]    ${params}=${None}
    ${resp}=    GET Request    ${CLUSTER_API_VM_CHECK}    params=${params}
    Response Should Be 200    ${resp}
    [Return]    ${resp}

# ════════════════════════════════════════════════════════════════════
# GET /api/clusters/vmbuild
# ════════════════════════════════════════════════════════════════════

Get Clusters For Vmbuild
    ${resp}=    GET Request    ${CLUSTER_API_VMBUILD}
    Response Should Be 200    ${resp}
    [Return]    ${resp}
