*** Settings ***
Library    Browser

*** Keywords ***
Open Toolshop
    [Documentation]    Opens the application and handles global blockers (CI-safe).
    New Browser    chromium    headless=true
    New Context    viewport={'width': 1920, 'height': 1080}
    New Page       %{BASE_URL}

    # Page is interactive when body is visible
    Wait For Elements State    css=body    visible    timeout=30s

    # Handle cookie / consent banner if present
    Handle Cookie Consent


Handle Cookie Consent
    [Documentation]    Accepts cookie consent if the banner is present.
    ${count}=    Get Element Count    css=button:has-text("Accept")
    IF    ${count} > 0
        Click    css=button:has-text("Accept")
        Sleep    500ms
    END


Close Toolshop
    Close Browser