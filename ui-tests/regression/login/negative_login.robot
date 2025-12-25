*** Settings ***
Documentation     Regression test for invalid login handling.
...               Verifies that an error message is shown for invalid credentials.
Resource          ../../resources/keywords/common.robot

*** Test Cases ***
Login With Invalid Credentials

    Click    css=[data-test="nav-sign-in"]

    Fill Text    css=input#email       invalid@example.com
    Fill Text    css=input#password    wrongpassword
    Click        css=[data-test="login-submit"]

    # Regression-level assertion: error feedback is shown
    Wait For Elements State    css=.alert-danger    visible    timeout=10s
