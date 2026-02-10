import time
import uuid
import json
from flask import Flask, request, g, jsonify

app = Flask(__name__)
SERVICE_NAME = "catalog"

@app.before_request
def before():
    g.t0 = time.time()
    rid = request.headers.get("X-Request-Id")
    g.request_id = rid if rid else str(uuid.uuid4())

@app.after_request
def after(resp):
    latency_ms = int((time.time() - g.t0) * 1000)
    record = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": "INFO",
        "service": SERVICE_NAME,
        "request_id": g.request_id,
        "method": request.method,
        "path": request.path,
        "status": resp.status_code,
        "latency_ms": latency_ms,
        "query": (request.query_string.decode("utf-8")[:200] if request.query_string else ""),
    }
    print(json.dumps(record), flush=True)
    resp.headers["X-Request-Id"] = g.request_id
    return resp

@app.get("/health")
def health():
    return "OK", 200

@app.get("/search")
def search():
    q = request.args.get("q", "")
    # mini réponse — le TP s’en fiche, on veut juste du trafic + logs
    return jsonify({"query": q, "results": ["Movie A", "Movie B"]})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
