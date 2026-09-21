#!/bin/bash
set -uo pipefail
MATRIX_URL="http://agentteams-controller:6167"
CTR="agentteams-manager"
WORKER_ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'

echo "===== 0. worker 容器内 DSH sessions 目录 ====="
docker exec agentteams-worker-dsh-worker-1 sh -c 'ls -la /root/agentteams-fs/agents/dsh-worker-1/.dsh/sessions/ 2>&1; echo "---runtime---"; ls -la /root/agentteams-fs/agents/dsh-worker-1/runtime/ 2>&1'

resp=$(docker exec "$CTR" curl -s -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login")
TOKEN=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
ENC=$(printf '%s' "$WORKER_ROOM" | sed 's/!/%21/g; s/:/%3A/g')

TXN="verify_$(date +%s)"
MSG='请只回复四个字：链路正常'
msg_json=$(python3 -c 'import json,sys;print(json.dumps({"msgtype":"m.text","body":sys.argv[1]}))' "$MSG")
echo "===== 1. 发消息 $TXN ====="
docker exec "$CTR" curl -s -X PUT -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d "$msg_json" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN" | head -c 300
echo

echo "===== 2. 轮询 worker 日志 90s ====="
for i in $(seq 1 9); do
  sleep 10
  echo "--- t=${i}0s ---"
  docker logs --since 12s agentteams-worker-dsh-worker-1 2>&1 | grep -v "runtime config refreshed" | tail -15
done

echo
echo "===== 3. 桥接状态里的最新事件 ====="
docker exec agentteams-worker-dsh-worker-1 sh -c 'python3 -c "
import json
d=json.load(open(\"/root/agentteams-fs/agents/dsh-worker-1/runtime/matrix-bridge-state.json\"))
ev=d.get(\"events\",{})
items=sorted(ev.items(), key=lambda kv: int(kv[1].get(\"updated_at\") or 0), reverse=True)[:3]
for k,v in items:
    print(k, \"status=\",v.get(\"status\"), \"attempts=\",v.get(\"attempts\"), \"err=\", (v.get(\"last_error\") or \"\")[:200])
print(\"rooms=\", json.dumps(d.get(\"rooms\"), ensure_ascii=False))
"' 2>&1
