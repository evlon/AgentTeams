#!/bin/bash
set -uo pipefail
echo "==== 1. agt get workers 全量状态 ===="
docker exec agentteams-manager sh -c 'agt get workers -o json 2>&1' | python3 -c 'import sys,json;
try:
  d=json.load(sys.stdin)
  for w in d.get("workers",[]):
    print(f"  name={w.get(\"name\")} runtime={w.get(\"runtime\")} phase={w.get(\"phase\")} state={w.get(\"state\")} containerState={w.get(\"containerState\")}")
except Exception as e:
  print("parse err:", e)' 2>&1

echo
echo "==== 2. dsh-worker-1 完整 spec ===="
docker exec agentteams-manager sh -c 'agt get workers dsh-worker-1 -o json 2>&1' 2>&1 | head -60
