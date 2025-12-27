*** Settings ***
Library    Browser    auto_closing_level=SUITE
Library    String
Library    DateTime

*** Variables ***
${BASE_URL}    %{BASE_URL=http://localhost:4200}
${HEADLESS}    %{HEADLESS=true}

# Cart in this app lives under /checkout
${CART_PATH}   /checkout

# Demo credentials (used by login smoke / optional keywords)
${EMAIL}       %{DEMO_EMAIL=customer@practicesoftwaretesting.com}
${PASSWORD}    %{DEMO_PASSWORD=welcome01}

# Selectors (centralized -> easier maintenance)
${NAVBAR}              css=nav.navbar
${PRODUCT_CARD}        css=a.card[data-test^="product-"]
${NAV_SIGN_IN}         css=[data-test="nav-sign-in"]
${LOGIN_EMAIL}         css=input#email
${LOGIN_PASSWORD}      css=input#password
${LOGIN_SUBMIT}        css=[data-test="login-submit"]

*** Keywords ***
Open Toolshop
    New Browser    chromium    headless=${HEADLESS}    chromiumSandbox=false
    New Context    viewport={'width': 1280, 'height': 800}
    New Page       ${BASE_URL}
    Register Keyword To Run On Failure    Capture Failure Screenshot
    Wait Until Toolshop Ready

Capture Failure Screenshot
    ${test}=    Get Variable Value    ${TEST NAME}    unknown-test
    ${safe}=    Replace String Using Regexp    ${test}    [^A-Za-z0-9._-]+    _
    Take Screenshot    filename=${safe}.png

Wait Until Toolshop Ready
    Wait For Elements State    css=body    visible    timeout=20s
    Wait For Elements State    ${NAVBAR}   visible    timeout=20s

Close Toolshop
    Close Browser

Wait For At Least One Product Card
    Wait Until Keyword Succeeds    60s    2s    First Product Card Should Be Visible

First Product Card Should Be Visible
    # Avoid strict mode violation by targeting the first match explicitly
    Wait For Elements State    ${PRODUCT_CARD} >> nth=0    visible    timeout=5s

Login As Demo User
    Wait For Elements State    ${NAV_SIGN_IN}     visible    timeout=20s
    Click    ${NAV_SIGN_IN}

    Wait For Elements State    ${LOGIN_EMAIL}     visible    timeout=20s
    Wait For Elements State    ${LOGIN_PASSWORD}  visible    timeout=20s
    Fill Text    ${LOGIN_EMAIL}     ${EMAIL}
    Fill Text    ${LOGIN_PASSWORD}  ${PASSWORD}
    Click        ${LOGIN_SUBMIT}

    Wait For Login To Complete

Wait For Login To Complete
    Wait Until Keyword Succeeds    20s    500ms    Login Should Be Completed

Login Should Be Completed
    ${url}=    Get Url
    Should Not Contain    ${url}    /login
    Wait For Elements State    ${NAVBAR}    visible    timeout=10s

Go To Cart
    # Deterministic: cart is the /checkout page in this app
    Go To    ${BASE_URL}${CART_PATH}
    Wait Until Keyword Succeeds    20s    500ms    Cart Page Should Be Visible

Cart Page Should Be Visible
    # Robust presence check for checkout/cart page
    Wait For Elements State    text=/proceed to checkout/i    visible    timeout=10s