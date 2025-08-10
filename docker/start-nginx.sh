#!/bin/sh
set -euo pipefail

# 设置默认的 Bearer Token（如果环境变量未设置）
BEARER_TOKEN="${BEARER_TOKEN:-your_secret_token_here}"

# 创建用户可写的nginx配置和临时目录
mkdir -p /tmp/nginx/client_temp /tmp/nginx/proxy_temp /tmp/nginx/fastcgi_temp /tmp/nginx/uwsgi_temp /tmp/nginx/scgi_temp

# 构建 Host 白名单 map 片段
# ALLOWED_HOSTS 形如："api.example2.com,api.example.com"
ALLOWED_HOSTS_INPUT=${ALLOWED_HOSTS:-}
ALLOWED_HOSTS_MAP=""
if [ -n "$ALLOWED_HOSTS_INPUT" ]; then
  list=$(printf '%s' "$ALLOWED_HOSTS_INPUT" | tr ',' ' ')
  for h in $list; do
    # 去除首尾空格并转小写
    h_trim=$(printf '%s' "$h" | sed 's/^ *//; s/ *$//' | tr 'A-Z' 'a-z')
    [ -z "$h_trim" ] && continue
    # 仅允许字母/数字/点/短横线
    if printf '%s' "$h_trim" | grep -Eq '^[A-Za-z0-9.-]+$'; then
      ALLOWED_HOSTS_MAP="${ALLOWED_HOSTS_MAP}
    ${h_trim} 1;"
    fi
  done
  # 若最终为空，则降级为允许所有
  if [ -z "$ALLOWED_HOSTS_MAP" ]; then
    ALLOWED_HOSTS_MAP="~^.*$ 1;"
  fi
else
  # 未设置时，允许所有（使用正则匹配任意 Host）
  ALLOWED_HOSTS_MAP="~^.*$ 1;"
fi

# 构建安全的正则：^(host1|host2)$，各 host 内的点需转义
ALLOWED_HOSTS_REGEX=".*"
if [ -n "$ALLOWED_HOSTS_INPUT" ]; then
  list=$(printf '%s' "$ALLOWED_HOSTS_INPUT" | tr ',' ' ')
  hosts_regex=""
  for h in $list; do
    h_trim=$(printf '%s' "$h" | sed 's/^ *//; s/ *$//' | tr 'A-Z' 'a-z')
    [ -z "$h_trim" ] && continue
    if printf '%s' "$h_trim" | grep -Eq '^[A-Za-z0-9.-]+$'; then
      escaped=$(printf '%s' "$h_trim" | sed 's/\./\\\./g')
      if [ -z "$hosts_regex" ]; then
        hosts_regex="$escaped"
      else
        hosts_regex="$hosts_regex|$escaped"
      fi
    fi
  done
  [ -n "$hosts_regex" ] && ALLOWED_HOSTS_REGEX="$hosts_regex"
fi

# 使用 envsubst 替换 nginx 配置文件中的环境变量，输出到临时目录
export BEARER_TOKEN
export ALLOWED_HOSTS_REGEX
envsubst '${BEARER_TOKEN} ${ALLOWED_HOSTS_REGEX}' < /etc/nginx/nginx.conf.template > /tmp/nginx/nginx.conf

# 启动 nginx，使用临时配置文件
exec /usr/sbin/nginx -c /tmp/nginx/nginx.conf -g 'daemon off;'