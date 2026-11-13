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

## Round 3 · 实地代码调研校验（2026-11-13，组织人发起）

R1/R2 结论基于共享上下文推演，未核实代码。Round 3 派三路调研员（inv-api / inv-web / inv-docs）实地核码，**核心教训：代码现实显著领先于项目简报的 v1 画像，初稿近半"待办"实为已交付**。

### 被证伪/修正的关键假设

| 初稿假设 | 代码现实 | 证据 |
|---|---|---|
| v1 同步 SSE 绑死连接、"此路必废" | 执行与 HTTP 已解耦（进程内 RunWorker + 孤儿补偿） | `run_worker.py:93-238` |
| P0' 新建 runs/run_events | 三表族 + Alembic 已存在，任务是收敛而非新建 | `models.py:291-343` |
| 断线重连用 Last-Event-ID | 已冻结 cursor + `/lg-rag/replay`，手动续看 | `router.py:503-593` |
| HITL 闸骨架 P1 待建 | 已交付并 freeze（decide→resume、TTL、四入口前端） | `app/ops/hitl/`、`HitlApprovalView.vue` |
| ToolRegistry 新建、3-5 硬编码工具 | Capability 体系 27 文件已完整 | `app/ops/capability/` |
| 权限自创三档 read/write/admin | 现有 side_effect 四档 + risk_level 双维度 | `types.py:7-24` |
| L2 记忆 agent_notes 单表双态 | 已有 facts+episodes 双表、状态机、抽取管线默认关 | `models.py:520-648` |
| L3 = pgvector 底座 | Qdrant 默认、pgvector 降级 | `00-current-state.md:18` |
| 审计 = 单张 audit_log | 分域多表（receipts/llm_usage/hitl_requests） | inv-api §2.7 |
| FC 兼容性冒烟为 P1 任务 | 主路径不经模型原生 tool_call，无的放矢 | inv-api §2.5 |
| 面板已降级/可降级描述 | 四面板仍在主导航前五位；仅默认落地页改 `/chat` | `AppLayout.vue:38-47` |

### 调研新发现（文档套已吸纳）

- 多租户 freeze（F1–F6）：session.tenant_id 为真源，全部新 DDL 须含 tenant_id——初稿完全遗漏，已成贯穿约束。
- 现存安全风险：`app/ops/chat/ws.py` 未鉴权 demo WS 仍在路由；旧 chat 图代码残留。
- 已登记缺陷 N-R2-1（resume 链丢失）列入 P0'。
- Web 页面版图含 Observability/LC Evidence/Capability 三额外页；iOS 有 323 行 WebSocket 实验资产待裁定去留。
- `docs/README.md` 未索引本目录；`docs/_tech_graph/shared/graph.json` 残留与"废弃 graph.json"决策矛盾（卫生项）。

### 组织人裁定（R3 新增）

- L2 记忆："禁止自动写"软化为"默认关 + 人工可审"（对齐代码）；propose→confirm 交互降级为 P3 可选增强。
- 审计：分域表 + 统一视图，不另建 audit_log 单表。
- P0' 接受条件改为：不破 lg-rag-sse-v1 freeze、不触发 tenant freeze 闸。

## 遗留开放项

1. P0' 的正式 task 单起草（落 ops-desk-api 仓，走 spec-wave 闸）；内容按 v2 重定基线（收敛三表族 + checkpointer 默认开 + 旧遗产下线 + WS 端点处置 + N-R2-1）。
2. v1 项目简报中"多轮对话/ReAct 不在 v1"条款的正式修订（现网 supervisor 图已越过该条款，简报画像整体过时，建议全面刷新）。
3. ~~SiliconFlow/百炼 tool_call 冒烟测试集~~（R3 裁定：主路径不经 FC，无的放矢；降级为引入 FC 时的前置）。
4. P4 通用化的检验标准（需要真实第二领域出现后再议）。
5. （R3 新增）run 是否升为一等实体表的裁定；chat-stream-v1 等契约的修订清单（见 inv-docs 建议 8）；iOS AGENTS.md 过时端点修订；IMWebSocketClient 去留；docs/README.md 补索引与 graph.json 清理。
