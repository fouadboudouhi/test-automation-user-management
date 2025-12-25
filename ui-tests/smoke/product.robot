*** Settings ***
Documentation     Smoke test verifying that at least one product card is visible.
Resource          ../resources/keywords/common.robot

*** Test Cases ***
Product Page Is Reachable
    [Documentation]    Pass criteria: at least 1 product card becomes visible (handles slow startup).
    [Tags]    smoke    product
    Wait For At Least One Product Card
    ${count}=    Get Element Count    css=a.card[data-test^="product-"]
    Should Be True    ${count} > 0
