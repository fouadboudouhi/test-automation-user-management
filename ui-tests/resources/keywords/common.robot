*** Settings ***
Documentation     Common browser lifecycle keywords.
Library           Browser

*** Keywords ***
Open Toolshop
    [Documentation]    Opens the application under test in a CI-stable way.
    New Browser    chromium    headless=true
    New Context    viewport={'width': 1920, 'height': 1080}
    New Page       %{BASE_URL}

    # IMPORTANT:
    # Do NOT wait for "networkidle" in CI.
    # The application keeps background requests open.
    Wait For Load State    domcontentloaded    timeout=30s

Close Toolshop
    [Documentation]    Closes the browser.
    Close Browser