#!/bin/bash
set -uo pipefail
# 探测 Nacos uploadAgentSpecFromZip 期望的 ZIP 布局
API=/tmp/himarket-api.sh
PID=$(cat /tmp/worker_pid.txt)
TOK=$(bash $API login | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["access_token"])')

try_zip() {
  local label="$1"; local zipfile="$2"
  echo "--- 尝试: $label ---"
  curl -sk --max-time 60 --resolve market-admin.ai.ict.cmcc:443:127.0.0.1 \
    -X POST "https://market-admin.ai.ict.cmcc/api/v1/workers/${PID}/package" \
    -H "Authorization: Bearer ${TOK}" \
    -F "file=@${zipfile};type=application/zip" | head -c 300
  echo
}

# 布局 A：根层 manifest.json（当前）
python3 - <<'PY'
import json, zipfile
name = "AgentTeams DSH Worker"
manifest = {
  "name": name,
  "description": "AgentTeams DSH Worker",
  "content": json.dumps({"version":"1.0","description":"AgentTeams DSH Worker","tags":["agentteams"],"worker":{"suggested_name":name,"base_image":"agentteams-deepseek-harness-worker:v0.1.3","apt_packages":[],"pip_packages":[],"npm_packages":[]},"proxy":{"suggested":False,"reason":""}}, ensure_ascii=False),
  "uniformId": 1789950000000,
  "resources": [{"name":"AGENTS.md","type":"config"}],
}
with zipfile.ZipFile("/tmp/tA.zip","w",zipfile.ZIP_DEFLATED) as z:
    z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False))
    z.writestr("AGENTS.md", "# AgentTeams DSH Worker\n")
print("tA: 根层 manifest.json + AGENTS.md")
PY

# 布局 B：带顶层目录
python3 - <<'PY'
import json, zipfile
name = "AgentTeams DSH Worker"
manifest = {
  "name": name, "description": "AgentTeams DSH Worker",
  "content": json.dumps({"version":"1.0","worker":{"suggested_name":name}}, ensure_ascii=False),
  "uniformId": 1789950000000,
  "resources": [{"name":"AGENTS.md","type":"config"}],
}
with zipfile.ZipFile("/tmp/tB.zip","w",zipfile.ZIP_DEFLATED) as z:
    z.writestr("agentspec/manifest.json", json.dumps(manifest, ensure_ascii=False))
    z.writestr("agentspec/AGENTS.md", "# x\n")
print("tB: 顶层目录 agentspec/")
PY

# 布局 C：manifest.json 内容为嵌套结构
python3 - <<'PY'
import json, zipfile
name = "AgentTeams DSH Worker"
manifest = {
  "name": name,
  "description": "AgentTeams DSH Worker",
  "content": {"version":"1.0","worker":{"suggested_name":name}},
  "uniformId": 1789950000000,
  "resources": [{"name":"AGENTS.md","type":"config"}],
}
with zipfile.ZipFile("/tmp/tC.zip","w",zipfile.ZIP_DEFLATED) as z:
    z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False))
    z.writestr("AGENTS.md", "# x\n")
print("tC: content 是对象非字符串")
PY

try_zip "A 根层 manifest.json (content=string)" /tmp/tA.zip
try_zip "B 顶层目录 agentspec/" /tmp/tB.zip
try_zip "C content 为对象" /tmp/tC.zip
