#!/bin/bash
set -uo pipefail
echo "===== agentspec 名称（UTF-8）====="
kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e 'select id,name,namespace_id,status from nacos.ai_resource where type="agentspec" order by id desc limit 15;' 2>/dev/null

echo
echo "===== agentspec 总数 ====="
kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e 'select count(*) from nacos.ai_resource where type="agentspec";' 2>/dev/null

echo
echo "===== 版本信息（version_info）示例 ====="
kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e 'select name, left(version_info,300) from nacos.ai_resource where type="agentspec" order by id desc limit 3;' 2>/dev/null
