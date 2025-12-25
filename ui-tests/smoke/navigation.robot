*** Settings ***
Documentation     Smoke test verifying that navigation is present.
Resource          ../resources/keywords/common.robot

*** Test Cases ***
Navigation Is Visible
    [Documentation]    Pass criteria: navbar is visible.
    [Tags]    smoke    navigation
    Wait For Elements State    css=nav.navbar    visible    timeout=20s
