#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
echo "############ AgentTeams × HiMarket 最终验收 ############"
echo

echo "===== A. DSH Worker 运行时 ====="
docker ps --format '{{.Names}}|{{.Status}}|{{.Image}}' | grep dsh-worker
docker exec agentteams-worker-dsh-worker-1 sh -c 'printenv TEAMHARNESS_DSH_MAX_TOKENS'
docker exec agentteams-worker-dsh-worker-1 sh -c 'grep -c "entry?.header?.id" /opt/agentteams/dsh-template/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js' | sed 's/^/  session-resume fix present: /'
echo "  最近错误数（应为 0）:"
docker logs --since 10m agentteams-worker-dsh-worker-1 2>&1 | grep -cE "requested resume for missing|CONTEXT_WINDOW_EXCEEDED|STREAM_CLOSED" || echo "  0"

echo
echo "===== B. Worker 状态 ====="
docker exec agentteams-controller sh -c 'export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker status --name dsh-worker-1 -o json' 2>&1

echo
echo "===== C. HiMarket 门户可见产品（匿名视角）====="
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

echo
echo "===== D. AgentTeams 两个产品 ====="
for PID in product-b75dd88f9ff94238bbbb1f1e272ec676 product-10e5b8064b4a4f7fa7e48a4bead29767; do
  bash $API GET "/api/v1/products/${PID}" | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
print(f"   {d[\"productId\"]} | {d[\"name\"]} | {d[\"type\"]} | {d[\"status\"]}")
'
done

echo
echo "===== E. Worker 门户页面可达 ====="
for u in "/workers" "/workers/product-b75dd88f9ff94238bbbb1f1e272ec676"; do
  c=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 --resolve market.ai.ict.cmcc:443:127.0.0.1 "https://market.ai.ict.cmcc${u}")
  echo "   ${u} -> ${c}"
done

echo
echo "===== F. AgentTeams 平台服务健康 ====="
for c in agentteams-controller agentteams-manager; do
  docker ps --format '{{.Names}}|{{.Status}}' | grep "^${c}|"
done
