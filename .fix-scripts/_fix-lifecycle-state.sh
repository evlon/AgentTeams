#!/bin/bash
# 修复 dsh-worker-1 的 lifecycle 过时状态，防止 manager heartbeat 的 check-idle 立即再次暂停它
set -euo pipefail

LF=/root/manager-workspace/worker-lifecycle.json
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

echo "==== 修复前 ===="
cat "$LF"

# 备份
cp -a "$LF" "${LF}.bak-$(date +%Y%m%d%H%M%S)"

# 更新 dsh-worker-1：container_status=running，idle_since=当前时间（计时器归零），清除 auto_stopped_at
python3 - "$LF" "$TS" <<'PYEOF'
import sys, json
path, ts = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = json.load(f)
w = d.setdefault("workers", {}).setdefault("dsh-worker-1", {})
w["container_status"] = "running"
w["idle_since"] = ts
w.pop("auto_stopped_at", None)
d["updated_at"] = ts
with open(path, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
print("updated dsh-worker-1 -> running, idle_since=", ts)
PYEOF

echo
echo "==== 修复后 ===="
cat "$LF"
