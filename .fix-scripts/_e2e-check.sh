#!/bin/bash
set -uo pipefail
MATRIX_URL="http://agentteams-controller:6167"
CTR="agentteams-manager"
WORKER="agentteams-worker-dsh-worker-1"
WORKER_ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'

echo "===== 0. 前置状态 ====="
docker exec "$WORKER" sh -c 'python3 -c "
import json
d=json.load(open(\"/root/agentteams-fs/agents/dsh-worker-1/runtime/matrix-bridge-state.json\"))
print(\"rooms =\", json.dumps(d.get(\"rooms\"), ensure_ascii=False))
print(\"events =\", len(d.get(\"events\") or {}))
"'
echo "sessions:"; docker exec "$WORKER" sh -c 'ls /root/agentteams-fs/agents/dsh-worker-1/.dsh/sessions/ 2>&1'

resp=$(docker exec "$CTR" curl -s -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login")
TOKEN=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
[ -z "$TOKEN" ] && { echo "LOGIN FAILED: $resp"; exit 1; }
ENC=$(printf '%s' "$WORKER_ROOM" | sed 's/!/%21/g; s/:/%3A/g')

TXN="e2e_$(date +%s)"
MSG='请只回复四个字：链路正常'
msg_json=$(python3 -c 'import json,sys;print(json.dumps({"msgtype":"m.text","body":sys.argv[1]}))' "$MSG")
echo
echo "===== 1. 发消息 ====="
docker exec "$CTR" curl -s -X PUT -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d "$msg_json" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN" | head -c 200
echo

echo "===== 2. 轮询日志 ====="
for i in $(seq 1 12); do
  sleep 10
  L=$(docker logs --since 12s "$WORKER" 2>&1 | grep -v "runtime config refreshed")
  if [ -n "$L" ]; then echo "--- t=${i}0s ---"; echo "$L" | tail -12; fi
done

echo
echo "===== 3. 最终桥接状态 ====="
docker exec "$WORKER" sh -c 'python3 -c "
import json
d=json.load(open(\"/root/agentteams-fs/agents/dsh-worker-1/runtime/matrix-bridge-state.json\"))
ev=d.get(\"events\",{})
items=sorted(ev.items(), key=lambda kv: int(kv[1].get(\"updated_at\") or 0), reverse=True)[:4]
for k,v in items:
    print(\" \", k[:24], \"status=\",v.get(\"status\"), \"answer=\", (v.get(\"answer\") or \"\")[:80], \"err=\", (v.get(\"last_error\") or \"\")[:120])
print(\"rooms =\", json.dumps(d.get(\"rooms\"), ensure_ascii=False))
"'
echo "sessions:"; docker exec "$WORKER" sh -c 'ls /root/agentteams-fs/agents/dsh-worker-1/.dsh/sessions/ 2>&1'
