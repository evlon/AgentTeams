#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh

echo "===== 1. 门户匿名可见的 WORKER 列表 ====="
curl -sk --max-time 20 --resolve market.ai.ict.cmcc:443:127.0.0.1 \
  "https://market.ai.ict.cmcc/api/v1/products?page=1&size=50&type=WORKER" \
  | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("匿名可见 WORKER totalElements =", d["totalElements"])
for p in d["content"]:
    print("  ", p["productId"], "|", p["name"], "|", p["status"])
'

echo
echo "===== 2. 门户 Worker 页面可达性 ====="
for u in "/workers" "/workers/product-b75dd88f9ff94238bbbb1f1e272ec676"; do
  c=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 --resolve market.ai.ict.cmcc:443:127.0.0.1 "https://market.ai.ict.cmcc${u}")
  echo "  ${u} -> ${c}"
done

echo
echo "===== 3. AgentTeams Worker 详情 ====="
bash $API GET "/api/v1/products/product-b75dd88f9ff94238bbbb1f1e272ec676" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("  productId =", d["productId"])
print("  name      =", d["name"])
print("  type      =", d["type"])
print("  status    =", d["status"])
print("  desc      =", (d.get("description") or "")[:100])
'

echo
echo "===== 4. 下载包验证（匿名）====="
curl -sk -o /tmp/dl.zip -w "  download -> %{http_code}, size=%{size_download}\n" --max-time 30 \
  --resolve market.ai.ict.cmcc:443:127.0.0.1 \
  "https://market.ai.ict.cmcc/api/v1/workers/product-b75dd88f9ff94238bbbb1f1e272ec676/download"
python3 -c "
import zipfile
try:
    z=zipfile.ZipFile('/tmp/dl.zip')
    print('  ZIP 内容:', z.namelist())
except Exception as e:
    print('  非 ZIP:', e)
"
