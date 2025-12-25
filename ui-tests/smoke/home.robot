*** Settings ***
Documentation     Smoke test verifying that the homepage is reachable.
Resource          ../resources/keywords/common.robot

*** Test Cases ***
Homepage Is Reachable
    [Documentation]    Pass criteria: body + navbar are visible.
    [Tags]    smoke    home
    Wait For Elements State    css=body         visible    timeout=20s
    Wait For Elements State    css=nav.navbar   visible    timeout=20s
