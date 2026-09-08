# 事故：生产 `OPS_DESK_SECRET` 丢失（2026-08-17）

> **给谁**：SSH 改 `/opt/ops-desk/.env` 之后，GHA `deploy-api` 报 `OPS_DESK_SECRET required`，或登录全员失效。  
> **对照**：改 Flag 如何进容器 → [`02-prod-env-reload.md`](./02-prod-env-reload.md)  
> **对照**：首次发邀请 → [`../../deploy/README.md`](../../deploy/README.md) §4  
> **GHA 失败例**：api 仓 [actions/runs/32007359706](https://github.com/Cyning12/ops-desk-api/actions/runs/32007359706)（合入 PR #40 后 `deploy-api`）

**纪律**：密钥、邀请码明文 **禁止** 提交 git、禁止贴进聊天。下文命令只确认「有没有」，不要把 `printenv` 输出拷到对话里。

---

## 0. `OPS_DESK_SECRET` 是什么

登录态 HMAC 胡椒，**不是** LLM / SiliconFlow / 数据库密码。

- Cookie 里是明文 session token；库表 `ops_sessions.token_hash`、`ops_invite_tokens.token` 存的是 `HMAC-SHA256(OPS_DESK_SECRET, token)`。
- 实现：`ops-desk-api/app/ops/security.py` → `hash_token()`。
- 生产 compose：`${OPS_DESK_SECRET:?OPS_DESK_SECRET required}`。空值则 **compose 插值直接失败**，镜像不会起来。

轮换密钥 = 旧 Cookie 全部失效，库里 **未使用的邀请码也作废**（hash 对不上）。`ops_users` 用户行还在，但登录仍要一张 **新的未使用邀请码**。

---

## 1. 这次发生了什么

| 项 | 内容 |
|---|---|
| 时间 | 2026-08-17 15:47 UTC+8 |
| 触发 | 合入 api PR #40（SiliconFlow 精排 + Langfuse）→ `push` `master` → `deploy-api` |
| 成功对照 | 同日稍早 PR #39 的 `deploy-api` 仍为绿 |
| 失败步 | rsync `/opt/ops-desk/api` **已成功**；远端 `docker compose … up -d --build api` 在 **插值阶段** 退出 |
| 日志 | `error while interpolating services.api.environment.OPS_DESK_SECRET: required variable OPS_DESK_SECRET is missing a value` |
| 现网状态 | 旧 api 容器未重建（build 没开始），网站仍跑 **合入前** 的代码 |
| 根因 | 手改服务器 `/opt/ops-desk/.env` 时把 `OPS_DESK_SECRET` 删空或整文件覆盖。GHA **不**下发、**不**备份这份文件 |

`.env` 在 gitignore；`deploy-info.local.md` 里只是占位符 `<openssl rand -hex 32>`。本机仓根 `.env` 的 `change-me-in-production` **不是**生产值。

---

## 2. 查询：先找回旧值（有则不必轮换）

compose 插值失败时，**旧容器往往还在**。优先从进程环境抄回。

### 2.1 旧容器（首选）

```bash
cd /opt/ops-desk/deploy

docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  exec -T api printenv OPS_DESK_SECRET
```

若这条也因插值失败（compose 连 exec 都展不开），绕过 compose：

```bash
docker ps --format '{{.Names}}' | grep -i api
docker exec <容器名> printenv OPS_DESK_SECRET
```

把输出写回 `/opt/ops-desk/.env` 的 `OPS_DESK_SECRET=`，然后走 §4 重跑部署。**不要**用本机占位值。

### 2.2 编辑器备份

```bash
ls -l /opt/ops-desk/.env /opt/ops-desk/.env~ /opt/ops-desk/.env.bak /opt/ops-desk/.env.swp
grep '^OPS_DESK_SECRET=' /opt/ops-desk/.env~
```

### 2.3 不要去翻

| 地方 | 原因 |
|---|---|
| `git log` / GitHub | `.env` 从未入库 |
| 本机 `ops-desk-api/.env` | 开发假值 |
| `docs/04-infrastructure/deploy-info.local.md` | 未填真值 |

旧容器已没、备份也没有 → §3 重新生成。

---

## 3. 解决方案：重新生成（本次实际路径）

**不要** `systemctl restart docker`。**不要** `docker compose down`。**不要** `docker compose restart api`（`restart` 不重读 `--env-file`）。

```bash
# 3.1 生成（只看终端，不要贴聊天）
openssl rand -hex 32

# 3.2 只改这一行，不要整文件覆盖（以免再丢掉 DB_PASSWORD 等）
sudo vim /opt/ops-desk/.env
# OPS_DESK_SECRET=<上面那串>

grep '^OPS_DESK_SECRET=' /opt/ops-desk/.env
# 只确认等号右边非空

# 3.3 不要单独 restart。用 GHA 一次完成发版 + 注入：
# 本机：
gh run rerun 32007359706 --failed -R Cyning12/ops-desk-api
```

GHA 命令已是 `up -d --build api`，会读**当时**的 `/opt/ops-desk/.env`。不必再手动 restart。

若只想先让 compose 吃到新密钥、稍后再发版：

```bash
cd /opt/ops-desk/deploy
docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  up -d --no-deps api
```

`DB_PASSWORD` **不要**一起乱改（那是 Postgres 角色密码，和这次无关）。

---

## 4. 再次生成邀请码（轮换密钥后必做）

脚本：`ops-desk-api/scripts/create_initial_user.py`  
默认用户 `admin` / 角色 `maintainer`。用户已存在则只再发一张邀请（**每次运行都是新 token**）。必须在 **新密钥已进入该进程** 之后跑，否则 hash 仍对不上。

### 生产（容器内）

```bash
cd /opt/ops-desk/deploy

docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  exec -T api python scripts/create_initial_user.py
```

输出形如：`{"username": "admin", "invite_token": "…", "role": "maintainer"}`  
用该 `invite_token` + 用户名 `admin` 在登录页重新登录。旧 Cookie 作废。

首次部署同一条也写在 [`deploy/README.md`](../../deploy/README.md) §4（有的环境要 `sudo docker compose`）。

### 本机 `make dev`

```bash
cd /path/to/ops-desk-api
.venv/bin/python scripts/create_initial_user.py
```

登录：`POST /api/ops/auth/login`，body `{"username":"admin","invite_token":"<输出>"}`。联调示例见 api 仓 `docs/ios/api-auth-chat.md`。

---

## 5. 合主分支会不会自动加载新 `.env`

**不会。**

| | 本机 | 生产 |
|---|---|---|
| 合 PR | 只更新代码；`.env` gitignore | GHA rsync **排除** `.env` |
| 何时读 env | 进程启动 / uvicorn `--reload` 因 `.py` 变化重启 | `compose up`（`--env-file`）把 **yaml 里声明过的键** 灌进容器 |
| 手改 `.env` 后 | 重启 `make dev` | `up -d --no-deps api` 或 GHA `up -d --build api`；**禁止**只 `restart` |

新键（如 `RAG_RERANK_BACKEND`、`LANGFUSE_ENV`）还须现网 `docker-compose.prod.yml` 已透传。GHA **不会**自动 scp workspace 的 compose。未透传时：精排代码把空的 `RAG_RERANK_BACKEND` 当成 `siliconflow`；`LANGFUSE_ENV` 空则默认 `prod`。

---

## 6. 自检

- [ ] `grep '^OPS_DESK_SECRET=' /opt/ops-desk/.env` 非空
- [ ] `deploy-api` 绿，或 `curl -fsS http://127.0.0.1:8000/health`
- [ ] 容器内 `printenv OPS_DESK_SECRET` 非空（不要把值拷走）
- [ ] 已在 **新容器** 里跑过 `create_initial_user.py`，拿到新邀请码
- [ ] 登录页用 `admin` + 新邀请码可进
- [ ] 未 `docker compose down`、未重启 docker 守护进程、未改 `DB_PASSWORD`

---

## 修订

| 日期 | 说明 |
|---|---|
| 2026-08-17 | 首稿：GHA #40 插值失败；旧值不在 git；轮换后须重发邀请 |
