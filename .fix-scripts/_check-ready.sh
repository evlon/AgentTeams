#!/bin/bash
set -uo pipefail
sleep 20
echo "==== worker 就绪日志 ===="
docker logs --since 40s agentteams-worker-dsh-worker-1 2>&1 | grep -v 'runtime config refreshed' | tail -10
