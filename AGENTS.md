# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This repository is a collection of Dockerized MCP (Model Context Protocol) servers for social media platforms, designed to work with Docker MCP Gateway. It enables AI agents to post content, manage drafts, and interact with various social platforms.

## Build & Setup Commands

```bash
# Full setup (builds Docker images, creates catalog, configures secrets, enables servers)
bash setup.sh

# Build individual MCP server images
docker build -t crosspost-mcp:latest .
docker build -t substack-enhanced-mcp:latest ./substack-enhanced
docker build -t medium-mcp:latest ./medium
docker build -t reddit-mcp:latest ./reddit
docker build -t facebook-mcp:latest ./facebook
docker build -t twitter-enhanced-mcp:latest ./twitter-enhanced
docker build -t bluesky-enhanced-mcp:latest ./bluesky-enhanced

# Run the gateway
docker mcp gateway run --catalog docker-mcp --catalog social-media

# List available tools
docker mcp tools ls

# Manage secrets (used by setup.sh)
docker mcp secret set <secret_key>
docker mcp secret rm <secret_key>

# Manage catalog
docker mcp catalog create social-media
docker mcp catalog add social-media <server-name> ./social-media-catalog.yaml
docker mcp catalog rm social-media

# Enable/disable servers
docker mcp server enable <server-name>
docker mcp server disable <server-name>
```

## Architecture

### Server Types

1. **Wrapper servers** - Dockerfiles that install and run existing npm/pip packages:
   - `crosspost` (root Dockerfile) - Wraps `@humanwhocodes/crosspost` for multi-platform posting
   - `medium/` - Wraps `mcp-medium` npm package
   - `reddit/` - Clones and runs `github.com/Arindam200/reddit-mcp`
   - `facebook/` - Clones and runs `github.com/HagaiHen/facebook-mcp-server`
   - `twitter-enhanced/` - Installs `x-twitter-mcp` pip package
   - `bluesky-enhanced/` - Clones and builds `github.com/brianellin/bsky-mcp-server`

2. **Custom server** - The only custom implementation in this repo:
   - `substack-enhanced/` - Node.js MCP server using `@modelcontextprotocol/sdk`
   - Implements 6 tools: `create_draft_post`, `publish_draft`, `list_drafts`, `list_posts`, `get_post`, `delete_draft`
   - Converts Markdown-ish syntax to Substack's Tiptap/ProseMirror JSON format

### Key Files

- `setup.sh` - Main setup script; detects configured platforms from `.env`, builds only needed images, registers with Docker MCP Gateway
- `social-media-catalog.yaml` - Defines all server configurations, including Docker images and secret mappings
- `.env.example` / `.env` - Platform credentials; copy `.env.example` to `.env` and fill in credentials for platforms you want to use

### Secret Naming Convention

Secrets follow the pattern `<server-name>.<lowercase_var>`, matching Docker MCP conventions:
- `substack.substack_publication_url`
- `crosspost.twitter_api_consumer_key`
- `twitter-enhanced.twitter_bearer_token`

## Working with the Substack Server

The `substack-enhanced/` server is the only custom code requiring maintenance:

```bash
# Install dependencies (for local development)
cd substack-enhanced && npm install

# Run locally (requires env vars)
SUBSTACK_PUBLICATION_URL=https://your.substack.com \
SUBSTACK_SESSION_TOKEN=... \
SUBSTACK_USER_ID=... \
node index.js
```

The server uses Substack's unofficial API authenticated via session cookie. The `textToDoc()` function converts Markdown to Substack's expected Tiptap JSON format.
