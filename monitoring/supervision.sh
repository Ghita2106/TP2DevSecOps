#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:5001}"

echo "[supervision] request-id propagation"
RID="demo-$(date +%s)"
HDRS="$(curl -s -D - -o /dev/null -H "X-Request-Id: $RID" "$BASE_URL/health")"

echo "$HDRS" | grep -i "x-request-id: $RID" >/dev/null
echo "[supervision] OK"
