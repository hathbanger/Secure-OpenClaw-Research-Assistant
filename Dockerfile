ARG OPENCLAW_IMAGE=openclaw:local
FROM ${OPENCLAW_IMAGE}

USER root

RUN mkdir -p /home/node/.openclaw/agents/research-agent/agent \
             /home/node/.openclaw/skills/remember-feedback \
             /home/node/.openclaw/skills/csmoove-music-taste \
             /home/node/.openclaw/workspace \
             /home/node/.openclaw/credentials \
             /home/node/.openclaw/logs \
 && chown -R node:node /home/node/.openclaw

COPY --chown=node:node config/openclaw.json /home/node/.openclaw/openclaw.json
COPY --chown=node:node agents/research-agent/agent/soul.md /home/node/.openclaw/agents/research-agent/agent/soul.md
COPY --chown=node:node skills/remember-feedback/SKILL.md /home/node/.openclaw/skills/remember-feedback/SKILL.md
COPY --chown=node:node skills/csmoove-music-taste/SKILL.md /home/node/.openclaw/skills/csmoove-music-taste/SKILL.md

USER node
