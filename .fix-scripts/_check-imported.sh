#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh

echo "===== 1. 导入的 WORKER 产品（前 10）====="
bash $API GET '/api/v1/products?page=1&size=200&type=WORKER' | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("totalElements =", d["totalElements"])
for p in d["content"][:10]:
    wc = (p.get("feature") or {}).get("workerConfig") or {}
    print(f"  {p[\"productId\"]} | {p[\"name\"]} | status={p[\"status\"]} | agentSpecName={wc.get(\"agentSpecName\")} | online={wc.get(\"latestVersion\")}")
'

echo
echo "===== 2. 找一个 READY 的产品查 versions ====="
PID=$(bash $API GET '/api/v1/products?page=1&size=200&type=WORKER' | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]["content"]
for p in d:
    if p["status"]=="READY":
        print(p["productId"]); break
')
echo "PICKED=$PID"
bash $API GET "/api/v1/workers/${PID}/versions" | head -c 800
echo
echo "===== 3. 该产品详情 ====="
bash $API GET "/api/v1/products/${PID}" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("name =", d["name"])
print("status =", d["status"])
print("type =", d["type"])
print("feature =", json.dumps(d.get("feature"), ensure_ascii=False)[:400])
'
