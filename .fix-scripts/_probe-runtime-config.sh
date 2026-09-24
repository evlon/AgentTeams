#!/bin/bash
set -uo pipefail
echo "==== 1. controller 里 worker 的 runtime 配置（模型网关地址来源） ===="
docker exec agentteams-controller sh -c "ls -la /data/agentteams-controller/ 2>/dev/null" 2>&1 | head -30
echo
echo "--- 找 runtime.yaml / runtime 相关 ---"
docker exec agentteams-controller sh -c "find /data -name 'runtime*.yaml' -o -name 'runtime*.json' 2>/dev/null | head -20" 2>&1
echo
echo "==== 2. embedded 部署的环境变量（gateway/matrix/模型相关） ===="
docker exec agentteams-controller sh -c "printenv 2>/dev/null | grep -iE 'GATEWAY|LLM|MODEL|HIGRESS|MATRIX|AGENTTEAMS' | sort" 2>&1 | head -50
echo
echo "==== 3. manager 环境变量（模型网关相关） ===="
docker exec agentteams-manager sh -c "printenv 2>/dev/null | grep -iE 'GATEWAY|LLM|MODEL|HIGRESS|AGENTTEAMS' | sort" 2>&1 | head -50
