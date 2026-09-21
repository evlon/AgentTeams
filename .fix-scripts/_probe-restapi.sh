#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
PORTAL="portal-c7e980809498465f8a4e86da88db243f"

echo "===== 探测可用的产品类型（逐类创建+删除）====="
for T in REST_API HTTP_API; do
  echo "--- $T ---"
  printf '{"name":"zz-probe-%s","description":"probe","type":"%s"}' "$T" "$T" > /tmp/p.json
  R=$(bash $API POST '/api/v1/products' /tmp/p.json)
  echo "$R" | head -c 300
  echo
  PID=$(printf '%s' "$R" | python3 -c 'import sys,json;d=json.load(sys.stdin);print((d.get("data") or {}).get("productId",""))' 2>/dev/null)
  if [ -n "$PID" ]; then
    echo "  创建成功 PID=$PID，尝试发布到门户："
    printf '{"portalId":"%s"}' "$PORTAL" > /tmp/pub.json
    bash $API POST "/api/v1/products/${PID}/publications" /tmp/pub.json | head -c 250
    echo
    echo "  清理..."
    bash $API DELETE "/api/v1/products/${PID}" | head -c 120
    echo
  fi
done

echo
echo "===== AgentTeams controller 暴露的 API 清单（用于 API 产品）====="
docker exec agentteams-controller sh -c 'export AGENTTEAMS_CONTROLLER_URL=http://127.0.0.1:8090; agt get workers -o json 2>/dev/null | head -c 200' 2>&1
