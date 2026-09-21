#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
GW="higress-fdf663bf4de7494fb0045054d5f058cf"

echo "===== 1. 创建 AGENT_API 产品 ====="
printf '{"name":"zz-probe-agentapi","description":"probe","type":"AGENT_API"}' > /tmp/ap.json
RESP=$(bash $API POST '/api/v1/products' /tmp/ap.json)
echo "$RESP" | head -c 400
echo
PID=$(printf '%s' "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["productId"])' 2>/dev/null)
echo "PID=$PID"
[ -z "$PID" ] && { echo "创建失败，终止"; exit 1; }

echo
echo "===== 2. PUT /products/{id}/ref 绑 Higress 网关 ====="
printf '{"productId":"%s","sourceType":"GATEWAY","gatewayId":"%s","higressRefConfig":{"fromGatewayType":"HIGRESS","routeName":"llm.ai.ict.cmcc-v1-models"}}' "$PID" "$GW" > /tmp/ref.json
cat /tmp/ref.json
echo
bash $API PUT "/api/v1/products/${PID}/ref" /tmp/ref.json | head -c 800
echo

echo
echo "===== 3. 回读 ref ====="
bash $API GET "/api/v1/products/${PID}/ref" | head -c 800
echo

echo
echo "===== 4. 清理探针 ====="
bash $API DELETE "/api/v1/products/${PID}" | head -c 200
echo
bash $API GET "/api/v1/products/${PID}" | head -c 200
