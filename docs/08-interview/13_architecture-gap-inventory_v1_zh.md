# 13 · 架构缺口清单（Gap Inventory）v1

> 面试定位：方向⑤（how-fail）与方向⑥（what-next）的弹药库。
> 收录截至 v1 核查（master）发现的所有架构级遗漏/缺口，按缺口性质分五类。
> 使用纪律见 §6。所有锚点基于 ops-desk-api 仓 master。

---

## §1 A 类 · 已实现但默认关（部署态缺口，10 处）

| # | 缺口 | 锚点 |
|---|---|---|
| 1 | 委派令牌三档默认 off（observe/enforce 待命） | app/ops/capability/gateway.py:277-334 |
| 2 | LLM 预算检查点默认 off（零直通） | app/llm/providers/base.py:44-47 |
| 3 | PG checkpointer 闸控，默认 InMemorySaver（重启全丢） | app/ops/lg_rag/run_worker.py:138-142 |
| 4 | 防重持久化 store 默认不启用（幂等键查了白查） | OPS_CAPABILITY_PERSISTENCE，app/ops/capability/__init__.py:111-112 |
| 5 | Langfuse tracing 默认关；打分采样默认 0 | app/ops/lg_rag/tracing.py:1-11 |
| 6 | 真摘要默认关（窗口外只剩占位） | SESSION_SUMMARY_ENABLED，app/ops/lg_rag/continuity.py:14-17 |
| 7 | query rewrite（指代消解）默认关 | LG_RAG_QUERY_REWRITE_ENABLED，continuity.py:19-24 |
| 8 | observe 模型满足度闸默认关 | LG_RAG_REACT_SATISFACTION，app/ops/lg_rag/multi/nodes.py:1692-1740 |
| 9 | MCP 接入默认关 | OPS_CAPABILITY_MCP_ENABLED，capability/__init__.py:107-108 |
| 10 | HITL auto_resume 扫描器仅 MODE_AUTO 才挂 | app/main.py:49-62 |

讲法：这不是「没做完」，是「先量后闸」的灰度纪律——每项都有 env 开关与切换标准（如 delegation 的 would_block 率≈0 才切 enforce）。

## §2 B 类 · 写侧/读侧不匹配（接线缺口，3 处）

| # | 缺口 | 锚点 |
|---|---|---|
| 11 | ctx._host_policy.allow_write 读侧生效，但 lg_rag 链路无注入方——env 之外没有单次放行通道 | app/ops/capability/policy.py:83-93（全仓仅 tests 写） |
| 12 | memory 写入侧在跑、注入侧休眠（零消费实证后关停）——语料在攒但没人消费 | app/ops/lg_rag/sse_stream.py:508；continuity.py:5-12 |
| 13 | 孤儿补偿按 2026-10-20 已接线口径（doc 10 §3.5 挂点待回填 file:line） | app/ops/lg_rag/run_worker.py:185-238 |

⚠️ B 类是最容易被深挖打脸的点：读侧生效+写侧缺失 = 「功能看着在，实际到不了」。面试前必须背熟 #11/#12 的真实状态。

## §3 C 类 · 明确 stub / 未做（功能缺口，4 处）

| # | 缺口 | 锚点 |
|---|---|---|
| 14 | critic 纯规则 stub：只看有无 error 键，不看内容；最终答案无语义验收 | app/ops/strategy/critic.py:1,47-61 |
| 15 | Result agent 未做（verdict 路由骨架全接通，只是换判定器） | critic.py:47-61 + app/ops/lg_rag/multi/graph.py:52-74 |
| 16 | memory ④a 真实构建未做 | continuity.py:5-12 |
| 17 | 无 per-node 模型分档：全图 5 个 LLM 调用点同档同模型 | app/ops/lg_rag/nodes.py:35-40 _ROUTER_MODEL |

讲法：C 类全部「骨架已留位」——#15 是最典型：verdict 路由（retry_planner/rebind/end）全接通，Result agent 只是把规则判定器换成独立语义验收，且口径已定「只能否决不能放行，放行权永远在确定性信号」。

## §4 D 类 · 取证/观测缺口（4 处）

| # | 缺口 | 锚点 |
|---|---|---|
| 18 | turns 表无 run_id 列：结论↔过程关联只能靠 thread_id+时间窗 | app/db/models.py:306-321 |
| 19 | react_observation 全文、supervisor 原始输出全文无持久化载体（仅 tracing 开时的 span） | doc 11 §7 裸奔点 5/6 |
| 20 | delegation 审计、闸拒不落回执表（logger+span only，重启即失） | app/ops/capability/delegation.py:65-69 |
| 21 | metrics 进程内计数，多实例各一份无聚合 | app/ops/lg_rag/metrics.py:11-13 |

讲法：#18 可转成路线图项——「结论行补 run_id 外键」是长期对话管理模块要补的一张索引。

## §5 E 类 · 设计内在代价（非 bug，面试必须主动认）

| # | 代价 | 口径 |
|---|---|---|
| 22 | 窗口外历史只剩占位，语义细节实丢 | 「确定性窗口是保守选择，三件套灰度路线已铺」 |
| 23 | 结论与过程分离 → 模型跨轮取不到证据细节 | 「过程留给 replay 取证；模型侧靠摘要件演进」 |
| 24 | 32/2/4 是保守默认无测算过程 | 「设计期保守默认+env 可调」，别说「测算出 32」 |

## §6 面试使用纪律

| 类 | 策略 |
|---|---|
| A 已实现默认关 | **主动讲**——灰度方法论是最硬的牌，「先量后闸」展示工程成熟度 |
| B 写读不匹配 | **背熟防打脸**——被问必须秒答真实状态，含糊=穿帮 |
| C stub/未做 | **被问才答**，答必带「骨架已留位/演进路线」；主动认比被拆穿强 |
| D 取证缺口 | 配 replay 机制讲——「能取证什么、缺什么、补法」三段式 |
| E 内在代价 | 展示权衡意识——每个代价都有「为什么认账」的理由 |

总口径：**「可见的缺口才是可治理的缺口」**——这份清单的存在本身就是方法论证明：每条都有锚点、有状态、有演进位。

---

## §7 iOS 恢复期并行优先级（2026-10-22 定）

> 背景：个人恢复 iOS 技术、对接 agent 交互期间，后端只做「挡对接的」+「零代码纯开关的」，大石头延后。

### P0 · 挡 iOS 对接，先做

| 项 | 缺口 | 为什么挡 iOS | 成本 |
|---|---|---|---|
| #18 | turns 表无 run_id 列 | 客户端会话列表想挂「查看执行过程/replay」入口，必须能从结论行定位 run；没有它 iOS 侧只能按时间猜 | 小：alembic 迁移 + persist 写入 + API 透出 |
| #5 | Langfuse tracing 默认关 | 联调排障刚需——iOS 端帧流异常时要能拉 trace 对帧序 | 零代码：dev 环境开 env |
| — | （非后端缺口）iOS 侧帧契约消化：11 类帧 + 在飞 replay 409+Retry-After 退避 | doc 11 §3 帧清单即对接规格 | iOS 侧工作 |

### P1 · iOS demo 叙事完整度，按需

| 项 | 缺口 | 触发条件 | 成本 |
|---|---|---|---|
| #11 | allow_write Host 注入无 writer | 仅当 demo 要演示「审批后真正执行写」全闭环；否则演示审批流即可，写被拦反而显闸链 | 中：注入点+放行语义 |
| #3 | PG checkpointer 默认关 | 仅当 demo 要演示「挂起跨进程重启恢复」；单进程内 HITL InMemorySaver 已够 | 零代码：开 env |
| #1 | delegation 默认 off | 联调期切 observe 攒 would_block 数据，为日后 enforce 备料 | 零代码：开 env |
| — | （客户端轨）web 无独立审批页，只有 Chat 页内联审批（HitlApprovalCard 三入口+侧栏徽章+手动刷新不轮询） | 后端契约已冻结备好：GET /ops/hitl/pending + POST decide + POST resume（decide≠resume 两步钉死，仅本人 owner）；web 审批页与 iOS 审批 UI 并行开发、同契约互调，后端零改动 | 纯前端工作 |

### P2 · 顺手验证，不挡路

| 项 | 缺口 | 动作 |
|---|---|---|
| #6 | 真摘要默认关 | dev 开 env 观察多轮效果，为「长期对话管理模块」攒实证 |
| #8 | observe 模型满足度闸默认关 | dev 开 env 看误报率 |
| #20 | 审计/闸拒不落回执表 | 缓——iOS 阶段用 tracing 顶着 |
| #21 | metrics 多实例无聚合 | 缓——单机 demo 无感 |

### P3 · 大石头，专项立项（走完整 Harness 流程）

| 项 | 缺口 | 备注 |
|---|---|---|
| #14/#15 | critic stub / Result agent | verdict 路由骨架已留位；面试前 >2 周可起草 SPEC |
| #16 | memory ④a 真实构建 | 依赖 P2 #6 的实证数据 |
| #17 | per-node 模型分档 | 需先定分档策略（成本/质量矩阵） |

并行原则：**iOS 恢复期后端代码改动只放行 #18 一项**；其余全是开关翻转或纯 iOS 侧工作，不占设计带宽。

---

v1.1 2026-10-22 · +§7 iOS 恢复期并行优先级（P0-P3）

v1 2026-10-21 · 汇总 doc 10 §5 红线表 + doc 11 §4 红线表/§7 裸奔点 + 会话核查新增（#11/#17/#18 等） · 核查基准 ops-desk-api master