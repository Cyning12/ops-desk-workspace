# 跨仓信息沟通与任务流转

> 更新日期：2026-07-15  
> 范围：四仓库平级结构下，workspace、api、web、ios 之间如何同步接口变更与任务状态

---

## 1. 核心原则

Claude Code / Cursor 本身**没有自动跨仓感知能力**。一个 Agent 打开 `ops-desk-api` 时，它不会知道 `ops-desk-web` 里改了什么。

所以跨仓沟通靠 **"契约先行 + 文档真值 + 任务 handoff"**，而不是靠工具自动推送。

---

## 2. 契约先行（Contract First）

任何涉及多端的接口变更，**先在 workspace 定义契约**，再进子仓实现。

### 2.1 契约放在哪里

workspace 作为唯一真值来源：

```
ops-desk-workspace/
└── docs/
    ├── contracts/                  # 跨仓接口契约
    │   ├── api-v1-overview.md      # REST API 总览
    │   ├── api-v1-chat-stream.md   # SSE Chat 详细契约
    │   └── api-v1-auth.md          # 鉴权契约
    └── _tech_graph/
        └── 00_main.graph.yaml      # 总图中引用各契约
```

### 2.2 契约文档里写什么

以 `api-v1-chat-stream.md` 为例：

```markdown
# POST /api/ops/chat/stream

## 请求
- method: POST
- content-type: application/json
- authorization: Bearer token 或 Cookie ops_session

```json
{
  "message": "string",
  "session_id": "string?",
  "model": "string?"
}
```

## 响应
- content-type: text/event-stream

## SSE 事件类型
| event_type | payload | 前端行为 | iOS 行为 |
|---|---|---|---|
| run.start | { run_id } | 显示 thinking | 显示 thinking |
| thinking | { content, step } | 追加思考区 | 追加思考区 |
| answer | { content } | 追加答案区 | 追加答案区 |
| done | { latency_ms, model } | 结束加载 | 结束加载 |
| error | { stage, message } | 显示错误 | 显示错误 |

## 示例
```

---

## 3. 任务流转流程

### 3.1 标准跨仓任务链路

```text
workspace task: feature-chat-sse
  ├─ 定义契约 api-v1-chat-stream.md
  ├─ HG-AUDIT-R1 approved
  ├─ spawn api task
  │     └─ api 实现 /api/ops/chat/stream
  │     └─ api 更新 api/docs/_tech_graph/
  │     └─ api close → 回填 workspace
  ├─ spawn web task
  │     └─ web 按契约实现 useOpsChatSse
  │     └─ web 更新 web/docs/_tech_graph/
  │     └─ web close → 回填 workspace
  ├─ spawn ios task
  │     └─ ios 按契约实现 ChatService
  │     └─ ios 更新 ios/docs/_tech_graph/
  │     └─ ios close → 回填 workspace
  └─ workspace close
       └─ 更新 docker-compose.yml
       └─ 三端联调
```

### 3.2 谁来 spawn 子任务

**workspace Agent（总调度）**。它不负责写代码，只负责：

1. 写总 task 和契约文档。
2. 通过人工闸后，分别进入 api/web/ios 子仓执行。
3. 收集三端 close 报告，更新 workspace 状态。

### 3.3 子仓如何知道契约

子仓 Agent 打开子仓后，读取：

1. 本子仓 `AGENTS.md`
2. `../ops-desk-workspace/docs/contracts/xxx.md`（相对路径）
3. 如果需要，也读对应子仓的 `docs/_tech_graph/`

例如 web 任务：

```markdown
## 依赖
- 契约：`../ops-desk-workspace/docs/contracts/api-v1-chat-stream.md`
- 后端实现参考：`../ops-desk-api/docs/_tech_graph/10_flow_chat.md`
```

---

## 4. 回填机制

### 4.1 子仓 close 时必须回填的信息

每个子仓任务完成后，在 workspace 的 invokes 或 task 评论中记录：

| 子仓 | 回填内容 |
|---|---|
| api | 实际接口路径、字段微调、模型 fallback 行为、错误码 |
| web | 调用的 API、组件位置、已知兼容性问题 |
| ios | 调用的 API、SwiftData 缓存策略、已知兼容性问题 |

### 4.2 状态更新

workspace 的 task 文件中用 checklist 跟踪：

```markdown
- [x] api: POST /api/ops/chat/stream 实现
- [x] web: ChatView SSE 消费
- [ ] ios: ChatService SSE 解析
- [ ] workspace: docker-compose 联调
```

---

## 5. 如何让前端/iOS 知道后端实际接口

三种方式，从轻到重：

### 方式 1：契约文档（推荐 v1）

后端实现前，契约已经在 workspace 定好。前端/iOS 按契约开发。如果后端实现有微调，后端 close 时更新契约文档，web/ios 在下个 task 中读取更新后的契约。

**优点**：简单、人可读、AI 易理解。  
**缺点**：契约和代码可能短暂不同步。

### 方式 2：后端 tech graph 作为实现参考

后端实现后，在 `ops-desk-api/docs/_tech_graph/` 中维护精确的 endpoint 节点，包含：

```yaml
nodes:
  - id: "POST /api/ops/chat/stream"
    kind: endpoint
    contract:
      path: "/api/ops/chat/stream"
      file: "app/ops/chat/router.py"
      line: 12
      request_schema: "ChatStreamRequest"
      response_type: "text/event-stream"
```

web/ios 可以直接引用这个图谱节点。

**优点**：图谱即文档，变更时强制同步。  
**缺点**：需要维护，初期 overhead。

### 方式 3：OpenAPI / Swagger + 代码生成（v2 考虑）

FastAPI 原生生成 `/docs` OpenAPI schema。可以：

1. 后端 CI 导出 `openapi.json`。
2. workspace 或 api 仓维护 `openapi.json`。
3. 前端/iOS 根据 OpenAPI 生成 TypeScript / Swift client。

**优点**：机器可读、类型安全。  
**缺点**：对 v1 过重；Swift 代码生成工具链复杂。

**v1 推荐方式 1 + 方式 2 结合**：
- 人用契约文档（`docs/contracts/`）
- AI 用 tech graph 节点（`docs/_tech_graph/`）

---

## 6. 是否有"钩子"自动触发

### 6.1 Claude Code 没有内置跨仓钩子

Claude Code 的 skills、hooks、MCP 都是**单会话 / 单 workspace** 的。它不能在一个仓库改动后自动通知另一个仓库的 Agent。

### 6.2 可以做的半自动化

| 机制 | 作用 | 实现成本 |
|---|---|---|
| workspace 总 task + 子 task | 人工/AI 按流程 spawn | 低 |
| GitHub PR 模板 | 强制填写"影响面""前端/iOS 是否需要跟进" | 低 |
| CI contract check | 校验 api 实现与 workspace 契约是否一致 | 中 |
| `@cyning/harness verify` | 30 前检查 task 是否读取了最新契约 | 低 |
| GitHub webhook + 脚本 | 后端 PR merged 后自动创建 web/ios follow-up task | 高 |

**v1 推荐**：用 workspace 总 task + 子 task + PR 模板，不追求 webhook 自动化。

---

## 7. 推荐的最小可行流程（v1）

1. 人在 workspace 创建 task，定义契约文档。
2. `HG-AUDIT-R1` 后，AI 进入 api 实现，同时读取契约。
3. api close 时，更新契约文档（如有微调），并在 workspace task 中打勾。
4. AI 进入 web 实现，读取更新后的契约 + api tech graph。
5. web close 后，workspace 再打勾。
6. AI 进入 ios 实现，读取同样的契约。
7. ios close 后，workspace 更新 `docker-compose.yml`，组织联调。

---

## 8. 下一步落点

为支持这个流程，workspace 需要创建：

```
ops-desk-workspace/
└── docs/
    ├── contracts/                  # 新增
    │   └── README.md
    └── tasks/
        └── active/
            └── TEMPLATE-cross-repo.md  # 跨仓任务模板
```

这些内容可以在初始化 harness 骨架时一并创建。
