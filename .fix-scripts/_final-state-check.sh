#!/bin/bash
set -uo pipefail
echo "==== worker 容器 restart 策略 ===="
docker inspect agentteams-worker-dsh-worker-1 --format 'restart={{.HostConfig.RestartPolicy.Name}}' 2>&1
echo
echo "==== controller 容器 restart 策略 ===="
docker inspect agentteams-controller --format 'restart={{.HostConfig.RestartPolicy.Name}}' 2>&1
echo
echo "==== manager 容器 restart 策略 ===="
docker inspect agentteams-manager --format 'restart={{.HostConfig.RestartPolicy.Name}}' 2>&1
echo
echo "==== 最终状态总览 ===="
docker ps --format "{{.Names}}|{{.Status}}|{{.Image}}" | grep -iE "dsh|agentteams" 
echo
echo "==== worker 当前 status（最终） ===="
docker exec agentteams-controller sh -c "export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt worker status --name dsh-worker-1 -o json" 2>&1 | head -20
