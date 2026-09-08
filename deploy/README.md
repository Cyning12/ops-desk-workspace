# Ops Desk 生产部署 Runbook

> 服务器：腾讯云 Lighthouse `82.157.125.39`（`ssh ops-desk`）· 域名 `www.cynaya.cn`  
> 架构：`https://www.cynaya.cn/` → Nginx(443) → `/` 静态 Web（`/opt/ops-desk/web/dist`）· `/api` → `127.0.0.1:8000`（compose: api + db）

---

## 首次部署（一次性）

### 0. 本地前置

- `ssh ops-desk` 免密可用（key 已入 agent）
- `ops-desk-web` 已 `pnpm build`（产物 `dist/`）
- 已从腾讯云 SSL 控制台下载 `cynaya.cn` 的 Nginx 格式证书（`*.crt` + `*.key`）

### 1. SSL 证书上服务器

```bash
scp cynaya.cn.crt cynaya.cn.key ops-desk:/tmp/
ssh ops-desk 'sudo mkdir -p /etc/nginx/ssl \
  && sudo mv /tmp/cynaya.cn.crt /tmp/cynaya.cn.key /etc/nginx/ssl/ \
  && sudo chmod 600 /etc/nginx/ssl/cynaya.cn.key'
```

### 2. 服务器 `.env`

```bash
ssh ops-desk 'mkdir -p /opt/ops-desk'
scp deploy/.env.example ops-desk:/opt/ops-desk/.env
ssh ops-desk 'chmod 600 /opt/ops-desk/.env && vim /opt/ops-desk/.env'
```

填：`DB_PASSWORD`、`OPS_DESK_SECRET`（`openssl rand -hex 32`）、两个 LLM key、（首次导入用的）`SUPABASE_DATABASE_URL`。

### 3. 部署

```bash
cd ops-desk-workspace/deploy
./deploy.sh
```

### 4. 首次初始化数据

再次生成邀请码（密钥轮换后、邀请用尽时同一条；每次运行都是**新 token**）：

脚本在 api 仓 `scripts/create_initial_user.py`。必须在 **当前容器已加载的 `OPS_DESK_SECRET`** 下执行。丢失密钥的查询与轮换见 [`docs/04-infrastructure/03-ops-desk-secret-incident.md`](../docs/04-infrastructure/03-ops-desk-secret-incident.md)。

```bash
# 初始 maintainer + 邀请密钥（记录输出的 invite_token）
ssh ops-desk 'sudo docker compose -f /opt/ops-desk/deploy/docker-compose.prod.yml \
  --env-file /opt/ops-desk/.env exec api python scripts/create_initial_user.py'

# Supabase 历史数据导入（幂等，可先 --dry-run）
ssh ops-desk 'sudo docker compose -f /opt/ops-desk/deploy/docker-compose.prod.yml \
  --env-file /opt/ops-desk/.env exec api python scripts/import_from_supabase.py'
```

> 导入完成后可把 `.env` 里的 `SUPABASE_DATABASE_URL` 清空。

### 5. E2E 验收（HTTPS）

- [ ] `https://www.cynaya.cn/` 打开登录页（HTTP 自动跳转）
- [ ] 邀请密钥登录 → Overview 指标非空
- [ ] Issues / PRs / Graph 显示真实数据
- [ ] Chat 发送消息，SSE 流式渲染正常
- [ ] `wss://www.cynaya.cn/api/ops/chat/ws` 不可达（WS 已禁用）

---

## 日常更新

| 场景 | 命令 |
|---|---|
| 后端代码更新 | `./deploy.sh --skip-web` |
| 前端更新（先 `pnpm build`） | `./deploy.sh --skip-api` |
| 全量 | `./deploy.sh` |
| 只改 Nginx | `./deploy.sh --nginx-only` |
| **只改** `/opt/ops-desk/.env` | **不要** `restart`。见 [`docs/04-infrastructure/02-prod-env-reload.md`](../docs/04-infrastructure/02-prod-env-reload.md)：`up -d --no-deps api` 后 `printenv` 核对 |

## 回滚

- 前端：`ssh ops-desk 'mv /opt/ops-desk/web/dist.bak.<ts> /opt/ops-desk/web/dist'`（deploy.sh 每次自动备份上一份）
- 后端：`git checkout <旧版本>` 后 `./deploy.sh --skip-web`；数据库用 pg_dump 备份恢复（备份策略 Epic 8.6 后续）

## 故障排查

```bash
ssh ops-desk 'sudo docker compose -f /opt/ops-desk/deploy/docker-compose.prod.yml ps'
ssh ops-desk 'sudo docker compose -f /opt/ops-desk/deploy/docker-compose.prod.yml logs --tail=100 api'
ssh ops-desk 'sudo nginx -t && sudo tail -50 /var/log/nginx/error.log'
```

---

## 修订记录

| 日期 | 说明 |
|---|---|
| 2026-07-25 | 初版（task `deploy-prod`） |
