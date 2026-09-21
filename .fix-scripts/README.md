# AgentTeams 修复脚本归档（2026-09-21）

本次会话（部署 agentTeams）用于诊断与修复的一次性脚本，按用途分组保留，便于复现。

## 核心修复（两个）
| 脚本 | 用途 |
|---|---|
| `_fix-worker-env.sh` | 给 Worker CR 注入 `TEAMHARNESS_DSH_MAX_TOKENS=8192`（修复 maxTokens 溢出 400） |
| `_apply-fix.sh` / `_apply-fix-durable.sh` | 给容器内 runner.js 打 session-resume 修复补丁 |
| `_build-image-v014.sh` | 构建并推送 `agentteams-deepseek-harness-worker:v0.1.4`（含修复） |
| `_deploy-v014.sh` | 更新 Worker CR 镜像到 v0.1.4 并重建容器 |
| `_e2e-verify-v014.sh` | 两轮端到端验证（create + resume） |

## HiMarket 集成
| 脚本 | 用途 |
|---|---|
| `_himarket-api.sh` | HiMarket 管理员 API 客户端（登录+调用） |
| `_register-agentteams-worker.sh` / `_register-worker-v2.sh` | 注册 AgentTeams Worker 产品（v2 为正确 ZIP 格式） |
| `_publish-worker.sh` / `_publish-worker-v2.sh` | 提审→发布→门户上线 |
| `_register-agentapi.sh` / `_register-agentapi-v2.sh` | 注册 Agent API 产品 |
| `_verify-worker-portal.sh` / `_verify-agentapi.sh` / `_check-imported.sh` | 门户可见性验收 |

## 诊断/探测（只读）
`_probe-*.sh`、`_dump-*.sh`、`_fix-bridge-state.sh`、`_verify-fixed.sh`、`_verify-live.sh`、`_test-agentapi.sh`、`_higress-register.sh`、`_verify-maxtokens-v013.sh`
