#!/bin/bash
set -uo pipefail
echo "==== recreate-dsh-worker 脚本（看它怎么设置 worker，是否带 idleTimeout） ===="
cat /opt/agentteams-install/recreate-dsh-worker-fixed.sh 2>&1 | head -80
echo
echo "==== recreate-dsh-worker-v013.sh ===="
cat /opt/agentteams-install/recreate-dsh-worker-v013.sh 2>&1 | head -80
