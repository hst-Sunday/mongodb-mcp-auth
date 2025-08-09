FROM mongodb/mongodb-mcp-server:latest AS mcp

# Use Alpine with nginx for compatibility with MCP server binary (both Alpine-based)
FROM nginx:alpine

# Install supervisor and other dependencies
RUN apk add --no-cache supervisor dumb-init

# Copy Node.js runtime and MCP server from the MCP image
COPY --from=mcp /usr/local/bin/node /usr/local/bin/node
COPY --from=mcp /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=mcp /usr/local/bin/mongodb-mcp-server /usr/local/bin/mongodb-mcp-server
COPY --from=mcp /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Ensure executable permissions
RUN chmod +x /usr/local/bin/node \
    && chmod +x /usr/local/bin/mongodb-mcp-server \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

# Copy Nginx config as template (will be processed by envsubst)
COPY nginx/nginx.conf /etc/nginx/nginx.conf.template

# Supervisor configuration to run MCP server and Nginx together
COPY docker/supervisord.conf /etc/supervisor/supervisord.conf
COPY docker/start-mcp.sh /docker/start-mcp.sh
COPY docker/start-nginx.sh /docker/start-nginx.sh
RUN chmod +x /docker/start-mcp.sh /docker/start-nginx.sh && mkdir -p /var/log/supervisor

# Default MCP HTTP exposure inside container; can be overridden at runtime
ENV MDB_MCP_TRANSPORT="http" \
    MDB_MCP_HTTP_HOST="0.0.0.0" \
    MDB_MCP_HTTP_PORT="3000"

# Expose Nginx port
EXPOSE 80

# Use dumb-init for proper signal handling, then run supervisord in foreground
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]


