*** Settings ***
Documentation     Regression: searching for a non-existing product shows the "no products found" state.
Resource          ../../resources/keywords/common.robot

*** Variables ***
${NO_RESULTS_QUERY}    __no_such_product__987654321__

*** Test Cases ***
Search With No Results Shows Empty List
    [Tags]    regression
    # Preconditions: we are on home/products list and search field exists
    Wait For Elements State    css=[data-test="search-query"]    visible    timeout=20s

    Fill Text    css=[data-test="search-query"]    ${NO_RESULTS_QUERY}
    Click        css=[data-test="search-submit"]

    Wait Until Keyword Succeeds    20s    1s    No Results State Should Be Visible
    Product List Should Be Empty


*** Keywords ***
No Results State Should Be Visible
    # 1) Make sure the page acknowledges the query (prevents false positives)
    Wait For Elements State    text=Searched for:    visible    timeout=2s
    Wait For Elements State    text=${NO_RESULTS_QUERY}    visible    timeout=2s

    # 2) Verify the explicit empty-state message
    Wait For Elements State    text=There are no products found.    visible    timeout=2s

Product List Should Be Empty
    # If your product cards are anchors with data-test="product-..."
    ${count}=    Get Element Count    css=a.card[data-test^="product-"]
    Should Be Equal As Integers    ${count}    0