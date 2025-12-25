#!/usr/bin/env bash
set -euo pipefail

# --- ensure we run from repo root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# --- config (override via env) ---
BASE_URL="${BASE_URL:-http://localhost:4200}"
API_DOC_URL="${API_DOC_URL:-http://localhost:8091/api/documentation}"

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"

# Compose service names
API_SERVICE="${API_SERVICE:-laravel-api}"
DB_SERVICE="${DB_SERVICE:-mariadb}"

# DB readiness check (expects MYSQL_ROOT_PASSWORD env exists in DB container)
DB_READY_CMD="${DB_READY_CMD:-mysqladmin ping -h 127.0.0.1 -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --silent}"

# Seed/migrate
SEED_CMD="${SEED_CMD:-php artisan migrate:fresh --seed}"

# Robot
TEST_ROOT="${TEST_ROOT:-ui-tests}"
SMOKE_TAG="${SMOKE_TAG:-smoke}"
REGRESSION_TAG="${REGRESSION_TAG:-regression}"

ARTIFACTS_DIR="${ARTIFACTS_DIR:-artifacts_local}"
SMOKE_OUT="${ARTIFACTS_DIR}/smoke"
REG_OUT="${ARTIFACTS_DIR}/regression"

# Cleanup behaviour
CLEANUP="${CLEANUP:-false}"  # set CLEANUP=true to auto down -v at end

echo "==> Repo root:          ${REPO_ROOT}"
echo "==> BASE_URL:           ${BASE_URL}"
echo "==> API_DOC_URL:        ${API_DOC_URL}"
echo "==> Compose file:       ${COMPOSE_FILE}"
echo "==> API service:        ${API_SERVICE}"
echo "==> DB service:         ${DB_SERVICE}"
echo "==> Seed cmd:           ${SEED_CMD}"
echo "==> Smoke tag:          ${SMOKE_TAG}"
echo "==> Regression tag:     ${REGRESSION_TAG}"
echo "==> Artifacts dir:      ${ARTIFACTS_DIR}"
echo "==> Cleanup at end:     ${CLEANUP}"
echo

dc() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

wait_for_url() {
  local url="$1"
  local name="$2"
  local attempts="${3:-120}"
  local sleep_s="${4:-2}"

  echo "==> Waiting for ${name} (${url}) ..."
  for ((i=1; i<=attempts; i++)); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      echo "==> ${name} reachable ✅"
      return 0
    fi
    sleep "${sleep_s}"
  done

  echo "==> ${name} NOT reachable ❌"
  return 1
}

wait_for_db() {
  echo "==> Waiting for DB '${DB_SERVICE}' to accept connections ..."
  for i in {1..60}; do
    if dc exec -T "${DB_SERVICE}" sh -lc "${DB_READY_CMD}" >/dev/null 2>&1; then
      echo "==> DB is ready ✅"
      return 0
    fi
    sleep 2
  done
  echo "==> DB did not become ready in time ❌"
  return 1
}

seed_with_retry() {
  echo "==> Running migrate+seed in '${API_SERVICE}' ..."
  for i in {1..30}; do
    if dc exec -T "${API_SERVICE}" ${SEED_CMD}; then
      echo "==> Seed completed ✅"
      return 0
    fi
    echo "==> Seed failed (attempt ${i}/30). Retrying in 2s..."
    sleep 2
  done
  echo "==> Seed failed after retries ❌"
  return 1
}

verify_products_exist() {
  echo "==> Verifying seed: product count must be > 0 ..."
  local out
  out="$(dc exec -T "${API_SERVICE}" php artisan tinker --execute="echo \App\Models\Product::count();" 2>/dev/null || true)"
  local count
  count="$(echo "${out}" | tr -dc '0-9' || true)"

  if [[ -z "${count}" ]]; then
    echo "==> Could not read product count from tinker output ❌"
    echo "Raw output:"
    echo "${out}"
    return 1
  fi

  if [[ "${count}" -le 0 ]]; then
    echo "==> Seed verification failed: product count=${count} ❌"
    return 1
  fi

  echo "==> Seed verification OK: product count=${count} ✅"
  return 0
}

cleanup() {
  if [[ "${CLEANUP}" == "true" ]]; then
    echo "==> Stopping docker stack (down -v) ..."
    dc down -v || true
  else
    echo "==> Leaving docker stack running (CLEANUP=false)."
  fi
}

print_debug_logs() {
  echo "==> Docker status:"
  dc ps || true
  echo "==> laravel-api logs (tail):"
  dc logs --no-color "${API_SERVICE}" | tail -n 200 || true
  echo "==> mariadb logs (tail):"
  dc logs --no-color "${DB_SERVICE}" | tail -n 200 || true
  echo "==> web logs (tail):"
  dc logs --no-color web | tail -n 200 || true
}

trap cleanup EXIT

# --- preflight ---
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }
command -v robot  >/dev/null 2>&1 || { echo "ERROR: robot not found in PATH"; exit 1; }
command -v rfbrowser >/dev/null 2>&1 || { echo "ERROR: rfbrowser not found (robotframework-browser missing?)"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found"; exit 1; }

# --- start docker stack ---
echo "==> Starting docker stack ..."
dc up -d --pull missing
dc ps

# --- wait for API ---
if ! wait_for_url "${API_DOC_URL}" "API" 120 2; then
  echo "==> API not reachable. Debug logs:"
  print_debug_logs
  exit 1
fi

# --- wait for DB ---
if ! wait_for_db; then
  echo "==> DB not ready. Debug logs:"
  print_debug_logs
  exit 1
fi

# --- migrate+seed ---
if ! seed_with_retry; then
  echo "==> Seed failed. Debug logs:"
  print_debug_logs
  exit 1
fi

# --- verify seeded data exists ---
if ! verify_products_exist; then
  echo "==> Seed verification failed. Debug logs:"
  print_debug_logs
  exit 1
fi

# --- wait for UI ---
if ! wait_for_url "${BASE_URL}" "UI" 120 2; then
  echo "==> UI not reachable. Debug logs:"
  print_debug_logs
  exit 1
fi

# --- init browser deps (idempotent) ---
echo "==> rfbrowser init"
rfbrowser init

# --- run SMOKE (QGate) ---
echo
echo "==> Running SMOKE (Quality Gate)"
mkdir -p "${SMOKE_OUT}"
BASE_URL="${BASE_URL}" robot \
  --outputdir "${SMOKE_OUT}" \
  --include "${SMOKE_TAG}" \
  "${TEST_ROOT}"

echo
echo "==> SMOKE passed ✅"

# --- run REGRESSION only if smoke passed ---
echo
echo "==> Running REGRESSION"
mkdir -p "${REG_OUT}"
BASE_URL="${BASE_URL}" robot \
  --outputdir "${REG_OUT}" \
  --include "${REGRESSION_TAG}" \
  "${TEST_ROOT}"

echo
echo "==> REGRESSION finished ✅"
echo
echo "Smoke report:      ${SMOKE_OUT}/report.html"
echo "Regression report: ${REG_OUT}/report.html"