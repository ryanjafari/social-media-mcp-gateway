FROM node:22-slim

# mcp-medium: MCP server for publishing posts to Medium
# Requires a legacy Medium integration token (no new tokens are being issued)
RUN npm install -g mcp-medium

ENTRYPOINT ["mcp-medium"]
