"""本地一键启动前端与三个后端服务。"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = APP_DIR / "data"
DATABASE_URL = f"sqlite:///{(DATA_DIR / 'netdevops.db').as_posix()}"


def build_env(extra_env: dict[str, str] | None = None) -> dict[str, str]:
    """构建统一的进程环境变量。"""
    env = os.environ.copy()
    env["PYTHONPATH"] = str(APP_DIR)
    env["QYTANG_NETDEVOPS_DB_URL"] = DATABASE_URL
    env["QYTANG_RESOURCE_SERVICE_URL"] = "http://127.0.0.1:8002"
    env["QYTANG_AUDIT_SERVICE_URL"] = "http://127.0.0.1:8003"
    env["QYTANG_DEVICE_PROXY_URL"] = "http://127.0.0.1:8001/"
    env["QYTANG_RESOURCE_PROXY_URL"] = "http://127.0.0.1:8002/"
    env["QYTANG_AUDIT_PROXY_URL"] = "http://127.0.0.1:8003/"
    env["QYTANG_FRONTEND_HOST"] = "0.0.0.0"
    env["QYTANG_FRONTEND_PORT"] = "8080"
    if extra_env:
        env.update(extra_env)
    return env


def spawn_process(command: list[str], env: dict[str, str]) -> subprocess.Popen:
    """启动单个后台进程。"""
    return subprocess.Popen(command, cwd=APP_DIR, env=env)


def terminate_processes(processes: list[subprocess.Popen]) -> None:
    """关闭所有子进程。"""
    for process in processes:
        if process.poll() is None:
            process.terminate()
    end_time = time.time() + 5
    for process in processes:
        if process.poll() is None:
            wait_seconds = max(0.0, end_time - time.time())
            try:
                process.wait(timeout=wait_seconds)
            except subprocess.TimeoutExpired:
                process.kill()


def main() -> None:
    """启动完整本地联调栈。"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    python_bin = sys.executable
    processes: list[subprocess.Popen] = []

    commands = [
        (
            "device-service",
            [
                python_bin,
                "-m",
                "uvicorn",
                "backend.device_service.main:app",
                "--host",
                "0.0.0.0",
                "--port",
                "8001",
            ],
            {"QYTANG_AUTO_SEED": "true"},
        ),
        (
            "resource-service",
            [
                python_bin,
                "-m",
                "uvicorn",
                "backend.resource_service.main:app",
                "--host",
                "0.0.0.0",
                "--port",
                "8002",
            ],
            {},
        ),
        (
            "audit-service",
            [
                python_bin,
                "-m",
                "uvicorn",
                "backend.audit_service.main:app",
                "--host",
                "0.0.0.0",
                "--port",
                "8003",
            ],
            {},
        ),
        (
            "frontend",
            [python_bin, "frontend/server.py"],
            {},
        ),
    ]

    def handle_signal(signum, frame):  # noqa: ARG001
        """收到信号后优雅退出。"""
        terminate_processes(processes)
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    for service_name, command, extra_env in commands:
        print(f"[run_local_stack] starting {service_name}")
        processes.append(spawn_process(command, build_env(extra_env)))

    while True:
        for process in processes:
            if process.poll() is not None:
                terminate_processes(processes)
                raise SystemExit(f"服务异常退出，退出码: {process.returncode}")
        time.sleep(2)


if __name__ == "__main__":
    main()
