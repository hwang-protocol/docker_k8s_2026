#!/usr/bin/env python3
"""
为第五章生成固定可复用的 JWT 演示材料。
"""

from __future__ import annotations

import base64
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path


CHAPTER_DIR = Path("/docker_k8s_2026/k8s/05-security-and-zero-trust")
PKI_DIR = CHAPTER_DIR / "pki"

PRIVATE_KEY = PKI_DIR / "jwt-demo-private.pem"
PUBLIC_KEY = PKI_DIR / "jwt-demo-public.pem"
JWKS_FILE = PKI_DIR / "jwks.json"
USER_TOKEN = PKI_DIR / "user.jwt"
ADMIN_TOKEN = PKI_DIR / "admin.jwt"

ISSUER = "https://secure-app.qytk8s.com/auth"
AUDIENCE = "mesh-demo"


def run_command(command: list[str], capture_output: bool = False) -> str:
    """运行外部命令。"""
    result = subprocess.run(
        command,
        check=True,
        text=True,
        capture_output=capture_output,
    )
    return result.stdout if capture_output else ""


def b64url_encode(raw: bytes) -> str:
    """返回不带补位符的 Base64URL 字符串。"""
    return base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")


def ensure_keypair() -> None:
    """如果本地还没有演示密钥，则生成 RSA 密钥对。"""
    PKI_DIR.mkdir(parents=True, exist_ok=True)

    if PRIVATE_KEY.exists() and PUBLIC_KEY.exists():
        return

    run_command(
        [
            "openssl",
            "genpkey",
            "-algorithm",
            "RSA",
            "-out",
            str(PRIVATE_KEY),
            "-pkeyopt",
            "rsa_keygen_bits:2048",
        ]
    )
    run_command(
        [
            "openssl",
            "pkey",
            "-in",
            str(PRIVATE_KEY),
            "-pubout",
            "-out",
            str(PUBLIC_KEY),
        ]
    )


def build_jwk() -> dict:
    """从公钥中提取 modulus 和 exponent，生成 JWK。"""
    output = run_command(
        ["openssl", "rsa", "-pubin", "-in", str(PUBLIC_KEY), "-text", "-noout"],
        capture_output=True,
    )

    modulus_match = re.search(r"Modulus:\n(.*?)Exponent:", output, flags=re.S)
    exponent_match = re.search(r"Exponent:\s+(\d+)", output)
    if not modulus_match or not exponent_match:
        raise RuntimeError("无法从 openssl 输出中解析 RSA 公钥")

    modulus_hex = re.sub(r"[^0-9A-Fa-f]", "", modulus_match.group(1))
    exponent_int = int(exponent_match.group(1))

    modulus_bytes = bytes.fromhex(modulus_hex)
    exponent_bytes = exponent_int.to_bytes((exponent_int.bit_length() + 7) // 8, "big")

    kid = hashlib.sha256(PUBLIC_KEY.read_bytes()).hexdigest()[:16]

    return {
        "kty": "RSA",
        "use": "sig",
        "alg": "RS256",
        "kid": kid,
        "n": b64url_encode(modulus_bytes),
        "e": b64url_encode(exponent_bytes),
    }


def sign_rs256(signing_input: bytes) -> str:
    """使用 openssl 对 JWT 前两段做 RS256 签名。"""
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(PRIVATE_KEY)],
        input=signing_input,
        check=True,
        capture_output=True,
    )
    return b64url_encode(result.stdout)


def build_token(payload: dict) -> str:
    """生成一个 JWT。"""
    jwks = json.loads(JWKS_FILE.read_text(encoding="utf-8"))
    kid = jwks["keys"][0]["kid"]

    header = {
        "alg": "RS256",
        "typ": "JWT",
        "kid": kid,
    }

    header_part = b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_part = b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_part}.{payload_part}".encode("utf-8")
    signature_part = sign_rs256(signing_input)
    return f"{header_part}.{payload_part}.{signature_part}"


def write_materials() -> None:
    """生成 jwks.json 和演示 token。"""
    now = int(time.time())

    jwk = build_jwk()
    JWKS_FILE.write_text(json.dumps({"keys": [jwk]}, indent=2), encoding="utf-8")

    user_payload = {
        "iss": ISSUER,
        "aud": AUDIENCE,
        "sub": "demo-user",
        "preferred_username": "demo-user",
        "role": "user",
        "iat": now,
        "exp": now + 86400 * 365,
    }
    admin_payload = {
        "iss": ISSUER,
        "aud": AUDIENCE,
        "sub": "demo-admin",
        "preferred_username": "demo-admin",
        "role": "admin",
        "iat": now,
        "exp": now + 86400 * 365,
    }

    USER_TOKEN.write_text(build_token(user_payload), encoding="utf-8")
    ADMIN_TOKEN.write_text(build_token(admin_payload), encoding="utf-8")


def main() -> None:
    """主流程。"""
    ensure_keypair()
    write_materials()
    print(f"已生成：{JWKS_FILE}")
    print(f"已生成：{USER_TOKEN}")
    print(f"已生成：{ADMIN_TOKEN}")


if __name__ == "__main__":
    main()
