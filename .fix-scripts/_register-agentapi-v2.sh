#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
PORTAL="portal-c7e980809498465f8a4e86da88db243f"
PID=$(cat /tmp/agentapi_pid.txt)
echo "复用已发布产品 PID=$PID"

echo "===== 1. 先取消发布（改 ref 前置要求）====="
PUBID=$(bash $API GET "/api/v1/products/${PID}/publications" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
c=d.get("content") or []
print(c[0]["publicationId"] if c else "")
' 2>/dev/null)
echo "publicationId=$PUBID"
if [ -n "$PUBID" ]; then
  bash $API DELETE "/api/v1/products/${PID}/publications/${PUBID}" | head -c 200
  echo
fi

echo
echo "===== 2. 创建 API Definition（spec 带 type 判别）====="
python3 - "$PID" <<'PY' > /tmp/apidef2.json
import json, sys
pid = sys.argv[1]
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
bash $API POST '/api/v1/api-definitions' /tmp/apidef2.json | head -c 700
echo

echo
echo "===== 3. 产品状态与 ref ====="
bash $API GET "/api/v1/products/${PID}" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print("  status =", d["status"], "| type =", d["type"])
'
bash $API GET "/api/v1/products/${PID}/ref" | head -c 900
echo

echo
echo "===== 4. 重新发布到门户 ====="
printf '{"portalId":"%s"}' "$PORTAL" > /tmp/pub4.json
bash $API POST "/api/v1/products/${PID}/publications" /tmp/pub4.json | head -c 300
echo
bash $API GET "/api/v1/products/${PID}" | python3 -c 'import sys,json; print("  final status =", json.load(sys.stdin)["data"]["status"])'
