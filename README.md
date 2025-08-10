## mongodb-mcp-auth

将 `mongodb/mongodb-mcp-server` 与 `nginx` 整合为单一 Docker 镜像，提供 HTTP 反向代理与 Bearer Token 鉴权。

### 目录结构

```
Dockerfile                      # 统一镜像构建入口
docker/supervisord.conf         # 同容器内同时运行 MCP Server 与 Nginx
docker/start-mcp.sh             # MCP Server 启动适配脚本
nginx/nginx.conf                # Nginx 反代与 Bearer 鉴权配置
docker-compose.yml              # 仅用于参考（原多容器方式）
```

### 主要特性

- **单一镜像**：同一容器内运行 MCP Server + Nginx（反向代理、鉴权、SSE 友好）。
- **可配置**：通过环境变量配置 MCP Server 行为，可挂载自定义 `nginx.conf`。

## 快速开始

### 从 GitHub Container Registry (GHCR) 拉取镜像

一旦代码推送到 GitHub，GitHub Actions 会自动构建并发布 Docker 镜像到 GHCR。

1) 拉取最新镜像：

```bash
docker pull ghcr.io/hst-Sunday/mongodb-mcp-auth:latest
```

2) 运行容器：

```bash
docker run -d \
  --name mongodb-mcp-auth \
  -p 80:8080 \
  -e MDB_MCP_CONNECTION_STRING="<your_mongodb_connection_string>" \
  -e MDB_MCP_READ_ONLY="true" \
  -e BEARER_TOKEN="<your_bearer_token>" \
  -e ALLOWED_HOSTS="api.example2.com,api.example.com" \
  ghcr.io/hst-Sunday/mongodb-mcp-auth:latest
```

3) 访问服务：

- HTTP 入口：`http://localhost/`
- 默认需携带 Bearer Token（见下文"鉴权与 Nginx 配置"）

**可用标签：**
- `latest` - 主分支最新版本
- `v1.0.0` - 特定版本标签
- `main` - 主分支

## 环境变量（传递给 MCP Server）

- **MDB_MCP_CONNECTION_STRING**（推荐）
  - 用于直连 MongoDB 的连接串，例如：`mongodb+srv://<user>:<pass>@<cluster>/?retryWrites=false&ssl=true&authSource=admin`
  - 与 Atlas Service Account 模式二选一。

- 可选的 Atlas Service Account 模式（如 MCP Server 支持）：
  - `MDB_MCP_API_CLIENT_ID`
  - `MDB_MCP_API_CLIENT_SECRET`

- **BEARER_TOKEN**（新增）
  - 设置 Nginx Bearer Token 鉴权的密钥，例如：`"your_secret_token"`
  - 如不设置，将使用默认值：`"sunday20250809."`
  
 - **ALLOWED_HOSTS**（新增）
   - 通过逗号分隔的域名白名单，仅允许这些 Host 访问反向代理。
   - 例如：`ALLOWED_HOSTS="api.example2.com,api.example.com"`
   - 未设置时为兼容性考虑将放行所有 Host（生产环境建议务必设置）。
  
- 其他常用参数：
  - `MDB_MCP_READ_ONLY`：设为 `"true"` 启用只读。
  - `MDB_MCP_TRANSPORT`：统一镜像默认 `http`（容器内 3000，被 Nginx 反代）。
  - `MDB_MCP_HTTP_HOST`：默认 `0.0.0.0`。
  - `MDB_MCP_HTTP_PORT`：默认 `3000`。
  - `MDB_MCP_LOGGERS`：如 `mcp,disk,stderr`。
  - 其余高级参数可参考 MCP Server 官方文档。

提示：不要把敏感信息写入仓库。通过运行时 `-e` 或 Secret 注入更安全。

## 鉴权与 Nginx 配置

本镜像内置 Nginx，反向代理到同容器内的 MCP Server（`127.0.0.1:3000`）。开启基于 Bearer Token 的鉴权：

### 方式 A：使用环境变量设置 Token（推荐）

通过 `BEARER_TOKEN` 环境变量动态配置 Bearer Token：

```bash
docker run -d -p 80:8080 \
  -e MDB_MCP_CONNECTION_STRING="..." \
  -e BEARER_TOKEN="your_secret_token_here" \
  -e ALLOWED_HOSTS="api.example2.com" \
  ghcr.io/hst-Sunday/mongodb-mcp-auth:latest
```

### 方式 B：挂载自定义配置

```bash
docker run -d -p 80:8080 \
  -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf.template:ro \
  -e MDB_MCP_CONNECTION_STRING="..." \
  -e BEARER_TOKEN="your_secret_token_here" \
  ghcr.io/hst-Sunday/mongodb-mcp-auth:latest
```

### 测试访问

```bash
curl -H "Authorization: Bearer your_secret_token_here" http://localhost/
```

如需启用 TLS，请在 `nginx.conf` 中添加证书配置或挂载证书文件，并将监听端口改为 443。

## 本地构建与运行

```bash
# 构建
docker build -t ghcr.io/hst-Sunday/mongodb-mcp-auth:latest .

# 运行（示例）
docker run -d \
  --name mongodb-mcp-auth \
  -p 8080:8080 \
  -e MDB_MCP_CONNECTION_STRING="<your_mongodb_connection_string>" \
  -e BEARER_TOKEN="<your_bearer_token>" \
  ghcr.io/hst-Sunday/mongodb-mcp-auth:latest

# 访问：http://localhost:8080/
```

## 端口与网络

- 镜像对外暴露：`8080/tcp`（非特权端口，适合非root用户）
- 容器内 MCP Server 监听：`127.0.0.1:3000`（由 Nginx 反代）
- 容器内 Nginx 监听：`0.0.0.0:8080`

## 故障排查

- 访问 401：确认 `Authorization: Bearer <token>` 与 `nginx.conf` 中的 `expected_bearer` 一致。
- 端口冲突：宿主机 `80` 被占用时，使用其他端口映射（如 `-p 8080:80`）。
- 无法连接数据库：检查 `MDB_MCP_CONNECTION_STRING` 是否正确、网络是否可达、IP 白名单是否放行。
- 查看日志：
  - Nginx 与 MCP Server 日志均通过前台输出，可用 `docker logs -f <container>` 观察。

## 备注

- 仓库中的 `docker-compose.yml` 为原始多容器部署示例；本项目主推“单一镜像”方式。
- 工作流支持多架构构建：`linux/amd64` 和 `linux/arm64`，使用缓存优化构建速度。

## 许可证

本仓库默认以与上游依赖兼容的开源许可证为基础。若无特殊声明，可按你的组织策略添加 `LICENSE` 文件。


