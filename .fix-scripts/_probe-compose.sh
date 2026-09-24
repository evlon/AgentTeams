#!/bin/bash
set -uo pipefail
echo "==== 找 agentteams 的 compose/部署文件 ===="
docker inspect agentteams-controller --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>&1
echo
docker inspect agentteams-controller --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>&1
echo
echo "==== compose 文件内容里 DEEPSEEK_HARNESS_WORKER_IMAGE 相关 ===="
CFG=$(docker inspect agentteams-controller --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>/dev/null)
echo "config_files=$CFG"
if [ -n "$CFG" ]; then
  docker exec agentteams-controller sh -c "grep -n 'DEEPSEEK_HARNESS_WORKER_IMAGE\|deepseek-harness-worker' $CFG 2>/dev/null" 2>&1
fi
echo
echo "==== 直接从节点文件系统找 compose 文件 ===="
ssh -o ConnectTimeout=5 root@127.0.0.1 "find /root -maxdepth 3 -name 'docker-compose*.yml' -o -maxdepth 3 -name 'compose*.yml' 2>/dev/null | head -20" 2>&1
echo "--- 也找 .env ---"
find /root -maxdepth 3 -name '.env' 2>/dev/null | head -20
