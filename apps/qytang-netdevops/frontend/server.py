"""提供静态页面与本地 API 代理。"""

from __future__ import annotations

import json
import os
from time import perf_counter
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib import error, parse, request

from opentelemetry.trace import SpanKind

from backend.common.metrics import MetricsCollector
from backend.common.tracing import inject_trace_headers, mark_span_error, setup_tracing, traced_span


FRONTEND_DIR = Path(__file__).resolve().parent
DEVICE_PROXY_URL = os.getenv("QYTANG_DEVICE_PROXY_URL", "http://127.0.0.1:8001/")
RESOURCE_PROXY_URL = os.getenv("QYTANG_RESOURCE_PROXY_URL", "http://127.0.0.1:8002/")
AUDIT_PROXY_URL = os.getenv("QYTANG_AUDIT_PROXY_URL", "http://127.0.0.1:8003/")
BIND_HOST = os.getenv("QYTANG_FRONTEND_HOST", "0.0.0.0")
PORT = int(os.getenv("QYTANG_FRONTEND_PORT", "8080"))
SERVICE_NAME = "frontend"
SERVICE_VERSION = "1.1.0"
metrics = MetricsCollector(SERVICE_NAME)


class FrontendHandler(SimpleHTTPRequestHandler):
    """处理静态文件和 API 代理。"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(FRONTEND_DIR), **kwargs)

    def do_GET(self) -> None:  # noqa: N802
        """优先处理代理请求。"""
        started = perf_counter()
        if self.path == "/healthz":
            self.render_json({"status": "ok", "service": SERVICE_NAME}, 200)
            metrics.record_http("GET", "/healthz", 200, perf_counter() - started)
            return
        if self.path == "/metrics":
            payload = metrics.render().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            metrics.record_http("GET", "/metrics", 200, perf_counter() - started)
            return
        if self.path.startswith("/api/"):
            self.proxy_request()
            return
        super().do_GET()
        metrics.record_http("GET", self.path, self.response_code, perf_counter() - started)

    def do_POST(self) -> None:  # noqa: N802
        """转发 POST 请求。"""
        self.proxy_request()

    def do_PUT(self) -> None:  # noqa: N802
        """转发 PUT 请求。"""
        self.proxy_request()

    def do_DELETE(self) -> None:  # noqa: N802
        """转发 DELETE 请求。"""
        self.proxy_request()

    def send_response(self, code: int, message: str | None = None) -> None:  # noqa: A003
        """记录最近一次响应码，便于写入指标。"""
        self.response_code = code
        super().send_response(code, message)

    def render_json(self, payload: dict[str, str], status_code: int) -> None:
        """返回 JSON 响应。"""
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def proxy_request(self) -> None:
        """把前端请求转发到对应后端服务。"""
        target_base, stripped_path = self.resolve_target()
        target_service = self.resolve_target_service()
        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length) if content_length else None

        proxied_url = parse.urljoin(target_base.rstrip("/") + "/", stripped_path.lstrip("/"))
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in {"host", "content-length", "accept-encoding", "connection"}
        }
        started = perf_counter()
        with traced_span(
            SERVICE_NAME,
            f"{self.command} {self.path}",
            kind=SpanKind.SERVER,
            attributes={
                "http.target": self.path,
                "proxy.target_service": target_service,
            },
        ) as span:
            # 必须在 span 上下文建立之后再注入 header，才能把整条链路继续传到后端。
            inject_trace_headers(headers, span=span)
            req = request.Request(url=proxied_url, data=body, method=self.command, headers=headers)
            try:
                with request.urlopen(req, timeout=10) as response:
                    payload = response.read()
                    self.send_response(response.status)
                    for header_key, header_value in response.headers.items():
                        if header_key.lower() in {"transfer-encoding", "connection", "content-encoding"}:
                            continue
                        self.send_header(header_key, header_value)
                    self.end_headers()
                    self.wfile.write(payload)
                    duration = perf_counter() - started
                    metrics.record_http(self.command, self.path, response.status, duration)
                    metrics.record_outbound(target_service, self.command, stripped_path, response.status, duration)
            except error.HTTPError as exc:
                payload = exc.read()
                self.send_response(exc.code)
                self.send_header("Content-Type", exc.headers.get("Content-Type", "text/plain; charset=utf-8"))
                self.end_headers()
                self.wfile.write(payload)
                duration = perf_counter() - started
                metrics.record_http(self.command, self.path, exc.code, duration)
                metrics.record_outbound(target_service, self.command, stripped_path, exc.code, duration)
                mark_span_error(span, f"代理调用失败: {exc.code} {proxied_url}")
            except error.URLError as exc:
                self.send_response(502)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(f'{{"detail":"代理目标不可达: {exc.reason}"}}'.encode("utf-8"))
                duration = perf_counter() - started
                metrics.record_http(self.command, self.path, 502, duration)
                metrics.record_outbound(target_service, self.command, stripped_path, 502, duration)
                mark_span_error(span, f"代理目标不可达: {proxied_url}")

    def resolve_target(self) -> tuple[str, str]:
        """根据路径前缀决定代理目标。"""
        routes = {
            "/api/device": DEVICE_PROXY_URL,
            "/api/resource": RESOURCE_PROXY_URL,
            "/api/audit": AUDIT_PROXY_URL,
        }
        for prefix, target in routes.items():
            if self.path.startswith(prefix):
                stripped_path = self.path[len(prefix) :]
                if not stripped_path:
                    stripped_path = "/"
                return target, stripped_path
        return DEVICE_PROXY_URL, self.path

    def resolve_target_service(self) -> str:
        """返回当前代理目标服务名。"""
        if self.path.startswith("/api/resource"):
            return "resource-service"
        if self.path.startswith("/api/audit"):
            return "audit-service"
        return "device-service"

    def log_message(self, format: str, *args) -> None:
        """保持控制台输出简单。"""
        print(f"[frontend] {self.address_string()} - {format % args}")


def main() -> None:
    """启动前端服务。"""
    setup_tracing(None, SERVICE_NAME, SERVICE_VERSION)
    server = ThreadingHTTPServer((BIND_HOST, PORT), FrontendHandler)
    print(f"QYT NetDevOps frontend listening on http://{BIND_HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
