FROM node:22-slim

# bsky-mcp-server: Enhanced Bluesky MCP server with 20+ tools
# (timeline, search, engagement, post creation, and more)
# Source: https://github.com/brianellin/bsky-mcp-server

RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm

RUN git clone --depth 1 https://github.com/brianellin/bsky-mcp-server.git /app
WORKDIR /app
RUN pnpm install && pnpm run build

ENTRYPOINT ["node", "build/src/index.js"]
