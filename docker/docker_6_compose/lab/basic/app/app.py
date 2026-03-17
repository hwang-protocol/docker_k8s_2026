import os

import redis
from flask import Flask, jsonify


app = Flask(__name__)

CACHE_HOST = os.getenv("CACHE_HOST", "redis")
CACHE_PORT = int(os.getenv("CACHE_PORT", "6379"))
APP_NAME = os.getenv("APP_NAME", "compose-basic-demo")
APP_ENV = os.getenv("APP_ENV", "prod")
APP_PORT = int(os.getenv("APP_PORT", "5000"))


def get_cache():
    return redis.Redis(host=CACHE_HOST, port=CACHE_PORT, decode_responses=True)


@app.get("/")
def index():
    cache = get_cache()
    hits = cache.incr("compose_basic_hits")
    return jsonify(
        {
            "app_name": APP_NAME,
            "app_env": APP_ENV,
            "cache_host": CACHE_HOST,
            "cache_port": CACHE_PORT,
            "hits": hits,
        }
    )


@app.get("/healthz")
def healthz():
    cache = get_cache()
    cache.ping()
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT)
