#!/bin/bash
set -uo pipefail
MATRIX_URL="http://agentteams-controller:6167"
CTR="agentteams-manager"
W="agentteams-worker-dsh-worker-1"
ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'

resp=$(docker exec "$CTR" curl -s -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login")
TOKEN=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
[ -z "$TOKEN" ] && { echo "LOGIN FAILED"; exit 1; }
ENC=$(printf '%s' "$ROOM" | sed 's/!/%21/g; s/:/%3A/g')

send() {
  local text="$1" txn="$2"
  local body
  body=$(python3 -c 'import json,sys;print(json.dumps({"msgtype":"m.text","body":sys.argv[1]}))' "$text")
  docker exec "$CTR" curl -s -X PUT -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $TOKEN" -d "$body" \
    "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/send/m.room.message/$txn" | head -c 120
  echo
}

echo "===== 第 1 轮（create 路径）====="
send "请只回复四个字：第一轮好" "t1_$(date +%s)"
sleep 80
echo "--- 日志 ---"
docker logs --since 90s "$W" 2>&1 | grep -v "runtime config refreshed" | tail -12

echo
echo "===== 第 2 轮（resume 路径 —— 本次修复的关键）====="
send "请只回复四个字：第二轮好" "t2_$(date +%s)"
sleep 80
echo "--- 日志 ---"
docker logs --since 90s "$W" 2>&1 | grep -v "runtime config refreshed" | tail -12

echo
echo "===== 最终 bridge state ====="
docker exec "$W" sh -c 'python3 -c "
import json
d=json.load(open(\"/root/agentteams-fs/agents/dsh-worker-1/runtime/matrix-bridge-state.json\"))
print(\"rooms =\", json.dumps(d.get(\"rooms\"), ensure_ascii=False))
ev=d.get(\"events\",{})
items=sorted(ev.items(), key=lambda kv: int(kv[1].get(\"updated_at\") or 0), reverse=True)[:4]
for k,v in items:
    print(\"  \", k[:22], \"status=\", v.get(\"status\"), \"answer=\", (v.get(\"answer\") or \"\")[:60], \"err=\", (v.get(\"last_error\") or \"\")[:90])
"'

echo
echo "===== 错误统计（应全为 0）====="
docker logs --since 200s "$W" 2>&1 | grep -cE "requested resume for missing|CONTEXT_WINDOW_EXCEEDED|STREAM_CLOSED" || echo 0
