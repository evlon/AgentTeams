#!/bin/bash
set -uo pipefail
Q() { kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e "$1" 2>/dev/null; }

GID='agentspec__enc.414920e5b7a5e7a88be5b888__enc.7631'

echo "===== 资源文件内容示例（各取前 300 字符）====="
for d in resource_config_AGENTS__md.json resource_config_SOUL__md.json resource_config_MEMORY__md.json resource_config_IDENTITY__md.json resource_crons_jobs__json.json resource_tool-analysis_tool-analysis__json.json; do
  echo "--- $d ---"
  Q "select left(content,300) from nacos.config_info where group_id='$GID' and data_id='$d' limit 1;"
  echo
done

echo
echo "===== config_info 表结构 ====="
Q 'desc nacos.config_info;'

echo
echo "===== 该 agentspec 的 tenant/其他字段 ====="
Q "select id,data_id,group_id,tenant_id,md5,type from nacos.config_info where group_id='$GID' limit 3;"
