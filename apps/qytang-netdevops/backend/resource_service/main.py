"""资源服务入口。"""

from __future__ import annotations

from time import perf_counter

from fastapi import Depends, FastAPI, Query
from fastapi.responses import PlainTextResponse
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from backend.common.database import get_db, init_database
from backend.common.metrics import MetricsCollector
from backend.common.models import Interface
from backend.common.schemas import InterfaceRead


app = FastAPI(title="QYT NetDevOps Resource Service", version="1.0.0")
metrics = MetricsCollector("resource-service")


@app.middleware("http")
async def metrics_middleware(request, call_next):
    """采集简单的请求指标。"""
    started = perf_counter()
    response = await call_next(request)
    metrics.record(request.url.path, perf_counter() - started)
    return response


@app.on_event("startup")
def startup_event() -> None:
    """服务启动时初始化数据库。"""
    init_database()


@app.get("/healthz")
def healthz() -> dict[str, str]:
    """返回健康状态。"""
    return {"status": "ok", "service": "resource-service"}


@app.get("/metrics", response_class=PlainTextResponse)
def metrics_endpoint() -> str:
    """输出 Prometheus 文本指标。"""
    return metrics.render()


@app.get("/api/v1/interfaces", response_model=list[InterfaceRead])
def list_interfaces(
    device_id: int | None = Query(default=None),
    db: Session = Depends(get_db),
) -> list[Interface]:
    """按设备查询接口列表。"""
    statement = select(Interface).order_by(Interface.device_id, Interface.id)
    if device_id is not None:
        statement = statement.where(Interface.device_id == device_id)
    return list(db.scalars(statement).all())


@app.get("/api/v1/devices/{device_id}/interfaces", response_model=list[InterfaceRead])
def list_device_interfaces(device_id: int, db: Session = Depends(get_db)) -> list[Interface]:
    """查询单台设备的接口。"""
    statement = select(Interface).where(Interface.device_id == device_id).order_by(Interface.id)
    return list(db.scalars(statement).all())


@app.get("/api/v1/summary")
def interface_summary(db: Session = Depends(get_db)) -> dict[str, int]:
    """返回接口汇总信息。"""
    total_interfaces = db.scalar(select(func.count()).select_from(Interface)) or 0
    up_interfaces = db.scalar(
        select(func.count()).select_from(Interface).where(Interface.oper_status == "up")
    ) or 0
    top_speed = db.scalar(select(func.max(Interface.speed_mbps)).select_from(Interface)) or 0
    return {
        "total_interfaces": int(total_interfaces),
        "up_interfaces": int(up_interfaces),
        "top_speed_mbps": int(top_speed),
    }
