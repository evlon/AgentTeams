#!/bin/bash
set -uo pipefail
TOKEN=$(docker exec agentteams-controller cat /data/agentteams-controller/admin-token 2>/dev/null | tr -d '\n')
echo "==== worker CR 完整 spec + status（含 idleTimeout / lastActiveAt） ===="
docker exec agentteams-controller sh -c "curl -sk -H 'Authorization: Bearer $TOKEN' https://127.0.0.1:6443/apis/agentteams.io/v1beta1/namespaces/default/workers/dsh-worker-1" 2>&1 \
  | python3 -c '
import sys,json
d=json.load(sys.stdin)
s=d.get("spec",{})
st=d.get("status",{})
print("spec.idleTimeout =", repr(s.get("idleTimeout")))
print("spec.state =", repr(s.get("state")))
print("spec.image =", s.get("image"))
print("status.LastActiveAt =", repr(st.get("lastActiveAt")))
print("status.phase =", st.get("phase"))
print("--- 全部 spec keys ---")
print(sorted(s.keys()))
print("--- 全部 status keys ---")
print(sorted(st.keys()))
' 2>&1
