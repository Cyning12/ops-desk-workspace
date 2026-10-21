# 收集任务：supervisor 五阶段 · 每阶段实际交付物及其持久化/观测位置映射

> 用途：面试叙事辅助——讲每个阶段时能指着说「这一阶段的产出落在这里，可以这样取证」。
> 纪律：**只读核查，不改任何文件**；每条结论带 file:line；存疑单独立清单，不得靠猜补全。

## 仓库与拓扑

- 仓库：/Users/cyning/Desktop/Ops-desk/ops-desk-api（FastAPI + LangGraph，master）
- 图拓扑真值：app/ops/lg_rag/multi/graph.py:96-104
  START → strategy_builder → supervisor → subtask_join → Send 并发工人(rag_subtask/info_extract/tool_exec) → observe → aggregator → critic_node → END/回环
- 五阶段划分：①收窄 strategy_builder ②规划 supervisor ③派发与执行 join+workers+observe ④聚合与质检 aggregator+critic ⑤落地 SSE/落盘（图外，app/ops/lg_rag/sse_stream.py, run_worker.py, router.py replay）

## 要回答的问题

每个阶段的「实际交付物」（该阶段产出的具体数据，如 allowlist、plan、subtask_results、react_observation、critic_verdict、最终 answer、error 帧）分别落在哪些**可观测/可取证载体**上：

1. SSE 帧：event_type + 发射点 file:line（app/ops/lg_rag/sse_stream.py）+ 落 ops_lg_rag_run_events 的写入点（app/ops/lg_rag/event_store.py）
2. LangGraph state 键：写回键名 + 写回点 file:line（app/ops/lg_rag/state.py + 各节点 return dict）
3. Langfuse span metadata 键：键名 + 写入点（app/ops/tracing.py；各节点 update_current_span_metadata 调用）
4. capability 回执/审计行：签发与调用回执的载体（app/ops/capability/，delegation.py 审计五动作）
5. 进程内 metrics 计数器：键名 + 位置
6. 纯 logger 行（无结构化载体的也要列出）

## 已知锚点（须验证+补全，不得照抄）

- builder.py:118-154（无 LLM）/:37-58 求交/:127 预算起计/:142-149 span 三键
- multi/nodes.py：supervisor :1192,1252-1279；join :893-1029；workers :1420-1610；observe :1984-2050；_observe :1656-1689；aggregator :2129-2164；write_replay_guard_skip :925-967
- strategy/critic.py:99-141（critic_node 写 critic_verdict + 前缀锁定 plan_prefix_ids/recoverable_point）
- sse_stream.py 帧位：run.start 334-341 / answer delta 361-363 / hitl.waiting 445-459 / done 家族 474-500 / error supervisor_plan 524-541 / worker_failed 542-557 / keepalive 73-75（不落盘）
- event_store.py:116-170（收尾判定）；hitl/router.py:520-560（resume 异步受理）

## 输出格式

主表（markdown）：
| 阶段 | 交付物 | SSE 帧(event_type + file:line) | state 键 | span 键 | metrics/回执/日志 | 落盘表 |
每阶段 1-N 行。

另附三张清单：
① **裸奔点**：哪一阶段的哪个交付物**没有任何持久化载体**（只活在内存/state 且 checkpointer 默认 InMemorySaver 时重启即丢的也算）
② **存疑清单**：与代码不符或无法确认的点
③ 复核基准：master commit hash