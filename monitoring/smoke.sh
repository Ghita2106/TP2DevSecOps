#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:5001}"

echo "[smoke] GET $BASE_URL/health"
curl -fsS "$BASE_URL/health" >/dev/null
echo "[smoke] OK"
