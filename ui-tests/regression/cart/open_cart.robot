*** Settings ***
Documentation    Regression: after adding a product to cart, the cart page is reachable.
Resource         ../../resources/keywords/common.robot

*** Test Cases ***
Open Cart After Adding Product
    [Documentation]    Add first product to cart and open the Shopping cart page.
    Wait For At Least One Product Card
    Click    xpath=(//a[contains(@class,"card") and starts-with(@data-test,"product-")])[1]
    Wait For Elements State    text=Add to cart    visible    timeout=30s
    Click    text=Add to cart
    Wait For Elements State    text=Shopping cart    visible    timeout=30s
    Click    text=Shopping cart
    Wait For Elements State    css=h1    visible    timeout=30s
