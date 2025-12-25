*** Settings ***
Documentation     Regression test for category filtering.
Resource          ../../resources/keywords/common.robot

*** Test Cases ***
Filter Products By Category
    Click    css=[data-test^="category-"] >> nth=0
    Wait Until Keyword Succeeds    10s    500ms    Filtered Results Should Exist

*** Keywords ***
Filtered Results Should Exist
    ${count}=    Get Element Count    css=a.card[data-test^="product-"]
    Should Be True    ${count} > 0
