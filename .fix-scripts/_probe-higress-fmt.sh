#!/bin/bash
set -uo pipefail
# 在节点上把 AgentTeams controller 接入 Higress（新建 service + ingress）
DATA=/opt/higress-standalone/data
CTRL_IP=$(docker inspect agentteams-controller --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "controller IP = $CTRL_IP"

echo "===== 1. 现有 services 格式参考 ====="
cat $DATA/services/k8s-roster.yaml

echo
echo "===== 2. 现有 ingress 格式参考（roster）====="
cat $DATA/ingresses/roster.yaml
