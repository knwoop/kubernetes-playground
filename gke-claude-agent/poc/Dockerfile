FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git ripgrep \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 --shell /bin/bash claude \
 && mkdir -p /workspace/repo /home/claude/.claude \
 && chown -R claude:claude /workspace /home/claude

USER claude
ENV HOME=/home/claude \
    CLAUDE_CONFIG_DIR=/home/claude/.claude \
    DISABLE_AUTOUPDATER=1 \
    PATH=/home/claude/.local/bin:$PATH

# Official installer, unmodified binary.
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace/repo
# claude -p runs per invocation through kubectl exec.
ENTRYPOINT ["sleep", "infinity"]
