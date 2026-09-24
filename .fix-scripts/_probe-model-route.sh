#!/bin/bash
set -uo pipefail
echo "==== 1. 模型路由现状（llm.ai.ict.cmcc） ===="
echo "--- /v1/models（无 key）---"
curl -sk --max-time 15 "https://llm.ai.ict.cmcc/v1/models" 2>&1 | head -c 800
echo
echo "--- Higress 控制台 AI routes 列表 ---"
# 从 higress-standalone 容器读 ai-route configmap 文件
docker exec higress-standalone sh -c "ls /data/configmaps/ 2>/dev/null | grep -i ai-route" 2>&1 | head -40
echo
echo "--- ai-proxy wasmplugin 里的 provider/modelMapping ---"
docker exec higress-standalone sh -c "cat /data/wasmplugins/ai-proxy.internal.yaml 2>/dev/null" 2>&1 | head -80

echo
echo "==== 2. Matrix homeserver 可达性 ===="
docker exec agentteams-manager sh -c "curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://agentteams-controller:6167/_matrix/client/versions 2>&1" 2>&1
echo " <- matrix versions status"
