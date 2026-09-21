#!/bin/bash
set -uo pipefail
W="agentteams-worker-dsh-worker-1"

echo "=== 1. 找到所有 runner.js 副本 ==="
docker exec "$W" sh -c 'find / -name runner.js -path "*teamharness*" 2>/dev/null'

echo
echo "=== 2. 对每一份应用修复 ==="
docker exec "$W" sh -c 'python3 - <<'"'"'PY'"'"'
import glob, io
old = "  const persisted = (await persistence.list()).some(header => header.id === sessionId)"
new = """  // DSH sessionPersistence.list() yields snapshots shaped
  // { header, revision, sizeBytes }; the identity lives on snapshot.header.id.
  // Reading .id off the snapshot yielded undefined, so a persisted session was
  // never recognised and every continuation turn failed with
  // \"requested resume for missing DSH session\". Accept both shapes.
  const persisted = (await persistence.list()).some(
    entry => (entry?.header?.id ?? entry?.id) === sessionId,
  )"""
paths = glob.glob("/opt/agentteams/dsh-template/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js") \
      + glob.glob("/root/agentteams-fs/agents/dsh-worker-1/.dsh/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js")
for p in paths:
    try:
        s = open(p, encoding="utf-8").read()
    except Exception as e:
        print("READ FAIL", p, e); continue
    if "entry?.header?.id" in s:
        print("ALREADY FIXED:", p); continue
    if old not in s:
        print("PATTERN MISSING:", p); continue
    open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
    print("FIXED:", p)
PY'

echo
echo "=== 3. 确认两份都已修复 ==="
docker exec "$W" sh -c 'for f in /opt/agentteams/dsh-template/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js /root/agentteams-fs/agents/dsh-worker-1/.dsh/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js; do printf "%s -> " "$f"; grep -c "entry?.header?.id" "$f"; done'

echo
echo "=== 4. 重启 bridge 进程让修复生效（不重建容器）==="
docker exec "$W" sh -c 'kill 7 2>/dev/null; sleep 2; echo killed'
sleep 8
docker ps --format '{{.Names}}|{{.Status}}' | grep dsh-worker
docker logs --tail 6 "$W" 2>&1
