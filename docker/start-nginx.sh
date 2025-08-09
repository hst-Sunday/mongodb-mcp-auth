#!/bin/sh
set -euo pipefail

# 设置默认的 Bearer Token（如果环境变量未设置）
BEARER_TOKEN="${BEARER_TOKEN:-your_secret_token_here}"

# 使用 envsubst 替换 nginx 配置文件中的环境变量
envsubst '${BEARER_TOKEN}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# 启动 nginx
exec /usr/sbin/nginx -g 'daemon off;'