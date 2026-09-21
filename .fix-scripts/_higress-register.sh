#!/bin/bash
set -uo pipefail
# 把 AgentTeams controller API 接入 Higress 并暴露为域名 agentteams.ai.ict.cmcc
DATA=/opt/higress-standalone/data
CTRL_IP=$(docker inspect agentteams-controller --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "controller IP = $CTRL_IP"
DOMAIN="agentteams.ai.ict.cmcc"
REG="agentteams-controller.internal"

echo "===== 1. 备份 mcpbridges/default.yaml ====="
cp $DATA/mcpbridges/default.yaml /tmp/default.yaml.bak-$(date +%s) && echo "backed up"

echo "===== 2. 检查是否已注册 ====="
if grep -q "$REG" $DATA/mcpbridges/default.yaml; then
  echo "已存在，跳过"
else
  echo "追加 static registry"
  # 在 spec.registries: 后插入
  python3 - "$DATA/mcpbridges/default.yaml" "$CTRL_IP" "$REG" <<'PY'
import sys, re
path, ip, name = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path, encoding='utf-8').read()
entry = f"""  - domain: {ip}:8090
    name: {name}
    port: 80
    protocol: http
    type: static
"""
if name in text:
    print("already present")
else:
    text = text.replace("spec:\n  registries:\n", "spec:\n  registries:\n" + entry, 1)
    open(path, 'w', encoding='utf-8').write(text)
    print("inserted")
PY
fi

echo "===== 3. 验证 ====="
grep -A 5 "registries:" $DATA/mcpbridges/default.yaml | head -10
grep -n "$REG" $DATA/mcpbridges/default.yaml

echo
echo "===== 4. 等 Envoy 重载 15s ====="
sleep 15

echo "===== 5. 从节点访问验证（dest 已注册）====="
curl -s -o /dev/null -w "controller via higress -> %{http_code}\n" --max-time 8 -H "Host: $DOMAIN" http://127.0.0.1/healthz
