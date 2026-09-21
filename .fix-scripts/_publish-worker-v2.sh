#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
PORTAL="portal-c7e980809498465f8a4e86da88db243f"
PID=$(cat /tmp/worker_pid.txt)

echo "===== 1. 提审（draft -> reviewing）====="
printf '{"status":"reviewing"}' > /tmp/st1.json
bash $API PATCH "/api/v1/workers/${PID}/versions/v1" /tmp/st1.json | head -c 300
echo
sleep 3
bash $API GET "/api/v1/workers/${PID}/versions" | python3 -c 'import sys,json; print("  ", json.dumps(json.load(sys.stdin)["data"], ensure_ascii=False))'

echo
echo "===== 2. 发布上线（-> online）====="
printf '{"status":"online"}' > /tmp/st2.json
bash $API PATCH "/api/v1/workers/${PID}/versions/v1" /tmp/st2.json | head -c 400
echo
sleep 3
bash $API GET "/api/v1/workers/${PID}/versions" | python3 -c 'import sys,json; print("  ", json.dumps(json.load(sys.stdin)["data"], ensure_ascii=False))'

echo
echo "===== 3. 设为最新版本 ====="
printf '{"latest":true}' > /tmp/st3.json
bash $API PATCH "/api/v1/workers/${PID}/versions/v1" /tmp/st3.json | head -c 300
echo

echo
echo "===== 4. 产品状态 ====="
bash $API GET "/api/v1/products/${PID}" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("  name =", d["name"])
print("  status =", d["status"])
print("  workerConfig =", json.dumps((d.get("feature") or {}).get("workerConfig"), ensure_ascii=False))
'

echo
echo "===== 5. 发布到门户 ====="
printf '{"portalId":"%s"}' "$PORTAL" > /tmp/pub2.json
bash $API POST "/api/v1/products/${PID}/publications" /tmp/pub2.json | head -c 400
echo
bash $API GET "/api/v1/products/${PID}" | python3 -c 'import sys,json; print("  status =", json.load(sys.stdin)["data"]["status"])'
