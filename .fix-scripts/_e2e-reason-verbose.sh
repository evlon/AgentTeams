#!/bin/bash
set -uo pipefail
MATRIX_URL="http://agentteams-controller:6167"
CTR="agentteams-manager"
W="agentteams-worker-dsh-worker-1"
ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'

echo "=== STEP1 login ==="
resp=$(docker exec "$CTR" curl -s --max-time 15 -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login")
echo "login resp: ${resp:0:200}"
TOKEN=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "LOGIN FAILED"; exit 1; fi
echo "TOKEN OK len=${#TOKEN}"
ENC=$(printf '%s' "$ROOM" | sed 's/!/%21/g; s/:/%3A/g')

echo "=== STEP2 send message ==="
TXN="t_$(date +%s)"
body=$(python3 -c 'import json,sys;print(json.dumps({"msgtype":"m.text","body":sys.argv[1]}))' "请回复四个字：你好世界")
sendresp=$(docker exec "$CTR" curl -s --max-time 15 -X PUT -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d "$body" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN")
echo "send resp: ${sendresp:0:200}"

echo "=== STEP3 wait 90s ==="
sleep 90

echo "=== STEP4 worker log ==="
docker logs --since 100s "$W" 2>&1 | grep -v "runtime config refreshed" | tail -40

echo "=== STEP5 room recent messages ==="
docker exec "$CTR" curl -s --max-time 15 -H "Authorization: Bearer $TOKEN" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/messages?dir=b&limit=15" \
  | python3 -c '
import sys,json,datetime
d=json.load(sys.stdin)
for e in d.get("chunk",[]):
    if e.get("type")=="m.room.message":
        sender=e.get("sender","")
        body=e.get("content",{}).get("body","")
        ts=e.get("origin_server_ts",0)
        t=datetime.datetime.fromtimestamp(ts/1000).strftime("%H:%M:%S")
        print(f"  [{t}] {sender}: {body[:100]}")
' 2>&1

echo "=== DONE ==="
