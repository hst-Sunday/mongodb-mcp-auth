#!/bin/sh
set -euo pipefail

# Run MCP server using Node.js directly with the correct path
if [ -f /usr/local/lib/node_modules/mongodb-mcp-server/dist/index.js ]; then
  exec /usr/local/bin/node /usr/local/lib/node_modules/mongodb-mcp-server/dist/index.js
fi

# Fallback: try the official entrypoint
if command -v docker-entrypoint.sh >/dev/null 2>&1; then
  exec docker-entrypoint.sh mongodb-mcp-server
fi

echo "Cannot find MCP server"
exit 1


