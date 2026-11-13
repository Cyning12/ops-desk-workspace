# 06 · 开工就绪包（P0' 任务卡与开工检查表）

> 日期：2026-11-13。状态：**Round 4 终局裁定已收口，三方评审一致 GO（附条件，已全部折算进任务卡）；待负责人最终拍板**。
> 前置阅读：本目录 README（一页结论）、05（讨论全程，含 R3 代码校验）。

## 1. Round 4 终局裁定汇总

| 编号 | 裁定项 | 结论 | 关键验收 |
|---|---|---|---|
| A1 | run 一等实体表 | **新建 `ops_lg_rag_runs`**（不复活旧 ops_runs）：run_id String(64) PK（uuid4().hex，与事件表同型零迁移）、tenant_id 必填、user_id FK、thread_id、status、created_at/finished_at；RunWorker start/finish 写入；run_events.run_id **不加 FK**（orphan 补偿先扫事件后补 run 行，顺序容错）、uq(run_id,seq) 不动 | orphan 扫描改走 runs 表；replay/resume 行为不变；不破 lg-rag-sse-v1 freeze |
| A2 | Goal 落地 | **图零改动，落图为外状态**：新建 `ops_goals(goal_id, tenant_id, thread_id, objective, status)`；P1 切入 = harness 在 stream 入口把 goal 摘要注入 query 前缀；status 规则流转（不让 LLM 自判） | 同 goal 跨 ≥3 轮会话可续；supervisor 五阶段图 diff 为零 |
| A3 | 旧遗产下线顺序 | ① 摘 `app/ops/router.py:33` chat_ws 注册（安全优先独立先行）→ ② 删 `chat/{ws,graph,service}.py` → ③ 归档导出后 alembic drop ops_runs/ops_run_events/ops_sessions_chat → ④ chat/router.py 410 端点保留为契约墓碑 | /api/ops/chat/ws 连接拒绝；全仓无旧 ChatState 引用 |
| A4 | worker 进程化 | 当前**不进程化**。触发阈值（任一）：并发在飞 run 持续 >8；单 run P95 >10min 且月部署 ≥4 次；需要 API 双副本 | — |
| P1 | FC 主路径 | **维持 supervisor plan-JSON + capability ainvoke**，不引入模型原生 FC。重估触发（任一）：Langfuse 观测 plan-JSON 解析失败率 >5%；子任务并行突破 ≤4 上限；P2b MCP 远端工具 >20 个 | 无代码变更，裁定入档即关闭 |
| P2 | checkpointer 默认开 | **Go**。纯 env 翻转无 DDL；存量 run 无 checkpoint 属预期（503 防御保留）。灰度三步：测试环境 HITL 全链回归 → 生产单副本翻转 → 观察 1 周 resume 错误率 0。回退 = env 关回 | freeze 回归通过 + N-R2-1 复测关闭 |
| P3 | 审计统一视图 | P0' 合格线 = **一张 DB view `v_audit_unified`**（union receipts/llm_usage/hitl_requests，公共列 ts/tenant_id/user_id/run_id/domain/action/outcome，带 tenant_id 过滤）。不做端点、不做聚合页 | 按 run_id + 时间窗一条 SQL 拉出跨三域执行链 |
| P4 | 记忆抽取灰度 | 顺序：**读 → 写 → 经验**（MEMORY_FACTS_ENABLED → MEMORY_FACTS_EXTRACT_ENABLED → MEMORY_EPISODES_WRITE_ENABLED），每步观察 1 周、写入行 100% 可在 admin/memory 浏览与 revoke；P0' 不动默认全关 | 任一不达标立即回关上一开关 |
| P5 | ws.py | **直接下线，不带闸保留**（未鉴权 + 自述 do not expose publicly + 功能被 lg-rag SSE 全覆盖），与旧 chat graph/service 同批清除 | 见 A3 |
| D1 | 面板降级验收 | ① P2a：对话窗问答与面板人工核对一致（3 条金样全过）+ 工具在 /capability 页可见且 side_effect=read；② P3：一级导航 ≤5 项且不含旧面板，Obs/LC/Capability 归管理员区；③ P4：主导航无面板页 + 一次真实会话产出至少一种面板 artifact | 分阶段各自验收 |
| D2 | IMWebSocketClient | **保留但冻结**：不删、不接、不开发，头注释标"实验资产·冻结"；P3 推送通道选型时复评，届时仍无需求则删 | 编译通过、主链路零引用 |
| D3 | iOS 审批落地 | 确认随 lg-rag 主链路 task 落地（流内就地批准 + pending 手动拉取），不等 P3、不接 APNs。task 排序：mainline → hitl-approval → replay-resume → history；contract-layer 尽快 CLOSE；任意时刻最多 2 个并行 | — |
| D4 | 简报刷新 | **改写 `00-project-brief.md`**（不新发版本，避免两份画像并存再次脱节）。lead 起草、product 审定定位/范围两节 | 刷新范围见 §5 |
| D5 | MVP-1 叙事 | 「你可以把一件运维事项交给 OpsDesk，它会跨多轮对话记住目标并持续推进，而不是每轮从零开始。」 | — |

## 2. 冲突与组织人裁定（R4 唯一跨域冲突）

**C-R4-1 · iOS WS 实验资产去留**：architect（A3②）主张随服务端 ws.py 同批删；product（D2）主张保留冻结至 P3 推送选型复评。
**裁定：采纳 D2（保留冻结），architect 异议记录在案。** 理由：该资产本就未接主链路、与服务端端点无运行时依赖，冻结零成本而删除不可逆；服务端 ws.py 下线后它失去对端，恰是"冻结不开发"语义的强化而非矛盾。若 P3 复评仍无需求，按 D2 删除。

## 3. P0' 任务卡（落 ops-desk-api 仓，走 spec-wave verify + HG-AUDIT-R1 闸）

> 全局红线：不破 lg-rag-sse-v1 freeze 词表；不触发 tenant freeze F1–F6（全部新 DDL 含 tenant_id）；每张卡独立可回退。

| # | 任务 | 范围（涉及文件） | 验收标准 | 依赖 |
|---|---|---|---|---|
| T1 | 安全收口：WS 下线 | 摘 `app/ops/router.py:33` chat_ws 注册；删 `app/ops/chat/ws.py` | /api/ops/chat/ws 连接拒绝；CI 绿 | 无，**最先行** |
| T2 | 旧 chat 遗产清除 | 删 `chat/graph.py`、`chat/service.py`；归档导出后 alembic drop ops_runs/ops_run_events/ops_sessions_chat；chat/router.py 410 墓碑保留 | 全仓零旧 ChatState 引用；迁移 up/down 通过 | T1 |
| T3 | checkpointer 默认开 | `LG_RAG_HTTP_CHECKPOINTER` 默认值翻转为 postgres（保留 env 回关）；灰度三步；N-R2-1 复测 | hitl-browser-decide-v1 freeze 回归通过；观察期 resume 错误率 0；N-R2-1 关闭 | T1（安全口子先收） |
| T4 | run 实体化 | 新建 `ops_lg_rag_runs`（DDL 见 A1）；RunWorker start/finish 写入；orphan 扫描改走 runs 表 | replay/resume 行为不变；orphan 补偿不再全扫事件表 | T3（status 流转依赖 resume 链完整） |
| T5 | goal 落表（仅 DDL） | 新建 `ops_goals`（见 A2），仅落表零功能；注入与状态流转属 P1 | 迁移通过、tenant_id 必填约束生效 | 无（可与 T4 并行） |
| T6 | 审计统一视图 | `v_audit_unified` SQL view（定义见 P3） | 按 run_id+时间窗一条 SQL 拉出跨三域执行链 | 无 |
| T7 | 文档与契约批 | 见 §5 清单（workspace 仓为主，iOS AGENTS.md 落 ops-desk-ios 仓） | spec-wave verify 通过；无暗文档 | 无 |

执行顺序约束（三方条件折算）：**T1 → T3 → T4** 为关键链；T2 紧随 T1；T5/T6/T7 任意并行。

## 4. 开工条件检查表（三方评审条件 → 折算落点）

| 条件 | 来源 | 折算 | 状态 |
|---|---|---|---|
| P0' task 单过 spec-wave + HG-AUDIT-R1 闸 | platform① / product① | §3 任务卡即 task 单草案，开工第一步正式落仓过闸 | ☐ 待办 |
| ws 下线先于 checkpointer 默认开合并 | platform② | 顺序约束 T1→T3 | ☑ 已入卡 |
| 审计 view 必含 tenant_id 过滤 | platform③ | T6 验收 | ☑ 已入卡 |
| 不破 lg-rag-sse-v1 freeze | platform④ / 全局红线 | 全局红线 | ☑ 已入卡 |
| C-1 先于 A1/A2 合并 | architect 前置 | T3→T4 顺序；A2 注入属 P1 | ☑ 已入卡 |
| 简报刷新 + 契约修订纳入同批 | product④ | T7 | ☑ 已入卡 |

## 5. 简报刷新与契约修订清单（T7 明细）

1. **改写 `docs/01-scope/00-project-brief.md`**：多轮/ReAct 条款改"已随 lg-rag 上线"；L3 底座改 Qdrant 默认口径；面板降级标注"落地页已切 /chat、导航降级为 P3 路线项"；记旧 chat 410 下线。lead 起草、product 审定定位/范围节。
2. **`docs/contracts/chat-stream-v1.md`**：追加「已被 lg-rag-sse-v1 + 03-general-agent 取代」状态行（整篇重写为 v2 另立 task）。
3. **`docs/README.md`**：目录树补索引 `01-scope/03-general-agent/`（消除暗文档）。
4. **`docs/_tech_graph/`**：清理 shared/graph.json 残留；00_main.graph.yaml 补 runs/run_events 数据流边。
5. **ops-desk-ios `AGENTS.md:64`**：删除已 410 的旧端点引用，改指 lg-rag 契约。

## 6. 开工后序列（确认衔接 04 路线图）

P0'（T1–T7）→ P1 Goal 收敛（ops_goals 注入 + 状态流转 + 同 goal 跨轮验收）→ P2a 面板数据工具化（D1① 金样验收）→ P2b 生态（MCP client + skill 加载器）→ P3 任务化（任务卡片/轨迹回放/面板入口降级 D1②/APNs 选型复评 D2）→ P4 通用化（D1③）。