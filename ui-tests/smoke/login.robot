*** Settings ***
Documentation     Smoke test verifying that login changes authentication state.
Resource          ../resources/keywords/common.robot
Suite Setup       Open Toolshop
Suite Teardown    Close Toolshop

*** Test Cases ***
Login Is Possible
    [Tags]    smoke    login

    # Open login form
    Wait For Elements State    css=[data-test="nav-sign-in"]    visible    timeout=20s
    Click    css=[data-test="nav-sign-in"]

    # Fill credentials
    Wait For Elements State    css=input#email       visible    timeout=20s
    Wait For Elements State    css=input#password    visible    timeout=20s

    Fill Text    css=input#email       ${EMAIL}
    Fill Text    css=input#password    ${PASSWORD}
    Click        css=[data-test="login-submit"]

    # Smoke-level assertion:
    # login is successful when sign-in disappears
    # and account navigation becomes available
    Wait Until Keyword Succeeds    20s    1s    Login Navigation Should Be Visible


*** Keywords ***
Login Navigation Should Be Visible
    ${signin}=    Get Element Count    css=[data-test="nav-sign-in"]
    ${account}=   Get Element Count    css=[data-test="nav-my-account"]

    Should Be Equal As Integers    ${signin}    0
    Should Be True                 ${account} > 0