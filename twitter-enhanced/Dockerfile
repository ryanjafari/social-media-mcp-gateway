FROM python:3.12-slim

# x-twitter-mcp: Enhanced Twitter/X MCP server with 19+ tools
# (profile lookup, search, followers, bookmarks, posting, and more)
# Source: https://github.com/rafaljanicki/x-twitter-mcp-server

RUN pip install --no-cache-dir x-twitter-mcp

ENTRYPOINT ["x-twitter-mcp-server"]
