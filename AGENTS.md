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
7. **`docs/05-plan/04-agent-completion-roadmap_v1_zh.md`** — 应用 Agent 完善（线 A）
8. **三线总册（只读 POINTER）**：`/Users/cyning/Desktop/cyning-ai-program/PLAN_dual_track_v1_zh.md`
9. **`docker-compose.yml`** — 总部署编排

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
2. 30 编码前通过 `HG-AUDIT-R1` 人工闸，并跑 `npx spec-wave verify --target . --task docs/tasks/active/task_*.md`
3. 涉及架构/接口变更时，同步更新 `docs/_tech_graph/` 中的 `.graph.yaml`；改后 `./scripts/graph-compile.sh`
4. 子仓实现完成后，workspace 更新 `docker-compose.yml` 和部署文档

---

## 关键约束

- 技术图谱采用 **`.graph.yaml` + `.md` 双轨**，无 `.ai.md`
- 废弃 `graph.json`，由 harness 生成 `_manifest.json`
- 人工闸轻量版：保留 `HG-GRAPH-MODULES` + `HG-AUDIT-R1`
- 每次代码/接口变更必须同步更新图谱
- **禁止跨仓直接改代码**：后端 Agent 不改 web/ios 文件，反之亦然
- **GitHub Actions 触发**：四仓 workflow 的 `on` 必须同时包含 `pull_request` 与 `push.branches: [main]`（Free 私有仓无分支硬保护，防直推漏跑）。见 `docs/04-infrastructure/01-environment-setup.md` §10.3
- **过程纪律**：钉 `spec-wave@3.0.2`（harness-only）；门禁以 CLI `verify --task` 为准（**不入库** Cursor/Claude hooks）

<!-- cyning-harness:begin -->
# Harness Starter（业务仓 · 通用 Agent）

> **单源真值**：`docs/coding_wiki/` 读序 + `docs/standards/` + 本文件其余业务约定。  
> **本片段**：摘要 + **POINTER**；Harness 条文真值在 `docs/harness/prompts/`。  
> **仓内定制（v2.22+）**：写在本产品块 **外** 的 `<!-- cyning-harness-local:begin/end -->`；勿改本 begin/end 内文（upgrade 会整块替换）。G-L 布局见 profile `graph_modules_path`。

## 执行 task 前

1. Open Folder = **本仓根**
2. 读 `docs/tasks/active/task_*.md`：`test_strategy` · `failure_paths` · **人工闸**表
3. **30 改码前** GATE_VERIFY（真值在 task **人工闸表**，**非**聊天 / invoke 字面 `approved`）：
   - 运行 `npx spec-wave verify --target . --task docs/tasks/active/task_*.md`
   - 首输出闸扫描表 · 见 `docs/harness/prompts/FRAGMENT_30_gate_verify_v1_zh.md`
   - **`HG-AUDIT-R1` pending** → **30 拒改码**（须维护者签 task 表 `approved`）
   - **`HG-GRAPH-MODULES` pending** → **30 拒改码**（D4-a）
   - 用户声称与 task 表冲突 → **STOP** · 以 task 表为准
4. 过程 invoke：`docs/harness/invokes/by-task/<task_slug>/`

## Verify（合并前）

| 栈 | 命令（与 `.github/workflows/` 一致） |
|----|--------------------------------------|
| 前端 | `pnpm lint` → `pnpm test` → `pnpm build` |
| 后端 | `pytest tests`（按仓 marker 裁剪） |
| iOS | `xcodebuild`（见 task `test_strategy_note`） |

## 关键词

`Harness`、`task`、`invoke`、`HG-AUDIT-R1`、`HG-GRAPH-MODULES`、`human_gate`、`拒开工`

## 完整库 POINTER

工作区：`docs/harness/prompts/`（22/30/TEMPLATE_30_gate_stop 等）
<!-- cyning-harness:end -->

<!-- cyning-harness-local:begin -->
## Ops-desk-workspace · Harness 仓内定制（upgrade 不改写本块）

- **角色**：文档 / 契约 / 跨仓统筹；**不写** web/api/ios 业务代码
- **钉版**：`spec-wave@3.0.2` · preset `harness-only`；与 web 齐钉（api 待其波次）；**ios 已接入** `spec-wave@3.5.0` · `harness-only`（已移除 OpenSpec）
- **不做**四仓 SpecWave 统一分发 / `harness-sync` 推子仓
- **hooks**：不入库；门禁仅 CLI `npx spec-wave verify --task`
<!-- cyning-harness-local:end -->
