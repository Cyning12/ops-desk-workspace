# 迁移路线图：Ops Desk Kimi Code v1

> 更新日期：2026-09  
> 总周期估算（历史）：8–10 周（1 人，含 ICP 备案等待时间）

---

## 进度水位（2026-09）

| 项 | 状态 |
|---|---|
| **迁移主线** | **已上线**（公网见 hygiene / 上线记录；细节以维护者确认） |
| **Chat** | **已切 lg-rag**：主路径 `POST /api/ops/lg-rag/stream`（+ replay）；旧 `POST /api/ops/chat/stream` → **410**（历史计划勿再当现网） |
| **前端栈** | **现网已是 Vue3**（Vite + Pinia + Element Plus + 水墨 CSS）；下文「Vue3 重写 / `@microsoft/fetch-event-source`」均为**历史计划** |
| **后续完善** | 见 [`04-agent-completion-roadmap_v1_zh.md`](./04-agent-completion-roadmap_v1_zh.md)；上线后卫生见 [`03-post-go-live-hygiene-orchestration.md`](./03-post-go-live-hygiene-orchestration.md) |
| **待确认** | §10.7 联调勾选 / CLOSE；图谱 web **P3**；生产 nginx 是否已改（见前端 §0 快照） |

> **纠偏通则**：文中仍写「计划 Vue3 重写」「fetch-event-source」「以 `POST /chat/stream` 为主」处，均按上表理解；**勿当现网真值**。

---

## 阶段划分

> 下表为**历史排期**；2026-09 迁移主线已上线，后续见进度水位与 `04-agent-completion-roadmap`。

```
Week 1–2: 基础设施准备（与开发并行）     → 已完成
Week 3–4: 后端 LangGraph 骨架 + 数据库落地 → 已完成
Week 5–6: 后端业务接口（Overview/Issues/PRs/Graph/Chat）→ 已完成（Chat 后演进为 lg-rag）
Week 7–8: 前端 Vue3 重写 + 联调           → 已上线（现网 Vue3；非「待重写」）
Week 9:   iOS 骨架 + 部署脚本            → 部署已上线；iOS 以维护者确认 / hygiene
Week 10:  ICP 收尾 + 域名切换 + 公测     → 已上线相关完成（细节以维护者确认）
```

> **Epic 级任务清单**已拆分到 [`01-epic-task-backlog.md`](./01-epic-task-backlog.md)，包含每个 Epic 下的具体任务、验收标准、当前状态与依赖。本 Roadmap 各 Phase 末尾会引用对应 Epic 编号。

---

## Phase 0：项目初始化（Week 1）· **已完成**

| 任务 | 输出 | 负责人 | 2026-09 |
|---|---|---|---|
| 创建迁移文档目录 | `docs/` | AI | ✅ 完成 |
| 冻结 v1 功能范围 | `01-scope/00-project-brief.md` | 人 | ✅ 完成 |
| 确定技术选型 | Vue3 + FastAPI + LangGraph + PG | 人 | ✅ 完成（现网已落地） |
| 创建新的 GitHub 私有仓库 | `ops-desk-workspace`、`ops-desk-web`、`ops-desk-api`、`ops-desk-ios` | 人 | ✅ 完成 |

### 关于仓库选择

**推荐方案：全新 4 仓库**

| 仓库 | 用途 | 技术栈 |
|---|---|---|
| `ops-desk-workspace` | AI 总调度、文档、任务单、架构图谱 | Markdown + Harness |
| `ops-desk-web` | 前端 | Vue3 + TypeScript + Element Plus |
| `ops-desk-api` | 后端 | FastAPI + LangGraph |
| `ops-desk-ios` | 移动端 | Swift + SwiftUI |

- 优点：干净，无历史包袱，四端职责清晰。
- 缺点：需要配置 4 套 CI/CD。

v1 建议 **全新 4 仓库**，避免 Next.js 和 Vue3 混在一个仓库。

---

## Phase 1：基础设施（Week 1–2，与开发并行）· **已上线相关完成**

| 任务 | 输出 | 时间 | 2026-09 |
|---|---|---|---|
| 购买腾讯云 Lighthouse | 服务器 IP、root 权限 | 1 天 | ✅ 完成（以维护者确认） |
| 购买域名 + 实名认证 | 域名所有权 | 1–3 天 | ✅ 完成（以维护者确认 / hygiene） |
| 提交 ICP 备案 | 备案号 | 10–20 工作日 | ✅ 已通过（细节见 hygiene / 维护者确认；本文不重核备案号） |
| 服务器初始化 | Docker、Docker Compose、Nginx、PG | 2 天 | ✅ 完成 |
| 配置 DNS 解析（备案前可用 IP+端口测试） | A 记录 | 备案后 | ✅ 已上线（以维护者确认） |
| 申请 SSL 证书 | 证书文件 | 备案后 | ✅ 已部署（续期细节见 hygiene） |

**关键路径（历史）**：ICP 备案。备案期间可用服务器 IP + 非 80/443 端口开发测试。

---

## Phase 2：后端骨架（Week 3–4）· **已完成**

> **纠偏（2026-09）**：下表验收「`POST /api/ops/chat/stream` 返回 SSE」为**历史里程碑**；现网 Chat 主路径已是 **lg-rag SSE**，旧 stream **410**。

### 2.1 新建后端仓库结构

```
ops-desk-api/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI 入口
│   ├── config.py               # 环境变量、模型配置
│   ├── deps.py                 # 鉴权依赖
│   ├── db/
│   │   ├── base.py             # SQLAlchemy Base
│   │   ├── session.py          # 异步 session
│   │   └── models.py           # ORM 模型
│   ├── ops/
│   │   ├── router.py
│   │   ├── auth.py             # 登录鉴权
│   │   ├── overview.py         # 总览指标
│   │   ├── issues.py           # Issues 接口
│   │   ├── pulls.py            # PR 接口
│   │   ├── graph.py            # Graph 接口
│   │   └── chat/
│   │       ├── router.py
│   │       ├── graph.py        # LangGraph StateGraph
│   │       ├── nodes.py        # intent / context / llm / answer
│   │       ├── state.py        # ChatState
│   │       ├── sse.py          # SSE 流式适配
│   │       └── service.py      # 接口适配
│   └── llm/
│       ├── factory.py          # 复用现有 Provider 工厂
│       ├── model_catalog.py    # 复用模型目录
│       └── providers/          # siliconflow / bailian
├── alembic/
├── docker/
├── docker-compose.yml
├── Dockerfile
├── pyproject.toml
└── tests/
```

### 2.2 新建 workspace 仓库结构

```
ops-desk-workspace/
├── AGENTS.md                   # AI 总调度入口
├── CLAUDE.md                   # 指针到 AGENTS.md
├── docs/
│   ├── README.md               # 项目总览
│   ├── architecture/           # 架构图谱
│   ├── tasks/
│   │   ├── active/             # 进行中的任务
│   │   └── done/               # 已完成的任务
│   └── specs/                  # SDD / SPEC
└── .cursor/
    └── rules/                  # Cursor 规则
```

### 2.3 关键任务

| 任务 | 验收标准 | 2026-09 |
|---|---|---|
| Docker Compose 跑通 FastAPI + PostgreSQL | `docker compose up` 后 `http://localhost:8000/health` 200 | ✅ 完成 |
| Alembic 初始化 + v1 表迁移 | 所有 ops_* 表创建成功 | ✅ 完成 |
| 从 Supabase 导出初始数据并导入本地 PG | Issues/PRs/Graph/Scan 数据可用 | ✅ 完成（以维护者确认） |
| LangGraph 最小 graph 跑通 | `POST /api/ops/chat/stream` 返回 SSE 流（**历史**；现网主路径为 lg-rag） | ✅ 历史里程碑已过 |
| LLM Provider 工厂接入 LangGraph | SiliconFlow / Bailian 可切换 | ✅ 完成 |

**本阶段对应 Epic**：Epic 1、Epic 2、Epic 6（任务 6.1–6.9）、Epic 7（任务 7.1–7.4）。详细清单见 [`01-epic-task-backlog.md`](./01-epic-task-backlog.md)。

---

## Phase 3：后端业务接口（Week 5–6）· **已完成**

| 模块 | 接口 | 说明 |
|---|---|---|
| Auth | `POST /api/ops/login` | HMAC 或 DB session |
| Overview | `GET /api/ops/overview` | 指标 + sync + scan + trend |
| Issues | `GET /api/ops/issues` | 列表 + 筛选 + 分页 |
| Pulls | `GET /api/ops/pulls` | 列表 + 筛选 + 分页 |
| Graph | `GET /api/ops/graph` | snapshot + module matrix |
| Chat（历史） | `POST /api/ops/chat/stream` | **历史计划**：SSE 流式对话；**现网 410**，主路径见下一行 |
| Chat（现网） | `POST /api/ops/lg-rag/stream`（+ replay） | **2026-09 真值**：lg-rag SSE |
| Chat | `GET /api/ops/chat/models` | 模型列表 |

**本阶段对应 Epic**：Epic 3、Epic 4（任务 4.4–4.5）、Epic 5、Epic 7（任务 7.5）。详细清单见 [`01-epic-task-backlog.md`](./01-epic-task-backlog.md)。

**Chat v1 的 LangGraph + SSE 设计**：

```python
class ChatState(TypedDict):
    query: str
    session_id: str | None
    run_id: str
    issue_context: list[dict]   # 从 issues 表注入的上下文
    pr_context: list[dict]      # 可选
    graph_context: dict | None  # 可选
    intent: str                 # "issue_qa" | "general" | "overview"
    answer: str
    events: list[dict]          # SSE 事件队列

builder = StateGraph(ChatState)
builder.add_node("intent", intent_node)
builder.add_node("load_issue_context", load_issue_context_node)
builder.add_node("answer", answer_node)
builder.set_entry_point("intent")
builder.add_conditional_edges("intent", route_by_intent)
builder.add_edge("load_issue_context", "answer")
builder.set_finish_point("answer")
```

FastAPI 路由通过 `graph.astream_events(...)` 获取事件，实时 emit SSE。详见 `02-backend-analysis/01-sse-chat-design.md`。

---

## Phase 4：前端 Vue3 重写（Week 7–8）· **已上线**

> **纠偏（2026-09）**：本节原为「计划重写」；**现网已是 Vue3 应用**（水墨 CSS，**不引** Tailwind；Chat 用 `useLgRagSse`，**无** `@microsoft/fetch-event-source`）。下方命令/依赖列表保留为历史草案。

### 4.1 项目初始化（历史草案）

```bash
npm create vue@latest ops-desk-web
# 选择：TypeScript、Pinia、Vue Router、ESLint、Prettier
npm install element-plus axios markdown-it highlight.js tailwindcss
```

### 4.2 开发顺序（历史；页面已扩展）

| 优先级 | 页面/模块 | 说明 |
|---|---|---|
| 1 | 登录页 | 最快闭环 |
| 2 | 布局 + 侧边导航 | 复刻 `/ops/kimi-code` 导航 |
| 3 | 总览 | 数据量小，易验证 |
| 4 | Issues / PRs | 表格 + 筛选 |
| 5 | Graph | 矩阵展示 |
| 6 | Chat | 历史写「保留轮询」；**现网**为 lg-rag SSE（另有 Obs / LC Evidence / LG RAG 等页） |

### 4.3 Chat 组件重点

- ~~使用 `@microsoft/fetch-event-source` 消费 SSE。~~ → **历史计划**；现网 **无**该依赖，主路径 `useLgRagSse` → `/api/ops/lg-rag/stream`。
- 用 Pinia 管理会话 / 流式状态（字段名以现网 chat store 为准；勿再默认旧 thinking/answer 模型）。
- `/api/ops/chat/models` 仍可作模型列表；**对话主链路已离开** `/api/ops/chat/stream`（410）。
- 答案用 `markdown-it` + `highlight.js` 渲染（以现网实现为准）。

---

## Phase 5：iOS 骨架（Week 9）

> **2026-09**：iOS 进度细节**未在本轮核实** → 以维护者确认 / 见 hygiene 与 `ops-desk-ios` 文档为准。下文为历史 v1 范围。

v1 只做：
- 登录页
- 会话列表
- 单轮 Chat（历史写复用 `POST /api/ops/chat/stream` SSE；**现网协议以维护者确认**——web/api 主路径已是 lg-rag）
- SSE 流式事件解析与展示

技术栈：
- SwiftUI
- Swift Concurrency
- URLSession
- 本地缓存：SwiftData

---

## Phase 6：部署与上线（Week 9–10）· **已上线**

### 6.1 部署脚本（workspace 统一编排）

`ops-desk-workspace/docker-compose.yml` 为总编排入口：

```yaml
# ops-desk-workspace/docker-compose.yml
version: "3.8"
services:
  db:
    image: pgvector/pgvector:pg15
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ops
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: opsdesk

  api:
    build: ../ops-desk-api
    environment:
      DATABASE_URL: postgresql+asyncpg://ops:${DB_PASSWORD}@db:5432/opsdesk
      OPS_LLM_PROVIDER: ${OPS_LLM_PROVIDER:-siliconflow}
      SILICONFLOW_API_KEY: ${SILICONFLOW_API_KEY}
      BAILIAN_API_KEY: ${BAILIAN_API_KEY}
      OPS_DESK_SECRET: ${OPS_DESK_SECRET}
    depends_on:
      - db

  web:
    image: nginx:alpine
    volumes:
      - ../ops-desk-web/dist:/usr/share/nginx/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - api

volumes:
  pgdata:
```

部署时：
1. 在 workspace 目录 clone 四个仓库为平级目录。
2. `ops-desk-web` 和 `ops-desk-api` 各自 CI 构建产物放在本仓。
3. workspace 执行 `docker compose up -d` 拉起全栈。

### 6.2 CI/CD

| 仓库 | CI 命令 |
|---|---|
| `ops-desk-workspace` | 文档/图谱一致性检查 |
| `ops-desk-web` | `pnpm install` → `pnpm lint` → `pnpm test` → `pnpm build` |
| `ops-desk-api` | `ruff check` → `pytest tests` → `docker build` |
| `ops-desk-ios` | `xcodebuild` / SwiftLint（可选） |

**触发约束（四仓统一）：** 每个 workflow 的 `on` 必须同时包含 `pull_request` 与 `push.branches: [main]`，防止直推 `main` 漏跑。详见 `docs/04-infrastructure/01-environment-setup.md` §10.3。

部署方式：
- GitHub Actions 构建 Docker 镜像/静态文件。
- 通过 `scp`/`rsync` 或 Docker Hub 推送到服务器。
- 服务器执行 `docker compose pull && docker compose up -d`。

### 6.3 上线前检查

> 2026-09：迁移上线主线已完成；下列勾选为历史清单。未在本轮逐项重核的，标「以维护者确认 / 见 hygiene」。

- [x] ICP 备案通过（以维护者确认 / hygiene）
- [x] 域名解析生效（以维护者确认）
- [x] SSL 证书配置正确（以维护者确认；续期见 hygiene）
- [ ] 数据库备份脚本运行正常（Epic 8.6 等；见 backlog / hygiene）
- [x] 登录/Overview/Issues/PRs/Graph/Chat 全部可用（Chat 现为 lg-rag；§10.7 联调勾选 → **待确认**）
- [ ] 30 天内完成公安备案（**未核实** → 以维护者确认 / hygiene）

**本阶段对应 Epic**：Epic 8。详细清单见 [`01-epic-task-backlog.md`](./01-epic-task-backlog.md)。

---

## 风险与应对

| 风险 | 影响 | 应对 |
|---|---|---|
| ICP 备案驳回 | 上线延迟 | 提前准备合规网站名称；必要时换个体工商户主体 |
| LangGraph API 变动 | 后端重构 | pin 版本 `langgraph>=0.2,<0.3` |
| 本地 PG 单点故障 | 数据丢失 | 每日 pg_dump + COS + 每周快照 |
| 模型额度不足 | Chat 不可用 | Bailian 自动 fallback；准备备用 key |
| iOS 开发拖慢 | 整体延期 | iOS 明确只做骨架，不追平 Web |
| 一人项目上下文切换 | 效率低 | 按阶段集中火力，不并行改三端 |

---

## 下一步行动

1. ✅ **Chat 历史**：保存并展示多轮。
2. ✅ **GitHub 数据同步方式**：复用现有 GHA sync 工作流。
3. ✅ **鉴权模式**：继续使用 DB session 表。
4. ✅ **默认 LLM Provider**：SiliconFlow。
5. ✅ **iOS v1**：范围曾定为只做 Chat；**进度未在本轮核实** → 以维护者确认 / `ops-desk-ios` 为准。
6. ✅ **迁移主线 / 上线**：已完成（见进度水位）。
7. **后续**：Agent / RAG 完善 → [`04-agent-completion-roadmap_v1_zh.md`](./04-agent-completion-roadmap_v1_zh.md)；卫生编排 → [`03-post-go-live-hygiene-orchestration.md`](./03-post-go-live-hygiene-orchestration.md)。§10.7 CLOSE、图谱 P3、生产 nginx → **待确认**。
