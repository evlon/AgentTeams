#!/bin/bash
# 完整修复：wake worker 并同步 lifecycle 状态，确保 worker 稳定 Running
set -euo pipefail

echo "==== STEP1: wake worker（state -> Running） ===="
docker exec agentteams-manager sh -c 'agt update worker --name dsh-worker-1 --state Running' 2>&1

echo
echo "==== STEP2: 等待容器拉起 ===="
for i in $(seq 1 30); do
  sleep 2
  st=$(docker ps --filter name=dsh-worker --format '{{.Status}}' 2>/dev/null)
  if [ -n "$st" ]; then
    echo "  container up: $st"
    break
  fi
  echo "  waiting... ($i)"
done

echo
echo "==== STEP3: 更新 lifecycle 状态（idle_since 归零） ===="
LF=/root/manager-workspace/worker-lifecycle.json
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
docker exec agentteams-manager sh -c "python3 -c '
import json
p=\"/root/manager-workspace/worker-lifecycle.json\"
d=json.load(open(p))
w=d[\"workers\"].setdefault(\"dsh-worker-1\",{})
w[\"container_status\"]=\"running\"
w[\"idle_since\"]=\"$TS\"
w.pop(\"auto_stopped_at\",None)
d[\"updated_at\"]=\"$TS\"
json.dump(d,open(p,\"w\"),indent=2)
print(\"lifecycle updated: running, idle_since=\",\"$TS\")
'"

echo
echo "==== STEP4: 最终确认 ===="
docker ps --filter name=dsh-worker --format '  {{.Names}}|{{.Status}}'
docker exec agentteams-manager sh -c 'agt get workers dsh-worker-1 -o json' | python3 -c '
import sys,json
d=json.load(sys.stdin)
print("  phase=", d.get("phase"), "state=", d.get("state"), "containerState=", d.get("containerState"))
'
echo
echo "==== lifecycle 最终值 ===="
docker exec agentteams-manager sh -c 'cat /root/manager-workspace/worker-lifecycle.json'
