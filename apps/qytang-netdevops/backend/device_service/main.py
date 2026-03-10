"""设备服务入口。"""

from __future__ import annotations

import os
from collections import Counter
from time import perf_counter

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.responses import PlainTextResponse
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from backend.common.config import get_audit_service_url, get_resource_service_url
from backend.common.database import get_db, init_database
from backend.common.metrics import MetricsCollector
from backend.common.models import Device
from backend.common.schemas import (
    AuditLogRead,
    DashboardSummary,
    DeviceCreate,
    DeviceDetail,
    DeviceRead,
    DeviceUpdate,
    DistributionItem,
    ServiceStatus,
)
from backend.common.seed import ensure_seed_data
from backend.common.service_clients import request_json


AUTO_SEED = os.getenv("QYTANG_AUTO_SEED", "false").lower() == "true"
RESOURCE_SERVICE_URL = get_resource_service_url()
AUDIT_SERVICE_URL = get_audit_service_url()

app = FastAPI(title="QYT NetDevOps Device Service", version="1.0.0")
metrics = MetricsCollector("device-service")


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
    if AUTO_SEED:
        ensure_seed_data()


def write_audit(action: str, entity_id: int | None, detail: str) -> None:
    """把业务动作同步写入审计服务。"""
    try:
        request_json(
            AUDIT_SERVICE_URL,
            "/api/v1/audits",
            method="POST",
            payload={
                "action": action,
                "entity_type": "device",
                "entity_id": entity_id,
                "operator": "course-admin",
                "detail": detail,
            },
        )
    except RuntimeError:
        # 审计链路异常时不阻断课堂演示主流程。
        return


def distribution_from_counter(counter: Counter[str]) -> list[DistributionItem]:
    """把 Counter 转成前端易用的分布列表。"""
    return [DistributionItem(label=label, value=value) for label, value in counter.most_common()]


@app.get("/healthz")
def healthz() -> dict[str, str]:
    """返回健康状态。"""
    return {"status": "ok", "service": "device-service"}


@app.get("/metrics", response_class=PlainTextResponse)
def metrics_endpoint() -> str:
    """输出 Prometheus 文本指标。"""
    return metrics.render()


@app.get("/api/v1/devices", response_model=list[DeviceRead])
def list_devices(
    keyword: str | None = Query(default=None),
    status: str | None = Query(default=None),
    vendor: str | None = Query(default=None),
    site: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> list[Device]:
    """按关键字和标签筛选设备。"""
    statement = select(Device).order_by(Device.hostname)
    if keyword:
        like_keyword = f"%{keyword}%"
        statement = statement.where(
            or_(
                Device.hostname.ilike(like_keyword),
                Device.mgmt_ip.ilike(like_keyword),
                Device.site.ilike(like_keyword),
                Device.role.ilike(like_keyword),
            )
        )
    if status:
        statement = statement.where(Device.status == status)
    if vendor:
        statement = statement.where(Device.vendor == vendor)
    if site:
        statement = statement.where(Device.site == site)
    return list(db.scalars(statement).all())


@app.get("/api/v1/devices/{device_id}", response_model=DeviceDetail)
def get_device_detail(device_id: int, db: Session = Depends(get_db)) -> DeviceDetail:
    """返回设备详情并聚合接口和审计。"""
    device = db.get(Device, device_id)
    if not device:
        raise HTTPException(status_code=404, detail="设备不存在")

    interfaces = request_json(RESOURCE_SERVICE_URL, f"/api/v1/devices/{device_id}/interfaces")
    audits = request_json(
        AUDIT_SERVICE_URL,
        "/api/v1/audits",
        params={"entity_type": "device", "entity_id": device_id, "limit": 5},
    )
    payload = DeviceRead.model_validate(device).model_dump()
    return DeviceDetail(**payload, interfaces=interfaces, audits=audits)


@app.post("/api/v1/devices", response_model=DeviceRead)
def create_device(payload: DeviceCreate, db: Session = Depends(get_db)) -> Device:
    """新增设备。"""
    item = Device(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    write_audit("create", item.id, f"新增设备 {item.hostname} ({item.mgmt_ip})")
    return item


@app.put("/api/v1/devices/{device_id}", response_model=DeviceRead)
def update_device(device_id: int, payload: DeviceUpdate, db: Session = Depends(get_db)) -> Device:
    """编辑设备。"""
    item = db.get(Device, device_id)
    if not item:
        raise HTTPException(status_code=404, detail="设备不存在")

    for key, value in payload.model_dump(exclude_none=True).items():
        setattr(item, key, value)
    db.commit()
    db.refresh(item)
    write_audit("update", item.id, f"更新设备 {item.hostname} 的基础属性")
    return item


@app.delete("/api/v1/devices/{device_id}")
def delete_device(device_id: int, db: Session = Depends(get_db)) -> dict[str, str]:
    """删除设备。"""
    item = db.get(Device, device_id)
    if not item:
        raise HTTPException(status_code=404, detail="设备不存在")
    hostname = item.hostname
    db.delete(item)
    db.commit()
    write_audit("delete", device_id, f"删除设备 {hostname}")
    return {"status": "deleted", "hostname": hostname}


@app.get("/api/v1/dashboard/summary", response_model=DashboardSummary)
def dashboard_summary(db: Session = Depends(get_db)) -> DashboardSummary:
    """返回 Dashboard 所需的汇总数据。"""
    devices = list(db.scalars(select(Device).order_by(Device.hostname)).all())
    total_devices = len(devices)
    online_devices = len([item for item in devices if item.status == "online"])
    risky_device_count = len([item for item in devices if item.status != "online"])

    vendor_distribution = distribution_from_counter(Counter(item.vendor for item in devices))
    site_distribution = distribution_from_counter(Counter(item.site for item in devices))
    status_distribution = distribution_from_counter(Counter(item.status for item in devices))

    interface_summary = request_json(RESOURCE_SERVICE_URL, "/api/v1/summary")
    recent_changes = request_json(AUDIT_SERVICE_URL, "/api/v1/audits", params={"limit": 8})

    service_matrix = [
        ServiceStatus(name="device-service", status="RUNNING", url="http://10.1.1.201:8001/healthz"),
        ServiceStatus(name="resource-service", status="RUNNING", url="http://10.1.1.201:8002/healthz"),
        ServiceStatus(name="audit-service", status="RUNNING", url="http://10.1.1.201:8003/healthz"),
    ]

    return DashboardSummary(
        total_devices=total_devices,
        online_devices=online_devices,
        interface_up_count=int(interface_summary.get("up_interfaces", 0)),
        recent_change_count=len(recent_changes),
        top_interface_speed_mbps=int(interface_summary.get("top_speed_mbps", 0)),
        risky_device_count=risky_device_count,
        vendor_distribution=vendor_distribution,
        site_distribution=site_distribution,
        status_distribution=status_distribution,
        recent_changes=[AuditLogRead.model_validate(item) for item in recent_changes],
        service_matrix=service_matrix,
    )
