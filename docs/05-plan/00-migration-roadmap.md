# 迁移路线图：Ops Desk Kimi Code v1

> 更新日期：2026-07-15  
> 总周期估算：8–10 周（1 人，含 ICP 备案等待时间）

---

## 阶段划分

```
Week 1–2: 基础设施准备（与开发并行）
Week 3–4: 后端 LangGraph 骨架 + 数据库落地
Week 5–6: 后端业务接口（Overview/Issues/PRs/Graph/Chat）
Week 7–8: 前端 Vue3 重写 + 联调
Week 9:   iOS 骨架 + 部署脚本
Week 10:  ICP 收尾 + 域名切换 + 公测
```

---

## Phase 0：项目初始化（Week 1）

| 任务 | 输出 | 负责人 |
|---|---|---|
| 创建迁移文档目录 | `docs/` | AI |
| 冻结 v1 功能范围 | `01-scope/00-project-brief.md` | 人 |
| 确定技术选型 | Vue3 + FastAPI + LangGraph + PG | 人 |
| 创建新的 GitHub 私有仓库 | `ops-desk-workspace`、`ops-desk-web`、`ops-desk-api`、`ops-desk-ios` | 人 |

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

## Phase 1：基础设施（Week 1–2，与开发并行）

| 任务 | 输出 | 时间 |
|---|---|---|
| 购买腾讯云 Lighthouse | 服务器 IP、root 权限 | 1 天 |
| 购买域名 + 实名认证 | 域名所有权 | 1–3 天 |
| 提交 ICP 备案 | 备案号（等待中） | 10–20 工作日 |
| 服务器初始化 | Docker、Docker Compose、Nginx、PG | 2 天 |
| 配置 DNS 解析（备案前可用 IP+端口测试） | A 记录 | 备案后 |
| 申请 SSL 证书 | 证书文件 | 备案后 |

**关键路径**：ICP 备案。备案期间可用服务器 IP + 非 80/443 端口开发测试。

---

## Phase 2：后端骨架（Week 3–4）

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

| 任务 | 验收标准 |
|---|---|
| Docker Compose 跑通 FastAPI + PostgreSQL | `docker compose up` 后 `http://localhost:8000/health` 200 |
| Alembic 初始化 + v1 表迁移 | 所有 ops_* 表创建成功 |
| 从 Supabase 导出初始数据并导入本地 PG | Issues/PRs/Graph/Scan 数据可用 |
| LangGraph 最小 graph 跑通 | `POST /api/ops/chat/stream` 返回 SSE 流 |
| LLM Provider 工厂接入 LangGraph | SiliconFlow / Bailian 可切换 |

---

## Phase 3：后端业务接口（Week 5–6）

| 模块 | 接口 | 说明 |
|---|---|---|
| Auth | `POST /api/ops/login` | HMAC 或 DB session |
| Overview | `GET /api/ops/overview` | 指标 + sync + scan + trend |
| Issues | `GET /api/ops/issues` | 列表 + 筛选 + 分页 |
| Pulls | `GET /api/ops/pulls` | 列表 + 筛选 + 分页 |
| Graph | `GET /api/ops/graph` | snapshot + module matrix |
| Chat | `POST /api/ops/chat/stream` | **SSE 流式对话，展示思考过程** |
| Chat | `GET /api/ops/chat/models` | 模型列表 |

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

## Phase 4：前端 Vue3 重写（Week 7–8）

### 4.1 项目初始化

```bash
npm create vue@latest ops-desk-web
# 选择：TypeScript、Pinia、Vue Router、ESLint、Prettier
npm install element-plus axios markdown-it highlight.js tailwindcss
```

### 4.2 开发顺序

| 优先级 | 页面/模块 | 说明 |
|---|---|---|
| 1 | 登录页 | 最快闭环 |
| 2 | 布局 + 侧边导航 | 复刻 `/ops/kimi-code` 导航 |
| 3 | 总览 | 数据量小，易验证 |
| 4 | Issues / PRs | 表格 + 筛选 |
| 5 | Graph | 矩阵展示 |
| 6 | Chat | 最复杂，保留轮询逻辑 |

### 4.3 Chat 组件重点

- 使用 `@microsoft/fetch-event-source` 消费 SSE。
- 用 Pinia 管理 `thinking` / `answer` / `toolResults` / `fallbackChain` / `loading`。
- 保持 `/api/ops/chat/models` 模型列表与 fallback 链路展示。
- 答案用 `markdown-it` + `highlight.js` 渲染。

---

## Phase 5：iOS 骨架（Week 9）

v1 只做：
- 登录页
- 会话列表
- 单轮 Chat（复用 `POST /api/ops/chat/stream` SSE）
- SSE 流式事件解析与展示

技术栈：
- SwiftUI
- Swift Concurrency
- URLSession
- 本地缓存：SwiftData

---

## Phase 6：部署与上线（Week 9–10）

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

部署方式：
- GitHub Actions 构建 Docker 镜像/静态文件。
- 通过 `scp`/`rsync` 或 Docker Hub 推送到服务器。
- 服务器执行 `docker compose pull && docker compose up -d`。

### 6.3 上线前检查

- [ ] ICP 备案通过
- [ ] 域名解析生效
- [ ] SSL 证书配置正确
- [ ] 数据库备份脚本运行正常
- [ ] 登录/Overview/Issues/PRs/Graph/Chat 全部可用
- [ ] 30 天内完成公安备案

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

1. **人确认**：Chat 历史是否保存并展示多轮？
2. **人确认**：GitHub 数据同步方式（复用 GHA sync / Python 定时任务 / 手动导入）？
3. **人确认**：鉴权模式（`hmac` / `db`）？
4. **人确认**：默认 LLM Provider（SiliconFlow / 百炼）？
5. **人确认**：iOS v1 是否只做 Chat？
6. **AI 下一步**：输出后端数据库 DDL + LangGraph 节点详细设计。
