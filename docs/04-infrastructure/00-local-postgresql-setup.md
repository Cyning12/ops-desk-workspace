# 本地 PostgreSQL 开发环境搭建 Checklist

> 适用范围：`ops-desk-api` 本地开发 / 测试  
> 数据库：PostgreSQL 15 + pgvector 扩展  
> 创建日期：2026-07-16

---

## 0. 前置条件

| 项 | 版本/说明 | 检查命令 |
|---|---|---|
| Docker | 20.10+ | `docker --version` |
| Docker Compose | v2+ | `docker compose version` |
| uv | 0.2+ | `uv --version` |
| Python | 3.11+ | `uv run python --version` |
| 克隆仓库 | `ops-desk-api` | `git status` |

---

## 1. 启动 PostgreSQL（推荐：Docker Compose）

### 1.1 仅启动数据库

```bash
cd /Users/cyning/Desktop/Ops-desk/ops-desk-api
docker compose up -d db
```

### 1.2 等待数据库就绪

```bash
docker compose ps db
# 状态应为 healthy
```

或手动检查：

```bash
docker compose exec db pg_isready -U ops -d opsdesk
# 预期输出：/var/run/postgresql:5432 - accepting connections
```

### 1.3 确认 pgvector 扩展已启用

```bash
docker compose exec db psql -U ops -d opsdesk -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
```

若未启用，手动创建：

```bash
docker compose exec db psql -U ops -d opsdesk -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

---

## 2. 启动 PostgreSQL（备选：本地安装）

若不想使用 Docker，可使用 Homebrew 安装 PostgreSQL 15：

```bash
# macOS
brew install postgresql@15
brew services start postgresql@15

# 创建用户和数据库
psql postgres -c "CREATE USER ops WITH PASSWORD 'ops_password';"
psql postgres -c "CREATE DATABASE opsdesk OWNER ops;"
psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE opsdesk TO ops;"

# 安装 pgvector（需对应 PostgreSQL 版本）
brew install pgvector
psql -U ops -d opsdesk -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

---

## 3. 配置环境变量

确保 `.env` 文件位于 `ops-desk-api` 根目录，且包含：

```bash
DATABASE_URL=postgresql+asyncpg://ops:ops_password@localhost:5432/opsdesk
```

检查当前配置：

```bash
grep DATABASE_URL .env
```

若使用 Docker Compose 启动全套服务（db + api），`.env` 中的 `DB_PASSWORD` 会注入 Compose：

```bash
DB_PASSWORD=ops_password
```

---

## 4. 运行 Alembic 数据库迁移

```bash
uv run alembic upgrade head
```

验证表已创建：

```bash
docker compose exec db psql -U ops -d opsdesk -c "\dt"
```

应看到以下表：

```text
ops_users
ops_invite_tokens
ops_sessions
ops_repos
ops_issues
ops_pull_requests
ops_sync_runs
ops_scan_snapshots
ops_graph_snapshots
ops_sessions_chat
ops_runs
ops_run_events
```

---

## 5. 验证后端启动

### 5.1 仅启动 API（已手动启动 PG）

```bash
uv run uvicorn app.main:app --reload --port 8000
```

或：

```bash
make dev
```

### 5.2 Docker Compose 启动全套服务

```bash
docker compose up -d
```

API 会等待 `db` healthy 后自动执行 `alembic upgrade head` 并启动。

### 5.3 健康检查

```bash
curl http://localhost:8000/health
# 预期：{"status":"ok"}
```

---

## 6. 验证测试

### 6.1 无 PG 时的测试

部分 router 集成测试依赖 PostgreSQL，本地无 PG 时会自动 skip（39 passed, 2 skipped 为正常）。

```bash
uv run pytest tests -q
```

### 6.2 有 PG 时的完整测试

```bash
# 确保 PG 已启动
docker compose up -d db

# 运行全部测试
uv run pytest tests -q
```

预期：全部通过，无 skip。

---

## 7. 验证 Chat SSE 端到端

### 7.1 先创建一个测试用户（Auth Epic 完成后可省略）

当前 `ops_users` 表为空，测试时通过 dependency override 绕过。真实调用需要：

```bash
# 临时插入测试用户（仅本地开发）
docker compose exec db psql -U ops -d opsdesk -c "
INSERT INTO ops_users (id, username, role) VALUES
('00000000-0000-0000-0000-000000000001', 'tester', 'viewer')
ON CONFLICT DO NOTHING;
"
```

### 7.2 使用 curl 测试 SSE

> **〔2026-11-14 注〕** 旧 `/api/ops/chat/stream` 已 **410 下线**；现网主路径为 lg-rag（freeze `lg-rag-sse-v1`，请求字段为 `query`）：

```bash
curl -N \
  -H "Accept: text/event-stream" \
  -H "Content-Type: application/json" \
  -b "ops_session=your-session-cookie" \
  -X POST http://localhost:8000/api/ops/lg-rag/stream \
  -d '{"query": "What is #1?"}'
```

预期输出类似：

```text
event: run.start
data: {"run_id":"...","seq":1,"ts_ms":0,"agent_role":"system","event_type":"run.start","payload":{"run_id":"..."}}

event: thinking
data: {...}

event: answer
data: {...}

event: done
data: {...}
```

---

## 8. 停止环境

```bash
# 停止并删除容器（保留数据卷）
docker compose down

# 停止并删除容器及数据卷（谨慎）
docker compose down -v

# 停止本地 brew 安装的 PG
brew services stop postgresql@15
```

---

## 9. 常见问题排查

### Q1: `docker compose up -d db` 提示端口 5432 被占用

```bash
lsof -i :5432
# 或
sudo lsof -i :5432
```

若本地已运行 PostgreSQL，选择其一：

- 停止本地 PG：`brew services stop postgresql@15`
- 修改 `docker-compose.yml` 端口映射，例如 `"5433:5432"`，并同步修改 `.env` 中的 `DATABASE_URL`

### Q2: `alembic upgrade head` 报错 `FATAL: database "opsdesk" does not exist`

数据库未创建。使用 Docker Compose 时会自动创建；本地安装需手动：

```bash
psql postgres -c "CREATE DATABASE opsdesk OWNER ops;"
```

### Q3: `CREATE EXTENSION vector` 报错

pgvector 未安装。Docker 镜像 `pgvector/pgvector:pg15` 已内置。本地安装需：

```bash
brew install pgvector
# 或对应 Linux 发行版的包管理器
```

### Q4: 测试报 `OSError: Connect call failed ('127.0.0.1', 5432)`

PostgreSQL 未启动或配置错误：

```bash
# 检查 PG 是否运行
docker compose ps db

# 检查 .env DATABASE_URL
export $(grep -v '^#' .env | xargs)
echo $DATABASE_URL
```

### Q5: `alembic upgrade head` 报错 `relation already exists`

通常是因为之前手动执行过 `ops_desk_ddl.sql`。建议：

```bash
# 清空数据库后重新迁移
docker compose down -v
docker compose up -d db
uv run alembic upgrade head
```

### Q6: Docker Compose 启动 api 服务后日志卡在 "waiting for db"

检查 db 健康状态：

```bash
docker compose logs db
```

常见原因：

- 数据卷损坏：`docker compose down -v` 后重试
- 端口冲突：见 Q1

---

## 10. 快速命令速查

```bash
# 启动 PG
docker compose up -d db

# 查看日志
docker compose logs -f db

# 进入 psql
docker compose exec db psql -U ops -d opsdesk

# 运行迁移
uv run alembic upgrade head

# 启动 API
make dev

# 运行测试
uv run pytest tests -q

# 全套启动
docker compose up -d

# 全套停止
docker compose down
```

---

## 11. 关联文档

- [`docs/05-plan/02-epic6-implementation-plan.md`](../../05-plan/02-epic6-implementation-plan.md)
- [`ops-desk-api/README.md`](../../../../ops-desk-api/README.md)
- [`ops-desk-api/docker-compose.yml`](../../../../ops-desk-api/docker-compose.yml)
- [`ops-desk-api/alembic/versions/20260715_init_ops_desk.py`](../../../../ops-desk-api/alembic/versions/20260715_init_ops_desk.py)

---

## 修订记录

| 日期 | 说明 |
|---|---|
| 2026-07-16 | 初始版本，覆盖 Docker、本地安装、迁移、测试与常见问题 |
