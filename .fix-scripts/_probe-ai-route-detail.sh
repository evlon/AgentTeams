#!/bin/bash
set -uo pipefail
echo "==== ai-route-chat-int-deepseek-v4-flash.yaml ===="
docker exec higress-standalone sh -c "cat /data/configmaps/ai-route-chat-int-deepseek-v4-flash.yaml" 2>&1 | head -60
echo
echo "==== ai-route-codebuddy-deepseek-v4-flash.yaml ===="
docker exec higress-standalone sh -c "cat /data/configmaps/ai-route-codebuddy-deepseek-v4-flash.yaml" 2>&1 | head -60
echo
echo "==== 直接探测 worker 用的模型（带 worker 侧可能用的 key） ===="
echo "--- 无 key POST chat/completions deepseek/deepseek-v4-flash ---"
curl -sk --max-time 30 -X POST "https://llm.ai.ict.cmcc/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek/deepseek-v4-flash","messages":[{"role":"user","content":"回复四个字：你好"}]}' 2>&1 | head -c 600
echo
