#!/bin/bash
set -uo pipefail
echo "==== 最终复核：worker 状态 + 最近日志 ===="
docker ps --format "{{.Names}}|{{.Status}}" | grep dsh-worker
echo "--- 最近 20 行日志（去掉噪音） ---"
docker logs --since 15m agentteams-worker-dsh-worker-1 2>&1 | grep -v "runtime config refreshed" | tail -20
echo
echo "==== 房间最近消息（确认最新一轮推理成功） ===="
CTR="agentteams-manager"
MATRIX_URL="http://agentteams-controller:6167"
ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'
TOKEN=$(docker exec "$CTR" curl -s -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
ENC=$(printf '%s' "$ROOM" | sed 's/!/%21/g; s/:/%3A/g')
docker exec "$CTR" curl -s -H "Authorization: Bearer $TOKEN" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/messages?dir=b&limit=8" \
  | python3 -c '
import sys,json,datetime
d=json.load(sys.stdin)
for e in d.get("chunk",[]):
    if e.get("type")=="m.room.message":
        sender=e.get("sender","")
        body=e.get("content",{}).get("body","")
        ts=e.get("origin_server_ts",0)
        t=datetime.datetime.fromtimestamp(ts/1000).strftime("%H:%M:%S")
        print(f"  [{t}] {sender}: {body[:80]}")
' 2>&1
