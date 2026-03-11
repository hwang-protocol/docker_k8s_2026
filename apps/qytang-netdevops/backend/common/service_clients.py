"""封装服务间 HTTP 调用。"""

from __future__ import annotations

import json
from time import perf_counter
from urllib import parse, request
from urllib.error import HTTPError, URLError

from opentelemetry.trace import SpanKind

from backend.common.metrics import MetricsCollector
from backend.common.tracing import inject_trace_headers, mark_span_error, traced_span


def request_json(
    base_url: str,
    path: str,
    method: str = "GET",
    payload: dict | None = None,
    params: dict[str, str | int] | None = None,
    timeout: int = 5,
    caller_service: str = "unknown-service",
    target_service: str = "upstream-service",
    metrics: MetricsCollector | None = None,
):
    """请求 JSON 接口并返回解析结果。"""
    url = base_url.rstrip("/") + path
    if params:
        query_string = parse.urlencode({key: value for key, value in params.items() if value is not None})
        url = f"{url}?{query_string}"

    body = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    started = perf_counter()
    with traced_span(
        caller_service,
        f"{method} {path}",
        kind=SpanKind.CLIENT,
        attributes={
            "http.method": method,
            "http.url": url,
            "peer.service": target_service,
        },
    ) as span:
        inject_trace_headers(headers, span=span)
        req = request.Request(url=url, data=body, method=method, headers=headers)
        try:
            with request.urlopen(req, timeout=timeout) as response:
                payload_text = response.read().decode("utf-8")
                duration = perf_counter() - started
                if metrics is not None:
                    metrics.record_outbound(target_service, method, path, response.status, duration)
                span.set_attribute("http.status_code", response.status)
                return json.loads(payload_text)
        except HTTPError as exc:
            duration = perf_counter() - started
            if metrics is not None:
                metrics.record_outbound(target_service, method, path, exc.code, duration)
            span.set_attribute("http.status_code", exc.code)
            mark_span_error(span, f"服务调用失败: {exc.code} {url}")
            raise RuntimeError(f"服务调用失败: {exc.code} {url}") from exc
        except URLError as exc:
            duration = perf_counter() - started
            if metrics is not None:
                metrics.record_outbound(target_service, method, path, 502, duration)
            mark_span_error(span, f"服务不可达: {url}")
            raise RuntimeError(f"服务不可达: {url}") from exc
