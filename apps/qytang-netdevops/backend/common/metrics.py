"""提供简单的指标采集能力。"""

from __future__ import annotations

from collections import defaultdict
from time import perf_counter


class MetricsCollector:
    """记录服务请求量和耗时。"""

    def __init__(self, service_name: str) -> None:
        self.service_name = service_name
        self.request_total = 0
        self.request_duration_total = 0.0
        self.route_counter: defaultdict[str, int] = defaultdict(int)

    def record(self, path: str, duration_seconds: float) -> None:
        """记录单次请求指标。"""
        self.request_total += 1
        self.request_duration_total += duration_seconds
        self.route_counter[path] += 1

    def render(self) -> str:
        """输出 Prometheus 文本格式。"""
        lines = [
            "# HELP qytang_requests_total Total HTTP requests.",
            "# TYPE qytang_requests_total counter",
            f'qytang_requests_total{{service="{self.service_name}"}} {self.request_total}',
            "# HELP qytang_request_duration_seconds_sum Total request duration seconds.",
            "# TYPE qytang_request_duration_seconds_sum counter",
            (
                f'qytang_request_duration_seconds_sum{{service="{self.service_name}"}} '
                f"{self.request_duration_total:.6f}"
            ),
            "# HELP qytang_route_requests_total Route level HTTP requests.",
            "# TYPE qytang_route_requests_total counter",
        ]
        for path, count in sorted(self.route_counter.items()):
            lines.append(
                f'qytang_route_requests_total{{service="{self.service_name}",path="{path}"}} {count}'
            )
        return "\n".join(lines) + "\n"


def now_seconds() -> float:
    """返回高精度单调时间。"""
    return perf_counter()
