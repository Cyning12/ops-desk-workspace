# Ops Desk Kimi Code v1 · Epic 任务清单

> 创建日期：2026-07-16  
> 关联：[`00-migration-roadmap.md`](./00-migration-roadmap.md) · `ops-desk-api/docs/tasks/active/task_llm_provider_v1.md`

---

## 清单用途

本文档是 `00-migration-roadmap.md` 的细化展开：

- 每个 Epic 对应一个可独立验收的业务能力域。
- 每个任务包含**验收标准、当前状态、建议阶段、依赖**。
- 状态随代码进展同步更新；新增/合并任务需走 `10-task` 流程。

---

## 当前现状速览

| 维度 | 完成度 | 说明 |
|---|---|---|
| 工程骨架 | ~85% | FastAPI 入口、路由挂载、Docker Compose、Makefile 就绪 |
| 配置管理 | ~90% | `app/config.py`、`.env.example` 完整 |
| 数据库与 ORM | ~90% | 12 张表模型 + Alembic 初始迁移 + DDL 完整 |
| 技术图谱 | ~70% | `00_main`、`10_flow_chat` 已生成；`01_struct` 模块表已定义 |
| API 路由注册 | ~85% | 6 个子路由已挂载；issues/pulls/graph 已实现 |
| **LLM Provider** | **~100%** | **SiliconFlow / 百炼 Provider 已实现，fallback 链路可用** |
| **Chat 核心链路** | **~100%** | **图结构、LLM 接入、事件映射、持久化均已完成** |
| 认证鉴权 | ~100% | DB session + HttpOnly Cookie + invite token + maintainer 保护已实现 |
| 业务数据接口 | ~60% | Issues / PRs / Graph 只读接口已实现；Overview 仍为空壳 |
| Admin 同步 | ~80% | GHA sync payload upsert 已实现；初始数据导入脚本未开始 |
| 测试 | ~55% | auth/chat/admin sync/issues/pulls/graph 测试已补齐；Provider/Chat 节点独立测试待补 |

**当前最大阻塞点**：无。Epic 3、Epic 4.1~4.4、Epic 5.2~5.4 已完成；下一步可进入 Epic 5.1 Overview、Epic 4.5 初始数据导入脚本，或继续 iOS 登录+chat 联调。

---

## Epic 1：基础设施与工程骨架

**目标**：让后端可本地运行、可 CI 构建、可 Docker 部署。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 1.1 | FastAPI 入口与异常处理 | `GET /health` 返回 `{"status":"ok"}`；未处理异常返回结构化 JSON | 基本完成 | Phase 0 | — |
| 1.2 | 配置与环境变量 | `.env.example` 覆盖全部配置；`app/config.py` 加载无报错 | 基本完成 | Phase 0 | — |
| 1.3 | Docker Compose 编排 | `docker compose up` 同时拉起 API + PG，`/health` 200 | 基本完成 | Phase 1 | 1.1, 2.1 |
| 1.4 | CI/CD 工作流 | `.github/workflows/pytest.yml` 启用；新增 `tech-graph.yml` 执行 `./scripts/graph-compile.sh` | 部分完成 | Phase 1 | 1.1 |
| 1.5 | Makefile 与本地开发命令 | `make dev` / `make lint` / `make test` / `make migrate` 全部可用 | 基本完成 | Phase 0 | — |

**非范围**：生产环境多机部署、K8s 编排、灰度发布。

---

## Epic 2：数据库与数据模型

**目标**：v1 全部数据表可用，Alembic 管理迁移，索引合理。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 2.1 | Alembic 初始迁移 | `alembic upgrade head` 成功创建 12 张表 | 基本完成 | Phase 0 | — |
| 2.2 | ORM 模型与 DDL 对齐 | `ops_desk_ddl.sql` 与 `app/db/models.py` 字段一致；新增字段必须带 migration | 基本完成 | Phase 0 | 2.1 |
| 2.3 | 数据库连接与 session 依赖 | `get_db()` 提供 `AsyncSession`；路由可注入 | 基本完成 | Phase 0 | 2.1 |
| 2.4 | 索引与查询性能 | 所有列表查询命中已定义索引；慢查询日志可观测 | 未开始 | Phase 2 | 2.1 |

**非范围**：分库分表、读写分离、异地备份。

---

## Epic 3：认证鉴权体系

**目标**：预置用户 + 邀请密钥登录，DB session + HttpOnly Cookie。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 3.1 | `ops_users` / `ops_invite_tokens` 初始化 | 可执行脚本创建首个 maintainer 用户与邀请密钥 | 已完成 | Phase 2 | 2.1 |
| 3.2 | 登录接口 `POST /api/ops/login` | 校验 username + invite token；签发 `ops_session` HttpOnly Cookie | 已完成 | Phase 2 | 3.1 |
| 3.3 | Session 校验依赖 | `get_current_user` 校验 cookie 中 token_hash；过期拒绝 | 已完成 | Phase 2 | 3.2 |
| 3.4 | 登出与 me 接口 | `POST /api/ops/logout` 使 session 过期；`GET /api/ops/me` 返回当前用户 | 已完成 | Phase 2 | 3.2 |
| 3.5 | 角色权限中间件 | `require_maintainer` 仅允许 maintainer 访问 admin/sync | 已完成 | Phase 2 | 3.3 |

**非范围**：用户注册、OAuth、JWT、RBAC 细粒度权限。

---

## Epic 4：GitHub 数据同步（Admin）

**目标**：复用现有 GHA sync 工作流，将 issue/PR/scan/graph 数据写入本地 PG。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 4.1 | Sync payload Schema | 定义 `SyncPayload` Pydantic 模型，覆盖 repo/issues/PRs/sync_run/scan/graph | 已完成 | Phase 2 | — |
| 4.2 | Admin sync endpoint | `POST /api/ops/admin/sync` 接收 payload，按 repo upsert 全部数据 | 已完成 | Phase 2 | 3.5, 4.1 |
| 4.3 | Upsert 业务逻辑 | issue/PR 按 `(repo_id, number)` 唯一键更新；保留 `raw_payload` | 已完成 | Phase 2 | 4.2 |
| 4.4 | Sync 幂等与状态记录 | `ops_sync_runs` 记录每次 sync 状态与 summary | 已完成 | Phase 2 | 4.2 |
| 4.5 | 初始数据导入脚本 | 从 Supabase 导出 CSV/psql 导入本地 PG 的脚本 | 已完成（直连 DB 导入脚本 + 指引；真实数据导入待维护者执行） | Phase 2 | 4.3 |

**非范围**：定时任务、增量同步 diff 算法、同步失败自动重试策略。

---

## Epic 5：业务数据接口

**目标**：为前端 Overview / Issues / PRs / Graph 页面提供只读数据。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 5.1 | Overview 指标 | `GET /api/ops/overview` 返回 PR Cycle Time、Review Time、Issue Throughput、Sync 状态、Scan 摘要、Trend | 空壳 | Phase 3 | 4.3 |
| 5.2 | Issues 列表与筛选 | `GET /api/ops/issues` 支持 state/labels/scan_status/module_tag 筛选 + 分页 | 已完成 | Phase 3 | 4.3 |
| 5.3 | Pull Requests 列表与筛选 | `GET /api/ops/pulls` 支持 state/ci_status/draft 筛选 + 分页 | 已完成 | Phase 3 | 4.3 |
| 5.4 | Graph 快照 | `GET /api/ops/graph` 返回最新 graph snapshot + module matrix | 已完成 | Phase 3 | 4.3 |
| 5.5 | 模型列表 | `GET /api/ops/chat/models` 返回可用模型与 fallback 链 | 已完成（Epic 3 任务中实现） | Phase 3 | 6.1 |

**非范围**：复杂聚合报表、实时 WebSocket 推送、Graph 可视化渲染。

---

## Epic 6：LLM Provider 与 Chat 流式回答

**目标**：实现 `POST /api/ops/chat/stream`，SSE 实时返回 thinking/answer/tool_result/done/error，并持久化完整事件流。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 6.1 | SiliconFlow Provider 实现 | `complete_stream()` 通过 httpx/async OpenAI 客户端流式调用；支持模型切换；返回 `LlmChunk` | **已完成** | Phase 2 | 1.2 |
| 6.2 | 百炼 Provider 实现 | 同上；支持配额耗尽时按 `model_catalog.py` 链自动 fallback | **已完成** | Phase 2 | 1.2 |
| 6.3 | Provider 工厂与 fallback 事件 | `get_llm_provider()` 按 `OPS_LLM_PROVIDER` 返回实例；fallback 时 emit `model.fallback` | 已完成 | Phase 2 | 6.1, 6.2 |
| 6.4 | `load_context_node` 查 DB | 根据意图查询 `ops_issues` / `ops_pull_requests` / `ops_graph_snapshots` 并注入 `ChatState` | 已完成 | Phase 2 | 2.1 |
| 6.5 | `answer_node` 接入 LLM | 调用 Provider `complete_stream()`；将流式 chunk 转为 `answer` 事件；聚合完整 answer | 已完成 | Phase 2 | 6.3, 6.4 |
| 6.6 | `run_chat_stream` 事件映射 | 将 LangGraph `astream_events` 映射为 SSE：`thinking` / `tool_result` / `answer` / `model.fallback` / `done` / `error` | 已完成 | Phase 2 | 6.5 |
| 6.7 | `ops_runs` / `ops_run_events` 持久化 | `run.start` 创建 run；流结束后批量写入事件；失败不阻塞 SSE | 已完成 | Phase 2 | 2.1, 6.6 |
| 6.8 | Chat SSE 路由端到端 | `POST /api/ops/chat/stream` 本地可调用并收到完整 SSE 事件；失败路径符合 task 失败路径表 | 已完成 | Phase 2 | 6.7 |
| 6.9 | Chat 单元/集成测试 | Provider mock 测试；SSE 事件格式测试；DB 持久化测试 | 已完成 | Phase 2 | 6.8 |

**非范围**：多轮对话上下文压缩、复杂 tool calling、RAG 向量检索、文件上传/图片理解。

> **说明**：Epic 6 即 `ops-desk-api/docs/tasks/active/task_llm_provider_v1.md` 的当前执行范围。

---

## Epic 7：测试与质量门禁

**目标**：`pytest tests` 与 `ruff check app tests` 全绿，核心链路有测试覆盖。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 7.1 | 测试基础设施 | `conftest.py` 提供 async client、DB session fixture、LLM mock | 骨架 | Phase 2 | 2.1 |
| 7.2 | Provider 单元测试 | SiliconFlow / 百炼 mock HTTP 测试；fallback 链测试 | 未开始 | Phase 2 | 6.1, 6.2 |
| 7.3 | Chat 节点测试 | `intent_node`、`load_context_node`、`answer_node` 独立单元测试 | 未开始 | Phase 2 | 6.4, 6.5 |
| 7.4 | Chat SSE 集成测试 | 调用 `/api/ops/chat/stream` 验证事件序列与持久化 | 未开始 | Phase 2 | 6.8 |
| 7.5 | 业务接口测试 | Overview / Issues / PRs / Graph 接口返回预期结构 | Issues/PRs/Graph 已完成；Overview 待补 | Phase 3 | 5.1~5.4 |
| 7.6 | Lint 与类型检查 | `ruff check app tests` 通过；必要时启用 `pyright`/`mypy` | 部分完成 | Phase 1 | 1.4 |

**非范围**：100% 覆盖率、负载测试、安全渗透测试。

---

## Epic 8：部署与运维

**目标**：国内服务器可一键部署，域名 + ICP 备案后可公网访问。

| # | 任务 | 验收标准 | 当前状态 | 阶段 | 依赖 |
|---|---|---|---|---|---|
| 8.1 | 腾讯云服务器初始化 | Docker、Docker Compose、Nginx、PG 安装完成 | 未开始 | Phase 1 | — |
| 8.2 | 域名购买与 ICP 备案 | 域名实名 + ICP 提交；备案号下发 | 未开始 | Phase 1 | — |
| 8.3 | SSL 证书配置 | Nginx HTTPS 配置正确；自动续期 | 未开始 | Phase 6 | 8.2 |
| 8.4 | workspace 统一编排 | `ops-desk-workspace/docker-compose.yml` 拉起 db/api/web | 未开始 | Phase 6 | 1.3 |
| 8.5 | 部署脚本与 CI 推送 | GitHub Actions 构建产物 → 服务器；`docker compose up -d` | 未开始 | Phase 6 | 8.4 |
| 8.6 | 数据库备份策略 | 每日 `pg_dump` + 腾讯云 COS；每周服务器快照 | 未开始 | Phase 6 | 2.1 |
| 8.7 | 上线前 E2E 检查 | 登录 / Overview / Issues / PRs / Graph / Chat 全部可用 | 未开始 | Phase 6 | 全部前置 |

**非范围**：多云容灾、自动扩缩容、SLA 监控告警体系。

---

## 阶段交付地图

| 阶段 | 时间 | 可验收产出 | 涉及 Epic |
|---|---|---|---|
| Phase 0 | Week 1 | 仓库与工程骨架 | Epic 1, Epic 2 |
| Phase 1 | Week 1–2 | 可本地运行的 API + PG | Epic 1.3~1.4, Epic 7.6, Epic 8.1~8.2 |
| Phase 2 | Week 3–4 | LLM Provider + Chat SSE 端到端跑通 | Epic 3, Epic 4.1~4.3, Epic 6, Epic 7.1~7.4 |
| Phase 3 | Week 5–6 | 后端业务接口完整 | Epic 4.4~4.5, Epic 5, Epic 7.5 |
| Phase 4 | Week 7–8 | 前端 Vue3 联调 | （前端仓库） |
| Phase 5 | Week 9 | iOS 骨架 | （iOS 仓库） |
| Phase 6 | Week 9–10 | 部署上线 | Epic 8.3~8.7 |

---

## 修订记录

| 日期 | 说明 |
|---|---|
| 2026-07-16 | 初始版本，基于当前代码库扫描与 roadmap 拆分 |
| 2026-07-17 | Epic 6 标记完成；更新 LLM Provider / Chat 核心链路完成度；阻塞点清空 |
| 2026-07-17 | Epic 3 完成；Epic 4.1~4.4、Epic 5.2~5.4 标记完成；更新完成度与下一步说明 |
| 2026-07-24 | Epic 4.5 完成（Supabase 直连导入脚本 + 指引，PR #5）；Epic 5.5 勾掉（Epic 3 已实现）；PR #2~#5 全部合入 master |
