*** Settings ***
Library    Browser

*** Keywords ***
Open Toolshop
    New Browser    chromium    headless=true
    New Context    viewport={'width': 1920, 'height': 1080}
    New Page       %{BASE_URL}

    # CI-stable: don't wait for networkidle
    Wait For Load State    domcontentloaded    timeout=30s

    # IMPORTANT: take a screenshot automatically when a Browser keyword fails
    Register Keyword To Run On Failure    Take Screenshot

Close Toolshop
    Close Browser