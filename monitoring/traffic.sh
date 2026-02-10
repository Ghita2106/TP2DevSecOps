#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:5000}"
N="${N:-60}"
MODE="${MODE:-ok}"          # ok | slow | error | suspect

echo "Traffic: base=$BASE_URL N=$N mode=$MODE"

for i in $(seq 1 "$N"); do
  RID="rid-$i-$(date +%s%N)"
  case "$MODE" in
    ok)
      curl -s -o /dev/null -H "X-Request-Id: $RID" "$BASE_URL/health" || true
      curl -s -o /dev/null -H "X-Request-Id: $RID" "$BASE_URL/demo?mode=ok" || true
      ;;
    slow)
      curl -s -o /dev/null -H "X-Request-Id: $RID" "$BASE_URL/demo?mode=slow" || true
      ;;
    error)
      curl -s -o /dev/null -H "X-Request-Id: $RID" "$BASE_URL/demo?mode=error" || true
      ;;
    suspect)
      curl -s -o /dev/null -H "X-Request-Id: $RID" "$BASE_URL/../../etc/passwd" || true
      curl -s -o /dev/null -H "X-Request-Id: $RID" "$BASE_URL/demo?mode=ok&x=' OR 1=1 --" || true
      ;;
  esac
done
