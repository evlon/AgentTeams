#!/bin/bash
set -uo pipefail
MATRIX_URL="http://agentteams-controller:6167"
CTR="agentteams-manager"
W="agentteams-worker-dsh-worker-1"
ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'

resp=$(docker exec "$CTR" curl -s -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login")
TOKEN=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
[ -z "$TOKEN" ] && { echo "LOGIN FAILED"; echo "$resp"; exit 1; }
echo "LOGIN OK, token len=${#TOKEN}"
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

echo "==== 发送任务消息 ===="
send "请回复四个字：你好世界" "t_$(date +%s)"
echo
echo "==== 等待 worker 推理（120s） ===="
sleep 120
echo "--- worker 日志（近 130s） ---"
docker logs --since 130s "$W" 2>&1 | grep -v "runtime config refreshed" | tail -30
echo
echo "==== 读房间最近消息，看 worker 是否回复 ===="
docker exec "$CTR" curl -s -H "Authorization: Bearer $TOKEN" \
  "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/messages?dir=b&limit=10" \
  | python3 -c '
import sys,json
d=json.load(sys.stdin)
for e in d.get("chunk",[]):
    if e.get("type")=="m.room.message":
        sender=e.get("sender","")
        body=e.get("content",{}).get("body","")
        ts=e.get("origin_server_ts",0)
        import datetime
        t=datetime.datetime.fromtimestamp(ts/1000).strftime("%H:%M:%S")
        print(f"  [{t}] {sender}: {body[:80]}")
' 2>&1
