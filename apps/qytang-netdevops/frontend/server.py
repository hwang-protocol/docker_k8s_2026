"""提供静态页面与本地 API 代理。"""

from __future__ import annotations

import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib import error, parse, request


FRONTEND_DIR = Path(__file__).resolve().parent
DEVICE_PROXY_URL = os.getenv("QYTANG_DEVICE_PROXY_URL", "http://127.0.0.1:8001/")
RESOURCE_PROXY_URL = os.getenv("QYTANG_RESOURCE_PROXY_URL", "http://127.0.0.1:8002/")
AUDIT_PROXY_URL = os.getenv("QYTANG_AUDIT_PROXY_URL", "http://127.0.0.1:8003/")
BIND_HOST = os.getenv("QYTANG_FRONTEND_HOST", "0.0.0.0")
PORT = int(os.getenv("QYTANG_FRONTEND_PORT", "8080"))


class FrontendHandler(SimpleHTTPRequestHandler):
    """处理静态文件和 API 代理。"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(FRONTEND_DIR), **kwargs)

    def do_GET(self) -> None:  # noqa: N802
        """优先处理代理请求。"""
        if self.path.startswith("/api/"):
            self.proxy_request()
            return
        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        """转发 POST 请求。"""
        self.proxy_request()

    def do_PUT(self) -> None:  # noqa: N802
        """转发 PUT 请求。"""
        self.proxy_request()

    def do_DELETE(self) -> None:  # noqa: N802
        """转发 DELETE 请求。"""
        self.proxy_request()

    def proxy_request(self) -> None:
        """把前端请求转发到对应后端服务。"""
        target_base, stripped_path = self.resolve_target()
        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length) if content_length else None

        proxied_url = parse.urljoin(target_base.rstrip("/") + "/", stripped_path.lstrip("/"))
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in {"host", "content-length", "accept-encoding", "connection"}
        }
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
        except error.HTTPError as exc:
            payload = exc.read()
            self.send_response(exc.code)
            self.send_header("Content-Type", exc.headers.get("Content-Type", "text/plain; charset=utf-8"))
            self.end_headers()
            self.wfile.write(payload)
        except error.URLError as exc:
            self.send_response(502)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(f'{{"detail":"代理目标不可达: {exc.reason}"}}'.encode("utf-8"))

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

    def log_message(self, format: str, *args) -> None:
        """保持控制台输出简单。"""
        print(f"[frontend] {self.address_string()} - {format % args}")


def main() -> None:
    """启动前端服务。"""
    server = ThreadingHTTPServer((BIND_HOST, PORT), FrontendHandler)
    print(f"QYT NetDevOps frontend listening on http://{BIND_HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
