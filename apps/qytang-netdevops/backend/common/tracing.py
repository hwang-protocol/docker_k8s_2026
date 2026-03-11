"""提供 OpenTelemetry 初始化与常用辅助函数。"""

from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

from opentelemetry import propagate, trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.resources import DEPLOYMENT_ENVIRONMENT, SERVICE_NAME, SERVICE_VERSION, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.trace import SpanKind, Status, StatusCode


_INITIALIZED_SERVICES: set[str] = set()


def get_trace_endpoint() -> str:
    """返回 OTLP Trace 上报地址。"""
    return os.getenv("QYTANG_OTEL_ENDPOINT", "").strip()


def is_tracing_enabled() -> bool:
    """判断当前是否启用 Trace 上报。"""
    return bool(get_trace_endpoint())


def setup_tracing(app, service_name: str, version: str, engine=None) -> None:
    """为当前服务初始化 OpenTelemetry。"""
    if not is_tracing_enabled():
        return

    if service_name in _INITIALIZED_SERVICES:
        return

    resource = Resource.create(
        {
            SERVICE_NAME: service_name,
            SERVICE_VERSION: version,
            DEPLOYMENT_ENVIRONMENT: os.getenv("QYTANG_DEPLOYMENT_ENV", "lab"),
        }
    )
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(
                endpoint=get_trace_endpoint(),
                insecure=True,
            )
        )
    )
    trace.set_tracer_provider(provider)

    if app is not None:
        FastAPIInstrumentor.instrument_app(app, tracer_provider=provider)
    if engine is not None:
        SQLAlchemyInstrumentor().instrument(engine=engine)
    _INITIALIZED_SERVICES.add(service_name)


def get_tracer(service_name: str):
    """返回当前服务的 tracer。"""
    return trace.get_tracer(service_name)


def inject_trace_headers(headers: dict[str, str], span=None) -> None:
    """把当前上下文注入 HTTP 头。"""
    if not is_tracing_enabled():
        return
    if span is not None:
        propagate.inject(headers, context=trace.set_span_in_context(span))
        return
    propagate.inject(headers)


@contextmanager
def traced_span(
    service_name: str,
    span_name: str,
    *,
    kind: SpanKind = SpanKind.INTERNAL,
    attributes: dict[str, str | int | float] | None = None,
) -> Iterator:
    """创建一个带属性的 span。"""
    tracer = get_tracer(service_name)
    with tracer.start_as_current_span(span_name, kind=kind) as span:
        if attributes:
            for key, value in attributes.items():
                span.set_attribute(key, value)
        yield span


def mark_span_error(span, detail: str) -> None:
    """给当前 span 标记错误。"""
    span.set_status(Status(status_code=StatusCode.ERROR, description=detail))
