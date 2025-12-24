*** Settings ***
Library    Browser

*** Variables ***
${BASE_URL}    %{BASE_URL=https://practicesoftwaretesting.com}
${EMAIL}       %{DEMO_EMAIL=customer@practicesoftwaretesting.com}
${PASSWORD}    %{DEMO_PASSWORD=welcome01}

*** Keywords ***
Open Toolshop
    New Browser    chromium    headless=true
    New Context
    ...    viewport={'width': 1920, 'height': 1080}
    ...    recordVideo={'dir': 'artifacts/browser/videos'}
    New Page       %{BASE_URL}

    # CI-stable readiness
    Wait For Elements State    css=body    visible    timeout=30s

    # Take screenshot automatically on any Browser failure
    Register Keyword To Run On Failure    Capture Page Screenshot


Capture Page Screenshot
    [Documentation]    Captures a screenshot on failure into a known CI folder.
    Take Screenshot    artifacts/browser/screenshots


Close Toolshop
    Close Browser