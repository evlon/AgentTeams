#!/bin/bash
set -uo pipefail
echo "==== worker 容器状态 ===="
docker ps --filter name=dsh-worker --format '{{.Names}}|{{.Status}}'

echo
echo "==== worker controller state ===="
docker exec agentteams-manager sh -c 'agt get workers dsh-worker-1 -o json' | python3 -c '
import sys,json
d=json.load(sys.stdin)
print("phase=", d.get("phase"))
print("state=", d.get("state"))
print("containerState=", d.get("containerState"))
print("image=", d.get("image"))
'

echo
echo "==== worker 最近日志（去噪） ===="
docker logs --tail 15 agentteams-worker-dsh-worker-1 2>&1 | grep -v "runtime config refreshed" | tail -12
