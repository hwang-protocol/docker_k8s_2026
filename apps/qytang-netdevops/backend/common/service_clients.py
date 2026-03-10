"""封装服务间 HTTP 调用。"""

from __future__ import annotations

import json
from urllib import parse, request
from urllib.error import HTTPError, URLError


def request_json(
    base_url: str,
    path: str,
    method: str = "GET",
    payload: dict | None = None,
    params: dict[str, str | int] | None = None,
    timeout: int = 5,
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

    req = request.Request(url=url, data=body, method=method, headers=headers)
    try:
        with request.urlopen(req, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        raise RuntimeError(f"服务调用失败: {exc.code} {url}") from exc
    except URLError as exc:
        raise RuntimeError(f"服务不可达: {url}") from exc
