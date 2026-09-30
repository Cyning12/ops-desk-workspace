# Harness 接入与技术图谱策略

> 更新日期：2026-09-18（纠偏 SpecWave）  
> 范围：Ops Desk 四仓库如何接入 **SpecWave（`spec-wave`）**，以及技术图谱如何作为接口对接文档  
> 包演进：原 cyning harness npm 包 → `dsh-coding-kit` → **`spec-wave`**（现行安装终点）

---

## 1. 接入目标

在项目开发中引入 **SpecWave** 纪律包，实现：

- 统一 AI Coding 流程：task → spec/task-audit → code → self-check → close
- 每次代码/接口变更后，同步更新技术图谱
- 技术图谱同时作为**架构地图**和**接口对接文档**
- 采用 **YAML-first 双轨**：`.graph.yaml` 为源，`*.md` 为编译生成物
- **不再使用 `.ai.md`**

---

## 2. 接入方式

### 2.1 现行裁定：各仓自钉（废弃「workspace 统一分发」）

| 仓 | SpecWave | 说明 |
|---|---|---|
| `ops-desk-api` | **钉 `3.0.0`** | fullstack-node-py |
| `ops-desk-web` | **钉 `3.0.0`** | 前端过程轨 |
| `ops-desk-workspace` | **钉 `3.0.0` · preset `harness-only`** | 文档/契约/统筹；轻量落盘 |
| `ops-desk-ios` | **不接入** | OpenSpec |

**废弃**：以 workspace 为中心 `harness-sync` 向子仓推送模板的「统一分发」方案。各仓各自 `package.json` exact 钉版 + `.coding-kit/manifest.json`，自行 `upgrade` / `sync prompts`。

### 2.2 workspace 落盘（现行）

```
ops-desk-workspace/
├── package.json                    # devDependency: spec-wave@3.0.2
├── .coding-kit/manifest.json
├── scripts/
│   └── graph-compile.sh            # KIT_CLI=spec-wave@3.0.2
├── docker-compose.yml
└── docs/
    ├── _tech_graph/                # workspace 级总图（可先最小骨架）
    │   └── 00_main.graph.yaml
    ├── tasks/
    └── harness/
        └── prompts/
```

子仓保留各自的 `docs/_tech_graph/`：
- `ops-desk-web/docs/_tech_graph/` — 前端页面、组件、事件流
- `ops-desk-api/docs/_tech_graph/` — 后端路由、LangGraph、数据库表
- `ops-desk-ios/docs/_tech_graph/` — iOS 页面、URLSession SSE

workspace 总图通过锚点 / `::triggers` / `::depends_on` 指向子仓子图（满图另 task 充实）。

### 2.3 子仓 / workspace 初始化命令

```bash
# 文档仓（workspace）
npx spec-wave@3.0.2 init --preset harness-only --tools cursor,claude,agents --yes

# 实现仓（api/web 示例；preset 按仓）
npx spec-wave@3.0.2 init --preset harness-only --tools cursor,claude,agents --yes
```

生成 / 维护：
- `.coding-kit/manifest.json`（现行落盘根；legacy `.cyning-harness/` 只读若存在）
- `docs/harness/prompts/`
- `docs/tasks/active/` / `docs/tasks/done/`
- `AGENTS.md` / `CLAUDE.md` 产品块

**hooks**：3.0.0 `host apply` 可能物化 Cursor/Claude hooks；Ops Desk **约定不入库 hooks**，门禁以 CLI `verify --task` 为准。

### 2.4 CI / 本地验证

各实现仓 CI / 本地：

```bash
npx spec-wave verify --target . --task docs/tasks/active/task_xxx.md
./scripts/graph-compile.sh
```

workspace：

```bash
npx spec-wave verify --target . --task docs/tasks/active/task_xxx.md
./scripts/graph-compile.sh
```

---

## 3. 技术图谱：架构 + 接口文档一体化

### 3.1 图谱分层

| 层级 | 位置 | 内容 |
|---|---|---|
| 总图 | `ops-desk-workspace/docs/_tech_graph/00_main.graph.yaml` | 四仓库关系、数据流、部署拓扑 |
| 前端图 | `ops-desk-web/docs/_tech_graph/` | 页面路由、组件、Pinia store、API client、SSE 事件处理 |
| 后端图 | `ops-desk-api/docs/_tech_graph/` | FastAPI 路由、LangGraph 节点、DB 表、SSE 事件契约 |
| iOS 图 | `ops-desk-ios/docs/_tech_graph/` | SwiftUI 页面、网络层、SSE 解析 |
| 数据同步 | `ops-desk-workspace/docs/_tech_graph/10_flow_sync.graph.yaml` | GHA sync → admin endpoint → PG（可后续补） |

### 3.2 接口契约纳入图谱

在 `ops-desk-api` 图谱中，节点应包含：

- **REST Endpoint 节点**：`GET /api/ops/issues`、请求/响应字段
- **SSE Endpoint 节点**：`POST /api/ops/chat/stream`、事件类型表
- **DB 表节点**：`ops_users`、`ops_sessions`、`ops_runs`、`ops_run_events`
- **LangGraph 节点**：`intent_node`、`load_issue_context_node`、`answer_node`
- **跨端事件契约**：`SseEvent` schema、payload 类型

示例 YAML 片段：

```yaml
nodes:
  - id: "POST /api/ops/chat/stream"
    label: "SSE 流式对话"
    kind: "endpoint"
    contract:
      method: "POST"
      request:
        message: string
        session_id: string?
        model: string?
      response: "text/event-stream"
      events:
        - run.start
        - thinking
        - tool_result
        - answer
        - done
        - error
```

### 3.3 编译与校验

修改流程：

1. 改 `.graph.yaml`（唯一编辑源）
2. 运行 `./scripts/graph-compile.sh`（默认 `KIT_CLI=spec-wave@3.0.2`）
3. 提交 `.graph.yaml` + 编译生成的 `.md`（及仓内若有的 `_manifest.json` / `graph.json` 产物）

---

## 4. graph_schema.json 处理建议

### 4.1 当前情况

历史子仓曾用 `graph.json`（由 `.ai.md` 导出）作为机器轨。

### 4.2 推荐方案：YAML-first

**决策：全面切到 YAML-first，废弃以 `.ai.md` 为源的旧轨。**

理由：
- SpecWave / 原 harness v2 明确 YAML-first，`.ai.md` 已弃用。
- `.graph.yaml` 可同时表达架构拓扑和接口契约（`contract` 字段）。
- `npx spec-wave graph yaml compile|check` 提供机械校验。

### 4.3 迁移步骤（历史 · 多数已完成于 api/web）

1. 各仓初始化 SpecWave + `docs/_tech_graph/`。
2. 填写模块边界表（人签 `HG-GRAPH-MODULES`）。
3. 用 `.graph.yaml` 维护总图与子流程。
4. 关键 endpoint / DB / 事件节点附加 `contract`。
5. 新增接口：先改 `.graph.yaml` 再改代码。

### 4.4 兼容性说明

- api/web 可保留仓内 `graph.json` 转换脚本作运行时 artifact，**不以**其为编辑源。

---

## 5. 人签与人工闸

### 5.1 建议启用的人工闸

| 闸 | 触发时机 | 作用 |
|---|---|---|
| `HG-GRAPH-MODULES` | 首次填写模块边界后 | 未 approved 不 30 |
| `HG-TASK-DRAFT` | 每个 task 起草后 | task 范围确认 |
| `HG-AUDIT-R1` | 30 编码前 | task 审核通过 |
| `HG-CLOSE` | 40 自检后 | 关账确认 |

### 5.2 v1 采用轻量版

**决策：v1 采用轻量版人工闸。**

启用：
- `HG-GRAPH-MODULES`
- `HG-AUDIT-R1`

简化：
- `HG-TASK-DRAFT` / `HG-CLOSE` 由人与 AI 协作完成，不强制独立闸。
- 一人项目下须落盘 invoke。

---

## 6. 目录落点（建议）

### workspace

```
ops-desk-workspace/
├── AGENTS.md
├── CLAUDE.md
├── package.json                  # spec-wave@3.0.2
├── scripts/
│   └── graph-compile.sh
├── docker-compose.yml
└── docs/
    ├── _tech_graph/
    │   └── 00_main.graph.yaml
    ├── tasks/
    └── harness/
        └── prompts/
```

### 子仓（以 api 为例）

```
ops-desk-api/
├── AGENTS.md
├── package.json                  # spec-wave@3.0.0
├── scripts/
│   └── graph-compile.sh
├── app/
└── docs/
    ├── _tech_graph/
    ├── tasks/
    └── harness/
```

---

## 7. 风险与注意

| 风险 | 应对 |
|---|---|
| SpecWave 学习成本 | 轻量版闸；workspace 用 harness-only |
| 图谱维护 overhead | 变更后强制 `./scripts/graph-compile.sh` |
| 子仓图与总图不同步 | 总图锚点；子仓变更时更新 workspace 边 |
| 3.0 hooks 物化 | **不入库**；门禁仅 CLI verify |

---

## 8. 下一步

1. ~~YAML-first / 轻量闸~~：**已裁定**  
2. ~~workspace SpecWave 骨架~~：见 `task_workspace_specwave_init_3_0_0`  
3. 充实 workspace 总图（契约 / sync 流）— 另 task  
4. 子仓图谱与契约持续对齐
