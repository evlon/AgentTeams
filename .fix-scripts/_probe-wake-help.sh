#!/bin/bash
set -uo pipefail
echo "==== agt worker wake --help ===="
docker exec agentteams-controller agt worker wake --help 2>&1 | head -30
echo
echo "==== agt worker ensure-ready --help ===="
docker exec agentteams-controller agt worker ensure-ready --help 2>&1 | head -30
echo
echo "==== agt worker status --help ===="
docker exec agentteams-controller agt worker status --help 2>&1 | head -30
echo
echo "==== 当前 worker 状态（wake 前） ===="
docker exec agentteams-controller sh -c "export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker status --name dsh-worker-1 -o json" 2>&1 | head -40
