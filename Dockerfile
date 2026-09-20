# syntax=docker/dockerfile:1
# keys-MiniMax-Code-CLI-Browser-Scroll-Context-Enhancement-Pack-with-Jev-Ultrafast-Integration
# arm64 image: MiniMax Code CLI with the pack's validated TUI patches applied,
# the arm64 browser stack, and the compaction-fix tooling.
#
# Strategy: build the patched source bundles, then overlay them onto the
# official @minimax-ai/code npm release (which ships the correct arm64 native
# modules). Nothing else from the official package is modified.
ARG NODE_IMAGE=node:22-bookworm

FROM ${NODE_IMAGE} AS patched-build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends git python3 make g++ pkg-config \
 && rm -rf /var/lib/apt/lists/*
RUN corepack enable && corepack prepare pnpm@9.12.0 --activate
WORKDIR /src
# MiniMax Code at the exact commit both patches sit on
RUN git init -q . \
 && git remote add origin https://github.com/MiniMax-AI/minimax-code.git \
 && git fetch -q --depth 1 origin a5639bcc6146754e01f1ae18bb88545f18299fd6 \
 && git checkout -q FETCH_HEAD
COPY patches/ /patches/
RUN git config user.email "keys-pack-builder@localhost" \
 && git config user.name "keys-pack builder" \
 && git am /patches/0001-tui-transcript-scrollbar.patch /patches/0002-tui-context-meter-status-item.patch \
 && pnpm install --frozen-lockfile \
 && node scripts/build.mjs

FROM ${NODE_IMAGE} AS runtime
ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
RUN apt-get update \
 && apt-get install -y --no-install-recommends git python3 ca-certificates xz-utils procps \
 && rm -rf /var/lib/apt/lists/*
# Official 0.4.12 base (arm64 natives) from the public npm registry, no install scripts
WORKDIR /dl
RUN npm pack @minimax-ai/code@0.4.12 \
 && mkdir -p /opt/mcode/lib/node_modules/@minimax-ai/code \
 && tar xf minimax-ai-code-0.4.12.tgz -C /opt/mcode/lib/node_modules/@minimax-ai/code --strip-components=1 \
 && rm -rf /dl
# Overlay the patched bundles on top
COPY --from=patched-build /src/dist/ /opt/mcode/lib/node_modules/@minimax-ai/code/
# arm64 browser stack (Playwright real arm64 Chromium; Google ships no arm64 Linux Chrome)
RUN npx --yes playwright@latest install --with-deps chromium \
 && rm -rf /var/lib/apt/lists/* /root/.cache
# Pack tooling that is useful in-container
COPY compaction-fix/ /opt/keys-pack/compaction-fix/
COPY performance/ /opt/keys-pack/performance/
# Launcher mirrors the upstream .mcode-launcher invocation
RUN printf '#!/bin/sh\nset -eu\nexec /usr/bin/node /opt/mcode/lib/node_modules/@minimax-ai/code/cli.js "$@"\n' \
      > /usr/local/bin/mcode && chmod +x /usr/local/bin/mcode \
 && chmod +x /opt/keys-pack/compaction-fix/*.py /opt/keys-pack/compaction-fix/*.sh /opt/keys-pack/performance/*.py
LABEL org.opencontainers.image.title="keys MCode enhancement pack (patched MiniMax Code CLI + arm64 browser stack)" \
      org.opencontainers.image.description="MiniMax Code CLI 0.4.12 with validated TUI scrollbar + context-meter patches, arm64 Playwright Chromium, compaction-fix tooling" \
      org.opencontainers.image.source="https://github.com/drowzeys/keys-MiniMax-Code-CLI-Browser-Scroll-Context-Enhancement-Pack-with-Jev-Ultrafast-Integration" \
      org.opencontainers.image.licenses="MIT"
ENTRYPOINT ["/usr/local/bin/mcode"]
