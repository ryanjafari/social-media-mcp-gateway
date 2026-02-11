# Social Media MCP Gateway

Post to 13+ social networks from your AI coding agent (Cursor, VS Code, etc.) through a single [Docker MCP Gateway](https://docs.docker.com/desktop/features/mcp-catalog-and-toolkit/) endpoint.

## Architecture

```
Cursor / AI Agent
       |
       |  Streamable HTTP (localhost:8811/sse)
       v
+-------------------------+
|   Docker MCP Gateway    |
|  Aggregates all servers |
|  Injects secrets per    |
|  container              |
+---+---+---+---+---+---+-+
    |   |   |   |   |   |
    v   v   v   v   v   v
   7 isolated Docker containers
```

| Server | Platforms | Source | Tools |
|--------|-----------|--------|-------|
| **crosspost** | Twitter, Mastodon, Bluesky, LinkedIn, Discord, Dev.to, Telegram, Slack, Nostr | [@humanwhocodes/crosspost](https://github.com/humanwhocodes/crosspost) | 1 (multi-post) |
| **substack** | Substack | Custom built | 6 (create, publish, list, get, delete drafts, list posts) |
| **medium** | Medium | [designly1/mcp-medium](https://github.com/designly1/mcp-medium) | Publish |
| **reddit** | Reddit | [Arindam200/reddit-mcp](https://github.com/Arindam200/reddit-mcp) | Post, reply, search, analytics |
| **facebook** | Facebook Pages | [HagaiHen/facebook-mcp-server](https://github.com/HagaiHen/facebook-mcp-server) | Post, comments, insights |
| **twitter-enhanced** | Twitter/X | [rafaljanicki/x-twitter-mcp-server](https://github.com/rafaljanicki/x-twitter-mcp-server) | 19+ (search, followers, bookmarks, etc.) |
| **bluesky-enhanced** | Bluesky | [brianellin/bsky-mcp-server](https://github.com/brianellin/bsky-mcp-server) | 20+ (timeline, search, engagement, etc.) |

> **Note:** Crosspost overlaps with twitter-enhanced and bluesky-enhanced for basic posting. Crosspost is for quick multi-platform blasts; the enhanced servers add rich read/search/engagement tools. Both can run simultaneously -- the AI picks the right tool based on your prompt.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with MCP Gateway support
- Docker MCP Gateway installed via Homebrew (`brew install docker-mcp`)

## Setup

1. **Clone the repo:**

   ```bash
   git clone git@github.com:ryanjafari/social-media-mcp-gateway.git
   cd social-media-mcp-gateway
   ```

2. **Create your `.env` file:**

   ```bash
   cp .env.example .env
   ```

3. **Fill in credentials** for the platforms you want to use. Leave the rest blank -- only servers with credentials will be activated.

4. **Run setup:**

   ```bash
   bash setup.sh
   ```

   This will: build Docker images, register the catalog, store secrets via `docker mcp secret set`, enable servers, and restart the gateway.

5. **Configure your AI agent.** In Cursor's `mcp.json` (or equivalent):

   ```json
   {
     "mcpServers": {
       "docker-mcp": {
         "url": "http://localhost:8811/sse"
       }
     }
   }
   ```

## Adding more platforms later

Fill in the new credentials in `.env` and re-run `bash setup.sh`. The script only builds and enables servers that have credentials -- everything else is skipped.

## Secret naming convention

Secrets are stored in Docker MCP's secret store with a `servername.` prefix, matching the convention used by built-in servers:

```
github.personal_access_token          # built-in
notion.internal_integration_token     # built-in
substack.substack_publication_url     # ours
substack.substack_session_token       # ours
reddit.reddit_client_id               # ours
```

## Project structure

```
.
├── .env.example                 # Credential template (all fields blank)
├── setup.sh                     # One-command setup script
├── social-media-catalog.yaml    # Docker MCP catalog definition
├── Dockerfile                   # Crosspost server image
├── substack-enhanced/           # Custom Substack MCP server (built by us)
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── medium/Dockerfile
├── reddit/Dockerfile
├── facebook/Dockerfile
├── twitter-enhanced/Dockerfile
├── bluesky-enhanced/Dockerfile
└── docs/
    └── architecture.html        # Visual architecture diagram (open in browser)
```

## Credential guides

| Platform | How to get credentials |
|----------|----------------------|
| **Twitter/X** | [Developer Portal](https://developer.twitter.com) -- create an app, get OAuth 1.0a keys |
| **Mastodon** | Your instance > Settings > Applications > generate access token |
| **Bluesky** | [bsky.app](https://bsky.app) > Settings > App Passwords |
| **LinkedIn** | [Developer Portal](https://developer.linkedin.com) -- OAuth 2.0 token (expires ~60 days) |
| **Discord** | [Developer Portal](https://discord.com/developers/applications) -- bot token + channel ID, or webhook URL |
| **Dev.to** | [Settings > Extensions](https://dev.to/settings/extensions) -- API key |
| **Telegram** | Message [@BotFather](https://t.me/BotFather) -- create bot, get token + chat ID |
| **Slack** | [API Apps](https://api.slack.com/apps) -- create app, get token + channel |
| **Nostr** | Your private key in hex or nsec format + relay URLs |
| **Substack** | Browser DevTools > Application > Cookies > copy `substack.sid` value |
| **Medium** | [Settings > Integration tokens](https://medium.com/me/settings) (legacy -- no new tokens issued) |
| **Reddit** | [Preferences > Apps](https://www.reddit.com/prefs/apps) -- create "script" type app |
| **Facebook** | [Graph API Explorer](https://developers.facebook.com/tools/explorer) -- Page access token |
