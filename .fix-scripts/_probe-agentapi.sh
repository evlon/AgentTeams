#!/bin/bash
set -uo pipefail
echo "===== 1. Nacos 是否支持 A2A agent 资源 ====="
for p in "/nacos/v3/admin/ai/agents/list" "/nacos/v3/admin/ai/agents" "/nacos/v3/console/ai/agents"; do
  c=$(kubectl exec -n default deploy/nacos -- sh -c "curl -s -o /dev/null -w '%{http_code}' --max-time 8 'http://127.0.0.1:8848${p}'" 2>/dev/null)
  echo "  $p -> $c"
done

echo
echo "===== 2. ai_resource 全部 type ====="
kubectl exec -n default mysql-0 -- mysql --default-character-set=utf8mb4 -uroot -pCHANGE_ME_mysql_root -N -e 'select type,count(*) from nacos.ai_resource group by type;' 2>/dev/null

echo
echo "===== 3. HiMarket 支持的 SourceType 枚举 ====="
grep -n "GATEWAY\|NACOS\|AIREGISTRY\|EXTERNAL" /e/ai-works/open-repos/himarket/himarket-dal/src/main/java/com/alibaba/himarket/support/enums/SourceType.java 2>/dev/null | head -20

echo
echo "===== 4. ProductType 里 REST_API / HTTP_API 是否有前端页面 ====="
ls /e/ai-works/open-repos/himarket/himarket-web/himarket-frontend/src/pages/ 2>/dev/null | head -30

echo
echo "===== 5. higress 网关 ID ====="
bash /tmp/himarket-api.sh GET '/api/v1/gateways?page=1&size=20' | python3 -c '
import sys,json
d=json.load(sys.stdin)["data"]
items = d.get("content") if isinstance(d,dict) else d
for g in (items or []):
    print(" ", g.get("gatewayId"), "|", g.get("gatewayType"), "|", g.get("name"))
' 2>&1 | head -10
