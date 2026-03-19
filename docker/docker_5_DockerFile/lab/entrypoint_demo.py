import sys

import requests


if __name__ == "__main__":
    if len(sys.argv) > 1:
        target = sys.argv[1]
    else:
        target = "https://www.jd.com"

    req_result = requests.get(target, timeout=10)

    print(f"sys.argv={sys.argv}")
    print(f"url={target}")
    print(f"status_code={req_result.status_code}")
