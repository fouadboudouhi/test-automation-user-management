SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

# ----------------------------
# Config (override via env)
# ----------------------------
COMPOSE_FILE ?= docker/docker-compose.yml
COMPOSE_OVERRIDE ?=
COMPOSE_PROJECT_NAME ?= toolshop-e2e

API_SERVICE ?= laravel-api
DB_SERVICE  ?= mariadb

# Reverse proxy / docs
WEB_PORT     ?= 8091
API_HOST     ?= http://localhost:$(WEB_PORT)
API_DOCS_URL ?= $(API_HOST)/api/documentation
API_DOC_URL  ?= $(API_DOCS_URL)  # legacy alias

# UI
UI_PORT   ?= 4200
BASE_URL  ?= http://localhost:$(UI_PORT)

# DB
DB_NAME ?= toolshop

# Seed
SEED_CMD ?= php artisan migrate:fresh --seed

# Tests
UI_TEST_ROOT  ?= tests/ui
API_TEST_ROOT ?= tests/api

# Run explicit files to avoid "0 tests collected" surprises
API_SMOKE_FILE ?= $(API_TEST_ROOT)/smoke/test_api_smoke.py
API_REG_FILE   ?= $(API_TEST_ROOT)/regression/test_api_regression.py

SMOKE_TAG ?= smoke
REG_TAG   ?= regression
HEADLESS  ?= true

# Artifacts
ARTIFACTS     ?= artifacts
UI_ARTIFACTS  ?= $(ARTIFACTS)/ui
API_ARTIFACTS ?= $(ARTIFACTS)/api
K6_ARTIFACTS  ?= $(ARTIFACTS)/k6

# Python / pytest
PYTHON ?= python
PYTEST ?= $(PYTHON) -m pytest

# Coverage (optional)
COV ?= false
COV_FAIL_UNDER ?= 50

# Compose command (supports optional override file)
COMPOSE_FILES := -f $(COMPOSE_FILE)
ifneq ($(strip $(COMPOSE_OVERRIDE)),)
COMPOSE_FILES += -f $(COMPOSE_OVERRIDE)
endif

DC := docker compose -p $(COMPOSE_PROJECT_NAME) $(COMPOSE_FILES)

# ----------------------------
# Helpers
# ----------------------------
define require_cmd
	@command -v $(1) >/dev/null 2>&1 || { echo "Missing command: $(1)"; exit 127; }
endef

.PHONY: help up down clean ps logs \
        wait-api wait-ui wait-db seed verify-seed \
        rfbrowser-init ui-smoke ui-regression \
        api-smoke api-regression \
        smoke regression test-all \
        k6-smoke k6-ramp k6-peak k6-soak \
        lint format typecheck ui-open-latest

help:
	@echo "Targets:"
	@echo "  make up            - start docker stack"
	@echo "  make down          - stop stack (keep volumes)"
	@echo "  make clean         - stop stack and remove volumes"
	@echo "  make seed          - wait -> migrate:fresh --seed -> verify"
	@echo "  make smoke         - run API + UI smoke"
	@echo "  make regression    - run API + UI regression"
	@echo "  make test-all      - up -> seed -> smoke -> regression"
	@echo ""
	@echo "Load tests (k6):"
	@echo "  make k6-smoke      - short read-only smoke load"
	@echo "  make k6-ramp       - ramp up/hold/down (capacity trend)"
	@echo "  make k6-peak       - short spike/peak"
	@echo "  make k6-soak       - long run (manual/weekly), default 30m"
	@echo ""
	@echo "Useful overrides:"
	@echo "  COMPOSE_PROJECT_NAME=toolshop-e2e-2 WEB_PORT=8092 UI_PORT=4201 make test-all"
	@echo "  HEADLESS=false make ui-smoke"
	@echo "  COV=true COV_FAIL_UNDER=60 make api-smoke"
	@echo "  make k6-ramp K6_RAMP_TARGET=40 K6_RAMP_UP=3m K6_RAMP_HOLD=5m"
	@echo "  make k6-soak K6_SOAK_VUS=10 K6_SOAK_DURATION=30m"

up:
	$(DC) up -d --pull missing
	$(DC) ps
	@echo "API docs:    $(API_DOCS_URL)"
	@echo "UI:          $(BASE_URL)"

down:
	$(DC) down

clean:
	$(DC) down -v --remove-orphans

ps:
	$(DC) ps

logs:
	$(DC) logs --no-color --tail=250

wait-api:
	@echo "Waiting for API docs $(API_DOCS_URL) ..."
	@for i in {1..180}; do \
		curl -fsS "$(API_DOCS_URL)" >/dev/null 2>&1 && echo "API reachable" && exit 0; \
		sleep 2; \
	done; \
	echo "API not reachable"; \
	$(DC) logs --no-color --tail=350; \
	exit 1

wait-ui:
	@echo "Waiting for UI $(BASE_URL) ..."
	@for i in {1..180}; do \
		curl -fsS "$(BASE_URL)" >/dev/null 2>&1 && echo "UI reachable" && exit 0; \
		sleep 2; \
	done; \
	echo "UI not reachable"; \
	$(DC) logs --no-color --tail=350; \
	exit 1

wait-db:
	@echo "Waiting for DB $(DB_SERVICE) ..."
	@for i in {1..120}; do \
		$(DC) exec -T $(DB_SERVICE) sh -lc 'mysqladmin ping -h 127.0.0.1 -uroot -p"$$MYSQL_ROOT_PASSWORD" --silent' >/dev/null 2>&1 && echo "DB ready" && exit 0; \
		sleep 2; \
	done; \
	echo "DB not ready"; \
	$(DC) logs --no-color --tail=350; \
	exit 1

seed: wait-api wait-db
	@echo "Running seed: $(SEED_CMD)"
	$(DC) exec -T $(API_SERVICE) $(SEED_CMD)
	$(MAKE) verify-seed

verify-seed:
	@echo "Verifying product count > 0 (via SQL) ..."
	@COUNT="$$( $(DC) exec -T $(DB_SERVICE) sh -lc 'mysql -N -B -uroot -p"$$MYSQL_ROOT_PASSWORD" -h 127.0.0.1 -e "SELECT COUNT(*) FROM products;" "$(DB_NAME)"' 2>/dev/null || true )"; \
	COUNT="$$(echo "$$COUNT" | tr -dc '0-9')"; \
	echo "Product count: $$COUNT"; \
	if [[ -z "$$COUNT" || "$$COUNT" -le 0 ]]; then \
		echo "Seed verification failed (products count <= 0)."; \
		exit 1; \
	fi

# ----------------------------
# UI tests (Robot) - Run folders: run-001, run-002, ...
# ----------------------------
rfbrowser-init:
	@$(call require_cmd,rfbrowser)
	rfbrowser init

ui-smoke: wait-ui rfbrowser-init
	@$(call require_cmd,robot)
	@BASE_DIR="$(UI_ARTIFACTS)/smoke"; \
	mkdir -p "$$BASE_DIR"; \
	LAST="$$(find "$$BASE_DIR" -maxdepth 1 -type d -name 'run-*' -print 2>/dev/null \
		| sed -E 's#.*/run-##' \
		| sort -n \
		| tail -n 1)"; \
	LAST_NUM="$$(printf '%d' "$${LAST:-0}" 2>/dev/null || echo 0)"; \
	NEXT="$$((LAST_NUM + 1))"; \
	OUT="$$BASE_DIR/run-$$(printf '%03d' $$NEXT)"; \
	mkdir -p "$$OUT"; \
	echo "UI smoke artifacts: $$OUT"; \
	BASE_URL="$(BASE_URL)" HEADLESS="$(HEADLESS)" \
	robot --outputdir "$$OUT" --include "$(SMOKE_TAG)" "$(UI_TEST_ROOT)"

ui-regression: wait-ui rfbrowser-init
	@$(call require_cmd,robot)
	@BASE_DIR="$(UI_ARTIFACTS)/regression"; \
	mkdir -p "$$BASE_DIR"; \
	LAST="$$(find "$$BASE_DIR" -maxdepth 1 -type d -name 'run-*' -print 2>/dev/null \
		| sed -E 's#.*/run-##' \
		| sort -n \
		| tail -n 1)"; \
	LAST_NUM="$$(printf '%d' "$${LAST:-0}" 2>/dev/null || echo 0)"; \
	NEXT="$$((LAST_NUM + 1))"; \
	OUT="$$BASE_DIR/run-$$(printf '%03d' $$NEXT)"; \
	mkdir -p "$$OUT"; \
	echo "UI regression artifacts: $$OUT"; \
	BASE_URL="$(BASE_URL)" HEADLESS="$(HEADLESS)" \
	robot --outputdir "$$OUT" --include "$(REG_TAG)" "$(UI_TEST_ROOT)"

# ----------------------------
# API tests (pytest)
# ----------------------------
api-smoke: wait-api
	@$(call require_cmd,$(PYTHON))
	@test -f "$(API_SMOKE_FILE)" || { echo "Missing: $(API_SMOKE_FILE)"; exit 2; }
	@mkdir -p "$(API_ARTIFACTS)/smoke"
	@set +e; \
	API_HOST="$(API_HOST)" API_DOCS_URL="$(API_DOCS_URL)" \
	$(PYTEST) -q \
	  --junitxml="$(API_ARTIFACTS)/smoke/junit.xml" \
	  $$( [[ "$(COV)" == "true" ]] && echo "--cov=$(API_TEST_ROOT) --cov-report=term-missing --cov-report=xml:$(API_ARTIFACTS)/smoke/coverage.xml --cov-fail-under=$(COV_FAIL_UNDER)" ) \
	  "$(API_SMOKE_FILE)"; \
	RC=$$?; \
	set -e; \
	if [[ $$RC -eq 5 ]]; then \
		echo ""; \
		echo "ERROR: pytest collected 0 tests (exit code 5)."; \
		echo "Hint: run: $(PYTHON) -m pytest -vv --collect-only $(API_SMOKE_FILE)"; \
		exit 5; \
	fi; \
	exit $$RC

api-regression: wait-api
	@$(call require_cmd,$(PYTHON))
	@test -f "$(API_REG_FILE)" || { echo "Missing: $(API_REG_FILE)"; exit 2; }
	@mkdir -p "$(API_ARTIFACTS)/regression"
	@set +e; \
	API_HOST="$(API_HOST)" API_DOCS_URL="$(API_DOCS_URL)" \
	$(PYTEST) -q \
	  --junitxml="$(API_ARTIFACTS)/regression/junit.xml" \
	  $$( [[ "$(COV)" == "true" ]] && echo "--cov=$(API_TEST_ROOT) --cov-report=term-missing --cov-report=xml:$(API_ARTIFACTS)/regression/coverage.xml --cov-fail-under=$(COV_FAIL_UNDER)" ) \
	  "$(API_REG_FILE)"; \
	RC=$$?; \
	set -e; \
	if [[ $$RC -eq 5 ]]; then \
		echo ""; \
		echo "ERROR: pytest collected 0 tests (exit code 5)."; \
		echo "Hint: run: $(PYTHON) -m pytest -vv --collect-only $(API_REG_FILE)"; \
		exit 5; \
	fi; \
	exit $$RC

ui-open-latest:
	@set -e; \
	BASE="$(UI_ARTIFACTS)"; \
	if [ ! -d "$$BASE" ]; then \
		echo "No UI artifacts directory found at: $$BASE"; \
		exit 1; \
	fi; \
	LATEST_RUN="$$(find "$$BASE" -type f -name 'log.html' -path '*/run-*/log.html' 2>/dev/null | sort | tail -n 1)"; \
	if [ -z "$$LATEST_RUN" ]; then \
		echo "No log.html found under $$BASE (expected */run-*/log.html)"; \
		exit 1; \
	fi; \
	echo "Opening: $$LATEST_RUN"; \
	if command -v open >/dev/null 2>&1; then \
		open "$$LATEST_RUN"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "$$LATEST_RUN"; \
	elif command -v wslview >/dev/null 2>&1; then \
		wslview "$$LATEST_RUN"; \
	else \
		echo "No opener command found (open/xdg-open/wslview). File path:"; \
		echo "$$LATEST_RUN"; \
		exit 2; \
	fi

# ----------------------------
# Load tests (k6)
# ----------------------------
K6 ?= k6

K6_SCRIPT_SMOKE ?= load/k6/smoke.js
K6_SCRIPT_RAMP  ?= load/k6/ramp.js
K6_SCRIPT_PEAK  ?= load/k6/peak.js
K6_SCRIPT_SOAK  ?= load/k6/soak.js

K6_VUS ?= 10
K6_DURATION ?= 1m

K6_RAMP_TARGET ?= 25
K6_RAMP_UP     ?= 2m
K6_RAMP_HOLD   ?= 3m
K6_RAMP_DOWN   ?= 1m

K6_PEAK_VUS       ?= 50
K6_PEAK_RAMP_UP   ?= 15s
K6_PEAK_HOLD      ?= 60s
K6_PEAK_RAMP_DOWN ?= 30s

K6_SOAK_VUS      ?= 10
K6_SOAK_DURATION ?= 30m

k6-smoke: wait-api
	@$(call require_cmd,$(K6))
	@BASE_DIR="$(K6_ARTIFACTS)/smoke"; \
	mkdir -p "$$BASE_DIR"; \
	LAST="$$(find "$$BASE_DIR" -maxdepth 1 -type d -name 'run-*' -print 2>/dev/null \
		| sed -E 's#.*/run-##' \
		| sort -n \
		| tail -n 1)"; \
	LAST_NUM="$$(printf '%d' "$${LAST:-0}" 2>/dev/null || echo 0)"; \
	NEXT="$$((LAST_NUM + 1))"; \
	OUT="$$BASE_DIR/run-$$(printf '%03d' $$NEXT)"; \
	mkdir -p "$$OUT"; \
	echo "k6 smoke artifacts: $$OUT"; \
	API_URL="$(API_HOST)" DEMO_EMAIL="$(DEMO_EMAIL)" DEMO_PASSWORD="$(DEMO_PASSWORD)" \
	VUS="$(K6_VUS)" DURATION="$(K6_DURATION)" \
	$(K6) run --summary-export="$$OUT/summary.json" "$(K6_SCRIPT_SMOKE)"

k6-ramp: wait-api
	@$(call require_cmd,$(K6))
	@BASE_DIR="$(K6_ARTIFACTS)/ramp"; \
	mkdir -p "$$BASE_DIR"; \
	LAST="$$(find "$$BASE_DIR" -maxdepth 1 -type d -name 'run-*' -print 2>/dev/null \
		| sed -E 's#.*/run-##' \
		| sort -n \
		| tail -n 1)"; \
	LAST_NUM="$$(printf '%d' "$${LAST:-0}" 2>/dev/null || echo 0)"; \
	NEXT="$$((LAST_NUM + 1))"; \
	OUT="$$BASE_DIR/run-$$(printf '%03d' $$NEXT)"; \
	mkdir -p "$$OUT"; \
	echo "k6 ramp artifacts: $$OUT"; \
	API_URL="$(API_HOST)" DEMO_EMAIL="$(DEMO_EMAIL)" DEMO_PASSWORD="$(DEMO_PASSWORD)" \
	RAMP_TARGET="$(K6_RAMP_TARGET)" RAMP_UP="$(K6_RAMP_UP)" RAMP_HOLD="$(K6_RAMP_HOLD)" RAMP_DOWN="$(K6_RAMP_DOWN)" \
	$(K6) run --summary-export="$$OUT/summary.json" "$(K6_SCRIPT_RAMP)"

k6-peak: wait-api
	@$(call require_cmd,$(K6))
	@BASE_DIR="$(K6_ARTIFACTS)/peak"; \
	mkdir -p "$$BASE_DIR"; \
	LAST="$$(find "$$BASE_DIR" -maxdepth 1 -type d -name 'run-*' -print 2>/dev/null \
		| sed -E 's#.*/run-##' \
		| sort -n \
		| tail -n 1)"; \
	LAST_NUM="$$(printf '%d' "$${LAST:-0}" 2>/dev/null || echo 0)"; \
	NEXT="$$((LAST_NUM + 1))"; \
	OUT="$$BASE_DIR/run-$$(printf '%03d' $$NEXT)"; \
	mkdir -p "$$OUT"; \
	echo "k6 peak artifacts: $$OUT"; \
	API_URL="$(API_HOST)" DEMO_EMAIL="$(DEMO_EMAIL)" DEMO_PASSWORD="$(DEMO_PASSWORD)" \
	PEAK_VUS="$(K6_PEAK_VUS)" PEAK_RAMP_UP="$(K6_PEAK_RAMP_UP)" PEAK_HOLD="$(K6_PEAK_HOLD)" PEAK_RAMP_DOWN="$(K6_PEAK_RAMP_DOWN)" \
	$(K6) run --summary-export="$$OUT/summary.json" "$(K6_SCRIPT_PEAK)"

k6-soak: wait-api
	@$(call require_cmd,$(K6))
	@BASE_DIR="$(K6_ARTIFACTS)/soak"; \
	mkdir -p "$$BASE_DIR"; \
	LAST="$$(find "$$BASE_DIR" -maxdepth 1 -type d -name 'run-*' -print 2>/dev/null \
		| sed -E 's#.*/run-##' \
		| sort -n \
		| tail -n 1)"; \
	LAST_NUM="$$(printf '%d' "$${LAST:-0}" 2>/dev/null || echo 0)"; \
	NEXT="$$((LAST_NUM + 1))"; \
	OUT="$$BASE_DIR/run-$$(printf '%03d' $$NEXT)"; \
	mkdir -p "$$OUT"; \
	echo "k6 soak artifacts: $$OUT"; \
	API_URL="$(API_HOST)" DEMO_EMAIL="$(DEMO_EMAIL)" DEMO_PASSWORD="$(DEMO_PASSWORD)" \
	SOAK_VUS="$(K6_SOAK_VUS)" SOAK_DURATION="$(K6_SOAK_DURATION)" \
	$(K6) run --summary-export="$$OUT/summary.json" "$(K6_SCRIPT_SOAK)"

# Combined pipeline targets (API + UI)
smoke: api-smoke ui-smoke
regression: api-regression ui-regression

test-all: up seed smoke regression