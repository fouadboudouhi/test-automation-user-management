*** Settings ***
Documentation     Regression: verify Categories dropdown opens and contains entries.
Resource          ../../resources/keywords/common.robot

*** Test Cases ***
Categories Dropdown Contains Entries
    [Documentation]    Open Categories dropdown via stable data-test locator and assert it has at least 1 entry.
    [Tags]    regression

    # Strict-mode safe: use data-test instead of text=Categories (multiple matches on page).
    Click    css=[data-test="nav-categories"]

    # Wait until the bootstrap dropdown is actually open
    Wait For Elements State    css=ul.dropdown-menu.show    visible    timeout=10s

    # Assert at least one entry exists
    ${count}=    Get Element Count    css=ul.dropdown-menu.show a.dropdown-item
    Should Be True    ${count} > 0    msg=Expected at least 1 category entry, but found ${count}.