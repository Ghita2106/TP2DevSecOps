#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-compose.staging.yml}"
SERVICE="${SERVICE:-catalog}"
BASE_URL="${BASE_URL:-http://localhost:5001}"

MAX_5XX="${MAX_5XX:-0}"
MAX_P95_MS="${MAX_P95_MS:-400}"
MAX_TRAV="${MAX_TRAV:-0}"

mkdir -p reports

START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "[gate] 1) smoke + supervision"
BASE_URL="$BASE_URL" bash monitoring/smoke.sh
BASE_URL="$BASE_URL" bash monitoring/supervision.sh

echo "[gate] 2) traffic"
BASE_URL="$BASE_URL" bash monitoring/traffic.sh

echo "[gate] 3) extract logs since $START_TS"
docker compose -f "$COMPOSE_FILE" logs --no-log-prefix --since "$START_TS" "$SERVICE" \
  | tee "reports/${SERVICE}_logs.raw" >/dev/null

grep -E '^\{' "reports/${SERVICE}_logs.raw" > "reports/${SERVICE}_logs.jsonl" || true
if [ ! -s "reports/${SERVICE}_logs.jsonl" ]; then
  echo "[gate] ERROR: no JSON logs found (check logging in app.py)."
  exit 1
fi

echo "[gate] 4) compute metrics"
python3 monitoring/log_metrics.py "reports/${SERVICE}_logs.jsonl" "reports/log_report.json"

echo "[gate] 5) enforce thresholds"
COUNT_5XX="$(python3 -c 'import json;print(json.load(open("reports/log_report.json"))["count_5xx"])')"
P95="$(python3 -c 'import json;print(json.load(open("reports/log_report.json"))["p95_latency_ms"])')"
TRAV="$(python3 -c 'import json;print(json.load(open("reports/log_report.json"))["patterns"]["path_traversal_hits"])')"

echo "[gate] thresholds: 5xx<=${MAX_5XX} p95<=${MAX_P95_MS}ms trav<=${MAX_TRAV}"
echo "[gate] observed: 5xx=${COUNT_5XX} p95=${P95}ms trav=${TRAV}"

if [ "$COUNT_5XX" -gt "$MAX_5XX" ]; then
  echo "[gate] FAIL: too many HTTP 5xx"
  exit 1
fi
if [ "$P95" -gt "$MAX_P95_MS" ]; then
  echo "[gate] FAIL: p95 latency too high"
  exit 1
fi
if [ "$TRAV" -gt "$MAX_TRAV" ]; then
  echo "[gate] FAIL: suspicious traversal pattern detected"
  exit 1
fi

echo "[gate] OK"
