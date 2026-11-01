FROM debian:bookworm-slim

ARG CLAUDE_CODE_VERSION=2.1.316

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git bash findutils \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 10001 -s /bin/bash claude \
    && mkdir -p /workspace/repo \
    && chown -R 10001:10001 /workspace

USER 10001
ENV HOME=/home/claude \
    PATH=/home/claude/.local/bin:$PATH

# Official installer, pinned version; run from /tmp so nothing lands in the workspace.
# DISABLE_UPDATES must NOT be set here: the installer treats it as "do nothing".
# The installer also writes state under ~/.claude; remove it so the image ships no
# config, credentials or .claude.json (the PVC provides CLAUDE_CONFIG_DIR at run time).
WORKDIR /tmp
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION} \
    && rm -rf /home/claude/.claude /home/claude/.claude.json

ENV CLAUDE_CONFIG_DIR=/home/claude/.claude \
    CLAUDE_CODE_PROJECT_DIR_NAME=work \
    DISABLE_UPDATES=1

WORKDIR /workspace/repo
CMD ["sleep", "infinity"]
