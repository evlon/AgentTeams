#!/bin/bash
set -uo pipefail
API=/tmp/himarket-api.sh
# 地理学家（已发布，有 online 版本）
PID="product-0585208d1d02443d96e28388d8e4618e"
TOK=$(bash $API login | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["access_token"])')

echo "===== 1. 下载已有 Worker 的 ZIP ====="
curl -sk --max-time 60 --resolve market-admin.ai.ict.cmcc:443:127.0.0.1 \
  -o /tmp/sample.zip \
  "https://market-admin.ai.ict.cmcc/api/v1/workers/${PID}/download" \
  -H "Authorization: Bearer ${TOK}"
ls -la /tmp/sample.zip
file /tmp/sample.zip 2>/dev/null || true

echo
echo "===== 2. ZIP 内文件清单 ====="
python3 -c "
import zipfile
z = zipfile.ZipFile('/tmp/sample.zip')
for n in z.namelist():
    print(' ', n, z.getinfo(n).file_size)
"

echo
echo "===== 3. manifest.json 内容 ====="
python3 -c "
import zipfile, json
z = zipfile.ZipFile('/tmp/sample.zip')
for n in z.namelist():
    if 'manifest' in n.lower():
        print('FILE:', n)
        print(z.read(n).decode('utf-8')[:2000])
        print('---')
"

echo
echo "===== 4. 全部条目名（含目录结构）====="
python3 -c "
import zipfile
z = zipfile.ZipFile('/tmp/sample.zip')
for i in z.infolist():
    print(repr(i.filename), 'dir' if i.is_dir() else i.file_size)
"
