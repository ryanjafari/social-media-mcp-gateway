FROM node:22-slim

# Install crosspost globally
RUN npm install -g @humanwhocodes/crosspost

# Run crosspost in MCP mode with all platforms enabled.
# Flags: -t (Twitter/X), -m (Mastodon), -b (Bluesky), -l (LinkedIn),
#        -d (Discord bot), --discord-webhook, --devto (Dev.to),
#        --telegram, -s (Slack), -n (Nostr)
ENTRYPOINT ["crosspost", "--mcp", "-t", "-m", "-b", "-l", "-d", "--discord-webhook", "--devto", "--telegram", "-s", "-n"]
