#!/bin/bash
set -euo pipefail
# 构建含修复的 DSH worker 镜像 v0.1.4（基于 v0.1.3，仅覆盖 runner.js）
REG=dockerhub.kubekube.local  # placeholder, replaced below
REG=dockerhub.kubekey.local:31104
BASE=$REG/library/agentteams-deepseek-harness-worker:v0.1.3
NEW=$REG/library/agentteams-deepseek-harness-worker:v0.1.4

mkdir -p /root/at-fix
cd /root/at-fix

cat > Dockerfile <<'EOF'
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# fork(evlon) fix: TeamHarness DSH adapter read the session identity off the
# wrong object. DSH's sessionPersistence.list() yields snapshots shaped
# { header, revision, sizeBytes }, but runner.js read `.id` on the snapshot
# itself, which is always undefined -> a persisted session was never recognised
# -> every continuation turn took the "missing session" branch and failed with
#   dsh: requested resume for missing DSH session <id>
# This broke the SECOND and every later turn of each Matrix room.
COPY runner.js /opt/agentteams/dsh-template/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js
EOF

echo "=== 1. 构建镜像 ==="
docker build --build-arg BASE_IMAGE="$BASE" -t "$NEW" .

echo
echo "=== 2. 验证镜像内修复已就位 ==="
docker run --rm --entrypoint sh "$NEW" -c 'grep -n "entry?.header?.id" /opt/agentteams/dsh-template/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js && echo IMAGE_FIX_OK'

echo
echo "=== 3. 推送 Harbor ==="
docker push "$NEW"

echo
echo "=== 4. 完成 ==="
docker images | grep agentteams-deepseek-harness-worker
