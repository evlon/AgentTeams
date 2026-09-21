#!/bin/bash
set -uo pipefail
echo "===== 1. nacos 库里的 agentspec 记录 ====="
kubectl exec -n default mysql-0 -- mysql -uroot -pCHANGE_ME_mysql_root -N -e 'select id,data_id,group_id from nacos.config_info limit 5;' 2>/dev/null

echo
echo "===== 2. portal_db 里的 WORKER 产品 ====="
kubectl exec -n default mysql-0 -- mysql -uroot -pCHANGE_ME_mysql_root -N -e 'select product_id,name,type,status from portal_db.product where type="WORKER";' 2>/dev/null

echo
echo "===== 3. ai_resource 里的 agentspec ====="
kubectl exec -n default mysql-0 -- mysql -uroot -pCHANGE_ME_mysql_root -N -e 'select id,name,type,status from nacos.ai_resource where type="agentspec" limit 8;' 2>/dev/null

echo
echo "===== 4. ai_resource 表结构 ====="
kubectl exec -n default mysql-0 -- mysql -uroot -pCHANGE_ME_mysql_root -N -e 'desc nacos.ai_resource;' 2>/dev/null

echo
echo "===== 5. nacos_instance ====="
kubectl exec -n default mysql-0 -- mysql -uroot -pCHANGE_ME_mysql_root -N -e 'select * from portal_db.nacos_instance\G' 2>/dev/null | head -30
