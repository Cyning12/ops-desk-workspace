# 00 · 定位与产品形态

> 裁定议题：#23 议题1（定位边界）、议题7（端侧形态）。
> 三方立场一致，无保留冲突。
> **v2（2026-11-13）：经实地代码调研修正**——面板降级、审批面、iOS 路线的"现状"描述以代码事实为准。

## 1. 定位裁定：Agent 为核心，面板降级为工具视图

**裁定：OpsDesk 演进为以 Agent 为核心的单一心智产品。现有 Overview / Issues / PRs / Graph 四个运维面板降级为 Agent 的只读工具与可视化产物，拒绝"一个产品两个模式"。**

### 理由（讨论整合）

1. **"两个模式"对 1 人团队是双倍维护成本**（product）：两条路线各有页面体系与任务体系，每加一个功能都要回答"两个模式各怎么呈现"，团队规模负担不起。
2. **面板能力可被 Agent 原生吸收**（product/platform）：四视图本质是"对同步数据的查询与汇总"，P2 落地后天然成为只读工具（`query_issues` / `get_pr_metrics` / `graph_snapshot`）。产品价值跃迁来自"Agent 读面板数据给出结论"，而不是人自己看面板。
3. **权限模型天然覆盖**（platform）：面板改造为 read 级工具后，直接落入工具级三档权限体系，无需为旧面板单开访问控制。
4. **架构上不存在"谁降级谁"的冲突**（architect）：面板页与 Agent 控制台共享的只有登录与 PG，前端路由天然分离；面板的数据同步管道（kimi-code sync）顺势成为 P2 的第一批工具数据源。

### 落地口径（v2 修正：降级是目标态，不是既成事实）

- **现状（inv-web 调研）**：四面板仍为完整功能页且与「Agent 工作台」平级排在主导航前五位（`ops-desk-web/src/layouts/AppLayout.vue:38-47`）；已发生的实际动作只有默认落地页改为 `/chat`（`router/index.ts:23-24`，2026-10-16 裁定）。此外页面版图比"四面板+Chat"大：还有 Observability、LC Evidence、Capability 目录页、LG RAG 调试页，降级讨论须一并覆盖。
- **降级须拆成可验收步骤**（建议：P2a 面板数据工具化 → P3 面板入口降为次级 → P4 面板渲染为 Agent artifact），每步单独验收，不写成既成事实。
- v1 已确认的"Chat 单轮"范围与本裁定冲突，**按 #23 正式重新裁定**：Chat 演进的最终目标是任务受理与监督界面（见路线图 P1 起）。注：调研证实 Chat 早已越过单轮——supervisor 多智能体图为默认模式。

## 2. 端侧形态裁定

**裁定：北极星形态是"监督控制台"，但按演进式信息架构实现——对话窗为容器，任务看板 / 审批 / 轨迹回放以面板组件逐步嵌入。三种形态不是三个产品，而是同一份数据（runs / run_events / approvals）的三种投影，共享全部后端 API。**

### Web

| 阶段 | 形态 |
|---|---|
| P1–P2 | 对话窗（沿用 SSE + 思考过程折叠交互，均已存在；不预搭看板空壳） |
| P3 | 对话窗内嵌入任务卡片 + 轨迹回放（**审批卡片/审批页已交付**——composer 上浮层 + 独立 `/hitl` 页 + 对账机制，调研证实；任务卡片/轨迹回放仍零实现） |
| P4 | 完整监督控制台（任务列表按状态/目标聚合） |

产品原则（product）：P3 的异步任务必须能在对话窗内回填状态（任务卡片），否则监督体验断裂。

### iOS

**裁定：iOS 收缩为"移动人工闸 + 只读"，不做看板，不做缩小版 Web。**

- 独有价值场景：Agent 后台跑任务，走到人工闸时在手机上批准/驳回。
- **现状（inv-web 调研）**：iOS 已全面转向 lg-rag 契约（契约层 T1 已提交：11 类帧 typed enum + SSE 解析器 + 单测；SwiftData 本地已有 ChatSession/ChatRun/ChatRunEvent 三实体，与服务端 runs/run_events 同构）；主链路 ChatService 尚为骨架（`fatalError("TODO")`），5 个 active task 覆盖 mainline/history/hitl/replay。AGENTS.md 中"复用 /api/ops/chat/stream"已失效（该端点 410 Gone），需修订。
- **审批落地路径修正**：hitl 帧模型已就位（`LgRagFrame.swift:68,71`），审批随 lg-rag 主链路 task 一起落地，**不必等 P3 手动拉取形态**；APNs 仍留接口不实现。
- admin（irreversible）级工具在 iOS 端降级为仅展示。
- 遗留：`IMWebSocketClient.swift`（323 行 WebSocket 实验资产未接主链路）裁定去留。

## 3. 概念可见性映射（product 裁定，architect 附议）

harness 内部 4 概念，UI 只暴露 3 个，且用中文产品名：

| 内部概念 | UI 可见性 | 界面名称 |
|---|---|---|
| Goal | 可见 | **任务** |
| Schedule | 可见 | **定时任务** |
| Approval | 可见 | **审批** |
| Run | 不可见 | 以"一次执行 / 任务轨迹"渲染其事件流，非独立实体 |
| Skill | 终端用户不可见 | 仅管理员侧配置项 |

原则：4 概念进代码，3 概念进界面；Run 是引擎室的，不是仪表盘的（architect）。
