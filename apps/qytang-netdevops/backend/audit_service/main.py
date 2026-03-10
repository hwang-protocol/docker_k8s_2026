"""审计服务入口。"""

from __future__ import annotations

from time import perf_counter

from fastapi import Depends, FastAPI, Query
from fastapi.responses import PlainTextResponse
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from backend.common.database import get_db, init_database
from backend.common.metrics import MetricsCollector
from backend.common.models import AuditLog
from backend.common.schemas import AuditLogCreate, AuditLogRead


app = FastAPI(title="QYT NetDevOps Audit Service", version="1.0.0")
metrics = MetricsCollector("audit-service")


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
    return {"status": "ok", "service": "audit-service"}


@app.get("/metrics", response_class=PlainTextResponse)
def metrics_endpoint() -> str:
    """输出 Prometheus 文本指标。"""
    return metrics.render()


@app.get("/api/v1/audits", response_model=list[AuditLogRead])
def list_audits(
    entity_type: str | None = Query(default=None),
    entity_id: int | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[AuditLog]:
    """查询审计日志。"""
    statement = select(AuditLog).order_by(desc(AuditLog.created_at)).limit(limit)
    if entity_type:
        statement = statement.where(AuditLog.entity_type == entity_type)
    if entity_id is not None:
        statement = statement.where(AuditLog.entity_id == entity_id)
    return list(db.scalars(statement).all())


@app.post("/api/v1/audits", response_model=AuditLogRead)
def create_audit(payload: AuditLogCreate, db: Session = Depends(get_db)) -> AuditLog:
    """写入一条审计日志。"""
    item = AuditLog(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item
