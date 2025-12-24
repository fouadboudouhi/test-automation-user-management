*** Settings ***
Library    Browser

*** Keywords ***
Open Toolshop
    [Documentation]    Opens the application in a CI-stable way.
    New Browser    chromium    headless=true
    New Context    viewport={'width': 1920, 'height': 1080}
    New Page       %{BASE_URL}

    # CI-stable readiness check:
    # Body visible == page is interactive
    Wait For Elements State    css=body    visible    timeout=30s


Close Toolshop
    [Documentation]    Closes the browser.
    Close Browser