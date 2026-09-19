ARG HIGRESS_REGISTRY=higress-registry.cn-hangzhou.cr.aliyuncs.com

FROM ${HIGRESS_REGISTRY}/higress/mc:20260216 AS mc

FROM node:22.22-bookworm-slim

# Selectable DeepSeek Harness version: any published @deepseek-ai/dsh version
# is accepted. Note the image TAG does not encode it — the runtime tag is its
# own version line (DEEPSEEK_HARNESS_WORKER_VERSION, currently v0.1.0) and is
# pinned literally by the installer, Helm and the release workflow. The DSH
# version is instead recorded in the image label below, so a running worker can
# report which DSH it carries; publish under a distinct runtime tag when you
# need two DSH versions to coexist in the registry.
ARG DSH_VERSION=0.1.5-rc.2

# Recorded in the image so a running worker can report which DSH it carries.
LABEL org.opencontainers.image.title="AgentTeams DeepSeek Harness Worker" \
      ai.deepseek.dsh.version="${DSH_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        python3 \
        tini \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mc /usr/bin/mc /usr/local/bin/mc.bin
COPY shared/lib/ /opt/agentteams/scripts/lib/

RUN npm install --global "pnpm@11.7.0" "@deepseek-ai/dsh@${DSH_VERSION}" \
    && npm cache clean --force

COPY plugins/teamharness/ /opt/agentteams/plugins/teamharness/
RUN mkdir -p /opt/agentteams/dsh-template /tmp/adapter-pack \
    && DSH_HOME=/opt/agentteams/dsh-template pnpm --dir /opt/agentteams/plugins/teamharness/adapters/deepseek-harness pack --pack-destination /tmp/adapter-pack \
    && DSH_HOME=/opt/agentteams/dsh-template dsh plugin --profile headless add /tmp/adapter-pack/*.tgz \
    && rm -rf /tmp/adapter-pack

COPY deepseek-harness/scripts/deepseek-harness-worker-entrypoint.sh /opt/agentteams/scripts/deepseek-harness-worker-entrypoint.sh
COPY deepseek-harness/scripts/agentteams-dsh /usr/local/bin/agentteams-dsh
COPY deepseek-harness/scripts/bridge_state.py /opt/agentteams/scripts/bridge_state.py
COPY deepseek-harness/scripts/matrix_channel.py /opt/agentteams/scripts/matrix_channel.py
COPY deepseek-harness/scripts/matrix_bridge.py /opt/agentteams/scripts/matrix_bridge.py
COPY deepseek-harness/scripts/runtime_env.py /opt/agentteams/scripts/runtime_env.py

RUN chmod +x /opt/agentteams/scripts/lib/mc-wrapper.sh \
        /opt/agentteams/scripts/deepseek-harness-worker-entrypoint.sh \
        /opt/agentteams/scripts/matrix_bridge.py \
        /opt/agentteams/scripts/runtime_env.py \
        /usr/local/bin/agentteams-dsh \
    && ln -sf /opt/agentteams/scripts/lib/mc-wrapper.sh /usr/local/bin/mc \
    && mkdir -p /root/agentteams-fs/agents

WORKDIR /root/agentteams-fs/agents
EXPOSE 8088
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/agentteams/scripts/deepseek-harness-worker-entrypoint.sh"]
