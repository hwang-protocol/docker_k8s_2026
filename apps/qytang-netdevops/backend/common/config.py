"""集中管理应用路径和环境变量。"""

from __future__ import annotations

import os
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = APP_DIR / "data"


def get_database_url() -> str:
    """返回数据库连接串。"""
    sqlite_path = DATA_DIR / "netdevops.db"
    default_url = f"sqlite:///{sqlite_path.as_posix()}"
    return os.getenv("QYTANG_NETDEVOPS_DB_URL", default_url)


def get_resource_service_url() -> str:
    """返回资源服务地址。"""
    return os.getenv("QYTANG_RESOURCE_SERVICE_URL", "http://127.0.0.1:8002")


def get_audit_service_url() -> str:
    """返回审计服务地址。"""
    return os.getenv("QYTANG_AUDIT_SERVICE_URL", "http://127.0.0.1:8003")


def get_device_service_url() -> str:
    """返回设备服务地址。"""
    return os.getenv("QYTANG_DEVICE_SERVICE_URL", "http://127.0.0.1:8001")
