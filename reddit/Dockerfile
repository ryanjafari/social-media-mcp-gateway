FROM python:3.12-slim

# reddit-mcp: MCP server for Reddit (post, reply, search, analytics)
# Source: https://github.com/Arindam200/reddit-mcp

RUN apt-get update && apt-get install -y --no-install-recommends git curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Clone repo and install dependencies
RUN git clone --depth 1 https://github.com/Arindam200/reddit-mcp.git /app
WORKDIR /app
RUN uv sync

ENTRYPOINT ["uv", "run", "server.py"]
