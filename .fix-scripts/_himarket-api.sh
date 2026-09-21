#!/bin/bash
# 在 K8S 节点上执行：通过 market-admin 域名调 HiMarket API
# 用法: himarket-api.sh <METHOD> <PATH> [JSON_BODY_FILE]
set -uo pipefail

BASE="https://market-admin.ai.ict.cmcc"
ADMIN_USER="admin"
ADMIN_PASS="A5btuodxvcNZRoGh"
# 节点上域名解析需显式指向本机 Envoy
RESOLVE=(--resolve "market-admin.ai.ict.cmcc:443:127.0.0.1")

login() {
  curl -sk --max-time 20 "${RESOLVE[@]}" -X POST "${BASE}/api/v1/admins/login" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASS}\"}"
}

TOKEN_CACHE=/tmp/.himarket_token
get_token() {
  if [ -s "$TOKEN_CACHE" ]; then cat "$TOKEN_CACHE"; return; fi
  local resp tok
  resp=$(login)
  tok=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["access_token"])' 2>/dev/null)
  if [ -z "$tok" ]; then echo "LOGIN FAILED: $resp" >&2; return 1; fi
  printf '%s' "$tok" > "$TOKEN_CACHE"
  printf '%s' "$tok"
}

api() {
  local method="$1" path="$2" body="${3:-}"
  local tok; tok=$(get_token) || return 1
  if [ -n "$body" ]; then
    curl -sk --max-time 60 "${RESOLVE[@]}" -X "$method" "${BASE}${path}" \
      -H "Authorization: Bearer ${tok}" \
      -H 'Content-Type: application/json' \
      --data-binary "@${body}"
  else
    curl -sk --max-time 60 "${RESOLVE[@]}" -X "$method" "${BASE}${path}" \
      -H "Authorization: Bearer ${tok}"
  fi
}

case "${1:-}" in
  login)  login ;;
  *)      api "$@" ;;
esac
