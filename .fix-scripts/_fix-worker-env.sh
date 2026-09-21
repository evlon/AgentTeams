#!/bin/bash
set -uo pipefail
# 给 dsh-worker-1 注入 TEAMHARNESS_DSH_MAX_TOKENS，修复 256000 output tokens 溢出
# 通过内嵌 apiserver(6443) PATCH Worker CR —— spec.env 是 CRD 官方支持字段

TOKEN=$(cat /data/agentteams-controller/admin-token | tr -d '\n')
API="https://127.0.0.1:6443/apis/agentteams.io/v1beta1/namespaces/default/workers/dsh-worker-1"

echo "===== 1. PATCH spec.env ====="
curl -sk -X PATCH -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/merge-patch+json" \
  -d '{"spec":{"env":{"TEAMHARNESS_DSH_MAX_TOKENS":"8192"}}}' \
  "${API}" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("spec.env =", json.dumps(d.get("spec",{}).get("env"), ensure_ascii=False)); print("state =", d.get("spec",{}).get("state"))'

echo
echo "===== 2. 回读确认 ====="
curl -sk -H "Authorization: Bearer ${TOKEN}" "${API}" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("env =", json.dumps(d["spec"].get("env"), ensure_ascii=False)); print("generation =", d["metadata"]["generation"]); print("specHash =", d["status"].get("specHash"))'
