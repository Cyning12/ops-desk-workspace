# supervisor 五阶段 · 交付物持久化/观测位置映射（只读核查结果）

> 存档说明：本文为子代理（任务 Prompt 见同目录 stage-artifact-collection-prompt_v1_zh.md）只读核查的完整报告存档，浓缩版已回填 docs/08-interview/11_five-stage-supervisor-flow-script_v1_zh.md §7。

复核基准：`master @ e9529848dd7fcc905a650a7e9ead6e4a0645fda8`（唯一脏文件 docs/arch-browser/dist/site-data.json，与本次核查无关）。
图拓扑真值：app/ops/lg_rag/multi/graph.py:96-104。根 span：`lg-rag`（app/ops/lg_rag/graph.py:47-48,132-146，propagate_attributes session_id=thread_id）。

## 载体写入点总览（先记这些，后表只引用）

- **SSE→落盘**：所有业务帧经 `emit()` app/ops/lg_rag/sse_stream.py:278-328；有 user_id 时后台 task 落 `persist_run_event`（:295-327）→ app/ops/lg_rag/event_store.py:31-58 → 表 `ops_lg_rag_run_events`（app/db/models.py:327-328，唯一键 run_id+seq）。replay 读路径 `load_events_after` event_store.py:225-265 → POST /lg-rag/replay app/ops/lg_rag/router.py:382-428（在飞 409+Retry-After :401-409）。
- **Langfuse**：app/ops/tracing.py `trace_span` :162-210 / `update_current_span_metadata` :213-222 / `score_current_trace` :341-355（采样 OPS_EVAL_SCORE_SAMPLE_RATE 默认 0）；总开关 :114-127；nodes 内统一经 `_record_span_metadata` app/ops/lg_rag/multi/nodes.py:222-234。
- **capability 回执**：表 `ops_capability_receipts`（models.py:387-390）经 DbReceiptSink app/ops/capability/receipts.py:195-234；仅 `OPS_CAPABILITY_PERSISTENCE=db` 时装配（capability/persistence.py:31-67，import 时执行 capability/__init__.py:112）；默认 NullReceiptSink 只 `logger.warning`（receipts.py:68-74）。构建/过滤：`_build_receipt` gateway.py:471-514（只读且无 capture → None 不落；命中幂等未真执行 → None）；写能力**无论成败**都落（:522-532/:544-554）。
- **delegation 审计**：**不落表**（注释明写「记动作不记内容 · 不落新表」delegation.py:64）；载体 = `logger.info("delegation <action> <json>")` + span metadata `delegation_`*（audit_delegation delegation.py:132-147）。五动作词表 :65-69。
- **HITL 申请**：表 `ops_hitl_requests`（models.py:459）经 DbHitlStore app/ops/hitl/store.py:155-236；仅 `OPS_HITL_PERSISTENCE=db`（hitl/persistence.py:31-56，懒装配 get_hitl_store :59-64）；默认 NullHitlStore 不落库。
- **metrics**：进程内计数 app/ops/capability/metrics.py:24-39，`record_outcome` :55-85 由 gateway `invoke` :193 / `ainvoke` :208 唯一出口调用；`snapshot()` :88-120（scope=process_local）暴露于 GET /admin/capability/metrics app/ops/admin/capability.py:271-279；回执观测 /admin/capability/receipts :282-292；runtime 装配态 /admin/capability/runtime :81-107。
- **checkpointer**：默认 InMemorySaver（app/ops/lg_rag/graph.py:51-53，supervisor 图复用 multi/graph.py:105）；PG 需 `LG_RAG_HTTP_CHECKPOINTER=postgres`（app/ops/lg_rag/checkpointer.py:27-38），且 run_worker 仅 supervisor 模式装配 AsyncPostgresSaver（app/ops/lg_rag/run_worker.py:138-142）。

## 主表

| 阶段 | 交付物 | SSE 帧（event_type + file:line） | state 键（写回点） | span 键（写入点） | metrics/回执/日志 | 落盘表 |
|---|---|---|---|---|---|---|
| ①收窄 strategy_builder | allowlist | `node.progress`（role=strategy_builder，payload 含 allowed_capability_ids，经 _summarize_payload 键表 sse_stream.py:94-102 + map_node_update :205 + emit :473） | `allowed_capability_ids`/`allowed_skill_ids`（app/ops/strategy/builder.py:150-154） | `module`/`strategy_builder_catalog_count`/`strategy_builder_allowed_count`/`strategy_builder_stripped_ids`（builder.py:142-149） | allowlist 求交被裁 stripped 明细仅 `logger.warning`（builder.py:54-57）；scope_stripped/scope_truncated 仅 logger（builder.py:93-102） | ops_lg_rag_run_events |
| ①收窄 | 预算起计 | （同上 node.progress 帧顺带） | `supervisor_step_count`=1、首 bump 写 `supervisor_started_at`（builder.py:127 → budget.py:107-122，:113-114） | — | — | （state 仅 checkpointer；见裸奔 4） |
| ②规划 supervisor | plan（subtasks≤4） | `node.progress`（role=supervisor，payload 含 subtasks，截断 800 字符，sse_stream.py:94-102,205,473） | `subtasks`/`host_subtask_seq`/`inflight_subtask_ids`/`plan_prefix_ids`/`recoverable_point`（_stamp_host_plan nodes.py:656-708） | trace_span('supervisor') nodes.py:1190；键 `capability_catalog_count`/`subtask_count`/`subtask_types`/`supervisor_fallback`/`structured_output_fallback`/`supervisor_raw`/`plan_prefix_len`/`recoverable_point`（:1316-1335） | supervisor_fallback=True 时 `score_current_trace('stab.fallback',1)`（nodes.py:232-233，采样默认 0 不写）；非法 tool id `logger.warning`（:1203-1206） | ops_lg_rag_run_events |
| ②规划 | 降级/失败路径 | `error`{stage:supervisor_plan, retryable:true}（sse_stream.py:524-541，恰一帧即终态） | `supervisor_degraded`=True（灾备 single_rag，nodes.py:1290-1291） | 空 allowlist `supervisor_empty_allowlist`（:1154-1168）；首次失败 `supervisor_plan_failed`（:1258-1270）+ raise SupervisorPlanError（:1276-1279）；缺 run_id `supervisor_missing_run_id`（:1136-1148）；重规划 `replan_suffix_only`/`replan_carried_unresolved`（:1229-1248） | SupervisorPlanError 另落 `logger.warning`（sse_stream.py:529） | ops_lg_rag_run_events |
| ②规划 | delegation_scope 声明 | （含在 supervisor node.progress） | `delegation_scope`（nodes.py:1300-1315） | `delegation_scope_declared`/`count`/`stripped`/`truncated`（:1300-1315） | — | ops_lg_rag_run_events |
| ③派发与执行 join+Send | 委派令牌签发/拦截 | （拦截行体现在 subtask.progress 结果行 blocked_by=delegation_issue_hitl_required，nodes.py:999-1015） | `delegation_token` 注入 Send 载荷（route_next_subtask :1362-1365；签发体 _issue_delegation_token :454-479，subject_binding 四元组） | 签发/拦截走 audit span 键 `delegation_token_issued`/`delegation_token_issue_hitl_required` 等（delegation.py:132-147） | 审计 `token_issued`（delegation.py:470）/`token_superseded`（:464-469）/`token_issue_hitl_required`（nodes.py:999-1015）→ logger+span，**不落表** | （仅 SSE 帧行）ops_lg_rag_run_events |
| ③执行 workers | 进度 running/step | `subtask.progress`{status:running}（emit_subtask_running progress_stream.py:78-112；调用 nodes.py:1439）→ sink sse_stream.py:365-368；`subtask.progress`{status:step}（emit_subtask_step progress_stream.py:115-158；调用 nodes.py:1446-1453,1468-1474）；均经 emit 落盘占 seq | — | — | sink 异常仅 warning（progress_stream.py:104-112,149-158） | ops_lg_rag_run_events |
| ③执行 workers | subtask_results（每工人一条） | `subtask.progress`{status:done + subtask_result 摘要 + message}（map_node_update sse_stream.py:184-195） | `subtask_results`（merge_subtask_results state.py:141-182；rag :1490-1494 / _finish_worker :1397-1402 / join 写回 :1027-1028）；`inflight_subtask_ids`（:1019-1021） | info_extract `structured_output_fallback`（:1540-1549）；tool_exec 经 capability span（见下行） | 工人异常 error=repr 入结果行（nodes.py:1494）；done message 生成失败 warning（sse_stream.py:188-194） | ops_lg_rag_run_events |
| ③执行 tool_exec | capability 调用结果 | （含在上行 done 帧） | （结果行进 subtask_results） | capability span 键 `capability_id`/`kind`/`ok`/`args_summary`/`approval_id`/`risk_level`/`side_effect`/`receipt_id`/`policy`/`subtask_id`/`error`（_write_span_metadata gateway.py:1298-1343） | **metrics**：record_outcome（gateway.py:193/208 → metrics.py:55-85）；**回执**：写能力无论成败落 receipt（:522-532/:544-554）；**验签审计** `token_verified`（:306-312）/`token_rejected:<class>`（:313-320，enforce 拒 → ok=False 不落回执 :288-289）；delegation 注入 nodes.py:1595-1601 | **ops_capability_receipts**（仅 persistence=db）+ ops_lg_rag_run_events |
| ③收口 join | step_contract 拦截/重放守卫/预算补齐 | （blocked 行体现在 subtask.progress done 帧的 subtask_result） | 拦截/补齐均写 `subtask_results`（nodes.py:903-907 漏 id、:914-921 预算耗尽、:1027-1028） | `step_contract_blocked`/`step_contract_blocked_by_reason`（:1020-1026）；`write_replay_guard_skip`+replay_of（:985-991，结果行同名字段 :970-971） | write_replay_guard_skip 另落 `logger.info` JSON（:974-984） | ops_lg_rag_run_events |
| ③收口 observe | react_observation / hitl_requests | `node.progress`（role=observe；payload 只落 keys 列表——react_observation **不在** _summarize_payload 键表 sse_stream.py:94-102）；挂起时 `hitl.waiting`{requests,unpersisted}（sse_stream.py:445-459）+ `done`{status:waiting_approval}（:474-487） | `react_observation`/`hitl_requests`/`react_round`（observe_node return :2045-2050；判定 _observe :1656-1689）；批准应用 `hitl_unlocked_ids`/`hitl_interrupt`/react_round=0+剪旧结果（_apply_hitl_decision :1930-1981） | `react_round`/`react_verdict`/`react_unsatisfied`/`react_hitl_pending`/`react_hitl_unpersisted`（:2036-2044） | HITL 落库 `_persist_hitl`（:1810-1899，幂等键 run_id+subtask_id :1829-1838）；未落库 `logger.error`「HITL 申请**未落库**」（:1893-1897）+ SSE unpersisted 标记；hitl_persist_guard_skip/read_failed 日志（:1873,:1780-1785）；批准应用 logger.info（:1972-1980） | **ops_hitl_requests**（仅 OPS_HITL_PERSISTENCE=db）+ ops_lg_rag_run_events |
| ④聚合 aggregator | 最终 answer | `answer`{delta}（_answer_token_sink sse_stream.py:361-363，**每 delta 一帧一行落盘**）+ `answer`{content, final:true} 终帧（map_node_update :196-204） | `messages`=[AIMessage(answer)]（aggregator_node nodes.py:2164） | trace_span('aggregator')（nodes.py:2140，无附加 metadata 键）；LLM usage 走 update_current_generation_usage（tracing.py:225-253，complete 边界） | 空输出回退拼接 + `logger.warning`（nodes.py:2154-2163）；complete_answer_streaming :2147-2152 | ops_lg_rag_run_events；done 后 `persist_thread_turns`（sse_stream.py:503-507，thread_store） |
| ④质检 critic | critic_verdict / 前缀锁定 | `node.progress`（role=critic，payload 含 `critic_verdict`/`rebinding_count`；inner_retry_count 不在摘要键表） | `critic_verdict`/`inner_retry_count`/`rebinding_count`（critic.py:109-113）；retry/rebind 时 `plan_prefix_ids`(:134)/`recoverable_point`(:135) + SubtaskResultBatch replace 裁剪（:116-133）；判定纯函数 decide_critic_verdict :47-61（上限 MAX_INNER_RETRIES=1 :27 / MAX_REBINDING=1 :28） | `critic_outcome`/`inner_retry_count`/`rebinding_count`/`plan_prefix_len`（critic.py:142-149） | route_after_critic :76-84 → END/supervisor/strategy_builder | ops_lg_rag_run_events |
| ⑤落地（图外） | run.start / done 家族 / error | `run.start`{run_id,thread_id,mode,query}（sse_stream.py:334-341）；`done` 正常（:490-500，降级带 degraded:true :498）；`done`{waiting_approval}（:474-487）；`done`{disconnected}（_settle_disconnected :370-389；orphan 补偿 run_worker.py:218-232 + logger :237）；`error`{supervisor_plan :524-541 / lg_rag.worker_failed :542-557} | — | 根 span `lg-rag`（graph.py:47-48,132-146）；flush（sse_stream.py:566-567） | worker 启动/单飞复用/取消/失败 logger（run_worker.py:111,144,147,164）；event persist 失败 logger.exception（sse_stream.py:318-323） | ops_lg_rag_run_events |
| ⑤落地 | keepalive | SSE comment `: keepalive`（常量 sse_stream.py:73-75；HTTP 侧发射 sse_subscribe.py:44-53）——**不进 data JSON、不落盘**（注释 :72-73） | — | — | — | **无** |
| ⑤落地 | replay / 收尾判定 | replay 重放落盘帧（router.py:416-418） | — | — | 收尾判定 `run_is_terminal` event_store.py:94-126（error/done 行 :116-118）、`run_stream_closed` :129-149（:144）、`list_open_runs` :152-（:170）；resume 受理游标 _best_effort_replay_cursor hitl/router.py:506-517 | （读路径） |
| ⑤落地（HITL 恢复） | resume 受理与恢复段帧 | 恢复段帧经 `ResumeEventSink`（hitl/resume.py:87-156，`map_node_update` 复用）落同一 run 续 seq；受理响应含 replay.cursor（hitl/router.py:587-615） | resume 从 checkpoint 恢复（需 PG checkpointer，否则 503 checkpointer_not_configured hitl/router.py:571） | — | `resume_request` :520-615：preflight 守卫 :473-489 → 后台 `_run_resume_in_background` :492-503 → `_execute_decided_resume` :425-464（完成 logger :451-458；在飞登记 _RESUME_IN_FLIGHT :467-470 进程内）；失败仅 logger（:501,:574） | ops_lg_rag_run_events + ops_hitl_requests（状态已决行） |

## ① 裸奔点（无持久化载体 / 默认配置下重启即丢）

1. **delegation 审计五动作**（token_issued / token_issue_hitl_required / token_superseded / token_verified / token_rejected:）：只 logger.info + span metadata，明写「不落新表」（delegation.py:64,132-147）。tracing 关 → 只剩进程日志。
2. **capability metrics 计数器**：进程内 dict（metrics.py:24-39），snapshot scope=process_local（:97），重启归零、多实例各一份（:11-13）。
3. **delegation nonce registry / issuer seq / supersede 台账**：进程内（reset_delegation_state delegation.py:395-398）；一次性 nonce 消费状态重启即丢（token TTL 600s 兜底）。
4. **LangGraph state 全部键**（subtasks、subtask_results、react_observation、critic_verdict、delegation_token、hitl_checkpoint_id、plan_prefix_ids/recoverable_point 等）：默认 InMemorySaver（graph.py:51-53），**重启即丢**；LG_RAG_HTTP_CHECKPOINTER=postgres 才落 checkpoints 表，且仅 supervisor 模式装配（run_worker.py:138-142）。HITL 跨请求恢复在内存 saver 下不可能（checkpointer.py:30-38 注释明写）。
5. **react_observation 全文**：SSE node.progress 摘要不含该键（sse_stream.py:94-102），span 只有 react_* 计数/布尔（nodes.py:2036-2044）→ 观察内容正文**无任何持久化全文**，只在 state（见 4）。
6. **supervisor_raw（LLM 原始 plan 文本）**：仅 span 键（nodes.py:1316-1335）；SSE 只给 ≤800 字符 subtasks 摘要。tracing 关即无载体。
7. **builder stripped 明细 / scope_stripped / scope_truncated**：仅 logger.warning（builder.py:54-57,93-102）；span 有 strategy_builder_stripped_ids 但依赖 tracing 开关。
8. **capability 回执**：OPS_CAPABILITY_PERSISTENCE≠db 时 NullReceiptSink 只 warning（receipts.py:68-74），写操作回执不落库（persistence.py:63-66 启动告警「不可上生产」）。
9. **HITL 申请**：OPS_HITL_PERSISTENCE≠db 时 NullHitlStore 不落库（hitl/persistence.py:49-56）；留痕只有 SSE hitl.waiting{unpersisted:true} + logger.error（nodes.py:1893-1897）。
10. **RunEventBus._history / _workers 登记表 / _RESUME_IN_FLIGHT**：进程内（run_worker.py:30-71, hitl/router.py:467-470），重启即丢（晚到订阅者只能靠 DB replay）。
11. **纯 logger 行**（无任何结构化载体）：aggregator 空输出回退（nodes.py:2154-2163）、supervisor 非法 tool id（:1203-1206）、hitl_persist_guard_*（:1780-1785,:1873）、orphan 补偿（run_worker.py:237）、resume 各阶段（hitl/router.py:451-458,501,516,574）、auto_resume 审计 _audit（hitl/auto_resume.py:118-137）。

## ② 存疑/勘误清单（与任务书锚点的偏差 + 未完全确认项）

1. 任务书 builder 路径「app/ops/lg_rag/builder.py」有误：真值在 **app/ops/strategy/builder.py**（行号区间 :118-154 吻合）；critic 同理在 **app/ops/strategy/critic.py**（critic_node 实际 :99-150，父锚 :99-141 略短）。
2. 任务书 nodes.py:925-967「write_replay_guard_skip」：实际函数区间 **:960-996**（结果行字段 :970-971、logger :974-984、span :985-991），起点偏前。
3. 任务书 hitl/router.py:520-560「resume 异步受理」：实际 `resume_request` **:520-615**，异步投递在 :579-584；区间需扩到 615。
4. 任务书 event_store.py:116-170「收尾判定」：函数实为 `run_is_terminal` :94-126、`run_stream_closed` :129-149、`list_open_runs` :152-；SQL 条件行 :116-118/:144/:170 吻合，锚点指的是 WHERE 子句行而非函数头。
5. keepalive 常量确在 sse_stream.py:73-75，但**发射主路径在 sse_subscribe.py:44-53**（worker 内保留仅供单测，注释 :72-73）——两侧均不落盘，结论不变。
6. **answer delta 每帧落一行** ops_lg_rag_run_events（sse_stream.py:361-363 + emit 落盘 :295-327）：长回答会产生大量行，这是当前实现事实（T5.1 刻意设计），面试叙事时注意口径。
7. SSE critic 帧摘要只含 `critic_verdict`/`rebinding_count`；`inner_retry_count` 不在 _summarize_payload 键表（sse_stream.py:94-102），仅 state+span 可见。
8. app/llm/usage.py 的 LLM 用量落表（docstring :9「落表异常→log+计数」）未逐行核查表名/写入点——超出五阶段范围，如叙事涉及 token 成本需另核。
9. 工人节点 emit_subtask_step 的 step 词表（nodes.py:1446-1453,1468-1474 内联字符串）未逐一枚举。
10. aggregator span 无附加 metadata 键（仅 trace_span('aggregator') nodes.py:2140）——若叙事需要「聚合耗时」，只有 span 时长本身。

## ③ 复核基准

- 分支/提交：`master @ e9529848dd7fcc905a650a7e9ead6e4a0645fda8`
- 工作区脏文件：docs/arch-browser/dist/site-data.json（与核查无关，未读取未修改）
- 核查方式：只读（read/grep），未改任何文件。
