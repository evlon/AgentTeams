#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
PID=$(cat /tmp/agentapi_pid.txt)

echo "===== 1. 创建独立 API Definition（不绑产品，记录契约）====="
python3 - <<'PY' > /tmp/apidef3.json
import json
spec = {
    "type": "AGENT_API",
    "basePath": "/api/v1",
    "protocols": ["HTTP"],
    "httpRoutes": [
        {"path": "/workers", "method": "GET", "description": "列出所有 Worker"},
        {"path": "/workers/{name}", "method": "GET", "description": "查询 Worker 详情"},
        {"path": "/workers/{name}/status", "method": "GET", "description": "查询 Worker 运行时状态"},
        {"path": "/workers/{name}/wake", "method": "POST", "description": "唤醒 Worker"},
        {"path": "/workers/{name}/sleep", "method": "POST", "description": "休眠 Worker"},
        {"path": "/teams", "method": "GET", "description": "列出所有 Team"},
        {"path": "/humans", "method": "GET", "description": "列出所有 Human"},
        {"path": "/projects", "method": "GET", "description": "列出所有项目"},
        {"path": "/status", "method": "GET", "description": "集群状态"},
    ],
}
print(json.dumps({
    "name": "AgentTeams Controller API",
    "description": "AgentTeams 平台的 Agent 生命周期管理 API（agentteams-controller REST API）",
    "type": "AGENT_API",
    "version": "v1",
    "spec": spec,
}, ensure_ascii=False))
PY
bash $API POST '/api/v1/api-definitions' /tmp/apidef3.json | head -c 500
echo

echo
echo "===== 2. 列出 API Definitions ====="
bash $API GET '/api/v1/api-definitions?page=1&size=20' | head -c 600
echo

echo
echo "===== 3. 门户匿名可见 AGENT_API ====="
curl -sk --max-time 20 --resolve market.ai.ict.cmcc:443:127.0.0.1 \
  "https://market.ai.ict.cmcc/api/v1/products?page=1&size=20&type=AGENT_API" \
  | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("  totalElements =", d["totalElements"])
for p in d["content"]:
    print("   ", p["productId"], "|", p["name"], "|", p["status"])
'

echo
echo "===== 4. 门户所有已发布产品统计 ====="
curl -sk --max-time 20 --resolve market.ai.ict.cmcc:443:127.0.0.1 \
  "https://market.ai.ict.cmcc/api/v1/products?page=1&size=300" \
  | python3 -c '
import sys,json
from collections import Counter
d=json.load(sys.stdin)["data"]
print("  门户可见总数 =", d["totalElements"])
c=Counter((p["type"], p["status"]) for p in d["content"])
for (t,s),n in sorted(c.items()):
    print(f"   {t:14s} {s:10s} {n}")
'
