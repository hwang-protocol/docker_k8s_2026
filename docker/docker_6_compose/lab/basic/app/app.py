"""
Compose 基础实验：Flask 应用。
从环境变量读取 Redis 地址与运行配置，供 Compose 通过 environment 注入。
"""
import os

import redis
from flask import Flask, jsonify


app = Flask(__name__)

# 从环境变量读取配置，未设置时使用默认值；Compose 会在容器内注入这些变量
CACHE_HOST = os.getenv("CACHE_HOST", "redis")   # Redis 主机，Compose 中写服务名 redis 即可解析
CACHE_PORT = int(os.getenv("CACHE_PORT", "6379"))
APP_NAME = os.getenv("APP_NAME", "compose-basic-demo")
APP_ENV = os.getenv("APP_ENV", "prod")
APP_PORT = int(os.getenv("APP_PORT", "5000"))


def get_cache():
    """返回 Redis 客户端；decode_responses=True 使 get/incr 得到 str 而非 bytes。"""
    return redis.Redis(host=CACHE_HOST, port=CACHE_PORT, decode_responses=True)


@app.get("/")
def index():
    """首页：自增 Redis 中的计数，并返回当前配置与点击数（用于验证环境变量与连通性）。"""
    cache = get_cache()
    hits = cache.incr("compose_basic_hits")  # 键不存在时会先设为 0 再自增，得到 1
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
    """健康检查：能连上 Redis 并 ping 通即返回 ok，供 Compose healthcheck 调用。"""
    cache = get_cache()
    cache.ping()
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT)  # 监听所有网卡，便于容器内被 Nginx 反代
