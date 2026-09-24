#!/bin/bash
set -uo pipefail
W="agentteams-worker-dsh-worker-1"

echo "==== 1. worker 容器退出详情 ===="
docker inspect "$W" --format '{{.State.Status}} | exit={{.State.ExitCode}} | oom={{.State.OOMKilled}} | finished={{.State.FinishedAt}} | restarts={{.RestartCount}}' 2>&1

echo
echo "==== 2. worker 完整 spec ===="
TOKEN=$(docker exec agentteams-controller cat /data/agentteams-controller/admin-token 2>/dev/null | tr -d '\n')
docker exec agentteams-controller sh -c "curl -sk -H 'Authorization: Bearer $TOKEN' https://127.0.0.1:6443/apis/agentteams.io/v1beta1/namespaces/default/workers/dsh-worker-1" 2>&1 \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); s=d.get("spec",{}); print("spec =", json.dumps(s, ensure_ascii=False, indent=2)); print("status =", json.dumps(d.get("status",{}), ensure_ascii=False, indent=2))' 2>&1

echo
echo "==== 3. worker 容器最后日志（退出前） ===="
docker logs --tail 60 "$W" 2>&1

echo
echo "==== 4. controller 里 worker 相关日志（2h 内） ===="
docker logs --since 120m agentteams-controller 2>&1 | grep -iE "dsh-worker|worker" | tail -40

echo
echo "==== 5. 内存/磁盘 ===="
free -h 2>&1 | head -3
df -h / 2>&1 | tail -2
