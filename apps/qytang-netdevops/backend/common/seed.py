"""生成课堂演示数据。"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.common.database import SessionLocal, init_database
from backend.common.models import AuditLog, Device, Interface


DEVICE_SEED = [
    {"hostname": "bj-core-01", "mgmt_ip": "10.10.1.11", "vendor": "Cisco", "model": "Nexus9000", "version": "10.2(5)", "site": "Beijing", "role": "Core", "status": "online"},
    {"hostname": "bj-leaf-01", "mgmt_ip": "10.10.1.21", "vendor": "Cisco", "model": "Nexus9300", "version": "10.2(5)", "site": "Beijing", "role": "Leaf", "status": "online"},
    {"hostname": "sh-core-01", "mgmt_ip": "10.10.2.11", "vendor": "Juniper", "model": "QFX10008", "version": "22.4R3", "site": "Shanghai", "role": "Core", "status": "online"},
    {"hostname": "sh-edge-01", "mgmt_ip": "10.10.2.31", "vendor": "Juniper", "model": "SRX4100", "version": "22.4R3", "site": "Shanghai", "role": "Edge", "status": "online"},
    {"hostname": "sz-core-01", "mgmt_ip": "10.10.3.11", "vendor": "Huawei", "model": "CE12800", "version": "V300R022", "site": "Shenzhen", "role": "Core", "status": "online"},
    {"hostname": "sz-leaf-01", "mgmt_ip": "10.10.3.21", "vendor": "Huawei", "model": "CE6865", "version": "V300R022", "site": "Shenzhen", "role": "Leaf", "status": "online"},
    {"hostname": "hz-core-01", "mgmt_ip": "10.10.4.11", "vendor": "Arista", "model": "7050X3", "version": "4.31.1F", "site": "Hangzhou", "role": "Core", "status": "online"},
    {"hostname": "hz-border-01", "mgmt_ip": "10.10.4.41", "vendor": "Arista", "model": "7280SR3", "version": "4.31.1F", "site": "Hangzhou", "role": "Border", "status": "online"},
    {"hostname": "xa-edge-01", "mgmt_ip": "10.10.5.31", "vendor": "Cisco", "model": "ASR1001-X", "version": "17.9.4", "site": "Xian", "role": "Edge", "status": "degraded"},
    {"hostname": "gz-firewall-01", "mgmt_ip": "10.10.6.51", "vendor": "PaloAlto", "model": "PA-5220", "version": "11.1.2", "site": "Guangzhou", "role": "Firewall", "status": "degraded"},
    {"hostname": "cd-leaf-01", "mgmt_ip": "10.10.7.21", "vendor": "Huawei", "model": "CE6857", "version": "V300R021", "site": "Chengdu", "role": "Leaf", "status": "offline"},
    {"hostname": "wh-edge-01", "mgmt_ip": "10.10.8.31", "vendor": "Juniper", "model": "MX204", "version": "22.4R3", "site": "Wuhan", "role": "Edge", "status": "offline"},
]


AUDIT_SEED = [
    ("create", "device", 1, "netops-admin", "新增北京核心交换机 bj-core-01"),
    ("create", "device", 2, "netops-admin", "新增北京叶子交换机 bj-leaf-01"),
    ("update", "device", 9, "ops-pulse", "将 xa-edge-01 状态更新为 degraded"),
    ("update", "device", 10, "ops-pulse", "将 gz-firewall-01 状态更新为 degraded"),
    ("delete", "interface", 0, "course-demo", "模拟删除冗余测试接口 Loopback999"),
    ("update", "device", 5, "fabric-bot", "同步 CE12800 软件版本到 V300R022"),
    ("create", "device", 11, "site-admin", "新增成都叶子节点 cd-leaf-01"),
    ("update", "device", 12, "site-admin", "武汉出口设备 wh-edge-01 进入维护窗口"),
]


def seed_database(db: Session) -> None:
    """在空库中生成演示数据。"""
    existing_device = db.scalar(select(Device.id).limit(1))
    if existing_device:
        return

    devices: list[Device] = []
    down_budget = 5
    for device_index, payload in enumerate(DEVICE_SEED, start=1):
        device = Device(**payload)
        db.add(device)
        db.flush()

        for interface_index in range(1, 7):
            is_down = down_budget > 0 and device_index <= 4 and interface_index <= (2 if device_index == 1 else 1)
            oper_status = "down" if is_down else "up"
            if is_down:
                down_budget -= 1
            ip_address = ""
            if interface_index == 1:
                ip_address = f"172.{device_index}.0.1/31"
            elif interface_index == 2:
                ip_address = f"172.{device_index}.0.3/31"
            interface = Interface(
                device_id=device.id,
                name=f"Ethernet1/{interface_index}",
                ip_address=ip_address,
                speed_mbps=10000 if interface_index <= 2 else 1000,
                admin_status="up",
                oper_status=oper_status,
                description=f"{device.site}-{device.role}-uplink-{interface_index}",
            )
            db.add(interface)
        devices.append(device)

    for action, entity_type, entity_id, operator, detail in AUDIT_SEED:
        db.add(
            AuditLog(
                action=action,
                entity_type=entity_type,
                entity_id=entity_id if entity_id else None,
                operator=operator,
                detail=detail,
            )
        )

    db.commit()


def ensure_seed_data() -> None:
    """在空数据库中自动补齐演示数据。"""
    init_database()
    db = SessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
