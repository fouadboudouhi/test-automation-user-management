*** Settings ***
Documentation    Regression: product details page renders correctly and supports adding to cart.
Resource         ../../resources/keywords/common.robot

*** Test Cases ***
Product Details Page Shows Title And Add To Cart
    [Documentation]    Open the first product and verify basic details are present (title + Add to cart button).
    Wait For At Least One Product Card
    Click    xpath=(//a[contains(@class,"card") and starts-with(@data-test,"product-")])[1]
    Wait For Elements State    css=h1              visible    timeout=30s
    Wait For Elements State    text=Add to cart    visible    timeout=30s
