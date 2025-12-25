*** Settings ***
Documentation    Regression suite: functional user journeys. Runs only if Smoke (QGate) is green.
Resource         ../resources/keywords/common.robot
Test Setup       Open Toolshop
Test Teardown    Close Toolshop
Force Tags       regression
