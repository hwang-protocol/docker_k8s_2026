"""封装数据库初始化与会话。"""

from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from backend.common.config import DATA_DIR, get_database_url
from backend.common.models import Base


DATABASE_URL = get_database_url()


def create_db_engine():
    """根据连接串创建数据库引擎。"""
    engine_kwargs: dict[str, object] = {"future": True}
    if DATABASE_URL.startswith("sqlite"):
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        engine_kwargs["connect_args"] = {"check_same_thread": False}
    return create_engine(DATABASE_URL, **engine_kwargs)


ENGINE = create_db_engine()
SessionLocal = sessionmaker(bind=ENGINE, autoflush=False, autocommit=False, future=True)


def init_database() -> None:
    """初始化所有表结构。"""
    Base.metadata.create_all(bind=ENGINE)


def get_db() -> Generator[Session, None, None]:
    """返回可关闭的数据库会话。"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
