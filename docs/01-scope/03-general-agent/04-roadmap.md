# 04 · 演进路线图与 MVP 切分

> 裁定议题：#23 第 3 节候选路径的修订版。
> **v2（2026-11-13）：经实地代码调研整体右移**——初稿把大量已交付能力当作待办，本版先盘点已交付，再重排真正缺口。

## 0. 已交付能力盘点（调研证实，不再重复规划）

| 能力 | 状态 | 证据 |
|---|---|---|
| supervisor 五阶段多智能体编排（默认 chat 模式，observe 外环 ReAct 已存在，`LG_RAG_REACT_MAX_ROUNDS=2`） | ✅ 现网 | `multi/graph.py:79-105` |
| 执行与 HTTP 解耦（进程内 RunWorker + 孤儿补偿 300s） | ✅ 现网 | `run_worker.py:93-238` |
| 事件持久化 + replay 续看 + continue_from 继续回复 + HITL resume 三语义 | ✅ 现网 | `router.py:503-593`、`useLgRagSse.ts:129-133` |
| HITL 审批全链（interrupt/decide→resume/resume_mode/TTL/对账/四入口前端） | ✅ 已 freeze | `app/ops/hitl/`、`HitlApprovalView.vue` |
| Capability 工具体系（含一条真实写能力 ops.write.run_note） | ✅ 现网 | `app/ops/capability/` |
| 记忆双表 + 抽取管线（默认关）+ session_summaries 折叠骨架 | ✅ 已建默认关 | `models.py:346-648` |
| PG checkpointer（闸默认关）、LLM 韧性层、Langfuse tracing、多租户 | ✅ 现网 | 见 01/03 文档 |
| iOS lg-rag 契约层（11 类帧 typed enum + SSE 解析器 + 单测） | ✅ T1 已提交 | `LgRagFrame.swift`、`LgRagSseParser.swift` |

## 1. 修订后序列

```
P0' 收敛与默认开启 → P1 会话深化（Goal）→ P2a 工具对齐 → MVP 验证点 → P2b 生态 / P3 任务化 → P4 通用化
```

### P0' · 收敛与默认开启（≈2~3 任务单，走 spec-wave + HG-AUDIT-R1）

1. 默认开启 `LG_RAG_HTTP_CHECKPOINTER=postgres` 并回归 HITL resume 全链；
2. 裁定 run 是否升为一等实体表（与 `chat-stream-v1.md` §2、现役三表族裁定真源）；
3. 下线旧 chat 遗产（graph/service/**ws 未鉴权端点**/旧表）；
4. 审计统一查询视图；
5. 跟进已登记缺陷 N-R2-1（resume 链丢失）。
- 验收：不破 `lg-rag-sse-v1` freeze、不触发 tenant freeze 闸。

### P1 · 会话深化

- 在既有 supervisor 图上收敛 Goal（跨轮目标态）语义：多轮 = 同一 Goal 下多个 Run 的链；**不是新建 ReAct**（图里已有）。
- harness 概念：Run（现状沿用）+ Goal（新增一张 PG 表）；UI 只见"任务"。
- 上下文：滑动窗口 + issue 上下文重注入（维持）。
- **验证假设**：多轮 + 会话记忆能否当日常运维助手用。

### P2a · 工具对齐（初稿 MVP-2 大幅缩水后的真实缺口）

- 面板四视图查询接入 capability registry 成为 Agent 只读工具（`query_issues`/`get_pr_metrics`/`graph_snapshot`/overview），数据源沿用 kimi-code sync——复用既有 registry，**不做新 ToolRegistry**。
- 裁定 FC 主路径（维持 plan-JSON 还是切 bind_tools；冒烟测试仅在前者被替换时前置）。
- CapabilitySpec 与 MCP Tool Schema 字段对齐评审。
- **验证假设**：「Agent 读面板数据出结论」成立与否（定位裁定的技术验证点）。

### P2b · 生态（不变）

- MCP client 适配器（`langchain-mcp-adapters`，远端工具→capability 条目翻译器）。
- 最小 skill 加载器（workspace `skills/` 目录、启动加载、重启生效）。

### P3 · 任务化执行

- 新增：Schedule 表（定时任务触发器）；对话窗内**任务卡片 + 轨迹回放 UI**（当前零实现，grep 无 TaskCard/看板）；L2 记忆产品化（管理端浏览/撤销，可选 propose→confirm 交互）；`ops_session_summaries` 折叠摘要启用。
- 多副本前置：进程内状态外置（熔断/配额/幂等/nonce）、DB 租约 worker。
- **验证假设**：「给目标、等交付」心智成立。
- iOS：随 lg-rag 主链路落地 hitl 审批（active task 已立项），APNs 留接口。

### P4 · 通用化（愿景，不设排期）

- 领域配置化、多 Agent（Run 树 / supervisor 的 Send 并行泛化）。
- 纪律不变：ops 域内 P3 闭环之前不做空抽象。

## 2. 阶段纪律汇总（更新）

1. 每阶段最多引入一个新外部依赖。
2. 不预搭未来形态的 UI 空壳（审批面已交付为例外存量）。
3. **先盘点复用再规划新建**（本轮调研的教训：初稿近半"待办"实为已交付）。
4. 所有新 DDL 含 `tenant_id`，跨租户 404。
5. P4 之前的抽象必须服务 ops 域真实闭环。
