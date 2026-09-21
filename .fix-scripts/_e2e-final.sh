#!/bin/bash
set -uo pipefail
MATRIX_URL="http://agentteams-controller:6167"
CTR="agentteams-manager"
WORKER="agentteams-worker-dsh-worker-1"
WORKER_ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'

echo "=== 0. 重置 bridge state（ready=false，让首次走 create）==="
docker exec "$WORKER" sh -c 'python3 -c "
import json
p=\"/root/agentteams-fs/agents/dsh-worker-1/runtime/matrix-bridge-state.json\"
d=json.load(open(p))
for r in (d.get(\"rooms\") or {}).values():
    r[\"ready\"]=False
d[\"events\"]={}
json.dump(d, open(p,\"w\"), ensure_ascii=False, sort_keys=True)
print(\"rooms =\", json.dumps(d.get(\"rooms\"), ensure_ascii=False))
"'

echo
echo "=== 1. 重启 worker 让新 state + 修复生效 ==="
docker rm -f "$WORKER" >/dev/null 2>&1
sleep 3
docker exec agentteams-controller sh -c 'export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker ensure-ready --name dsh-worker-1' 2>&1
sleep 30
docker ps --format '{{.Names}}|{{.Status}}' | grep dsh-worker

echo
echo "=== 2. 修复是否随镜像恢复？（检查）==="
docker exec "$WORKER" sh -c 'R=/root/agentteams-fs/agents/dsh-worker-1/.dsh/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js; grep -n "entry?.header?.id" $R && echo "修复仍在" || echo "修复被重建覆盖，需重新应用"'

echo
echo "=== 3. 发消息（第 1 条：create）==="
resp=$(docker exec "$CTR" curl -s -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login")
TOKEN=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
ENC=$(printf '%s' "$WORKER_ROOM" | sed 's/!/%21/g; s/:/%3A/g')
TXN="e2e1_$(date +%s)"
msg_json=$(python3 -c 'import json;print(json.dumps({"msgtype":"m.text","body":"请只回复四个字：链路正常"}))')
docker exec "$CTR" curl -s -X PUT -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d "$msg_json" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN" | head -c 150
echo

echo "=== 4. 等 75s 看第 1 条处理 ==="
sleep 75
docker logs --since 90s "$WORKER" 2>&1 | grep -v "runtime config refreshed" | tail -15

echo
echo "=== 5. 发第 2 条（resume 路径，关键验证）==="
TXN2="e2e2_$(date +%s)"
msg_json2=$(python3 -c 'import json;print(json.dumps({"msgtype":"m.text","body":"请只回复四个字：再次正常"}))')
docker exec "$CTR" curl -s -X PUT -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d "$msg_json2" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN2" | head -c 150
echo
sleep 75
echo "--- 第 2 条处理结果 ---"
docker logs --since 80s "$WORKER" 2>&1 | grep -v "runtime config refreshed" | tail -15
