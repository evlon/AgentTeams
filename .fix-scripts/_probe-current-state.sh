#!/bin/bash
set -uo pipefail
echo "==== all agentteams/dsh containers (incl stopped) ===="
docker ps -a --format "{{.Names}}|{{.Status}}|{{.Image}}" | grep -iE "dsh|agentteams"
echo
echo "==== worker CR list ===="
docker exec agentteams-controller sh -c "export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker list" 2>&1 | head -50
echo
echo "==== worker CR raw (dsh-worker-1) ===="
TOKEN=$(docker exec agentteams-controller cat /data/agentteams-controller/admin-token 2>/dev/null | tr -d '\n')
if [ -n "$TOKEN" ]; then
  docker exec agentteams-controller sh -c "curl -sk -H 'Authorization: Bearer $TOKEN' https://127.0.0.1:6443/apis/agentteams.io/v1beta1/namespaces/default/workers/dsh-worker-1" 2>&1 | head -60
else
  echo "no admin-token found"
fi
echo
echo "==== controller logs (recent, dsh-related) ===="
docker logs --since 60m agentteams-controller 2>&1 | grep -iE "dsh|deepseek|worker" | tail -30
