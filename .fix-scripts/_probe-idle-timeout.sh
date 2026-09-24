#!/bin/bash
set -uo pipefail
echo "==== 1. idle timeout 相关配置（controller env） ===="
docker exec agentteams-controller sh -c "printenv | grep -iE 'IDLE|TIMEOUT|SLEEP|PAUSE'" 2>&1
echo
echo "==== 2. agentteams-install 目录 ===="
ls -la /opt/agentteams-install/ 2>&1 | head -30
echo
echo "==== 3. agentteams-manager.env 里 DEEPSEEK/idle 相关 ===="
grep -iE "DEEPSEEK|IDLE|TIMEOUT|SLEEP|PAUSE|WORKER_IMAGE" /root/agentteams-manager.env 2>&1
echo
echo "==== 4. install 脚本里 idle/pause 相关 ===="
grep -rniE "idle|pause|sleep|timeout" /opt/agentteams-install/ 2>/dev/null | grep -iE "idle|pause|sleep" | head -30
