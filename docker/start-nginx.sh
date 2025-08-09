#!/bin/sh
set -euo pipefail

# 设置默认的 Bearer Token（如果环境变量未设置）
BEARER_TOKEN="${BEARER_TOKEN:-your_secret_token_here}"

# 创建用户可写的nginx配置和临时目录
mkdir -p /tmp/nginx/client_temp /tmp/nginx/proxy_temp /tmp/nginx/fastcgi_temp /tmp/nginx/uwsgi_temp /tmp/nginx/scgi_temp

# 使用 envsubst 替换 nginx 配置文件中的环境变量，输出到临时目录
envsubst '${BEARER_TOKEN}' < /etc/nginx/nginx.conf.template > /tmp/nginx/nginx.conf

# 启动 nginx，使用临时配置文件
exec /usr/sbin/nginx -c /tmp/nginx/nginx.conf -g 'daemon off;'