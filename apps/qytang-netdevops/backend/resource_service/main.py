"""资源服务入口。"""

from __future__ import annotations

from time import perf_counter

from fastapi import Depends, FastAPI, Query, Request
from fastapi.responses import PlainTextResponse
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from backend.common.database import ENGINE, get_db, init_database
from backend.common.metrics import MetricsCollector
from backend.common.models import Interface
from backend.common.schemas import InterfaceRead
from backend.common.tracing import setup_tracing, traced_span


SERVICE_NAME = "resource-service"
SERVICE_VERSION = "1.1.0"

app = FastAPI(title="QYT NetDevOps Resource Service", version=SERVICE_VERSION)
metrics = MetricsCollector(SERVICE_NAME)
setup_tracing(app, SERVICE_NAME, SERVICE_VERSION, engine=ENGINE)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """采集入站请求指标。"""
    started = perf_counter()
    response = await call_next(request)
    metrics.record_http(request.method, request.url.path, response.status_code, perf_counter() - started)
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
    with traced_span(SERVICE_NAME, "resource.list_interfaces"):
        statement = select(Interface).order_by(Interface.device_id, Interface.id)
        if device_id is not None:
            statement = statement.where(Interface.device_id == device_id)
        metrics.record_operation("interface_list")
        return list(db.scalars(statement).all())


@app.get("/api/v1/devices/{device_id}/interfaces", response_model=list[InterfaceRead])
def list_device_interfaces(device_id: int, db: Session = Depends(get_db)) -> list[Interface]:
    """查询单台设备的接口。"""
    with traced_span(SERVICE_NAME, "resource.list_device_interfaces", attributes={"device.id": device_id}):
        statement = select(Interface).where(Interface.device_id == device_id).order_by(Interface.id)
        metrics.record_operation("interface_list_by_device")
        return list(db.scalars(statement).all())


@app.get("/api/v1/summary")
def interface_summary(db: Session = Depends(get_db)) -> dict[str, int]:
    """返回接口汇总信息。"""
    with traced_span(SERVICE_NAME, "resource.interface_summary"):
        total_interfaces = db.scalar(select(func.count()).select_from(Interface)) or 0
        up_interfaces = db.scalar(
            select(func.count()).select_from(Interface).where(Interface.oper_status == "up")
        ) or 0
        top_speed = db.scalar(select(func.max(Interface.speed_mbps)).select_from(Interface)) or 0
        metrics.record_operation("interface_summary")
        return {
            "total_interfaces": int(total_interfaces),
            "up_interfaces": int(up_interfaces),
            "top_speed_mbps": int(top_speed),
        }
