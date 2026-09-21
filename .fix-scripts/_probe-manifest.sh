#!/bin/bash
set -uo pipefail
MYSQL='kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e'

echo "===== 1. 一个 agentspec 的 manifest.json 完整内容 ====="
kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e "select content from nacos.config_info where data_id='manifest.json' limit 1;" 2>/dev/null | head -c 2500

echo
echo
echo "===== 2. 该 agentspec 的所有 data_id（资源文件）====="
kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e "select distinct group_id from nacos.config_info where data_id='manifest.json' limit 1;" 2>/dev/null

echo
echo "===== 3. 用该 group_id 列全部 data_id ====="
GID=$(kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e "select group_id from nacos.config_info where data_id='manifest.json' limit 1;" 2>/dev/null | tr -d '\r')
echo "group_id=$GID"
kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e "select data_id from nacos.config_info where group_id='$GID';" 2>/dev/null

echo
echo "===== 4. AgentTeams 在 Higress 的路由 ====="
ssh ai-k8s "ls /opt/higress-standalone/data/ingresses/ | grep -iE 'agent|team' || echo '(无 agentteams 路由)'" 2>&1

echo
echo "===== 5. AgentTeams 域名探测 ====="
ssh ai-k8s 'for d in agentteams.ai.ict.cmcc agent.ai.ict.cmcc; do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -H "Host: $d" http://127.0.0.1/); echo "$d -> $c"; done' 2>&1
