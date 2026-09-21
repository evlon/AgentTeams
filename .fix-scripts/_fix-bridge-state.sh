#!/bin/bash
set -uo pipefail
# 修正 MinIO 里 matrix-bridge-state.json：rooms[].ready 与真实 session 存在性对齐
# 症状：ready=true 但 .dsh/sessions 为空 → runner 走 resume 分支 → "requested resume for missing DSH session"

mc alias set m http://127.0.0.1:9000 admin admindd14c08a1b14 >/dev/null 2>&1
SRC="m/agentteams-storage/agents/dsh-worker-1/runtime/matrix-bridge-state.json"

echo "===== 1. 备份 ====="
mc cp "$SRC" /tmp/bridge-state.bak.json >/dev/null 2>&1 && echo "backup -> /tmp/bridge-state.bak.json"

echo "===== 2. 重置 ready=false（保留 session_id，让 runner 走 create）====="
mc cat "$SRC" > /tmp/bridge-state.json
python3 - <<'PY'
import json
p = "/tmp/bridge-state.json"
d = json.load(open(p, encoding="utf-8"))
rooms = d.get("rooms") or {}
for rid, room in rooms.items():
    if isinstance(room, dict):
        print(f"  before: {rid} ready={room.get('ready')} session_id={room.get('session_id')}")
        room["ready"] = False
# 清理失败事件记录，避免重试噪声
d["events"] = {k: v for k, v in (d.get("events") or {}).items() if isinstance(v, dict) and v.get("status") != "completed"}
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, sort_keys=True)
print("  after : all rooms ready=False, completed events cleared")
PY

echo "===== 3. 写回 MinIO ====="
mc cp /tmp/bridge-state.json "$SRC" >/dev/null 2>&1 && echo "written"

echo "===== 4. 回读确认 ====="
mc cat "$SRC" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("rooms =", json.dumps(d.get("rooms"), ensure_ascii=False)); print("events_count =", len(d.get("events") or {}))'

echo
echo "===== 5. 重启 worker 容器让新状态生效 ====="
docker rm -f agentteams-worker-dsh-worker-1 >/dev/null 2>&1
sleep 3
docker exec agentteams-controller sh -c 'export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker wake --name dsh-worker-1' 2>&1
sleep 25
echo "===== 6. 容器内 state 与 sessions ====="
docker exec agentteams-worker-dsh-worker-1 sh -c 'python3 -c "
import json
d=json.load(open(\"/root/agentteams-fs/agents/dsh-worker-1/runtime/matrix-bridge-state.json\"))
print(\"rooms =\", json.dumps(d.get(\"rooms\"), ensure_ascii=False))
"; echo "--- sessions ---"; ls -la /root/agentteams-fs/agents/dsh-worker-1/.dsh/sessions/ 2>&1'
