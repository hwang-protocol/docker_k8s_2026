"""提供标准 Prometheus 指标采集能力。"""

from __future__ import annotations

from time import perf_counter

from prometheus_client import Counter, Histogram, generate_latest


HTTP_REQUESTS_TOTAL = Counter(
    "qytang_http_requests_total",
    "QYT NetDevOps HTTP request total.",
    ["service", "method", "path", "status_code"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "qytang_http_request_duration_seconds",
    "QYT NetDevOps HTTP request duration.",
    ["service", "method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10),
)

OUTBOUND_REQUESTS_TOTAL = Counter(
    "qytang_outbound_requests_total",
    "QYT NetDevOps outbound request total.",
    ["service", "target_service", "method", "path", "status_code"],
)

OUTBOUND_REQUEST_DURATION_SECONDS = Histogram(
    "qytang_outbound_request_duration_seconds",
    "QYT NetDevOps outbound request duration.",
    ["service", "target_service", "method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10),
)

BUSINESS_OPERATIONS_TOTAL = Counter(
    "qytang_business_operations_total",
    "QYT NetDevOps business operation total.",
    ["service", "operation", "result"],
)


class MetricsCollector:
    """封装单个服务的指标写入逻辑。"""

    def __init__(self, service_name: str) -> None:
        self.service_name = service_name

    def record_http(self, method: str, path: str, status_code: int, duration_seconds: float) -> None:
        """记录入站 HTTP 指标。"""
        normalized_path = path or "/"
        HTTP_REQUESTS_TOTAL.labels(
            service=self.service_name,
            method=method,
            path=normalized_path,
            status_code=str(status_code),
        ).inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(
            service=self.service_name,
            method=method,
            path=normalized_path,
        ).observe(duration_seconds)

    def record_outbound(
        self,
        target_service: str,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float,
    ) -> None:
        """记录服务间调用指标。"""
        normalized_path = path or "/"
        OUTBOUND_REQUESTS_TOTAL.labels(
            service=self.service_name,
            target_service=target_service,
            method=method,
            path=normalized_path,
            status_code=str(status_code),
        ).inc()
        OUTBOUND_REQUEST_DURATION_SECONDS.labels(
            service=self.service_name,
            target_service=target_service,
            method=method,
            path=normalized_path,
        ).observe(duration_seconds)

    def record_operation(self, operation: str, result: str = "success") -> None:
        """记录关键业务动作次数。"""
        BUSINESS_OPERATIONS_TOTAL.labels(
            service=self.service_name,
            operation=operation,
            result=result,
        ).inc()

    def render(self) -> str:
        """输出 Prometheus 文本格式。"""
        return generate_latest().decode("utf-8")


def now_seconds() -> float:
    """返回高精度单调时间。"""
    return perf_counter()
