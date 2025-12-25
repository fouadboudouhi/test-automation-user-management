*** Settings ***
Documentation     Regression test for add-to-cart functionality.
...               Expected to expose known demo application issues.
Resource          ../../resources/keywords/common.robot

*** Test Cases ***
Add Product To Cart
    Wait Until Keyword Succeeds    15s    500ms    Product Cards Should Exist
    Click    css=a.card[data-test^="product-"] >> nth=0
    Click    text=Add to cart
    Wait For Elements State    text=Shopping cart    visible    timeout=10s

*** Keywords ***
Product Cards Should Exist
    ${count}=    Get Element Count    css=a.card[data-test^="product-"]
    Should Be True    ${count} > 0
