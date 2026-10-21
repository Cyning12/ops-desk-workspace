# 11 · supervisor 五阶段流转讲书稿 v1（10min 架构版主轴）

> **定位**：10min 架构版的 5min 主轴。按时间线五阶段讲完一次 run 的完整生命周期。
> **讲法**：每阶段四段 = **看点**（一句话钩子）→ **机制+数字锚点**（带 file:line）→ **这一阶段在哪被观察** → **追问钩子**（预判追问一句话答案）。
> **真源**：docs/08-interview/09 篇 + master 代码抽查（@31924af，PR #282 已确认在 master）。
> ⚠️ 原始 34KB 审核文（/tmp/lg_rag_supervisor_lifecycle.md）已被系统清理丢失；Step 编号映射为近似推断，引用一律以本表 file:line 为准。
> **红线纪律**：讲现状分清「已实现生效 / 默认关闭 / 已知未做」——见 §4 红线表；口径雷区见 §5。

---

## §1 五阶段总览（30 秒连诵版）

| 阶段 | 名称 | 一句话看点 |
|---|---|---|
| 一 | 收窄 | Builder 无 LLM 先把能力菜单收窄成白名单，planner 才上场——**fail-closed 从入口开始** |
| 二 | 规划 | 首次规划失败默认抛错停图——**绝不静默冒充单 rag 成功** |
| 三 | 派发 | Send 按依赖并发，join 闸先校验契约再签发——**缺字段不喂坏数据、改历史交人批** |
| 四 | 聚合 | observe 判「活干完没」，critic 判「答案行不行」——**没有待发步骤 ≠ 满足了问题** |
| 五 | 落地 | 断连只是退订——**执行与 HTTP 订阅解耦，每帧落盘可 replay 取证** |

---

## §2 逐阶段详表

### 阶段一 · 收窄（query → strategy_builder）

**看点**：给模型的不是「全部工具」，是「交集后的白名单」——收窄发生在 LLM 之前，连幻觉出高危工具的机会都没有。

**机制+数字锚点**：

- allowlist = candidates ∩ Registry ∩ Policy 基线可见集，**未知 key → 空集非全开**（app/ops/strategy/builder.py:37-58 build_allowlist_from_candidates，stripped 剔除留痕）；strategy_builder_node 无 LLM（builder.py:118-154）。
- **6+2 历史窗口**：6 轮全量 + 更早按 2 轮一组合摘要（app/ops/lg_rag/continuity.py:48-49 常量、52-87 compress_window；⚠️ 09 篇写 44-79 行号偏移，已更正）。
- **32 步预算从 builder 入口起计**（builder.py:127 bump_supervisor_step）；单能力范围上限 MAX_SCOPE_IDS=64（builder.py:62）。
- 跨用户 thread → 404 不泄露存在性（app/ops/lg_rag/router.py:199-213）。

**这一阶段在哪被观察**：span strategy_builder_catalog_count / allowed_count / stripped_ids（builder.py:142-149）；空 allowlist 不是 error——降级单 rag + span supervisor_empty_allowlist（app/ops/lg_rag/multi/nodes.py:1154-1168）；日志「strategy_builder 剔除非法/不可见 capability id」。

**追问钩子**：

- 「为什么不直接让模型自己选工具？」→ 只裁剪防不住幻觉 id，所以可见裁剪和执行拦截双管（capability/baseline.py:57-59）。
- 「收窄成空菜单怎么办？」→ 显式降级单 rag + 标记，不假装 supervisor 跑过。

---

### 阶段二 · 规划（supervisor 拆 plan）

**看点**：首次规划失败默认 fail-closed——一帧 error 帧就是终态，其后没有 done，失败语义用户可见、前端可重试。

**机制+数字锚点**：

- **≤4 子任务**（nodes.py:86 MAX_SUBTASKS，cap 外不校验直接截断 :174-211）。
- **32 步预算**（budget.py:18 DEFAULT_MAX_SUPERVISOR_STEPS，env LG_RAG_SUPERVISOR_MAX_STEPS）⚠️ 口径：是 supervisor **总步**（每节点入口 bump），**不是 32 次 LLM 调用**，也不计 rag 子图步数（graph.py:21 注释）。
- **2 ReAct 轮**（budget.py:33-37 LG_RAG_REACT_MAX_ROUNDS）——步数与轮数是两个维度（graph.py:21-22）。
- supervisor_node = complete 一次 + parse_only，**不双重 LLM**（nodes.py:1125-1207）；非法 tool id → structured fallback。
- 无 locked 前缀（=首次）规划失败 → raise SupervisorPlanError 停图（nodes.py:1252-1279）。

**错误帧**：error{stage:"supervisor_plan", retryable:true} **恰一帧即终态**（sse_stream.py:524-541），经 emit 落 ops_lg_rag_run_events。

**这一阶段在哪被观察**：span supervisor_plan_failed / supervisor_fallback / structured_output_fallback / supervisor_invalid_tool_id / subtask_count / plan_prefix_len（nodes.py:1258-1270, 1316-1335）；日志「lg_rag supervisor 首次规划失败，fail-closed 停图 run_id=%s」。

**追问钩子**：

- 「一点容错都没有吗？」→ 有灾备：LG_RAG_SUPERVISOR_PLAN_ON_FAIL=single_rag 显式 env 开，降级全程带 degraded 标记（nodes.py:1110-1122, 1280-1291）；默认 error 是刻意的。
- 「重规划失败也停？」→ 不停：有 locked 前缀说明已有战果，沿用未解决后缀、**不换 subtask_id**（防重放，nodes.py:1216-1250）。

---

### 阶段三 · 派发（subtask_join → Send 并发工人）

**看点**：join 是派发前的最后一道闸——先校验步骤契约，再签发委派令牌；校验不过的子任务写成带原因码的 blocked 终态，不是模糊报错。

**机制+数字锚点**：

- 拓扑真值：START→builder→supervisor→join→条件 Send；工人→join 回环；observe/aggregator/critic 边（graph.py:96-104 + 52-74 三张条件边映射表；⚠️ 白板讲解别漏 observe 节点；图谱 flow 旧文档仍画 intent_node 是已知滞后，勿照旧讲）。
- route_next_subtask 按依赖+inflight 一批 Send 并发；**逐子任务重新签发委派令牌，重发/重规划一律重签发、禁续期**（nodes.py:1339-1372）。
- join 三段闸（nodes.py:893-1029）：①sc.gate 契约校验 → blocked 错误终态级联停（step_contract.py:58-84，原因码 contract_missing_field / prefix_touch_required→HITL）②delegation_issue_hitl_required 拦签发 ③write_replay_guard 孪生步 guard-skip（异 sid 同 canonical 已成功 → 不派发照抄 output + replay_of 台账）。
- **委派令牌 TTL 600s 墙钟禁续期**（delegation.py:43-46）；**六类拒绝 R-a~R-f**（delegation.py:54-62；⚠️ 口径：6 主类 + R-a 伞下 2 个审计单列 signature_invalid/secret_missing，被追问「篡改归哪类」时答得出）。
- 工人每次工具调用过**七层闸链**（capability/gateway.py:337-468：委派验签347→lookup351→enabled363→Policy380→熔断405先于配额「先谈别打了再谈打几次」→kill switch+配额422→参数校验444）。

**这一阶段在哪被观察**：SSE subtask.progress（running/step/done + 可读 message 模板，progress_stream.py:78-134）；span step_contract_blocked(+_by_reason)（nodes.py:1020-1026）、write_replay_guard_skip + replay_of（:974-991）；审计**五动作词表** token_issued / token_issue_hitl_required / token_superseded / token_verified / token_rejected:（delegation.py:65-69）；gateway 侧 span policy_blocked / blocked=circuit|budget|kill_switch / args_schema_invalid。

**追问钩子**：

- 「blocked 和 error 什么区别？」→ blocked 是业务闸判定（带原因码、可转 HITL、经 subtask.progress 表面化），error 帧只给未捕获技术异常（error{stage:"lg_rag.worker_failed"}，sse_stream.py:542-557）。
- 「令牌为什么禁续期？」→ 续期 = 变相扩大授权窗口；重发即重签发，旧 nonce 作废（nonce_reused 拒绝类）。

⚠️ **本阶段红线**：delegation 默认 off（LG_RAG_DELEGATION_MODE，off=整段短路零 diff，delegation.py:95-100）；SECURITY_INPUT_ISOLATION_ENABLED 默认 false（slots.py:27,291-298）。

---

### 阶段四 · 聚合（observe → aggregator → critic）

**看点**：两个收口判定分开做——observe 每轮判「活干完没/要不要人」，critic 收尾判「答案行不行/要不要再来」；一个要确定性信号，一个要确定性规则。

**机制+数字锚点**：

- observe_node：确定性信号判定，verdict=replan/settle（nodes.py:1984-2050）；**hitl_pending → interrupt() 真挂起**。
- aggregator_node 独立节点：LLM 综合 subtask_results → 分节 markdown，token 经 answer_stream 桥流式出帧（nodes.py:2129-2147+，answer_stream.py:1-24 contextvar sink 机制——只有终答 token 进 SSE）。
- **critic = 规则 stub 纯函数**（app/ops/strategy/critic.py:1 文件头自述「S4 · 无 LLM 主路径」；:47-61 decide_critic_verdict：无 error→pass / error+空 allowlist→rebind / error+非空→retry_planner / 全局预算耗尽→强制 end）。
- **MAX_INNER_RETRIES=1 / MAX_REBINDING=1**（critic.py:27-28）；**全局 32 步/墙钟耗尽优先于局部 1+1 回环额度**（critic.py:54-56, 80-81）。

**这一阶段在哪被观察**：SSE answer delta + 终帧 {content, final:true}（sse_stream.py:361-363, 196-204）；span react_round / react_verdict / react_unsatisfied / react_hitl_pending（nodes.py:2036-2044）、critic_outcome / inner_retry_count / rebinding_count（critic.py:142-149）。

**追问钩子**：

- 「critic 为什么不用 LLM？」→ 收尾判定要确定性、可测试、可重现；LLM 评委引入不可重现性，stub 是设计如此（讲现状必须这么说）。
- 「HITL 挂起靠什么？」→ 真靠 checkpointer：interrupt 期间节点 return 不进 checkpoint（nodes.py:2003-2005）——所以 Postgres checkpointer 闸控开启前，跨进程/重启不可恢复是明示边界，不是暗坑。

---

### 阶段五 · 落地（SSE 逐帧落盘 / 断连 / 孤儿补偿 / replay）

**看点**：SSE 是「只读订阅者」——断连只是退订，worker 照跑；每一帧都是一条数据库记录，事后可以不重跑 LLM 原样回放。

**机制+数字锚点**：

- emit：seq 单调 + 后台 persist_run_event 落 ops_lg_rag_run_events（run_id+seq 唯一，sse_stream.py:278-328；表 models.py:327-328）⚠️ 口径：落盘以 if user_id 为条件（:295）且后台尽力（persist 失败只 log 不阻断已发帧 :318-323）——HTTP 路径必登录故实际全落，但不说「每帧必落」。
- 断连 = aclose 本订阅，**不 cancel worker**（sse_subscribe.py:59-63）；**不赌 ASGI disconnect 事件**（Wave A 裁定）。
- run_id 单飞：进程内 dict（run_worker.py:93-165）——⚠️ 多副本 DB 租约已知未做。
- **孤儿补偿**：无终帧且无活跃 worker → 补 done{status:"disconnected"}，默认陈旧 **300s**（run_worker.py:185-238，env LG_RAG_ORPHAN_STALE_SECONDS）。
- **replay**：cursor 非法 422 / 跨用户 404 / 在飞 409+Retry-After:2，seq>after_seq 重放（router.py:372-428）——刷新页面 = 断点续看，不重跑 LLM。
- **30s keepalive comment**：不落盘、不占 seq（sse_stream.py:73-75）。
- 审批消费 TTL **3600s**（nodes.py:296-310）；resume **异步受理**秒回 200（hitl/router.py:520-560；同步实测 130-310s 超前端 30s 超时——所以必须异步），恢复段帧照常同 run_id 落盘，前端靠 replay.cursor 追帧。

**这一阶段在哪被观察**：终帧家族四态——done（正常）/ done{degraded:true}（灾备）/ done{status:"waiting_approval"}（等人批）/ done{status:"disconnected"}（断连/孤儿补偿）全部落表（sse_stream.py:370-500）；结构化日志「lg-rag orphan compensated」「lg-rag event persist failed」「lg-rag run_worker single-flight reuse」。

**追问钩子**：

- 「进程崩了呢？」→ 孤儿扫描 300s 后补 disconnected 终帧，已落盘的帧 replay 仍可取——失败语义显式，不是挂着没人管。
- 「多副本部署怎么办？」→ 照实说：单飞是进程内 dict，DB 租约是已知边界未做。

---

## §3 SSE 帧全清单（event_type 取值）

| event_type | 含义 | 产出处 |
|---|---|---|
| run.start | 起步帧 {run_id, thread_id, mode, query}（query 是历史面标题真源） | sse_stream.py:334-341 |
| answer（delta） | 终答 token 流 {delta}；仅 aggregator/direct_answer token 进 SSE（contextvar sink 桥） | sse_stream.py:361-363；answer_stream.py |
| answer（final） | 终答整段 {content, final:true}；basic/router 无 aggregator 补 {content:"", note:"no_aggregator"} | sse_stream.py:196-204, 488-489 |
| subtask.progress | 子任务进度：running / step（里程碑+detail）/ done（完成摘要+可读 message） | progress_stream.py:78-134；sse_stream.py:184-195, 365-368 |
| node.progress | 非子任务非终答节点的 updates 摘要（strategy_builder/observe/critic_node 等） | sse_stream.py:205 |
| hitl.waiting | 图被 interrupt() 挂起：{reason:"hitl_waiting", requests:[…], unpersisted}，恰一帧后 break | sse_stream.py:445-459 |
| done | 正常终帧 {run_id, thread_id, latency_ms}；灾备降级附加 degraded:true | sse_stream.py:490-500 |
| done{status:"waiting_approval"} | HITL 挂起终帧（在等人批，不是跑完了） | sse_stream.py:474-487 |
| done{status:"disconnected"} | 断连/孤儿补偿终帧（worker 内补偿 + 孤儿扫描补偿同语义） | sse_stream.py:370-389；run_worker.py:218-231 |
| error{stage:"supervisor_plan"} | 规划失败 fail-closed 终帧，retryable:true，恰一帧即终态（其后无 done） | sse_stream.py:524-541 |
| error{stage:"lg_rag.worker_failed"} | 旁路流式调用未捕获异常终帧，retryable:true | sse_stream.py:542-557 |
| （非 event_type）keepalive | SSE comment 保活，30s 周期，不落盘不占 seq | sse_stream.py:73-75；sse_subscribe.py:51-54 |

收尾判定面：event_type ∈ {done, error} 即 run_stream_closed 真（event_store.py:116-118, 144, 170），replay 409 据此判定。

---

## §4 红线表（本维度 default-off / stub / 未做全集）

| 项 | 状态 | 锚点 | 口径 |
|---|---|---|---|
| delegation 委派令牌 | 默认 off（off=整段短路零 diff） | delegation.py:95-100；LG_RAG_DELEGATION_MODE | 「三档灰度 off/observe/enforce，先量后闸」 |
| Postgres checkpointer | 闸控默认关（InMemorySaver 默认） | checkpointer.py:27-38；LG_RAG_HTTP_CHECKPOINTER | 「恢复入口显式报错，不假装成功」 |
| critic | 规则 stub 无 LLM | critic.py:1,47-61 | 「设计如此：收尾判定要确定性可重现」 |
| MEMORY_FACTS / memory 注入 | 默认关 + supervisor 主链路零消费 | graph.py:161-162；nodes.py:1193-1199, 2064-2072 | 「机制已证零消费（双方自建 prompt），运行时实证待跑」 |
| SECURITY_INPUT_ISOLATION | 默认 false | slots.py:27,291-298 | 闸控装配 |
| Langfuse tracing | env 开关默认关（no-op 零成本） | tracing.py:1-11；OPS_CHAT_TRACER | 「可选装配，不开不影响主链路」 |
| metrics | 进程内计数 | metrics.py:11-13 | 多实例各一份已知边界 |
| RunWorker 单飞 | 进程内 dict | run_worker.py:93-165 | 多副本 DB 租约未做，照实说 |
| 孤儿补偿接线 | 2026-10-20 完成接线（口径） | run_worker.py:185-238；挂点 file:line **待回填** ← 用户侧 | 同 doc 10 §3.5 |

## §5 口径修正清单（被追问时别踩雷）

1. ❌「32 次 LLM 调用」→ ✅ supervisor **总步** 32（每节点入口 bump，不含 rag 子图步数，graph.py:21）。
2. ❌「六类拒绝」被追问「篡改归哪类」→ ✅ 6 主类 + R-a 伞下 2 审计单列 signature_invalid / secret_missing（delegation.py:54-57）。
3. ❌「每帧必落盘」→ ✅ if user_id 条件 + 后台尽力（persist 失败只 log 不阻断，sse_stream.py:295,318-323）；keepalive 不落不占 seq。
4. ❌「resume 同步续跑」→ ✅ **异步受理**秒回 200，前端 replay.cursor 追帧（hitl/router.py:520-560）。
5. 6+2 窗口行号：continuity.py:48-87（09 篇写 44-79 是偏移，内容属实）。
6. 拓扑白板别漏 **observe 节点**；条件边映射表在 graph.py:52-74（96-104 只是边注册段）。图谱 flow 旧文档仍画 intent_node 是已知滞后，勿照旧讲。
7. 「事件流/run_id」：resume 后帧接同一 run_id 续 seq 语义属实，但机制是异步受理+replay 追帧，不是同步续跑。
8. 步数与轮数两个维度：32 步是全局预算，2 轮是 ReAct 收口次数（budget.py:18 vs :33-37）。

## §6 时长压缩锚点

- **30 秒版**（电梯）：§1 总览表五句连诵 + 收尾「全链路的纪律就一条——失败显式化：每一阶段的错误都有专属帧、专属 stage、专属落盘位置，没有任何一处静默」。
- **2 分钟版**：每阶段一句看点 + 一个数字（6+2 / 4 子任务 / 600s / 1+1 回环 / 300s），观察段全砍，只留阶段五一句「断连只是退订」。
- **10 分钟版**：本稿全量（5min 五阶段 + 前后衔接见 doc 09/10）。

---

*v1 · 2026-10-20 · 真源：09 篇 + master@31924af 子代理逐锚点抽查（原始 34KB 审核文已失，本表接替其证据链角色）*

