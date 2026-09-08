# 后端现状分析：ai-ink-brain-api-python/api/ops/

> 分析日期：2026-07-15（§1 起）  
> 范围（历史）：Ops Desk 后端，不含 unified_chat / text2sql / RAG ingest 等通用模块  
> **现网真值**：见下方 **§0 · 2026-09 现状快照**；实现仓为 `ops-desk-api` / `ops-desk-web`

---

## 0. 2026-09 现状快照（真值优先）

> **读法**：本节能覆盖「现在线上/仓内是什么」；**§1 起全文是 2026-07 迁移前分析**，其中目录名、轮询 events、`rag_*`「v1 不迁移」、旧 Chat 入口等 **勿当现网真值**。  
> **未实测水位**：生产向量库条数 / 对账水位标为 **待人工**；§10.7 task 结案标为 **待 CLOSE**。

| 维度 | 现网 / 仓内真值（2026-09） |
|------|---------------------------|
| **Chat 主路径** | `POST /api/ops/lg-rag/stream`（freeze `lg-rag-sse-v1`，默认 `mode=supervisor`）；另有 `/invoke`、`/replay`。旧 `POST /api/ops/chat/stream` → **410 Gone**（T6） |
| **SSE 能力** | `updates`；顶层 `cursor` + `POST /api/ops/lg-rag/replay`；终答 `answer` delta（T5.1）；idle keepalive（§10.6）；`subtask.progress` `running`\|`done`（§10.7：api [#125](https://github.com/Cyning12/ops-desk-api/pull/125) 已合入，**task 待 CLOSE**） |
| **RAG** | 表 `ops_knowledge_chunks`；默认 `RAG_VECTOR_BACKEND=qdrant`（失败可降级 `pgvector`）；影子写 / DLQ；ingest 管线已有；compose Qdrant **v1.19**。生产向量水位：**待人工** |
| **编排** | `lg_rag` supervisor + SO Gateway + Capability Gateway |
| **Auth / 数据面** | DB session 鉴权；Issues / PRs / Overview / Graph 已落地；Admin sync 接收端 + **GHA sender 已迁**（api [#88](https://github.com/Cyning12/ops-desk-api/pull/88)）——旧「断链 / 无发送方」叙述过时 |
| **LLM** | SiliconFlow 默认首项 **DeepSeek-V4-Flash**；百炼 fallback 链保留 |
| **Alembic head** | `20260831_lg_rag_run_events` |
| **部署** | GHA `deploy-api` 已合入 `master`（push 触发） |
| **Active** | `task_lg_rag_sse_subtask_live` **待 CLOSE**（代码已合入 ≠ task 结案） |

交叉索引：线 A / RAG 计划纠偏见 [`../05-plan/04-agent-completion-roadmap_v1_zh.md`](../05-plan/04-agent-completion-roadmap_v1_zh.md)；传输 Spec 见 api 仓 `docs/spec/agent-infra/05_lg_rag_transport_and_session_plan_v0.md`。

---

## 1. 目录结构

> **历史（2026-07）**：下列树与路径指迁移源仓 `ai-ink-brain-api-python`，**不是**现网 `ops-desk-api` 目录真值。

```
api/ops/
├── auth/           # DB session 鉴权（login/logout/session）
├── chat/           # Chat 入口路由
├── chat_context.py # Chat 上下文构建（issue/PR/Graph 注入）
├── chat_service.py # Chat 业务编排
├── deps.py         # FastAPI Dependencies（鉴权、DB）
├── events_schema.py# ops_run_events 事件类型定义
├── graph/          # Graph 模块矩阵
├── intent_router.py# 意图路由
├── lists.py        # Issues / PRs 列表查询
├── metrics.py      # 总览指标
├── react_loop.py   # ReAct 循环（现有自研编排）
├── react_tools.py  # ReAct 工具
├── router.py       # FastAPI APIRouter 注册
├── runs.py         # Run / Event 读写
├── sessions.py     # Session 管理
├── tracing.py      # 追踪
└── llm/            # LLM Provider 工厂 + 模型目录
```

---

## 2. 数据模型（Supabase 当前）

| 表 | 用途 | 迁移优先级 |
|---|---|---|
| `ops_repos` | 仓库元数据（MoonshotAI/kimi-code） | 高 |
| `ops_issues` | Issue 数据 | 高 |
| `ops_pull_requests` | PR 数据 | 高 |
| `ops_sync_runs` | GitHub 同步历史 | 高 |
| `ops_scan_snapshots` | Scan 摘要 | 高 |
| `ops_graph_snapshots` | Graph 节点/边/模块 | 高 |
| `ops_sessions` | Chat Session | 高 |
| `ops_runs` | 单次 Chat Run | 高 |
| `ops_run_events` | Run 事件流 | 高 |
| `ops_users` / `ops_invite_tokens` | 登录鉴权 | 高 |
| `rag_*` / `documents` / 向量表 | RAG 相关 | **v1 不迁移**（Chat 只读 issue 内容，不走 RAG） |

> v1 的 Chat 不依赖向量检索，直接把 issue 的 title/body 作为文本上下文注入 LLM。

> **〔2026-09 引用注〕** 上表「RAG v1 不迁移」为 **迁移前决策**，现已过时。现网有 `ops_knowledge_chunks`、默认 Qdrant、ingest；Chat 主路径走 lg-rag SSE。见 **§0**。

---

## 3. 模型调用与切换逻辑

### 3.1 Provider 工厂

文件：`api/ops/llm/factory.py`

```python
_PROVIDERS = {
    "siliconflow": SiliconFlowProvider,
    "bailian": BailianProvider,
}
```

由环境变量 `OPS_LLM_PROVIDER` 控制，默认 `siliconflow`。

### 3.2 模型目录

文件：`api/ops/llm/model_catalog.py`

| Provider | 默认模型 | 自动 fallback |
|---|---|---|
| SiliconFlow | `deepseek-ai/DeepSeek-V4-Pro` | ❌ 不自动换模 |
| Bailian | `deepseek-v4-pro` | ✅ 配额耗尽时按链降级 |

> **〔2026-09 引用注〕** SiliconFlow 现网默认首项为 **DeepSeek-V4-Flash**（见 §0）；上表为迁移前目录快照，勿当现默认。

**Bailian fallback 链**（按顺序）：
1. `kimi/kimi-k2.7-code`（test_only）
2. `ZHIPU/GLM-5.2`（test_only）
3. `deepseek-v4-pro`
4. `deepseek-v4-flash`
5. `qwen3.7-plus`

test_only 模型无真实额度，fallback 时跳过其余 test_only，直达生产模型。

### 3.3 环境变量

```bash
OPS_LLM_PROVIDER=siliconflow          # 或 bailian
SILICONFLOW_API_KEY=...
OPS_LLM_MODEL=Qwen/Qwen2.5-72B-Instruct  # siliconflow 可选
BAILIAN_API_KEY=...
BAILIAN_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
BAILIAN_MODEL=qwen-plus
```

### 3.4 迁移建议

- 保留 `api/ops/llm/factory.py` 和 `api/ops/llm/model_catalog.py` 的接口契约。
- 将 `complete()` 接口封装为 LangGraph 可调用的 LLM 节点。
- 在 LangGraph 中通过 `on_quota_model_switch` 回调写入 `llm.model.fallback` 事件，保持前端兼容。

---

## 4. Chat 架构现状

### 4.1 请求入口

- `POST /api/ops/chat/messages` — 发起对话
- `GET  /api/ops/runs/{id}` — 查询 run 状态
- `GET  /api/ops/runs/{id}/events?after_seq=...` — 增量事件轮询

> **〔2026-09 引用注〕** 产品主路径已是 `POST /api/ops/lg-rag/stream`；旧 `POST /api/ops/chat/stream` → **410**。轮询 events **勿当现网真值**。见 §0。

### 4.2 当前流程

```
用户提问
  → intent_router 路由（fast / deep / react / clarify / session_00）
  → chat_context 注入 repo/issue/PR/graph 上下文
  → react_loop 或 chat_service 生成回答
  → 写入 ops_runs + ops_run_events
  → 前端轮询 events
```

### 4.3 事件类型（前端已依赖）

关键事件：
- `run.start` / `run.end`
- `router.decision`
- `agent.tool.result`（含 issue_number / citations）
- `final.answer`
- `llm.model.fallback`
- `llm.usage`
- `clarify.asked`
- `agent.react_step` / `agent.tool_call`

### 4.4 迁移方向

v1 直接采用 **LangGraph + SSE 流式**，不再保留现有轮询架构：

```
用户提问
  → FastAPI 路由
  → LangGraph StateGraph（intent → context → llm → answer）
  → 节点内 emit SSE 事件
  → StreamingResponse 实时推送
```

- `POST /api/ops/chat/messages` 与 `/api/ops/runs/{id}/events` 不再使用。
- 新增 `POST /api/ops/chat/stream`，返回 SSE 流。
- 事件 schema 尽量兼容现有 `ops_run_events`，便于未来扩展。
- **保存完整对话 + 思考过程**：SSE 事件流归档到 `ops_run_events`，历史思考过程 UI 默认折叠。

详细设计见 `01-sse-chat-design.md`。

---

## 5. 鉴权现状与迁移决策

两种模式由 `OPS_DESK_AUTH_MODE` 控制：

| 模式 | 说明 | 迁移决策 |
|---|---|---|
| `hmac`（默认） | 前端用 HMAC 签发 `ops_desk_token` Cookie | v1 **不使用** |
| `db` | 后端 DB Session，`ops_session` Cookie | v1 **使用**，需新增 `ops_users` + `ops_sessions` 表 |

**v1 采用 `db` 模式**：
- 需要 `ops_users` 表（预置用户，不开放注册）。
- 需要 `ops_invite_tokens` 表（邀请密钥）。
- 需要 `ops_sessions` 表（session_id、user_id、role、expires_at）。
- 登录后后端签发 `ops_session` HttpOnly Cookie。
- 角色分 `viewer` / `maintainer`。

---

## 6. 需要重写/新增的后端模块

| 模块 | 动作 | 说明 |
|---|---|---|
| `api/ops/chat_service.py` | 重写 | 用 LangGraph StateGraph 替换自研 react_loop |
| `api/ops/intent_router.py` | 重写 | 作为 LangGraph 第一个节点 |
| `api/ops/react_loop.py` | 废弃 | 功能合并进 LangGraph |
| `api/ops/chat_context.py` | 保留改造 | issue/PR/Graph 上下文注入逻辑 |
| `api/ops/llm/` | 保留 | Provider 工厂、模型目录直接复用 |
| `api/ops/events_schema.py` | 保留 | 事件契约保持 |
| `api/ops/runs.py` | 保留改造 | PG 替换 Supabase |
| `api/ops/sessions.py` | 保留改造 | PG 替换 Supabase |
| `api/ops/auth/` | 新增/改造 | v1 用 DB session，需 `ops_users` + `ops_sessions` |
| `api/ops/admin/sync.py` | 新增 | 接收 GHA sync payload 写入 PG |
| `api/ops/lists.py` | 保留改造 | SQLAlchemy 替换 Supabase |
| `api/ops/metrics.py` | 保留改造 | SQLAlchemy 替换 Supabase |
| `api/ops/graph/` | 保留改造 | PG 替换 Supabase |

---

## 7. 数据库迁移要点

1. **pgvector 扩展**：Graph 相关数据不需要向量，但保留扩展无额外成本。
2. **JSON 字段**：`ops_graph_snapshots.payload`、`ops_scan_snapshots.parsed_summary` 用 JSONB。
3. **新增表**：
   - `ops_users` — 预置用户（不开放注册）
   - `ops_invite_tokens` — 邀请密钥
   - `ops_sessions` — DB session
4. **索引**：
   - `ops_issues(repo_id, state, updated_at)`
   - `ops_pull_requests(repo_id, state, updated_at)`
   - `ops_run_events(run_id, seq)`
   - `ops_runs(session_id, created_at)`
5. **迁移脚本**：用 Alembic 管理；初始数据从 Supabase 导出 CSV/psql 导入。

## 8. 数据同步（GitHub → 本地 PG）

**决策**：复用现有 **kimi-code fork + kimi-code-meta** 的 GHA sync 工作流。

当前工作流：
- `kimi-code` fork 触发 GitHub Actions sync。
- `kimi-code-meta` 存储 sync 元数据与部分中间产物。
- 数据最终写入 Supabase。

迁移调整：
- sync target 从 Supabase 改为 `ops-desk-api` 的 PostgreSQL。
- 需要新增 `POST /api/ops/admin/sync` 接收 sync payload。
- 或保留 GHA 直接写 PG（需暴露 PG 连接串给 GHA secrets，不推荐）。
- **推荐**：GHA 调用 `ops-desk-api` 的 admin sync endpoint，由后端写入 PG。

涉及的表：
- `ops_repos`
- `ops_issues`
- `ops_pull_requests`
- `ops_sync_runs`
- `ops_scan_snapshots`
- `ops_graph_snapshots`

### 8.1 现状修正（2026-08-08 实测 · 数据链断尾）

> **〔2026-09 引用注〕** 本节描述的「无发送方 / 断尾」已由 **GHA sender 迁移（api #88 · done）** 根治；勿再把本节当现网同步链路真值。生产 sync 水位仍可能需运维核对，标 **待人工**。见 §0。

上节「迁移调整」只落地了**接收端**。截至 **2026-08-08** 真实数据链：

| 环节 | 现状 |
|------|------|
| 日更 GHA `ops-sync-kimi-code` | 仍在**旧仓** `Cyning12/ai-ink-brain-api-python` 运行（cron 每日 UTC 02:00 + 手动触发）；`api/ops/sync/store.py` 用 service role key **直写 Supabase**，不经过新 API |
| 新仓 `ops-desk-api` | 只有接收端 `POST /api/ops/admin/sync`（2026-07-17 实现并测试）；**无任何发送方**（仓内无 sync workflow / 推送脚本） |
| 新 PG（本地 / 生产） | 数据来自一次性快照 `scripts/import_from_supabase.py`（Supabase → 新 PG，幂等可重跑）；水位定格在导入时刻 |

**后果**：新库不会自动变新。实例：2026-08-08 本地 `ops_issues` 最大 number = 2041，Supabase 已同步到 2738；#2720 缺口直接阻塞 RAG 金样 G01（见 `docs/contracts/rag-knowledge-contract-v1.md` 验收栏）。

**刷新口径（路 1 · 现行）**：重跑 `import_from_supabase.py`（步骤见 `ops-desk-api/docs/ops/supabase-import-guide.md`），本地与生产同法。

**根治（路 2 · 技术债）**：sender 迁移——GHA 改 POST `/api/ops/admin/sync` 而非直写 Supabase，脱离旧仓 / Supabase 依赖。task 卡（当时）：`ops-desk-api/docs/tasks/active/task_ops_sync_sender_migration.md`。

> **〔2026-09〕路 2 已完成**：task 已归档 `ops-desk-api/docs/tasks/done/task_ops_sync_sender_migration.md`（PR #88）。
