#!/bin/bash
set -euo pipefail

if [ "${AGENTTEAMS_MATRIX_E2EE:-0}" = "1" ] || [ "${AGENTTEAMS_MATRIX_E2EE:-}" = "true" ]; then
    echo "[agentteams-dsh-worker] ERROR: DeepSeek Harness does not support Matrix E2EE; disable AGENTTEAMS_MATRIX_E2EE or choose another runtime" >&2
    exit 1
fi

DSH_LLM_CREDENTIAL="${DEEPSEEK_API_KEY:-${AGENTTEAMS_WORKER_GATEWAY_KEY:-}}"
if [ -z "${DSH_LLM_CREDENTIAL}" ]; then
    echo "[agentteams-dsh-worker] ERROR: no LLM credential available; set DEEPSEEK_API_KEY or provide the Controller-issued gateway key" >&2
    exit 1
fi

source /opt/agentteams/scripts/lib/agentteams-env.sh

WORKER_NAME="${AGENTTEAMS_WORKER_NAME:?AGENTTEAMS_WORKER_NAME is required}"
WORKER_HOME="${AGENTTEAMS_WORKER_HOME:-/root/agentteams-fs/agents/${WORKER_NAME}}"
RUNTIME_DIR="${WORKER_HOME}/runtime"
RUNTIME_CONFIG="${RUNTIME_DIR}/runtime.yaml"
REMOTE_WORKER="${AGENTTEAMS_STORAGE_PREFIX%/}/agents/${WORKER_NAME}"

log() {
    echo "[agentteams-dsh-worker $(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if ensure_mc_credentials && agentteams_mc_host_configured; then
    log "Using controller-issued storage credentials"
else
    if [ "${AGENTTEAMS_STORAGE_PROVIDER:-minio}" = "oss" ]; then
        log "ERROR: OSS storage credentials are unavailable"
        exit 1
    fi
    mc alias set "${AGENTTEAMS_STORAGE_ALIAS}" \
        "${AGENTTEAMS_FS_ENDPOINT:?AGENTTEAMS_FS_ENDPOINT is required}" \
        "${AGENTTEAMS_FS_ACCESS_KEY:?AGENTTEAMS_FS_ACCESS_KEY is required}" \
        "${AGENTTEAMS_FS_SECRET_KEY:?AGENTTEAMS_FS_SECRET_KEY is required}" >/dev/null
fi

mkdir -p "${WORKER_HOME}" "${RUNTIME_DIR}"
export HOME="${WORKER_HOME}"
export DSH_HOME="${WORKER_HOME}/.dsh"
export TEAMHARNESS_RUNTIME_CONFIG="${RUNTIME_CONFIG}"
export TEAMHARNESS_WORKSPACE="${WORKER_HOME}/workspace"
export TEAMHARNESS_DSH_SKILL_ROOT="${RUNTIME_DIR}/dsh-skills"
# Per-request output-token cap for the DeepSeek adapter (see llm-deepseek
# maxTokens in cordis.patch.yml). The default equals the DSH-native 256000,
# which is correct for the large production models; some smaller test models
# (e.g. deepseek-v4-flash, 262144 total context) overflow when 256000 + prompt
# exceeds that window, so override per deploy with TEAMHARNESS_DSH_MAX_TOKENS
# (e.g. export TEAMHARNESS_DSH_MAX_TOKENS=8192).
#
# fork(evlon) fix 2026-09-20: default lowered 256000 -> 8192 because the only
# model this deployment serves (deepseek/deepseek-v4-flash) has a 262144-token
# total context window; 256000 output + prompt exceeded it -> the first DSH turn
# failed (400 CONTEXT_WINDOW_EXCEEDED) AND, because the session had already been
# created before the 400, every later turn of the same room then failed with
# dsh: session "session-agentteams-<hash>" already exists. Lower value keeps the
# real token ceiling high while leaving headroom (prompt) inside the window.
# Raise/override via TEAMHARNESS_DSH_MAX_TOKENS when serving a larger model.
export TEAMHARNESS_DSH_MAX_TOKENS="${TEAMHARNESS_DSH_MAX_TOKENS:-8192}"
export TEAMHARNESS_PYTHON="/usr/bin/python3"
export AGENTTEAMS_PLUGIN_DIR="/opt/agentteams/plugins/teamharness"
export AGENTTEAMS_MATRIX_USER_ID="@${WORKER_NAME}:${AGENTTEAMS_MATRIX_DOMAIN}"
export DEEPSEEK_API_KEY="${DSH_LLM_CREDENTIAL}"
unset DSH_LLM_CREDENTIAL AGENTTEAMS_WORKER_GATEWAY_KEY

log "Pulling controller-projected runtime state"
RETRY=0
until mc mirror "${REMOTE_WORKER}/runtime/" "${RUNTIME_DIR}/" --overwrite >/dev/null 2>&1; do
    RETRY=$((RETRY + 1))
    if [ "${RETRY}" -ge 12 ]; then
        log "ERROR: runtime state is unavailable after ${RETRY} attempts"
        exit 1
    fi
    sleep 5
done
if [ ! -s "${RUNTIME_CONFIG}" ]; then
    log "ERROR: ${RUNTIME_CONFIG} is missing"
    exit 1
fi

export TEAMHARNESS_DSH_MODEL="$(python3 /opt/agentteams/scripts/runtime_env.py model "${RUNTIME_CONFIG}" "${TEAMHARNESS_DSH_MODEL:-deepseek-v4-flash}")"
export DEEPSEEK_BASE_URL="$(python3 /opt/agentteams/scripts/runtime_env.py base-url "${DEEPSEEK_BASE_URL:-}" "${AGENTTEAMS_AI_GATEWAY_URL:-}" "${RUNTIME_CONFIG}")"

mkdir -p "${DSH_HOME}"
cp -a /opt/agentteams/dsh-template/. "${DSH_HOME}/"
mkdir -p "${DSH_HOME}/sessions" "${TEAMHARNESS_WORKSPACE}"
if jq -e 'any((.rooms // {})[]; .ready == true)' "${RUNTIME_DIR}/matrix-bridge-state.json" >/dev/null 2>&1; then
    log "Restoring required DeepSeek Harness sessions"
    RETRY=0
    until mc mirror "${REMOTE_WORKER}/.dsh/sessions/" "${DSH_HOME}/sessions/" --overwrite >/dev/null 2>&1; do
        RETRY=$((RETRY + 1))
        if [ "${RETRY}" -ge 12 ]; then
            log "ERROR: persisted DeepSeek Harness sessions are unavailable after ${RETRY} attempts"
            exit 1
        fi
        sleep 5
    done
else
    mc mirror "${REMOTE_WORKER}/.dsh/sessions/" "${DSH_HOME}/sessions/" --overwrite >/dev/null 2>&1 || true
fi

agentteams-dsh --dump-config >/dev/null
log "DeepSeek Harness profile ready; starting Matrix channel loop"
exec python3 /opt/agentteams/scripts/matrix_bridge.py
