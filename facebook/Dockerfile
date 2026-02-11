FROM python:3.12-slim

# facebook-mcp-server: MCP server for Facebook Pages (post, comments, insights)
# Source: https://github.com/HagaiHen/facebook-mcp-server

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Clone repo and install dependencies
RUN git clone --depth 1 https://github.com/HagaiHen/facebook-mcp-server.git /app
WORKDIR /app
RUN pip install --no-cache-dir -r requirements.txt

ENTRYPOINT ["python", "server.py"]
