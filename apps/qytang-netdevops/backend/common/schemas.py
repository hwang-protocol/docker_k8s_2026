"""定义接口输入输出模型。"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class InterfaceRead(BaseModel):
    """设备接口输出结构。"""

    model_config = ConfigDict(from_attributes=True)

    id: int
    device_id: int
    name: str
    ip_address: str
    speed_mbps: int
    admin_status: str
    oper_status: str
    description: str


class AuditLogRead(BaseModel):
    """审计日志输出结构。"""

    model_config = ConfigDict(from_attributes=True)

    id: int
    action: str
    entity_type: str
    entity_id: int | None = None
    operator: str
    detail: str
    created_at: datetime


class AuditLogCreate(BaseModel):
    """新增审计日志输入结构。"""

    action: str
    entity_type: str
    entity_id: int | None = None
    operator: str = "course-admin"
    detail: str


class DeviceBase(BaseModel):
    """设备公共字段。"""

    hostname: str = Field(..., min_length=2, max_length=64)
    mgmt_ip: str = Field(..., min_length=7, max_length=32)
    vendor: str
    model: str
    version: str
    site: str
    role: str
    status: str


class DeviceCreate(DeviceBase):
    """新增设备输入结构。"""


class DeviceUpdate(BaseModel):
    """编辑设备输入结构。"""

    hostname: str | None = None
    mgmt_ip: str | None = None
    vendor: str | None = None
    model: str | None = None
    version: str | None = None
    site: str | None = None
    role: str | None = None
    status: str | None = None


class DeviceRead(DeviceBase):
    """设备输出结构。"""

    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime


class DeviceDetail(DeviceRead):
    """设备详情结构。"""

    interfaces: list[InterfaceRead] = []
    audits: list[AuditLogRead] = []


class DistributionItem(BaseModel):
    """分布统计项。"""

    label: str
    value: int


class ServiceStatus(BaseModel):
    """服务健康状态项。"""

    name: str
    status: str
    url: str


class DashboardSummary(BaseModel):
    """Dashboard 汇总输出结构。"""

    total_devices: int
    online_devices: int
    interface_up_count: int
    recent_change_count: int
    top_interface_speed_mbps: int
    risky_device_count: int
    vendor_distribution: list[DistributionItem]
    site_distribution: list[DistributionItem]
    status_distribution: list[DistributionItem]
    recent_changes: list[AuditLogRead]
    service_matrix: list[ServiceStatus]
