# 05 · 讨论记录与裁定表

> 本文档留存 #23 多轮讨论的过程与裁定依据，供日后追溯。
> 形式：三方专家（Agent 架构师 architect / 产品负责人 product / 平台与安全工程师 platform）两轮讨论；组织人（lead）整合并裁定少数冲突。

## Round 1 · 各方立场要点

### architect（议题2/4/7-架构）

- 编排：LangGraph 降级为图执行器，上覆自研薄 harness（Run/Goal/Schedule/Skill）；不引入 DSH（TS 运行时 + Python api，双运行时维护不起），机制裁剪移植。
- 执行：异步为体、SSE 为用；一切执行皆持久化 Run，SSE = run 事件流可断线重连订阅；PG LISTEN/NOTIFY + worker，不引 Redis。
- 提出 P0' 地基：v1 chat 存储直接建模为 runs/run_events。
- 端侧：三形态 = 同一 API 的三投影；iOS 只接只读 + 审批。

### product（议题1/7/路线）

- 定位：Agent 为核心、面板降级为工具视图，拒绝两个模式（双倍维护成本、心智分裂）。
- 端侧：北极星 = 监督控制台；演进式信息架构（对话窗为容器，组件逐步嵌入）；iOS = 移动人工闸。
- 路线：P1 → P2a（仅工具注册+FC）→ P3 → P2b/P4；MVP-1/2/3 切分，MVP-2 是方向证伪点。

### platform（议题3/5/6）

- 工具：私有 FC 优先，MCP 仅 client 后置；不做 MCP server；ToolRegistry 含权限标注。
- 记忆：三层模型；L2 禁止自动写，改"提议→人工确认"；知识库 pgvector 只读 RAG。
- 安全：工具级三档 + interrupt 单一闸 + append-only audit_log；闸骨架必须先于写能力就位。

## 冲突点与裁定

| # | 冲突 | 各方立场 | 最终裁定 |
|---|---|---|---|
| C1 | MCP 时机 | platform：client 后置；architect R1："MCP 优先包装在注册表后"；product：进 P2b | **P2b**（architect R2 收回"MCP 优先"）。硬约束：ToolRegistry schema 与 MCP Tool Schema 字段级对齐，P2b 适配器零返工 |
| C2 | 最小 skill 加载器时机 | platform：P2a 内（≈50 行）；architect/product：P2b | **P2b（2:1，组织人按多数裁定）**。P2a 提示词以 api 仓配置过渡；platform 少数意见记录在案 |
| C3 | P0' 是否 v1 scope 蔓延 | architect：必须做（≈2~3 任务单）；product：警惕蔓延 | **有条件接受**：仅数据层、v1 功能零增量；判定标准——删掉 P0' 后 v1 可上线且 P1 零迁移 |
| C4 | harness 概念数与 UI 可见性 | architect：4 概念，P1 只要 Run+Goal；product：UI 只暴露 3 概念 | **一致**：代码 4 概念（Run/Goal/Schedule/Skill），UI 3 概念（任务/定时任务/审批），Run/Skill 用户不可见 |
| C5 | L2 记忆自动写入 | platform：禁止自动写 | **三方一致禁止**；"提议→人工确认"复用 approval 闸；已确认记忆可浏览、可单条删除（product 补充） |

## R2 各方最终立场存档

### architect

- C1：收回"MCP 优先"；MCP client 进 P2b，不晚于 P3 前；schema 对齐硬约束。
- C3：P0' 三项清单（表 ≈0.5 天 / 序号协议 ≈0.5 天 / checkpointer ≈1 天），全部落在 v1"保存对话+思考过程"决策的实现路径内。
- C4：P1 只需 Run+Goal；Schedule 最早 P3（与 approval 同批）；Skill 最早 P2b（与 MCP 同批）。
- C5：附议；L2 写入 = approval 的一种 type，零新增机制。

### product

- C3：有条件接受 P0'（纯数据层、零功能增量）。
- C4：可见性映射确认；界面用中文产品名，不暴露技术词。
- C1/C2：MVP 切分不受影响，维持 MVP-1→2→3→P2b→P4；最小 skill 加载器放 P2b 可接受。
- C5：无异议且主动支持；要求已确认 L2 可浏览可删除。
- 技术中立声明：MCP 阶段归属只看两条验收（MVP-2 工具可调用；P2b 前不新增依赖 MCP 的功能承诺）。

### platform

- C1：MCP client 放 P2b；P2a 依赖配额留给 interrupt 审批链。
- C2：主张 P2a 含最小加载器（少数意见，未被采纳）；接受"Skill 体系高级特性后置"。
- C5：给出 agent_notes 单表双态设计与 propose_note 交互流。

## 遗留开放项

1. P0' 的正式 task 单起草（落 ops-desk-api 仓，走 spec-wave 闸）。
2. v1 项目简报中"多轮对话/ReAct 不在 v1"条款的正式修订（随 P1 启动一并改）。
3. SiliconFlow/百炼 tool_call 冒烟测试集的具体用例清单（P1 第一个任务）。
4. P4 通用化的检验标准（需要真实第二领域出现后再议）。
