#!/bin/bash
set -uo pipefail
echo "==== manager 挂载 ===="
docker inspect agentteams-manager --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'

echo
echo "==== manager 容器内 HOME 与 lifecycle 文件真实位置 ===="
docker exec agentteams-manager sh -c 'echo HOME=$HOME; ls -la ~/worker-lifecycle.json ~/state.json 2>&1; readlink -f ~/worker-lifecycle.json 2>&1'

echo
echo "==== 谁在触发 check-idle（cron? heartbeat? supervisord?） ===="
docker exec agentteams-manager sh -c 'crontab -l 2>/dev/null; echo ---; ls -la /etc/cron.d/ 2>/dev/null; echo ---; grep -rniE "check-idle|lifecycle-worker|idle" /etc/supervisor* /opt/agentteams/scripts 2>/dev/null | head -20'
