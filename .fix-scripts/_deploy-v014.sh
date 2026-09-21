#!/bin/bash
set -uo pipefail
W="agentteams-worker-dsh-worker-1"
NEW="dockerhub.kubekey.local:31104/library/agentteams-deepseek-harness-worker:v0.1.4"

echo "=== 1. 更新 Worker CR 镜像 ==="
docker exec agentteams-controller sh -c "export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt update worker --name dsh-worker-1 --image '$NEW'" 2>&1

echo
echo "=== 2. 确认 CR 与 env 都还在 ==="
TOKEN=$(docker exec agentteams-controller cat /data/agentteams-controller/admin-token | tr -d '\n')
docker exec agentteams-controller sh -c "curl -sk -H 'Authorization: Bearer $TOKEN' https://127.0.0.1:6443/apis/agentteams.io/v1beta1/namespaces/default/workers/dsh-worker-1" \
 | python3 -c 'import sys,json;d=json.load(sys.stdin);print("image =",d["spec"]["image"]);print("env =",json.dumps(d["spec"].get("env"),ensure_ascii=False))'

echo
echo "=== 3. 重建容器（sleep -> ensure-ready）==="
docker exec agentteams-controller sh -c 'export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker sleep --name dsh-worker-1' 2>&1
sleep 5
docker rm -f "$W" >/dev/null 2>&1 || true
docker exec agentteams-controller sh -c 'export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker ensure-ready --name dsh-worker-1' 2>&1
sleep 35

echo
echo "=== 4. 容器状态 + 镜像 + 修复 ==="
docker ps --format '{{.Names}}|{{.Status}}|{{.Image}}' | grep dsh-worker
docker exec "$W" sh -c 'grep -c "entry?.header?.id" /opt/agentteams/dsh-template/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js && echo IMAGE_FIX_PRESENT'

echo
echo "=== 5. 重置 bridge state（首次走 create）==="
docker exec "$W" sh -c 'python3 -c "
import json
p=\"/root/agentteams-fs/agents/dsh-worker-1/runtime/matrix-bridge-state.json\"
d=json.load(open(p))
for r in (d.get(\"rooms\") or {}).values(): r[\"ready\"]=False
d[\"events\"]={}
json.dump(d, open(p,\"w\"), ensure_ascii=False, sort_keys=True)
print(\"state reset:\", json.dumps(d.get(\"rooms\"), ensure_ascii=False))
"'
