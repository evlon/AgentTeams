#!/bin/bash
set -uo pipefail
W="agentteams-worker-dsh-worker-1"
R=/root/agentteams-fs/agents/dsh-worker-1/.dsh/profiles/headless/node_modules/agentteams-teamharness-dsh/runner.js

echo "=== 1. 恢复干净副本（去掉诊断插桩）==="
docker exec "$W" sh -c "cp ${R}.bak $R && grep -c DIAG $R || true"

echo
echo "=== 2. 应用真正的修复 ==="
docker exec "$W" sh -c "python3 - <<'PY'
p='$R'
s=open(p, encoding='utf-8').read()
old = '  const persisted = (await persistence.list()).some(header => header.id === sessionId)'
new = '''  // DSH sessionPersistence.list() yields snapshots shaped
  // { header, revision, sizeBytes }; the identity lives on snapshot.header.id.
  // Reading .id off the snapshot yielded undefined, so a persisted session was
  // never recognised and every continuation turn failed with
  // \"requested resume for missing DSH session\". Accept both shapes.
  const persisted = (await persistence.list()).some(
    entry => (entry?.header?.id ?? entry?.id) === sessionId,
  )'''
assert old in s, 'pattern not found'
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
print('FIX APPLIED')
PY"

echo
echo "=== 3. 验证修复 ==="
docker exec "$W" grep -n -A 3 "persisted = " $R | head -12

echo
echo "=== 4. 端到端测试：resume 已有 session ==="
docker exec "$W" python3 -c "
import os, subprocess
with open('/tmp/bridge.env','rb') as f:
    for kv in f.read().split(b'\0'):
        if b'=' in kv:
            k,v = kv.split(b'=',1); os.environ[k.decode()] = v.decode()
env = os.environ.copy()
env.update({'TEAMHARNESS_DSH_SESSION_ID':'session-diag-fresh-1','TEAMHARNESS_DSH_RESUME':'true','TEAMHARNESS_MATRIX_EVENT_ID':'\$fix1','TEAMHARNESS_DSH_ATTEMPT':'1'})
p = subprocess.run(['agentteams-dsh','只回复两个字：续接'], cwd=env['TEAMHARNESS_WORKSPACE'], env=env, text=True, capture_output=True, timeout=180)
print('rc =', p.returncode)
print('stdout =', p.stdout.strip()[:200])
print('stderr =', p.stderr.strip()[:300])
" 2>&1
