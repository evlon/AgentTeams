#!/bin/bash
set -uo pipefail
# 从节点主机执行：登录 Matrix 并发测试任务给 dsh-worker-1
MATRIX_URL="http://agentteams-controller:6167"
CTR="agentteams-manager"
WORKER_ROOM='!I0dHFzREElzpXVWPvq:matrix-local.agentteams.io:18080'
login_json='{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"admindd14c08a1b14"}'

echo "==> 1. 登录 Matrix"
resp=$(docker exec "$CTR" curl -s -X POST -H 'Content-Type: application/json' -d "$login_json" "$MATRIX_URL/_matrix/client/v3/login")
TOKEN=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "LOGIN FAILED: $resp"; exit 1; fi
echo "    ok token=${TOKEN:0:6}..."

ENC=$(printf '%s' "$WORKER_ROOM" | sed 's/!/%21/g; s/:/%3A/g')

echo "==> 2. 发测试任务"
TXN="maxtokens_verify_$(date +%s)"
MSG_TEXT='请用一句话回答：maxTokens 修复验证，你好。'
msg_json=$(python3 -c 'import json,sys;print(json.dumps({"msgtype":"m.text","body":sys.argv[1]}))' "$MSG_TEXT")
docker exec "$CTR" curl -s -X PUT -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d "$msg_json" "$MATRIX_URL/_matrix/client/v3/rooms/$ENC/send/m.room.message/$TXN" >/dev/null && echo "    sent $TXN"

echo "==> 3. 等 70s 观察 worker 日志"
sleep 70
echo "===== worker 日志（最近 90s）====="
docker logs --since 90s agentteams-worker-dsh-worker-1 2>&1 | tail -50
echo
echo "===== 是否有 400 / 错误 ====="
docker logs --since 90s agentteams-worker-dsh-worker-1 2>&1 | grep -icE "CONTEXT_WINDOW_EXCEEDED|already exists|STREAM_CLOSED|error" || echo "0 (无错误)"
