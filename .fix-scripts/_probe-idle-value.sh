#!/bin/bash
set -uo pipefail
echo "==== controller 容器里 idle timeout 实际值 ===="
docker exec agentteams-controller sh -c "printenv AGENTTEAMS_WORKER_IDLE_TIMEOUT; echo '---'; printenv AGENTTEAMS_DEEPSEEK_HARNESS_WORKER_IMAGE" 2>&1
echo
echo "==== manager 容器里 idle timeout ===="
docker exec agentteams-manager sh -c "printenv AGENTTEAMS_WORKER_IDLE_TIMEOUT; echo '---'; printenv AGENTTEAMS_DEEPSEEK_HARNESS_WORKER_IMAGE" 2>&1
echo
echo "==== db 里是否有 idle timeout / worker 配置表 ===="
docker exec agentteams-controller sh -c "ls -la /data/agentteams-controller/*.db 2>/dev/null; which sqlite3 2>/dev/null || echo no-sqlite3" 2>&1
echo
echo "==== 源码里 idle timeout 逻辑（controller 镜像内） ===="
docker exec agentteams-controller sh -c "grep -rniE 'WORKER_IDLE_TIMEOUT|idleTimeout|idle_timeout' /usr/local/bin /app 2>/dev/null | head -20" 2>&1
