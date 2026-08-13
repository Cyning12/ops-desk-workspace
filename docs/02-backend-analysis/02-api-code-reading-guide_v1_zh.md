# 02 · ops-desk-api 从零代码阅读指南

| 项 | 内容 |
|----|------|
| **状态** | `active` |
| **日期** | 2026-07-30 |
| **Open Folder** | `ops-desk-api/`（读代码）；本文件在 `ops-desk-workspace`（跨仓文档） |
| **对照代码** | 以仓库当前 `app/` 为准；旧分析文可能描述迁移前形态 |

> **目标**：从 0 建立对 api 仓的**流程、架构、技术点、亮点**心智模型，并按阶段读完关键真值。  
> **不是**：改码开工手册（改码仍走 `AGENTS.md` + active task + harness 闸）。

---

## 0. 读前准备

### 0.1 打开哪个文件夹

| 目的 | 打开 |
|------|------|
| 跟代码、跑测试 | `Ops-desk/ops-desk-api/` |
| 读本指南与跨仓契约 | `Ops-desk/ops-desk-workspace/`（或本文件路径） |

### 0.2 先建立边界（30 秒）

ops-desk-api 是 **Ops Desk 的 FastAPI + LangGraph 后端**，负责：

- REST：登录、Overview、Issues、PRs、Graph 快照
- Chat：LangGraph 编排 + **SSE**（主）/ **WebSocket**（演示）流式事件
- LLM：SiliconFlow / 百炼 Provider 工厂
- Admin：GHA sync payload → PostgreSQL
- **不**做：前端页面、iOS UI、完整 coding-agent / sandbox

### 0.3 技术栈速记

| 层 | 选型 |
|----|------|
| HTTP | FastAPI + Pydantic v2 |
| 编排 | LangGraph `StateGraph` |
| 流式 | `StreamingResponse`（SSE）+ 共享 `ChatEventStreamer` |
| DB | PostgreSQL + SQLAlchemy 2.0 async + asyncpg + Alembic |
| 依赖 | `uv` + `pyproject.toml`（`make dev` / `make test`） |

---

## 1. 推荐阅读节奏（五阶段）

按顺序读；每阶段末有「读完应能回答」自检。总阅读量约 **3～6 小时**（含跟一次 Chat 主路径代码）。

### 阶段 A · 定位与地图（30～45 min）

| 顺序 | 读什么 | 为什么 |
|------|--------|--------|
| A1 | `ops-desk-api/AGENTS.md` | 仓边界、关键入口、开发命令、约束 |
| A2 | `ops-desk-api/README.md` | 技术栈、本地启动 |
| A3 | `ops-desk-workspace/docs/01-scope/00-project-brief.md` | 产品范围与决策（为何 SSE、为何 DB session） |
| A4 | `ops-desk-api/docs/_tech_graph/LAYER_README.md` + `l1/01_modules.md` | 模块边界真值（entry/api/auth/chat/data/admin/llm/db） |
| A5 | `ops-desk-api/docs/_tech_graph/l0/00_main.md` | 顶层流程图 |

**自检**：能画出「Client → `/api/ops/*` → DB / LLM」的粗框图；说清 8 个 `module_id`。

### 阶段 B · 入口与横切（45～60 min）

按调用链打开源码（建议边读边在 IDE 里跳转）：

| 顺序 | 文件 | 看点 |
|------|------|------|
| B1 | `app/main.py` | FastAPI 实例、CORS、挂载 `ops_router`、`/health` |
| B2 | `app/config.py` | 环境变量：DB、鉴权 Cookie、LLM、WS 开关 |
| B3 | `app/ops/router.py` | 所有业务路由注册点 |
| B4 | `app/db/session.py` + `app/db/base.py` | 异步引擎 / `AsyncSession` |
| B5 | `app/db/models.py` | 表：用户/会话、repo/issue/PR、run/events、sync/graph 快照 |
| B6 | `app/ops/deps.py` + `app/ops/security.py` + `app/ops/auth.py` | Cookie session、邀请登录、角色 |

**自检**：一次登录如何写入 `ops_sessions`；`get_current_user` 如何从 Cookie 还原用户。

### 阶段 C · Chat 主路径（核心，90～120 min）

这是本仓**最值得精读**的链路。建议按下列顺序，并对照图谱 `l1/10_flow_chat.md`。

| 顺序 | 文件 | 看点 |
|------|------|------|
| C1 | `docs/_tech_graph/l1/10_flow_chat.md` | SSE/WS → Streamer → Graph → LLM 总图 |
| C2 | `app/ops/chat/router.py` | `POST /chat/stream`：建 session/run → `ChatState` → SSE |
| C3 | `app/ops/chat/state.py` | `ChatState`；`events` 用 `Annotated[..., add]` 累加 |
| C4 | `app/ops/chat/graph.py` | 节点边：intent → (issue_qa? context) → answer |
| C5 | `app/ops/chat/nodes.py` | 意图规则、`load_issue`、流式 answer |
| C6 | `app/ops/chat/service.py` | `graph.astream(..., stream_mode="updates")` 抽事件 |
| C7 | `app/ops/chat/streaming.py` | **亮点**：批刷 DB、协作取消、`asyncio.shield` 收尾 |
| C8 | `app/ops/chat/sse.py` + `schema.py` | SSE 帧格式、请求/响应模型 |
| C9 | （可选）`app/ops/chat/ws.py` | 与 SSE 共享 Streamer；演示用、可关 |

配套设计文（概念层，注意日期）：

- `ops-desk-workspace/docs/02-backend-analysis/01-sse-chat-design.md` — 事件类型与前端契约意图
- `ops-desk-workspace/docs/contracts/chat-tool-context-v1.md` — 工具化节点契约（P0 方向）

**自检**：口述「用户发 `#42 是什么问题`」从 HTTP 到 `done` 事件的每一步；知道事件存在哪张表。

### 阶段 D · 数据面与 Sync（45～60 min）

| 顺序 | 读什么 | 看点 |
|------|--------|------|
| D1 | `l1/11_flow_sync_to_chat.md` | Sync → 只读 API → Chat 上下文 |
| D2 | `app/ops/admin/sync.py` + `service.py` + `schema.py` | Maintainer 接收 GHA payload 并 upsert |
| D3 | `app/ops/issues.py` / `pulls.py` / `overview.py` / `graph.py` | 只读查询，供 Web/iOS |
| D4 | `app/llm/factory.py` + `model_catalog.py` + `providers/*` | Provider 工厂、默认模型、fallback 语义 |

**自检**：没有 sync 数据时 Chat `load_issue` 会怎样；Overview 与 Chat 是否共用同一批表。

### 阶段 E · 规范、测试与演进（30～45 min）

| 顺序 | 读什么 | 看点 |
|------|--------|------|
| E1 | `tests/test_chat_*.py` + `test_auth.py` + `test_admin_sync.py` | 行为契约在测试里 |
| E2 | `docs/standards/CODING_BACKEND_L2_v1_zh.md`（若存在） | 编码规范 |
| E3 | `docs/coding_wiki/README.md` → `stable.md` / `context.md` | Wiki 读序入口 |
| E4 | `05-plan/00-migration-roadmap.md` + `04-agent-completion-roadmap_v1_zh.md` | 已上线主线 vs Agent 完善增量 |
| E5 | （可选）`00-current-state.md` | **历史分析**：目录/轮询架构多为迁移前；对照阶段 C 的代码纠偏 |

**自检**：能说出「文档写的旧流程」与「现在 SSE + LangGraph」差在哪里；P0 主路径 `Issue #n → T1 → T4 → T13` 对应代码里哪一段已有/未有。

---

## 2. 一句话架构

```text
GitHub (GHA sync)
    → POST /api/ops/admin/sync  →  PostgreSQL（repos/issues/PRs/snapshots）
                                        ↑
Web / iOS REST 只读 ←── overview/issues/pulls/graph
                                        ↑
用户 Chat ──POST /api/ops/chat/stream──→ ChatEventStreamer
                                              → LangGraph（intent → context? → answer）
                                              → LLM Provider（流式 token）
                                              → ops_runs + ops_run_events（边推边存）
                                              → SSE event-stream 回前端
```

模块依赖（摘自 `01_modules.md`）：

```text
entry → api, db
api   → service/auth/db
auth  → db
chat  → llm, db
data  → db
admin → db
llm   → （无仓内依赖）
db    → （被依赖方）
```

---

## 3. 目录地图（当前真值）

```text
ops-desk-api/
├── app/
│   ├── main.py                 # FastAPI 入口
│   ├── config.py               # 环境配置
│   ├── deps.py                 # （应用级 deps，若有）
│   ├── db/                     # Base / models / session
│   ├── llm/                    # factory · catalog · providers
│   └── ops/
│       ├── router.py           # /api/ops 总注册
│       ├── auth.py / deps.py / security.py
│       ├── overview.py / issues.py / pulls.py / graph.py
│       ├── admin/              # sync 入站
│       └── chat/               # ★ 核心：graph · nodes · streaming · sse · ws
├── alembic/                    # 迁移
├── tests/                      # pytest
├── docs/
│   ├── _tech_graph/            # G-L0/G-L1/G-L2 图谱真值
│   ├── coding_wiki/            # 读序入口（正文仍在原路径）
│   ├── standards/ · harness/ · tasks/
│   └── deployment/
└── AGENTS.md · README.md · CLAUDE.md
```

对比：`00-current-state.md` 里的 `api/ops/react_loop.py`、轮询 events 等是**迁移前**描述；当前仓已是上表结构。

---

## 4. 主链路详解：一次 Chat SSE

### 4.1 HTTP 入口

1. 客户端 `POST /api/ops/chat/stream`（需登录 Cookie）。
2. `chat/router.py` 解析 `ChatStreamRequest`，生成 `run_id`。
3. 解析或创建 `ops_session_chats`，写入 `ops_runs`（status=`running`）。
4. 构造 `ChatState`，创建 `ChatEventStreamer`。
5. `StreamingResponse`：`media_type=text/event-stream`，禁用缓冲头。

### 4.2 LangGraph

`graph.py` 编译的图：

```text
START
  → detect_intent          # nodes.intent_node：#n → issue_qa；「总览」→ overview；否则 general
  → (条件边)
       issue_qa  → load_context → generate_answer → END
       overview/general → generate_answer → END
```

要点：

- **不是** LLM `bind_tools`；上下文加载是 **显式 Graph 节点**（契约文称 M1 / T1）。
- `intent` 当前为**规则**（正则 / 关键词），非再调一次 LLM 做路由。
- `load_issue_context_node` 查 `ops_issues`，产出 `tool_result` 事件（对齐工具语义）。
- `answer_node` 调 `provider.complete_stream`，把 token 打成 `answer` 事件；fallback 打成 `model.fallback`。

### 4.3 事件管线

```text
nodes 返回 { events: [...] }
  → service.run_chat_stream 展开
  → ChatEventStreamer.events() 赋 seq / ts_ms，yield
  → make_sse_event → 客户端
  → 每 10 条 flush → ops_run_events
  → finally：更新 ops_runs（completed / error / cancelled）+ 拼最终 answer
```

### 4.4 取消与断开（实现亮点）

`streaming.py` 中：

- `request_cancel()` + `asyncio.wait(FIRST_COMPLETED)`：取消可打断**进行中的** graph 步（含 LLM 生成），而非只在节点边界生效。
- 客户端断开触发 `CancelledError` 时，用 `asyncio.shield` 保证收尾落库，避免「流断了、run 永远 running」。

### 4.5 关键事件类型（与前端对齐）

| event_type | 典型来源 | 含义 |
|------------|----------|------|
| `run.start` | Streamer | 开始 |
| `thinking` | intent / answer 节点 | 思考过程 |
| `tool_result` | load_context | 工具结果（如 load_issue） |
| `answer` | answer 节点 | 答案增量 |
| `model.fallback` | LLM meta | 换模 |
| `error` | 节点 / Streamer | 错误 |
| `done` / `run.cancelled` | Streamer | 正常结束 / 取消 |

更完整的 schema 意图见 `01-sse-chat-design.md`；以运行中代码与前端消费为准。

---

## 5. 其他业务面（简读）

### 5.1 鉴权

- 模式：`OPS_DESK_AUTH_MODE=db`（v1 真值）。
- 登录：`username` + `invite_token` → 消耗/绑定邀请 → 发 HttpOnly `ops_session` Cookie。
- 角色：`viewer` / `maintainer`（sync 等写操作要 maintainer）。
- **不开放注册**；用户预置。

### 5.2 只读数据 API

- Overview 指标、Issues/PRs 列表筛选、Graph 快照：全部读 sync 进库的表。
- Chat 与列表共享同一数据真相；Chat 不另走向量 RAG（v1；P1 才谈 Ops 仓内 RAG）。

### 5.3 Admin Sync

- `POST /api/ops/admin/sync`：GHA（或运维）推 payload，后端 upsert。
- 推荐「GHA → API → PG」，避免把 PG 连接串暴露给 Actions。

### 5.4 LLM

- `get_llm_provider()` 按 `OPS_LLM_PROVIDER` 选 SiliconFlow / Bailian。
- 默认模型来自 `model_catalog`；配置空字符串会回落默认（见 `config` validator）。
- Bailian 侧有配额耗尽 fallback 链；事件通过 `model.fallback` 露出。

---

## 6. 技术点与亮点清单

读代码时建议刻意标这些「为什么这样设计」：

| # | 亮点 | 落点 | 价值 |
|---|------|------|------|
| 1 | **LangGraph 显式节点** 而非自研 ReAct 轮询 | `chat/graph.py` · `nodes.py` | 意图/上下文/回答可测、可观测、可演进到工具矩阵 |
| 2 | **SSE 主传输 + 事件归档** | `router` · `streaming` · `ops_run_events` | 实时 UX + 历史可回放（前端可折叠思考） |
| 3 | **传输无关的 Streamer** | `streaming.py` 被 SSE/WS 共用 | 演示 WS 不复制业务逻辑 |
| 4 | **协作取消 + shield 落库** | `ChatEventStreamer` | 生产向的取消与一致性 |
| 5 | **批量 flush 事件** | `_FLUSH_BATCH_SIZE=10` | 控内存与写放大 |
| 6 | **DB session 鉴权** | `auth` · `deps` | 国内自建部署友好，告别 HMAC 前端签发 |
| 7 | **Sync 与 Chat 解耦** | admin → tables → nodes | 数据入站与对话编排分模块 |
| 8 | **Provider 工厂 + catalog** | `app/llm/*` | 换模/换商不改 Chat 节点 |
| 9 | **技术图谱双轨** | `docs/_tech_graph/*.graph.yaml` + `.md` | Agent/人共享模块与流程真值 |
| 10 | **Harness 嵌入** | `AGENTS.md` · `docs/harness/` | 改码有闸、有 task，降低 AI 乱改 |

正在演进的产品亮点（规划，未必已全在代码里）：

- 契约：`docs/contracts/chat-tool-context-v1.md`（T1 load_issue 等）
- 路线：`05-plan/04-agent-completion-roadmap_v1_zh.md`（主路径 Issue #n → T1 → T4 → T13）

---

## 7. 文档纠偏（避免被旧文带偏）

| 文档 | 仍有用 | 需纠偏 |
|------|--------|--------|
| `00-current-state.md` | 表清单、鉴权决策、sync 思路 | 目录名 `api/ops/`、react_loop、事件**轮询** — 已过时 |
| `01-sse-chat-design.md` | 事件类型、设计目标 | 实现细节以 `app/ops/chat/*` 为准 |
| `AGENTS.md` 关键入口表 | 准确 | — |
| `_tech_graph` | **当前架构真值优先** | 锚点行号可能漂移，以符号/文件为准 |

口诀：**图谱 + 源码 > 迁移期分析文 > 路线图（未来）**。

---

## 8. 动手验证清单（加深理解）

在 `ops-desk-api` 根目录：

```bash
# 依赖与健康
uv sync --extra dev
make test          # 或：uv run pytest tests -q
make lint

# 本地起服务（需 PG + .env）
make dev
# 另开终端：curl -s http://127.0.0.1:8000/health
```

建议手动跟一次（有环境时）：

1. 登录拿 Cookie  
2. `POST /api/ops/chat/stream`，body 含 `"message": "#<存在的 issue 号> 摘要一下"`  
3. 观察 SSE：`run.start` → `thinking` → `tool_result` → `answer*` → `done`  
4. DB 查 `ops_runs` / `ops_run_events` 是否与 seq 一致  

无 LLM Key 时：优先读 `tests/test_chat_nodes.py`、`test_chat_service.py`、`test_chat_router.py` 理解契约。

---

## 9. 读完之后怎么继续

| 你的目标 | 下一步 |
|----------|--------|
| 改 Chat / 工具节点 | 先读 `chat-tool-context-v1.md` + `04-agent-completion-roadmap`；再开 task，勿直接改 `main` |
| 改鉴权 / 表结构 | `models.py` + Alembic + `01_modules` 是否要改图谱 |
| 对接前端事件 | `01-sse-chat-design.md` + web 仓 Chat 消费代码 |
| 对接 iOS | `GET /chat/sessions/latest`（router 注释写明为 iOS v1） |
| 运维部署 | `docs/deployment/` + workspace `04-infrastructure/` |

---

## 附录 A · 首周文件优先级（按行数粗估）

| 优先级 | 路径 | 约行数 | 角色 |
|--------|------|--------|------|
| P0 | `app/ops/chat/streaming.py` | ~320 | 流式与持久化核心 |
| P0 | `app/db/models.py` | ~270 | 数据模型 |
| P0 | `app/ops/chat/nodes.py` | ~150 | Agent 节点逻辑 |
| P0 | `app/ops/chat/router.py` | ~130 | HTTP 入口 |
| P0 | `app/ops/auth.py` | ~140 | 登录 |
| P1 | `app/ops/chat/ws.py` | ~200 | WS 演示 |
| P1 | `app/ops/admin/service.py` | （sync 业务） | 数据入站 |
| P1 | `app/llm/providers/*.py` | — | 流式与 fallback |
| P2 | overview/issues/pulls/graph | — | 只读 CRUD 风格查询 |

---

## 附录 B · 30 分钟「最小闭环」读法（赶时间）

若只有半小时，只读：

1. `AGENTS.md` 关键入口表  
2. `docs/_tech_graph/l0/00_main.md` + `l1/10_flow_chat.md`  
3. `app/ops/chat/graph.py` → `nodes.py` → `service.py` → `streaming.py`（只看 `ChatEventStreamer.events`）  
4. `app/db/models.py` 里 `OpsRun` / `OpsRunEvent` / `OpsIssue`  

然后回来按阶段 A～E 补全。

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-07-30 | 首版：对照当前 `app/` 与 G-L 图谱整理从零阅读路径 |
