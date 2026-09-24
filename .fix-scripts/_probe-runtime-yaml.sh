#!/bin/bash
set -uo pipefail
echo "==== worker runtime.yaml（minio 里） ===="
docker exec agentteams-controller sh -c "cat /data/minio/agentteams-storage/agents/dsh-worker-1/runtime/runtime.yaml 2>/dev/null" 2>&1 | head -80
echo
echo "==== 该 worker 的矩阵 bridge state ===="
docker exec agentteams-controller sh -c "cat /data/minio/agentteams-storage/agents/dsh-worker-1/runtime/matrix-bridge-state.json 2>/dev/null" 2>&1 | head -40
echo
echo "==== aigw-local 可达性（从 controller） ===="
docker exec agentteams-controller sh -c "curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://aigw-local.agentteams.io:8080/v1/models 2>&1" 2>&1
echo " <- aigw-local /v1/models"
echo
echo "==== aigw-local 容器是谁 ===="
docker ps -a --format "{{.Names}}|{{.Status}}|{{.Image}}" | grep -iE "aigw|higress|gateway"
