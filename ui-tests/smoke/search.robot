*** Settings ***
Documentation     Smoke test verifying that search is present.
Resource          ../resources/keywords/common.robot

*** Test Cases ***
Search Field Is Available
    [Documentation]    Pass criteria: search input is visible.
    [Tags]    smoke    search
    Wait For Elements State    css=[data-test="search-query"]    visible    timeout=20s
