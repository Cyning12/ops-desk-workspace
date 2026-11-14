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

## Round 4 · 终局裁定与开工评审（2026-11-13）

三方对遗留开放项给出可执行终局裁定（明细与任务卡见 06-kickoff-readiness.md）：
- architect：A1 run 实体化**新建** ops_lg_rag_runs（事件表不加 FK）；A2 Goal 图零改动落外状态 ops_goals；A3 下线顺序 摘WS路由→删旧码→归档drop表→410 墓碑；A4 进程化阈值量化（在飞>8 / P95>10min+月部署≥4 / 双副本需求）。**GO**，前置 C-1 先合并。
- platform：P1 维持 plan-JSON 主路径（重估三触发条件）；P2 checkpointer 默认开 Go（灰度三步）；P3 审计合格线=单张 v_audit_unified view；P4 记忆灰度读→写→经验；P5 ws.py 直接下线。**条件 GO**（task 单过闸、T1 先于 T3、view 含 tenant_id、不破 freeze）。
- product：D1 面板降级三步验收标准；D2 IMWebSocketClient 保留冻结（P3 复评）；D3 iOS 审批随主链路落地、task 排序 mainline→hitl→replay→history；D4 改写 project-brief 不新发版；D5 MVP-1 叙事定稿。**条件 GO**。
- 唯一跨域冲突 C-R4-1（iOS WS 资产删 vs 冻结）：组织人裁定采纳 D2 冻结，architect 异议记录在案。
- 三方条件全部折算进 P0' 任务卡 T1–T7，顺序关键链 T1→T3→T4。**结论：具备开工条件，待负责人拍板。**

## 遗留开放项

1. ~~P0' task 单起草~~ → R4 已产出任务卡 T1–T7（06-kickoff-readiness.md §3）；**开工第一步**：正式落 ops-desk-api 仓过 spec-wave + HG-AUDIT-R1 闸。
2. ~~简报修订~~ → R4-D4 裁定改写 00-project-brief.md，纳入 T7。
3. ~~FC 冒烟~~ → R4-P1 裁定维持 plan-JSON 主路径，冒烟集降级为重估触发条件的前置。
4. P4 通用化的检验标准（需要真实第二领域出现后再议）。
5. ~~run 实体化 / IMWebSocketClient 去留~~ → R4-A1 裁定新建 ops_lg_rag_runs；R4-D2 裁定冻结（冲突 C-R4-1 组织人已裁定）。~~契约修订清单 / iOS AGENTS.md / 索引与 graph.json~~ → 全部纳入 T7。
6. （R4 新增）P3 时点复评项：APNs 推送通道选型（联动 D2 复评）；管理端审计聚合页；agent_notes propose→confirm 交互增强。


---

## Round 5：P1 设计评审（2026-11-14 · architect 起草 / platform 安全 / product 端侧 / lead 整合）

- **产出**：[07-p1-goal-design.md](07-p1-goal-design.md)（P1 设计终稿：Goal → supervisor 收敛 · 图零改动 · 装配层注入 · SSE 零新帧 · 唯一新 DDL=uq_ops_goals_active_thread 部分唯一索引 · 任务切分 T1–T5）。
- **lead 事实复核两处**：① architect「runs 表无索引」证伪（迁移已建 idx(thread_id)/(status,created_at)，但派生发现 ORM 未声明 __table_args__ 的 autogenerate 漂移，并入 T4 修）；② 「待实证」graph.py:166/199 实证已实传 tenant_id/user_id/thread_id，接线零改动。
- **platform 三修正采纳**：① 隔离槽位四件套（第四分支归因/per-slot guide 压信任级/[当前目标]+[相似经验] 进伪造转义表/objective 单行化截 200）；② 闸体例（懒创建同挂 GOAL_INJECT_ENABLED 实现 off 零触达 · goal fetch wait_for ≤300ms · 1:1 约束补部分唯一索引）；③ goal_store 分层纪律（装配链路吞错+span · REST 显式 503/409）。
- **product 四裁定**：O-1 改判人工复活（否自动复活）；O-2 objective≠会话标题（两个实体）；O-3 接受 1:1；O-4 端侧最小面=常驻 goal chip+四动作，iOS 不晚于 hitl-approval task。
- **O-1~O-5 / R-1~R-2 全部关闭**，见 07 §6 终裁登记。
- **执行模式变更**：P0' 由 superagent 直推；自本论起实现段交付 bot（ops-desk-api issue #384 试单 · P1-T1 派单 #385）。
