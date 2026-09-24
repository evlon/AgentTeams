#!/bin/bash
set -uo pipefail
echo "==== controller 容器完整 labels ===="
docker inspect agentteams-controller --format '{{json .Config.Labels}}' 2>&1 | python3 -m json.tool 2>/dev/null | head -40
echo
echo "==== controller 启动命令/cmd ===="
docker inspect agentteams-controller --format 'Entrypoint={{json .Config.Entrypoint}} Cmd={{json .Config.Cmd}}' 2>&1
echo
echo "==== 节点上找 agentteams 部署脚本/目录 ===="
ls -la /root/ 2>&1 | grep -iE "agentteam|embedded|deploy|install" | head -20
echo "--- /root/agentteams* ---"
ls -d /root/*agentteam* 2>/dev/null
echo "--- /opt/agentteams* ---"
ls -d /opt/*agentteam* 2>/dev/null
echo "--- docker 网络 ---"
docker network ls 2>&1 | grep -iE "agentteam|aigw"
