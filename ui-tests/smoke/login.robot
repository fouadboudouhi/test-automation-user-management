*** Settings ***
Documentation     Smoke test verifying that login is possible.
Resource          ../resources/keywords/common.robot

*** Test Cases ***
Login Is Possible
    [Documentation]    Pass criteria: login completes (URL not containing /login anymore).
    [Tags]    smoke    login
    Wait For Elements State    css=[data-test="nav-sign-in"]    visible    timeout=20s
    Click    css=[data-test="nav-sign-in"]

    Wait For Elements State    css=input#email       visible    timeout=20s
    Wait For Elements State    css=input#password    visible    timeout=20s

    Fill Text    css=input#email       ${EMAIL}
    Fill Text    css=input#password    ${PASSWORD}
    Click        css=[data-test="login-submit"]

    # Robust: verify redirect away from /login instead of waiting for some element to detach
    Wait For Login To Complete
