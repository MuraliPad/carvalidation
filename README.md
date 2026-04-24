# MiO-X Robot Framework Test Suite — Boilerplate

> **Application:** MiO-X – The Autonomous Migration Engine
> **Framework:** Robot Framework + SeleniumLibrary + Allure

---

## Architecture

```
miox_tests/
│
├── config/
│   └── global_variables.robot        ← Single source of truth for all env/config vars
│
├── resources/
│   ├── base/
│   │   ├── browser_setup.resource    ← Browser open/close, waits, screenshots (NO page logic)
│   │   └── base_page.resource        ← Abstract base: shell locators + "Verify This Page Is Loaded" contract
│   │
│   ├── components/
│   │   └── sidebar_nav.resource      ← Shared component present on ALL pages after login
│   │                                    (Add: topbar.resource, modal.resource, table.resource, etc.)
│   │
│   └── pages/
│       ├── login_page.resource       ← Login page locators + keywords
│       ├── inventory_page.resource   ← Inventory page locators + keywords
│       ├── capacity_page.resource    ← STUB – extend as page is built
│       └── <new_page>.resource       ← ADD NEW PAGES HERE following the pattern below
│
├── tests/
│   ├── login/
│   │   └── TC_LOGIN.robot
│   └── inventory/
│       ├── TC_NAV.robot              ← Navigation/landing page tests
│       ├── TC_INVENTORY_DROPDOWN.robot
│       └── TC_ESX_TABLE.robot
│
├── results/                          ← Auto-created; .gitignore this
│   └── screenshots/
│
├── requirements.txt
├── run_tests.sh
└── README.md
```

---

## Layer Responsibilities

| Layer | File type | Rule |
|-------|-----------|------|
| **Config** | `global_variables.robot` | Variables ONLY. No keywords. |
| **Base** | `browser_setup.resource`, `base_page.resource` | Generic reusable keywords. Zero page knowledge. |
| **Component** | `components/*.resource` | Shared UI components (nav, modals, tables). Used by many pages. |
| **Page Object** | `pages/*.resource` | ONE file per page. Locators + keywords for THAT page only. |
| **Test Suite** | `tests/**/*.robot` | Thin. Calls keywords only. Zero locators. Zero HTML. |

---

## How To Add A New Page

**1. Create the page object** in `resources/pages/`:

```robotframework
*** Settings ***
Resource    ../base/base_page.resource   # ALWAYS import this

*** Variables ***
${MY_PAGE_TITLE}    xpath=...            # locators for THIS page

*** Keywords ***
Verify This Page Is Loaded               # MUST override this contract keyword
    Wait Until Element Is Visible    ${MY_PAGE_TITLE}
    Element Should Contain           ${MY_PAGE_TITLE}    Expected Title

# Add page-specific keywords below...
```

**2. Create the test suite** in `tests/<module>/`:

```robotframework
*** Settings ***
Resource    ../../resources/base/browser_setup.resource
Resource    ../../resources/pages/login_page.resource
Resource    ../../resources/components/sidebar_nav.resource
Resource    ../../resources/pages/my_new_page.resource

Suite Setup    Run Keywords
...    Open Browser And Navigate To App    AND
...    Login Via SSO And Wait For App Shell    AND
...    Navigate To My Page Via Sidebar    AND
...    Verify This Page Is Loaded

*** Test Cases ***
TC_XXX_001 My First Test
    [Tags]    smoke    P1
    My Page Keyword Here
```

**That's it.** No changes needed to any other file.

---

## Running Tests

```bash
# Install dependencies
pip install -r requirements.txt

# All tests, local Chrome
robot --listener allure_robotframework -d results tests/

# Smoke only
robot --listener allure_robotframework --include smoke -d results tests/

# Remote Selenium Grid
robot --listener allure_robotframework \
      --variable USE_REMOTE:True \
      --variable REMOTE_URL:http://<grid-host>:4444/wd/hub \
      -d results tests/

# Single suite
robot --listener allure_robotframework -d results tests/inventory/TC_ESX_TABLE.robot

# Allure live report
allure serve results/allure
```

---

## Key Variables (override at CLI)

| Variable | Default | Example override |
|----------|---------|-----------------|
| `BASE_URL` | dev URL | `--variable BASE_URL:https://miox-prod.example.com` |
| `BROWSER` | `chrome` | `--variable BROWSER:firefox` |
| `USE_REMOTE` | `${FALSE}` | `--variable USE_REMOTE:True` |
| `REMOTE_URL` | localhost:4444 | `--variable REMOTE_URL:http://grid:4444/wd/hub` |

---

## Tag Convention

| Tag | Meaning |
|-----|---------|
| `smoke` | Must-pass before every deploy |
| `regression` | Full regression cycle |
| `P1` / `P2` / `P3` | Priority |
| `login` `navigation` `inventory` `esx` `dropdown` | Module |
