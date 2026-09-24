#!/bin/bash
set -uo pipefail
W="agentteams-worker-dsh-worker-1"

echo "==== 1. wake worker ===="
docker exec agentteams-controller sh -c "export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker wake --name dsh-worker-1" 2>&1
echo
echo "==== 2. 等容器起来 ===="
sleep 25
docker ps --format "{{.Names}}|{{.Status}}|{{.Image}}" | grep dsh-worker
echo
echo "==== 3. worker 状态 ===="
docker exec agentteams-controller sh -c "export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker status --name dsh-worker-1 -o json" 2>&1 | head -30
echo
echo "==== 4. worker 日志（启动后） ===="
docker logs --since 30s "$W" 2>&1 | tail -30
