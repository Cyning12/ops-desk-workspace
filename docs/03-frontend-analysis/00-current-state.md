# 前端现状分析：ai-ink-brain/app/ops/kimi-code/

> 分析日期：2026-07-15  
> 技术栈：Next.js 15 App Router + TypeScript + Tailwind CSS

---

## 1. 页面结构

```
app/ops/kimi-code/
├── page.tsx              # 总览 Overview
├── issues/page.tsx       # Issues 列表
├── pulls/page.tsx        # Pull Requests 列表
├── graph/page.tsx        # Graph 矩阵
├── chat/page.tsx         # Chat（复用 OpsChatClient）
├── sessions/page.tsx     # Session 列表
└── sessions/[session_id]/page.tsx  # 单个 Session 详情
```

登录入口：`app/ops/login/page.tsx` + `login-form.tsx`

---

## 2. 各页面功能摘要

### 2.1 总览（Overview）

文件：`app/ops/kimi-code/page.tsx`

- 顶部标题 + 同步控制按钮（需 maintainer 角色）
- 三个指标卡：PR Cycle Time、PR Review Time、Issue Throughput
- Scan 摘要卡片
- 同步历史（最近 10 条）
- 30 天趋势图（closed issues / merged PRs）

### 2.2 Issues

文件：`app/ops/kimi-code/issues/page.tsx`

- 表格：# / 标题 / 状态 / 标签 / Scan / 更新于
- 筛选：state（全部/Open/Closed）、labels、scanTag、moduleId
- 分页：每页 25 条
- 标题链接跳转到 GitHub issue 原页

### 2.3 Pull Requests

文件：`app/ops/kimi-code/pulls/page.tsx`

- 表格：# / Title / State / CI / Review / Author / Updated
- 筛选：state（全部/Open/Closed/Merged）、checks（CI 状态）
- 分页

### 2.4 Graph

文件：`app/ops/kimi-code/graph/page.tsx`

- Graph Snapshot 摘要：版本、nodes/edges/graphs 数量
- 模块 × Issue 矩阵：模块名 / Issues / Open / P0 / P1 / P2 / Issue 编号 chips

### 2.5 Chat

文件：`app/ops/kimi-code/chat/page.tsx`

组件：`components/ops/OpsChatClient.tsx`

核心功能：
- Session 选择/新建
- 模型选择（从 `/api/ops/chat/models` 拉取）
- 发送消息 → 后端返回 run_id
- 轮询 `/api/ops/runs/{id}` + `/api/ops/runs/{id}/events`
- 展示：对话历史、最终答案、思考链/ReAct 链、Artifacts
- 支持 clarify 追问
- 展示模型 fallback 链路

---

## 3. 状态管理

当前：无全局状态库，主要靠：
- Server Component 直接获取数据
- Client Component 用 `useState` + `useEffect`
- localStorage 存储 `ops_chat_session_id`

Vue3 迁移建议：
- 使用 **Pinia** 管理：
  - `authStore` — 登录状态、角色
  - `chatStore` — session、turns、activeRunId
  - `opsDataStore` — issues/PRs/graph/overview 缓存

---

## 4. UI 风格

当前水墨极简风：
- 背景：`#F9F9F7`
- 文字：`#2C2C2C`
- 强调：低饱和靛蓝/石墨色
- 大量留白、衬线标题

Vue3 技术选型建议：

| 选型 | 建议 | 理由 |
|---|---|---|
| UI 库 | **Element Plus** | 后台组件全，与 Vue3 深度集成 |
| 样式 | Tailwind CSS + Element Plus 变量 + 自定义水墨 CSS 变量 | 保留水墨风 |
| Markdown | `markdown-it` + `highlight.js` | Chat 答案高亮 |
| 图标 | `@element-plus/icons-vue` | 与 Element Plus 配套 |
| HTTP | axios | 拦截器统一处理 401/错误 |
| **SSE** | **`@microsoft/fetch-event-source`** | 支持自定义 header、自动重连 |

---

## 5. API 调用层

### 5.1 跨域与 SSE

生产环境：Nginx 同一域名下反向代理 `/api` → FastAPI。
开发环境：Vite `server.proxy` 配置 `/api` → `http://localhost:8000`。

**SSE 要点**：
- 原生 `EventSource` 不支持自定义 header（如 Authorization），因此使用 `@microsoft/fetch-event-source`。
- 每个事件有 `event` 字段和 `data` JSON payload。
- 前端按 `event_type` 分类渲染：
  - `thinking` → 思考过程区
  - `tool_call` / `tool_result` → 工具调用区
  - `answer` → 最终答案区（Markdown 渲染）
  - `done` → 关闭连接、保存历史
  - `error` → 错误提示
- 连接断开需自动重连，但重连后应创建新 run（避免重复消费）。

### 5.2 API 列表

Vue3 前端直接调用后端 FastAPI：

```
GET  /api/ops/overview          → 总览数据
GET  /api/ops/issues            → Issue 列表
GET  /api/ops/pulls             → PR 列表
GET  /api/ops/graph             → Graph 矩阵
GET  /api/ops/chat/models       → 模型列表
POST /api/ops/chat/stream       → SSE 流式对话
POST /api/ops/login             → 登录
```

---

## 6. Vue3 项目目录建议

```
ops-desk-web/
├── public/
├── src/
│   ├── api/              # axios 封装 + 各模块 API
│   ├── assets/
│   ├── components/       # 通用组件 + ops 业务组件
│   ├── composables/      # 可复用逻辑（轮询、SSE、localStorage）
│   ├── router/           # Vue Router
│   ├── stores/           # Pinia
│   ├── styles/           # 水墨风 CSS 变量
│   ├── utils/            # 日期、markdown、事件解析
│   ├── views/
│   │   ├── LoginView.vue
│   │   ├── OverviewView.vue
│   │   ├── IssuesView.vue
│   │   ├── PullsView.vue
│   │   ├── GraphView.vue
│   │   └── ChatView.vue
│   ├── App.vue
│   └── main.ts
├── index.html
├── package.json
├── tsconfig.json
└── vite.config.ts
```

---

## 7. 与现有后端的接口兼容

v1 改为 **SSE 流式 Chat**，但 Issues/PRs/Graph/Overview 仍用普通 REST：
- 把 Next.js Server Component 的数据获取改成 Vue `setup` + `onMounted` + axios。
- 把 Server Actions/Route Handler 代理层删掉，直接请求 FastAPI。
- Chat 从轮询改为 `@microsoft/fetch-event-source` 实时事件流。

---

## 8. 组件拆分建议

| 现有 Next.js 组件 | Vue3 组件 |
|---|---|
| `MetricCard` | `OpsMetricCard.vue` |
| `ScanSummaryCard` | `OpsScanSummaryCard.vue` |
| `SyncControls` / `SyncRunHistoryLive` | `OpsSyncPanel.vue` |
| `TrendChart` | `OpsTrendChart.vue`（可用 ECharts 或 Chart.js） |
| `IssueTable` / `FilterBar` | `OpsIssuesView.vue`（内联） |
| `OpsChatClient` | `OpsChatView.vue` + 多个子组件 |
| `ThinkingChainTimeline` | `OpsThinkingChain.vue` |
| `OpsRunArtifacts` | `OpsRunArtifacts.vue` |

---

## 9. 前端迁移工作量评估

| 页面 | 复杂度 | 估算人天 |
|---|---|---|
| 登录页 | 低 | 0.5 |
| 总览 | 中 | 2 |
| Issues | 中 | 2 |
| Pull Requests | 中 | 1.5 |
| Graph | 中 | 1.5 |
| Chat | 高 | 4 |
| 布局/导航/路由 | 中 | 1.5 |
| API 层/状态管理 | 中 | 2 |
| 样式统一/水墨风 | 中 | 1.5 |
| **合计** | | **~17 人天** |

AI Coding 加成下，实际开发周期约 3–4 周（含联调）。
