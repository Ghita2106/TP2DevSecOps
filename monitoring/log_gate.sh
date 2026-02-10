#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.staging.yml}"
SERVICE="${SERVICE:-web}"

MAX_5XX_RATE="${MAX_5XX_RATE:-0.05}"
MAX_P95_MS="${MAX_P95_MS:-800}"
MAX_SUSPECT="${MAX_SUSPECT:-0}"

docker compose -f "$COMPOSE_FILE" logs --no-color "$SERVICE" > runtime-logs.txt

python - <<'PY'
import json, re, os, sys

MAX_5XX_RATE=float(os.environ["MAX_5XX_RATE"])
MAX_P95_MS=int(os.environ["MAX_P95_MS"])
MAX_SUSPECT=int(os.environ["MAX_SUSPECT"])

sus_re = re.compile(r"(\.\./|/etc/passwd|\bor\s+1=1\b|\bunion\b|<script)", re.I)

total=0
s5xx=0
sus=0
lat=[]

with open("runtime-logs.txt","r",encoding="utf-8",errors="ignore") as f:
    for line in f:
        line=line.strip()
        if not (line.startswith("{") and line.endswith("}")):
            continue
        try:
            evt=json.loads(line)
        except Exception:
            continue
        if "status" not in evt or "latency_ms" not in evt:
            continue
        total += 1
        st=int(evt["status"])
        lm=int(evt["latency_ms"])
        lat.append(lm)
        if 500 <= st <= 599:
            s5xx += 1
        if sus_re.search(f"{evt.get('path','')} {evt.get('user_agent','')}"):
            sus += 1

def p95(vals):
    if not vals:
        return 0
    vals=sorted(vals)
    k=int(round(0.95*(len(vals)-1)))
    return vals[k]

rate = (s5xx/total) if total else 0.0
p95ms = p95(lat)

report = {
  "total_requests": total,
  "5xx_count": s5xx,
  "5xx_rate": rate,
  "p95_latency_ms": p95ms,
  "suspect_count": sus,
  "thresholds": {"max_5xx_rate": MAX_5XX_RATE, "max_p95_ms": MAX_P95_MS, "max_suspect": MAX_SUSPECT},
}

fail=False
reasons=[]
if total == 0:
    fail=True; reasons.append("No JSON request logs found.")
if rate > MAX_5XX_RATE:
    fail=True; reasons.append(f"5xx rate too high: {rate:.3%} > {MAX_5XX_RATE:.3%}")
if p95ms > MAX_P95_MS:
    fail=True; reasons.append(f"p95 latency too high: {p95ms}ms > {MAX_P95_MS}ms")
if sus > MAX_SUSPECT:
    fail=True; reasons.append(f"suspect patterns: {sus} > {MAX_SUSPECT}")

report["pass"] = not fail
report["reasons"] = reasons

with open("runtime-gate-report.json","w",encoding="utf-8") as out:
    json.dump(report,out,indent=2)

print(json.dumps(report, indent=2))

sys.exit(1 if fail else 0)
PY
