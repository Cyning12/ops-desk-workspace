# 部署信息模板（deploy-info）

> **用法**：复制本文件为 `deploy-info.local.md`（已被 `.gitignore` 排除，**真值永不提交**），逐项填写。  
> **消费者**：Epic 8 部署 task（API + PG + Web + Nginx + SSL）。  
> **纪律**：本模板只含占位符；禁止把真实 IP/密钥/密码提交进 git。

---

## 1. 服务器（腾讯云 Lighthouse）

| 项 | 值 | 备注 |
|---|---|---|
| 公网 IP | `<PUBLIC_IP>` | 控制台实例详情页 |
| 内网 IP | `<PRIVATE_IP>` | 可选 |
| SSH 用户名 | `<SSH_USER>` | 通常 `ubuntu` 或 `root` |
| SSH 私钥路径 | `~/.ssh/<KEY_NAME>.pem` | 本机路径；私钥内容永不入 git |
| SSH 端口 | `22` | 默认值，改过则填实际值 |
| 系统 | Ubuntu 22.04 | 购买时镜像 |
| Docker | ✅ 已装（2026-07 按 01-environment-setup 执行） | `docker --version` 复核 |
| Nginx | ❓ 待验证 | `nginx -v`；未装则 `apt install -y nginx` |

## 2. 域名与 DNS

| 项 | 值 | 备注 |
|---|---|---|
| 域名 | `<example.com>` | ICP 已通过（2026-07） |
| DNS A 记录 | `<example.com>` → `<PUBLIC_IP>` | ❓ 待确认已解析 |
| www 子域 | `www.<example.com>` → `<PUBLIC_IP>` | 可选 |
| API 子域（如用） | `api.<example.com>` → `<PUBLIC_IP>` | 可选；v1 可单域名路径分流 |

## 3. SSL 证书

| 项 | 值 | 备注 |
|---|---|---|
| 方式 | 腾讯云免费证书 / acme.sh | 二选一 |
| crt 路径（服务器） | `/etc/nginx/ssl/<example.com>.crt` | 腾讯云下载 Nginx 格式 |
| key 路径（服务器） | `/etc/nginx/ssl/<example.com>.key` | 权限 600 |
| 自动续期 | acme.sh cron | 选 acme.sh 时适用 |

## 4. 生产环境变量（写入服务器 `.env`，不入库）

| 项 | 值 | 备注 |
|---|---|---|
| `OPS_DESK_SECRET` | `<openssl rand -hex 32>` | 部署脚本可生成 |
| `DATABASE_URL` | `postgresql+asyncpg://ops:<DB_PASSWORD>@db:5432/opsdesk` | compose 内网 |
| `DB_PASSWORD` | `<强随机>` | 生产 PG 独立密码 |
| `SILICONFLOW_API_KEY` | `<sk-...>` | 可复用现有 |
| `BAILIAN_API_KEY` | `<...>` | fallback 用 |
| `OPS_LLM_PROVIDER` | `siliconflow` | 默认 provider |
| `OPS_CHAT_WS_ENABLED` | `false` | **生产禁用未鉴权 WS 端点** |
| `SESSION_COOKIE_SECURE` | `true` | HTTPS 必须 |
| `CORS_ORIGINS` | `https://<example.com>` | 收紧到生产域名 |

## 5. CI/CD

| 项 | 值 | 备注 |
|---|---|---|
| 部署方式 | 服务器 git pull / GHA SSH 推送 | 待定，部署 task 拍板 |
| GitHub Secrets（如走 GHA） | `DEPLOY_SSH_KEY` · `DEPLOY_HOST` · `DEPLOY_USER` | 仓库 Settings 手动添加 |
| 部署目录（服务器） | `/opt/ops-desk` | compose 项目根 |

## 6. 网络与安全组

| 端口 | 用途 | 状态 |
|---|---|---|
| 22 | SSH | ❓ 待确认开放 |
| 80 | HTTP（跳转 HTTPS） | ❓ 待确认开放 |
| 443 | HTTPS | ❓ 待确认开放 |
| 8000 | API（仅内网/本机，不对外） | 不开放 |
| 5432 | PG（仅 compose 内网） | 不开放 |

---

## 填写进度

- [ ] 1. 服务器
- [ ] 2. 域名与 DNS
- [ ] 3. SSL
- [ ] 4. 生产环境变量（部署 task 启动时生成/收集）
- [ ] 5. CI/CD（部署 task 拍板后填）
- [ ] 6. 网络与安全组

## 修订记录

| 日期 | 说明 |
|---|---|
| 2026-07-24 | 初版（ops-desk-api 会话生成；部署轨 pending Web 前端 Epic） |
