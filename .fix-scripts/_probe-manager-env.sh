#!/bin/bash
set -uo pipefail
echo "==== manager 容器 env（IDLE/TIMEOUT/WORKER/RUNTIME 相关） ===="
docker inspect agentteams-manager --format '{{json .Config.Env}}' | python3 -c 'import sys,json; [print(x) for x in json.load(sys.stdin) if any(k in x for k in ["IDLE","TIMEOUT","WORKER","RUNTIME","DEEPSEEK"])]' 2>&1

echo
echo "==== controller 容器 env（IDLE/TIMEOUT/WORKER/RUNTIME 相关） ===="
docker inspect agentteams-controller --format '{{json .Config.Env}}' | python3 -c 'import sys,json; [print(x) for x in json.load(sys.stdin) if any(k in x for k in ["IDLE","TIMEOUT","WORKER","RUNTIME","DEEPSEEK"])]' 2>&1

echo
echo "==== manager 容器内是否读 WORKER_IDLE_TIMEOUT ===="
docker exec agentteams-manager sh -c "printenv | grep -iE 'IDLE|TIMEOUT'" 2>&1

echo
echo "==== 找 manager 里发 'paused due to idle timeout' 的源码 ===="
docker exec agentteams-manager sh -c "grep -rniE 'idle timeout|automatically paused|WORKER_IDLE_TIMEOUT' /usr/local/bin /app /opt 2>/dev/null | head -20" 2>&1
