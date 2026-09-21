#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
PORTAL="portal-c7e980809498465f8a4e86da88db243f"
NAME="AgentTeams Agent API"

echo "===== 1. 创建 AGENT_API 产品 ====="
printf '{"name":"%s","description":"AgentTeams 平台的 Agent 调用 API：通过 agentteams-controller REST API 管理 Worker / Team / Human，支持创建、唤醒、休眠、状态查询等 Agent 生命周期操作","type":"AGENT_API"}' "$NAME" > /tmp/a.json
RESP=$(bash $API POST '/api/v1/products' /tmp/a.json)
echo "$RESP" | head -c 350
echo
PID=$(printf '%s' "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["productId"])' 2>/dev/null)
[ -z "$PID" ] && { echo "创建失败"; exit 1; }
echo "PID=$PID"
echo "$PID" > /tmp/agentapi_pid.txt

echo
echo "===== 2. 创建 API Definition 并绑定产品 ====="
python3 - "$PID" <<'PY' > /tmp/apidef.json
import json, sys
pid = sys.argv[1]
base = "http://agentteams-controller:8090"
spec = {
    "type": "AGENT_API",
    "basePath": "/api/v1",
    "protocols": ["A2A", "HTTP"],
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
    "relatedProductId": pid,
    "version": "v1",
    "spec": spec,
}, ensure_ascii=False))
PY
cat /tmp/apidef.json | head -c 400
echo
bash $API POST '/api/v1/api-definitions' /tmp/apidef.json | head -c 600
echo

echo
echo "===== 3. 产品状态与 ref ====="
bash $API GET "/api/v1/products/${PID}" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("  status =", d["status"], "| type =", d["type"])
'
bash $API GET "/api/v1/products/${PID}/ref" | head -c 700
echo

echo
echo "===== 4. 发布到门户 ====="
printf '{"portalId":"%s"}' "$PORTAL" > /tmp/pub3.json
bash $API POST "/api/v1/products/${PID}/publications" /tmp/pub3.json | head -c 400
echo
bash $API GET "/api/v1/products/${PID}" | python3 -c 'import sys,json; print("  final status =", json.load(sys.stdin)["data"]["status"])'
