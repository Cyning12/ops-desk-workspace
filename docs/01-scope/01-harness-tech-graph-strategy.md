# Harness 接入与技术图谱策略

> 更新日期：2026-07-15  
> 范围：Ops Desk 四仓库如何接入 `@cyning/harness`，以及技术图谱如何作为接口对接文档

---

## 1. 接入目标

在项目开发中引入 `@cyning/harness` 纪律包，实现：

- 统一 AI Coding 流程：task → spec/task-audit → code → self-check → close
- 每次代码/接口变更后，同步更新技术图谱
- 技术图谱同时作为**架构地图**和**接口对接文档**
- 采用 harness v2 推荐的 **YAML-first 双轨**：`.graph.yaml` 为源，`*.md` 为编译生成物
- **不再使用 `.ai.md`**

---

## 2. 接入方式

### 2.1 推荐：workspace 统一分发

```
ops-desk-workspace/
├── package.json                    # devDependency: @cyning/harness
├── scripts/
│   ├── harness-init.sh             # 初始化四仓库 harness 骨架
│   ├── harness-sync.sh             # 同步 harness 模板更新到子仓
│   └── graph-compile.sh            # 编译 .graph.yaml → .md
├── docker-compose.yml
└── docs/
    └── _tech_graph/                # workspace 级总图
        ├── 00_main.graph.yaml
        ├── 00_main.md
        ├── 01_struct.md            # 模块边界表（人签）
        └── 99_mermaid_protocol.md
```

子仓保留各自的 `docs/_tech_graph/`：
- `ops-desk-web/docs/_tech_graph/` — 前端页面、组件、事件流
- `ops-desk-api/docs/_tech_graph/` — 后端路由、LangGraph、数据库表
- `ops-desk-ios/docs/_tech_graph/` — iOS 页面、URLSession SSE

workspace 总图通过 `::triggers` / `::depends_on` 指向子仓子图。

### 2.2 子仓 harness 初始化命令

在每个子仓根执行：

```bash
npx @cyning/harness@latest init --preset harness-only --ide cursor,agents --yes
```

生成：
- `.cyning-harness/manifest.json`
- `docs/harness/prompts/`
- `docs/tasks/active/` / `docs/tasks/done/`
- `docs/_tech_graph/` 模板
- `AGENTS.md` / `CLAUDE.md` 入口

### 2.3 CI 验证

每个子仓 CI 增加：

```bash
npx @cyning/harness verify --target . --task docs/tasks/active/task_xxx.md
```

workspace CI 增加：

```bash
npx @cyning/harness gate-check --target ./ops-desk-api --graph
npx @cyning/harness gate-check --target ./ops-desk-web --graph
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
| 数据同步 | `ops-desk-workspace/docs/_tech_graph/10_flow_sync.graph.yaml` | GHA sync → admin endpoint → PG |

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
2. 运行 `node scripts/graph_yaml_compile.js` 生成 `.md`
3. 运行 `npx @cyning/harness graph yaml check --input docs/_tech_graph`
4. 提交 `.graph.yaml` + `.md` + 生成的 `_manifest.json` / `_contract_manifest.json`

---

## 4. graph_schema.json 处理建议

### 4.1 当前情况

现有子仓使用 `graph.json`（由 `.ai.md` 导出）作为机器轨，schema 见 `ai-ink-brain/docs/_tech_graph/graph_v2_schema.md`。

### 4.2 推荐方案：全面切到 harness v2 YAML-first

**决策：全面切到 harness v2 YAML-first，废弃现有 `graph.json`。**

理由：
- `@cyning/harness` v2 已明确 YAML-first，`.ai.md` 已弃用。
- `.graph.yaml` 可以同时表达架构拓扑和接口契约（通过节点 `contract` 字段）。
- `npx @cyning/harness graph yaml compile|check` 提供机械校验。
- `_manifest.json` / `_contract_manifest.json` 由 CI 从 YAML 生成，作为运行时 artifact。
- 新仓库 `ops-desk-*` 从头开始，无需兼容旧 `graph_v2_schema.md`。

### 4.3 迁移步骤

1. 在 `ops-desk-workspace` 初始化 harness，复制 `graph/templates/` 到 `docs/_tech_graph/`。
2. 按 Ops Desk 业务填写 `01_struct.md` 模块边界表。
3. 用 `.graph.yaml` 重写总图和各子流程图。
4. 在关键 endpoint / DB / 事件节点上附加 `contract` 字段。
5. 废弃 `.ai.md` 和 `graph.json` 机器轨；由 harness 生成 `_manifest.json`。
6. 后续新增接口时，先改 `.graph.yaml` 再改代码。

### 4.4 兼容性说明

- 如果某些 IDE 插件或脚本仍依赖 `graph.json`，可临时保留一个转换脚本，但不作为主源。
- v1 不追求与旧 `graph_v2_schema.md` 的向后兼容；新仓库从头开始。

---

## 5. 人签与人工闸

### 5.1 建议启用的人工闸

| 闸 | 触发时机 | 作用 |
|---|---|---|
| `HG-GRAPH-MODULES` | 首次填写 `01_struct` 后 | 模块边界人签，未 approved 不 30 |
| `HG-TASK-DRAFT` | 每个 task 起草后 | task 范围确认 |
| `HG-AUDIT-R1` | 30 编码前 | task 审核通过 |
| `HG-CLOSE` | 40 自检后 | 关账确认 |

### 5.2 v1 采用轻量版

**决策：v1 采用轻量版人工闸。**

启用：
- `HG-GRAPH-MODULES`（模块边界人签，未 approved 不进入 30 编码）。
- `HG-AUDIT-R1`（30 编码前 task 审核）。

简化：
- `HG-TASK-DRAFT` / `HG-CLOSE` 由人与 AI 协作完成，不强制独立闸。
- 一人项目下，task 起草、自检、关账合并为同一流程，但须落盘 invoke。

---

## 6. 目录落点（建议）

### workspace

```
ops-desk-workspace/
├── AGENTS.md
├── CLAUDE.md
├── package.json
├── scripts/
│   ├── harness-init.sh
│   ├── harness-sync.sh
│   └── graph-compile.sh
├── docker-compose.yml
├── nginx.conf
└── docs/
    ├── README.md
    ├── _tech_graph/
    │   ├── 00_main.graph.yaml
    │   ├── 00_main.md
    │   ├── 01_struct.md
    │   ├── 10_flow_sync.graph.yaml
    │   ├── 10_flow_sync.md
    │   └── 99_mermaid_protocol.md
    ├── tasks/
    │   ├── active/
    │   └── done/
    └── harness/
        └── prompts/
```

### 子仓（以 api 为例）

```
ops-desk-api/
├── AGENTS.md
├── CLAUDE.md
├── package.json                  # devDependency: @cyning/harness
├── scripts/
│   └── graph-compile.sh
├── app/
├── tests/
└── docs/
    ├── _tech_graph/
    │   ├── 00_main.graph.yaml
    │   ├── 00_main.md
    │   ├── 01_struct.md
    │   ├── 10_flow_chat.graph.yaml
    │   ├── 10_flow_chat.md
    │   ├── 11_flow_auth.graph.yaml
    │   ├── 11_flow_auth.md
    │   └── 99_mermaid_protocol.md
    ├── tasks/
    └── harness/
```

---

## 7. 风险与注意

| 风险 | 应对 |
|---|---|
| harness 学习成本 | v1 先用轻量版闸；复杂流程后续逐步引入 |
| 图谱维护 overhead | 每次代码变更后强制更新 `.graph.yaml`；CI 校验不通过则阻断 |
| 子仓图谱与 workspace 总图不同步 | workspace 总图通过节点 `::triggers` 指向子仓；子仓变更时同步更新锚点 |
| 现有 `graph.json` 工具链废弃 | 提前评估是否有其他脚本依赖；必要时写临时兼容层 |

---

## 8. 下一步

1. **人确认**：是否全面切到 harness v2 YAML-first，废弃现有 `graph.json`？
2. **人确认**：人工闸启用全集还是轻量版？
3. **AI 下一步**：
   - 初始化 `ops-desk-workspace` 的 harness 骨架 + `docs/_tech_graph/`
   - 输出后端数据库 DDL
   - 输出 `ops-desk-api` 的 `00_main.graph.yaml` + `01_struct.md` 初稿
