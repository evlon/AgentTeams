#!/bin/bash
set -uo pipefail
echo "==== higress-standalone 里的 ai-route（aigw-local 实际用的） ===="
docker exec higress-standalone sh -c "ls /data/configmaps/ 2>/dev/null | grep -iE 'ai-route|route'" 2>&1
echo
echo "==== aigw-local 的 provider 与 modelMapping ===="
docker exec higress-standalone sh -c "cat /data/wasmplugins/ai-proxy.internal.yaml 2>/dev/null | grep -A40 'providers:'" 2>&1 | head -60
echo
echo "==== worker 镜像里的 DSH 版本 + 入口 ===="
docker exec agentteams-worker-dsh-worker-1 sh -c "cat /opt/agentteams/dsh-template/package.json 2>/dev/null | grep -iE 'version|deepseek' | head -5" 2>&1
echo "(worker 容器已停，可能 exec 失败)"
echo
echo "==== 镜像 label ===="
docker inspect dockerhub.kubekey.local:31104/library/agentteams-deepseek-harness-worker:v0.1.4 --format '{{index .Config.Labels "ai.deepseek.dsh.version"}}' 2>&1
