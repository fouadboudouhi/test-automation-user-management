*** Settings ***
Documentation    Regression: navigation back to home works after visiting a product details page.
Resource         ../../resources/keywords/common.robot

*** Test Cases ***
Navigate Back To Home From Product Details
    [Documentation]    Open a product details page, go back to Home, and verify product list is visible again.
    Wait For At Least One Product Card
    Click    xpath=(//a[contains(@class,"card") and starts-with(@data-test,"product-")])[1]
    Wait For Elements State    text=Add to cart    visible    timeout=30s
    Click    text=Home
    Wait For At Least One Product Card
