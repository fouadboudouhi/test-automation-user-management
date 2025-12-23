# User Management – Test Automation Project

This project demonstrates a production-like test automation setup for a small User Management system.
The focus is **not feature completeness**, but **test strategy, determinism, and CI-ready architecture**.

The system is intentionally kept small to allow deep discussion of:
- test architecture
- quality gates
- reproducibility
- trade-offs

---

## Why This Project

This project is designed to demonstrate how quality is built and protected
in a realistic engineering environment.

Instead of maximizing feature count, the focus is on:
- clear test responsibility boundaries
- deterministic and reproducible execution
- fast feedback through CI quality gates
- conscious trade-offs to reduce long-term maintenance cost

The scope is intentionally limited to allow meaningful discussion about
engineering decisions rather than implementation details.

---

## System Overview

The system consists of a minimal User Management application with full test automation on API and UI level.

### Core Components
- **FastAPI** – REST API for user management
- **PostgreSQL** – persistent storage (production-like)
- **Minimal Web UI** – only for critical UI test coverage
- **pytest** – API and UI test execution
- **Playwright (Python)** – UI automation
- **Docker & Docker Compose** – reproducible environments
- **GitHub Actions** – CI pipeline
- **Allure** – test reporting and failure analysis

---

## Architecture

```
┌────────────┐      HTTP      ┌──────────────┐      SQL     ┌────────────┐
│  UI Tests  │ ─────────────▶ │   FastAPI    │ ───────────▶ │ PostgreSQL │
│ Playwright │                │   User API   │              │            │
└────────────┘                └──────────────┘              └────────────┘
       ▲                              ▲
       │                              │
       │            HTTP              │
       └────────── API Tests ─────────┘
                    pytest
```

---

## API Scope (Intentionally Limited)

### User Operations
- Create User
- Get User
- Update User
- Delete User

### Negative Cases
- Duplicate email → `409 Conflict`
- Invalid payload → `422 Unprocessable Entity`
- User not found → `404 Not Found`

---

## Test Strategy

### Test Pyramid
- **~70% API Tests** – main quality gate
- **~20% UI Tests** – critical flows only
- **~10% Smoke Tests** – availability checks

UI tests validate intent, not backend state.

---

## Smoke Tests

Smoke tests verify that the system is deployable and fundamentally usable.

In this project, smoke coverage includes:
- application startup with database connectivity
- API health endpoint availability
- basic UI reachability

---

## Dependencies

All Python dependencies are pinned and documented in `requirements.txt`.

```text
fastapi
uvicorn
pydantic
email-validator
pytest
requests
playwright
allure-pytest
psycopg[binary]
```

---

## Summary

This project demonstrates how test automation can be used to actively protect software quality by:
- making quality ownership explicit
- applying a clear and intentional test strategy
- ensuring reproducible execution across local and CI environments
- enforcing meaningful quality gates in CI
