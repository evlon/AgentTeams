#!/bin/bash
set -uo pipefail
W="agentteams-worker-dsh-worker-1"
BASE=/root/agentteams-fs/agents/dsh-worker-1

echo "===== 1. sessions 目录树 ====="
docker exec "$W" sh -c "find $BASE/.dsh/sessions -maxdepth 3 2>&1 | head -30"

echo
echo "===== 2. 目录内文件详情 ====="
docker exec "$W" sh -c "ls -laR $BASE/.dsh/sessions/ 2>&1 | head -40"

echo
echo "===== 3. DSH_HOME 实际内容 ====="
docker exec "$W" sh -c "ls -la $BASE/.dsh/ 2>&1; echo '--- HOME ---'; echo HOME=\$HOME; echo DSH_HOME=\$DSH_HOME"

echo
echo "===== 4. MinIO 上的 .dsh/sessions ====="
docker exec agentteams-controller sh -c '
mc alias set m http://127.0.0.1:9000 admin admindd14c08a1b14 >/dev/null 2>&1
echo "--- sessions 对象 ---"
mc ls --recursive m/agentteams-storage/agents/dsh-worker-1/.dsh/ 2>&1 | head -20
'

echo
echo "===== 5. runtime.yaml（看 model/base_url）====="
docker exec "$W" sh -c "cat $BASE/runtime/runtime.yaml 2>&1 | head -30"
