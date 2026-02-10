import json, time, uuid, random
from flask import Flask, request, g

app = Flask(__name__)

@app.before_request
def before():
    g.start = time.time()
    g.request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))

@app.after_request
def after(resp):
    latency_ms = int((time.time() - g.start) * 1000)

    event = {
        "ts": time.time(),
        "request_id": g.request_id,
        "method": request.method,
        "path": request.path,
        "status": resp.status_code,
        "latency_ms": latency_ms,
        "user_agent": request.headers.get("User-Agent", ""),
    }
    print(json.dumps(event), flush=True)
    resp.headers["X-Request-Id"] = g.request_id
    return resp

@app.get("/health")
def health():
    return {"status": "ok"}

# endpoint utile pour générer de la latence/erreurs (démo gate)
@app.get("/demo")
def demo():
    mode = request.args.get("mode", "ok")

    # ajoute un peu de latence
    time.sleep(random.uniform(0.01, 0.15))

    if mode == "slow":
        time.sleep(0.9)  # force p95 haut
        return {"status": "slow"}, 200

    if mode == "error":
        return {"status": "error"}, 500

    return {"status": "ok"}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
