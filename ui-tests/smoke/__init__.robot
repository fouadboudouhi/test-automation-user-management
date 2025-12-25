*** Settings ***
Documentation    Smoke suite (Quality Gate): fast checks that the app is alive and key entry points work.
Resource         ../resources/keywords/common.robot
Test Setup       Open Toolshop
Test Teardown    Close Toolshop
Force Tags       smoke
