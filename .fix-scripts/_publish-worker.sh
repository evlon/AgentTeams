#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
PORTAL="portal-c7e980809498465f8a4e86da88db243f"   # AI 开放平台

echo "===== 1. 选定示例 Worker：地理学家 ====="
PID="product-0585208d1d02443d96e28388d8e4618e"
bash $API GET "/api/v1/products/${PID}" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("productId =", d["productId"])
print("name =", d["name"])
print("status =", d["status"])
'

echo
echo "===== 2. 发布到门户 AI 开放平台 ====="
printf '{"portalId":"%s"}' "$PORTAL" > /tmp/pub.json
bash $API POST "/api/v1/products/${PID}/publications" /tmp/pub.json | head -c 500
echo

echo
echo "===== 3. 回读产品状态 ====="
bash $API GET "/api/v1/products/${PID}" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("status =", d["status"])
'

echo
echo "===== 4. 门户发布记录 ====="
bash $API GET "/api/v1/products/${PID}/publications" | head -c 600
echo

echo
echo "===== 5. 匿名访问门户验证（开发者视角）====="
curl -sk --max-time 20 --resolve market.ai.ict.cmcc:443:127.0.0.1 \
  "https://market.ai.ict.cmcc/api/v1/products?page=1&size=5&type=WORKER" \
  | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("匿名可见 WORKER totalElements =", d["totalElements"])
for p in d["content"][:5]:
    print("  ", p["productId"], "|", p["name"], "|", p["status"])
'
