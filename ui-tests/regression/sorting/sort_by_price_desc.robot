*** Settings ***
Documentation    Regression: sorting products by price (descending) keeps results visible.
Resource         ../../resources/keywords/common.robot

*** Test Cases ***
Sort Products By Price Descending
    [Documentation]    Select price-desc sorting option and assert that product cards are still rendered.
    Wait For At Least One Product Card
    Select Options By    css=select[data-test="sort"]    value    price,desc
    Wait For At Least One Product Card
