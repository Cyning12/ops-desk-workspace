# ops-desk-workspace · Agent 导航

> **角色**：Ops Desk Kimi Code 的 AI 总调度工作空间。  
> **范围**：项目文档、架构图谱、任务单、跨仓编排。  
> **边界**：不写业务代码；业务实现分别落在 `ops-desk-web` / `ops-desk-api` / `ops-desk-ios`。

## Open Folder 说明

在 Claude Code / Cursor 中，**应将本目录 `ops-desk-workspace/` 作为 Open Folder 根目录**。  
父目录 `/Users/cyning/Desktop/Ops-desk/` 下的 `AGENTS.md` 仅作为多仓总入口参考；实际开发时请打开对应子仓：

| 工作场景 | Open Folder 目录 |
|---|---|
| 跨仓统筹、文档、docker-compose | `Ops-desk/ops-desk-workspace/` |
| 前端开发 | `Ops-desk/ops-desk-web/` |
| 后端开发 | `Ops-desk/ops-desk-api/` |
| iOS 开发 | `Ops-desk/ops-desk-ios/` |

---

## 必读（按顺序）

1. **`docs/README.md`** — 文档索引与状态
2. **`docs/01-scope/00-project-brief.md`** — 项目范围、目标、已确认决策
3. **`docs/01-scope/01-harness-tech-graph-strategy.md`** — Harness 接入与技术图谱策略
4. **`docs/01-scope/02-cross-repo-communication.md`** — 跨仓任务流转与信息沟通
5. **`docs/contracts/README.md`** — 跨仓接口契约索引
6. **`docs/05-plan/00-migration-roadmap.md`** — 迁移路线图
7. **`docker-compose.yml`** — 总部署编排

---

## 子仓导航

| 子仓 | 本地路径 | 职责 |
|---|---|---|
| web | `../ops-desk-web/` | Vue3 + Element Plus 前端 |
| api | `../ops-desk-api/` | FastAPI + LangGraph 后端 |
| ios | `../ops-desk-ios/` | SwiftUI iOS 应用 |

---

## 跨仓任务如何分工

当一项改动涉及多个仓库时，**不要在一个子仓里直接改另一个子仓的代码**。正确流程：

```
workspace 定义跨仓契约
  ├── api task：实现后端接口
  ├── web task：实现前端消费
  └── ios task：实现移动端消费
```

### workspace 的职责

1. **定义契约**：接口路径、请求/响应字段、SSE 事件类型、数据库表结构。
2. **出总任务单**：`docs/tasks/active/task_<主题>.md`，明确哪些子仓需要改动。
3. **维护总图谱**：`docs/_tech_graph/00_main.graph.yaml` 描述跨仓数据流。
4. **更新部署配置**：`docker-compose.yml`、Nginx、CI 编排。

### 子仓的职责

- **api**：按契约实现后端；可读取 workspace 契约，但不写前端/iOS 代码。
- **web**：按契约调用后端；不写后端接口。
- **ios**：按契约调用后端；不写后端接口。

### 示例：新增 Chat SSE

```text
workspace task: chat-sse-contract
  → 定义 POST /api/ops/chat/stream
  → 定义 SseEvent schema
  → HG-AUDIT-R1 approved

api task: chat-sse-backend
  → FastAPI 路由 + LangGraph + SSE emitter
  → 更新 api/docs/_tech_graph/

web task: chat-sse-frontend
  → useOpsChatSse composable + ChatView
  → 更新 web/docs/_tech_graph/

ios task: chat-sse-ios
  → ChatService SSE parser + ChatView
  → 更新 ios/docs/_tech_graph/

workspace close
  → 更新 docker-compose.yml
  → 验证三端联调
```

---

## 工作流

1. 需求/变更先在 workspace 起草 task：`docs/tasks/active/task_<主题>.md`
2. 30 编码前通过 `HG-AUDIT-R1` 人工闸
3. 涉及架构/接口变更时，同步更新 `docs/_tech_graph/` 中的 `.graph.yaml`
4. 子仓实现完成后，workspace 更新 `docker-compose.yml` 和部署文档

---

## 关键约束

- 技术图谱采用 **`.graph.yaml` + `.md` 双轨**，无 `.ai.md`
- 废弃 `graph.json`，由 harness 生成 `_manifest.json`
- 人工闸轻量版：保留 `HG-GRAPH-MODULES` + `HG-AUDIT-R1`
- 每次代码/接口变更必须同步更新图谱
- **禁止跨仓直接改代码**：后端 Agent 不改 web/ios 文件，反之亦然
- **GitHub Actions 触发**：四仓 workflow 的 `on` 必须同时包含 `pull_request` 与 `push.branches: [main]`（Free 私有仓无分支硬保护，防直推漏跑）。见 `docs/04-infrastructure/01-environment-setup.md` §10.3
