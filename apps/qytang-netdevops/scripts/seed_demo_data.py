"""手工执行演示数据初始化。"""

from backend.common.seed import ensure_seed_data


def main() -> None:
    """补齐演示数据。"""
    ensure_seed_data()
    print("OK: 演示数据已初始化")


if __name__ == "__main__":
    main()
