#!/bin/bash
set -uo pipefail
# 把 AgentTeams 的 DSH Worker 注册为 HiMarket WORKER 产品（完整闭环）
API=/tmp/himarket-api.sh
PORTAL="portal-c7e980809498465f8a4e86da88db243f"
NAME="AgentTeams DSH Worker"

echo "===== 1. 创建 WORKER 产品 ====="
printf '{"name":"%s","description":"AgentTeams 平台上的 DeepSeek Harness Worker（Matrix 房间内多智能体协作，由 agentteams-controller 编排）","type":"WORKER"}' "$NAME" > /tmp/w.json
RESP=$(bash $API POST '/api/v1/products' /tmp/w.json)
echo "$RESP" | head -c 400
echo
PID=$(printf '%s' "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["productId"])' 2>/dev/null)
[ -z "$PID" ] && { echo "创建失败"; exit 1; }
echo "PID=$PID"
echo "$PID" > /tmp/worker_pid.txt

echo
echo "===== 2. 构造 AgentSpec ZIP ====="
python3 - "$NAME" <<'PY'
import json, zipfile, sys, io
name = sys.argv[1]

agents_md = """# AgentTeams DSH Worker

你是运行在 **AgentTeams** 平台上的 DeepSeek Harness Worker。

## 你的身份
你是团队中的一名执行型数字员工，在 Matrix 房间里与 Manager、其他 Worker 和人类同事协作。

## 工作方式
- 所有沟通都发生在 Matrix 房间内，人类同事随时可见、可介入
- 你接收 Manager 派发的任务，执行后把结果回报到房间
- 你的工作区文件保存在中心化存储（MinIO），容器本身无状态

## 红线
- 绝不泄露凭据、令牌、密钥
- 绝不在未获批准的情况下执行破坏性操作
- 任务不明确时必须先澄清，不要臆测
"""

soul_md = """## 你的身份与记忆

- **角色**：AgentTeams 团队中的 DeepSeek Harness Worker
- **个性**：务实、严谨、重视可复现
- **记忆**：你记住每一次任务上下文的来龙去脉
- **经验**：你熟悉 Matrix 房间协作、MCP 工具调用、中心化文件存储

## 关键规则
- 收到任务先确认目标与验收标准
- 执行过程留痕，结果可复现
- 遇到阻塞如实上报，不隐瞒
"""

identity_md = f"# {name}\nAgentTeams 平台上的 DeepSeek Harness Worker：Matrix 房间内多智能体协作，由 agentteams-controller 编排。\n"

memory_md = "# 长期记忆\n\n由运行时写入；本模板未预置业务记忆。\n"

manifest_content = {
    "version": "1.0",
    "source": {
        "repository": "E:/ai-works/AgentTeams",
        "original_path": "deepseek-harness/",
        "openclaw_mode": True,
    },
    "description": "AgentTeams 平台上的 DeepSeek Harness Worker",
    "tags": ["agentteams", "deepseek-harness", "matrix"],
    "worker": {
        "suggested_name": name,
        "base_image": "agentteams-deepseek-harness-worker:v0.1.3",
        "apt_packages": [],
        "pip_packages": [],
        "npm_packages": [],
    },
    "proxy": {"suggested": False, "reason": ""},
}

manifest = {
    "name": name,
    "description": "AgentTeams 平台上的 DeepSeek Harness Worker（Matrix 房间内多智能体协作）",
    "content": json.dumps(manifest_content, ensure_ascii=False, indent=2) + "\n",
    "uniformId": 1789950000000,
    "resources": [
        {"name": "jobs.json", "type": "crons"},
        {"name": "IDENTITY.md", "type": "config"},
        {"name": "tool-analysis.json", "type": "tool-analysis"},
        {"name": "AGENTS.md", "type": "config"},
        {"name": "SOUL.md", "type": "config"},
        {"name": "MEMORY.md", "type": "config"},
    ],
}

tool_analysis = {
    "version": "1.0",
    "notes": "AgentTeams DSH worker static export",
    "packages": {"apt": [], "pip": [], "npm": []},
}

buf = io.BytesIO()
with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False))
    z.writestr("AGENTS.md", agents_md)
    z.writestr("SOUL.md", soul_md)
    z.writestr("IDENTITY.md", identity_md)
    z.writestr("MEMORY.md", memory_md)
    z.writestr("jobs.json", "[]\n")
    z.writestr("tool-analysis.json", json.dumps(tool_analysis, ensure_ascii=False, indent=2))

open("/tmp/agentspec.zip", "wb").write(buf.getvalue())
print("ZIP written, size =", len(buf.getvalue()))
with zipfile.ZipFile("/tmp/agentspec.zip") as z:
    print("entries:", z.namelist())
PY

echo
echo "===== 3. 上传 ZIP 到 Nacos（经 HiMarket）====="
TOK=$(bash $API login | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["access_token"])')
curl -sk --max-time 90 --resolve market-admin.ai.ict.cmcc:443:127.0.0.1 \
  -X POST "https://market-admin.ai.ict.cmcc/api/v1/workers/${PID}/package" \
  -H "Authorization: Bearer ${TOK}" \
  -F "file=@/tmp/agentspec.zip;type=application/zip" | head -c 600
echo

echo
echo "===== 4. 查看版本 ====="
bash $API GET "/api/v1/workers/${PID}/versions" | head -c 600
echo
