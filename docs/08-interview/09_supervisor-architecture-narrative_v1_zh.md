# 阶段三 · Agent 方向技术面作战手册（九）：supervisor 架构面试叙述框架

> 承接 `05`（八问 Q1–Q8）· `06`（十大细节方向）· `08`（三块承重墙深挖）。
> 本篇回答：**「完整掌握 supervisor 架构用于面试叙述」需要几个方向？**
> 素材真源：2026-10-19 supervisor 全流程架构审核（Step 0–14 逐节点证据链，全文备份 `/tmp/lg_rag_supervisor_lifecycle.md`；15 项图谱一致点 + 5 项差异点 + 11 条架构疑点），全部带 file:line。

---

## 0. 结论先行

你定的两个方向——**① 五层架构整体介绍、② 单 query 全流程逐节点**——**必要但不充分**。
它们是地图和路线，但资深面真正压的是地图上没有的东西：**为什么这样画、画错了怎么收场、凭什么说画对了、下一步改哪。**

| # | 方向 | 视角 | 回答的面试官问题 | 你的现状 |
|---|---|---|---|---|
| ① | 五层架构 | 空间（静态分层） | 「系统长什么样」 | ✅ 已列 |
| ② | query 全流程 | 时间（动态流转） | 「请求怎么走完」 | ✅ 已列（且有 Step 0–14 证据链） |
| ③ | **设计取舍**（为什么） | 决策 | 「为什么这么设计 / 对比过什么方案」 | ❌ 缺 |
| ④ | **失败与恢复图谱** | 逆境 | 「错了怎么办 / 怎么降级 / 怎么恢复」 | ❌ 缺 |
| ⑤ | **验证与观测**（凭什么对） | 证据 | 「怎么证明它是对的 / 敢上生产」 | ❌ 缺（08 篇有素材，需挂到 supervisor 上） |
| ⑥ | **已知边界与下一步** | 诚实 | 「有什么不足 / 继续做会做什么」 | ❌ 缺（审核 11 疑点 + 5 份 SPEC 是现成弹药） |

**一句话记忆锚点**：
「**①② 讲 what，③④⑤⑥ 讲 why / how-fail / how-prove / what-next。前两个决定你能不能讲，后四个决定你像不像资深的。**」

---

## 1. 方向①：五层架构（开场 · 2 分钟版）

### 1.1 讲法建议

不要逐层报菜名（那是 junior 讲法）。用「每层防什么错」串：

| 层 | 本仓实现 | 防什么 |
|---|---|---|
| 编排层 | LangGraph supervisor：`START → strategy_builder → supervisor → subtask_join → Send 工人/observe → aggregator → critic`（`app/ops/lg_rag/multi/graph.py:96-104`） | 规划失败静默冒充成功（supervisor-first fail-closed，PR #282） |
| 能力层 | capability gateway 七层闸链（`gateway.py:337-468`：delegation 验签→lookup→enabled→Policy→熔断→配额→args_schema） | 工具带错参数/越权/超支继续往下走 |
| 模型供给层 | LLM 工厂切面：预算三档/缓存/跨档降级（`app/llm/providers/base.py:39-156`） | 模型抖动与成本失控传导到用户 |
| 数据层 | thread/turn/run_event 三表 + checkpointer | 断连丢现场、对话状态不可恢复 |
| 传输层 | SSE + RunWorker 单飞 + replay/孤儿补偿（`run_worker.py:185-238`） | 断连即丢答案 |

### 1.2 常见追问预备

- 「为什么是 LangGraph 而不是 CrewAI/AutoGen？」→ 状态机显式可控：interrupt/resume 有 checkpointer 真挂起，Send 并发可审计；黑盒框架拿不到这些钩子。
- 「supervisor 和 router 有什么区别？」→ supervisor-first 后 router 降格为工人子图内部回环（rag 质量低→rewrite 重试≤2，`lg_rag/nodes.py:203-240`），粗路由只做模式对照轨，不再是主路径。

---

## 2. 方向②：单 query 全流程（主战场 · 10 分钟版）

### 2.1 讲法建议：14 步压成 5 幕

审核产出的 Step 0–14 是**备课真源**，但口述必须压缩。建议五幕结构（每幕一个「戏眼」决策点）：

| 幕 | 覆盖 Step | 戏眼（面试官记住你的点） |
|---|---|---|
| 一 · 入口与装配 | 0–3 | **fail-closed 从入口开始**：thread 归属校验跨用户 404；T3 历史窗口压缩（6 轮全量 + 2 轮一组摘要，`continuity.py:44-79`） |
| 二 · 规划 | 4–6 | **Builder 无 LLM 先收窄菜单**（allowlist = 基线∩candidates）→ planner 才上场；规划失败默认 `error{stage:supervisor_plan}`，**不静默单 rag** |
| 三 · 下发与执行 | 7–8 | **Send 并发 + join 闸契约校验**（consumes 缺字段→HITL 而非硬错）；工人过七层闸链 |
| 四 · 人闸与恢复 | 9–10 | **interrupt 真挂起靠 checkpointer**，resume 接同一 run_id 续 seq；批准只授权不代劳（`_apply_hitl_decision` 剪掉旧结果重跑） |
| 五 · 聚合与收尾 | 11–14 | aggregator 流式出 token；critic 规则路由（诚实说明是 stub）；事件全落盘可 replay |

### 2.2 关键数字（必须背，数字让叙述可信）

32 总步预算 · 2 ReAct 轮 · 6+2 历史窗口 · 4 子任务上限 · 600s 令牌 TTL · 3600s 审批消费 TTL · 300s 孤儿补偿 · 30s keepalive · 七层闸链 · 六类拒绝 R-a~R-f。

### 2.3 防翻车提醒

- **图谱 flow 文档滞后于代码**（仍画 intent_node）——白板画拓扑时以代码真值为准（`multi/graph.py:96-104`），别照旧图讲。
- **别把自己没核实的说成已实现**：memory 注入疑似 supervisor 零消费（疑点 #2 待实证）；delegation 默认 off；critic 是规则 stub。讲现状时这些都是「设计如此/已知边界」，不是缺陷——但说成「已实现且生效」会被追问戳穿。

---

## 3. 方向③：设计取舍（资深线 · 必补）

每个决策备一个「A/B/C 对比 + 为什么选它」。审核已产出现成的（5 份 SPEC §4 方案对比表全是素材）：

| 决策点 | 弃选 | 采纳理由一句话 |
|---|---|---|
| 规划失败语义 | 静默单 rag / 切 router 粗路由 | 假成功比失败更危险——观测上换了规划器用户却不知道 |
| 意图节点位置 | 前置 intent LLM / 并进 supervisor 一次调用 | 失败语义与分类信号不能缠在一起；意图退出阻塞位 |
| 指代消解插入点 | supervisor 节点内 / planner prompt 带历史 | 装配层是唯一「历史+原文皆备」且三模式共用的单点 |
| 委派令牌 | 拆一级模块 / JWT | HMAC 自包含 + nonce 防重放 + 三档灰度，纯函数零 IO 可测 |
| scenario 死代码 | 维持现状加文档 / 为它造新信号源 | 摘除与现行行为逐值等价，是唯一零风险选项 |

---

## 4. 方向④：失败与恢复图谱（「错了怎么收场」）

按 08 篇承重墙框架挂 supervisor 实例：

- **看得见的错**：`done.degraded` 帧显式标记降级；`error.stage` 定位到 supervisor_plan/worker；降级必带 `degraded_*` 标记注入 output（`gateway.py:1001-1005`）。
- **可逆的错**：HITL interrupt/resume 状态机；写能力落 receipts 回执 + 幂等 complete。
- **静默的错（防）**：审计记动作不记内容（五动作词表）；事件每帧落盘 + replay after_seq 断联续看；孤儿 run 补偿 `done{disconnected}`。
- **预算与熔断**：工厂重试/跨档降级先于失败判定；熔断先于配额（闸链顺序是设计点，能讲为什么：熔断挡故障放大，配额挡成本，故障时配额计数无意义）。

---

## 5. 方向⑤：验证与观测（「凭什么敢上生产」）

把 08 篇的三块承重墙挂到 supervisor 链路：R0–R15 红线对应 supervisor 层断言（如无 locked 前缀禁止 `_carry_plan`）；40 核验流水线；golden eval 真跑裁决；SSE replay 可作线上取证。追问「怎么测 LLM 系统」→ 假 LLM/spy provider 注入 + SO parse_only 契约断言 + 金样，不打真模型（memory-injection-consumer SPEC 的 Phase A 方法论可直接当答案）。

---

## 6. 方向⑥：已知边界与下一步（「诚实」是最强资深信号）

审核 11 条疑点 + 5 份 draft SPEC 就是现成的「我对自己系统的体检报告」。面试主动讲三条最漂亮的：

1. **指代消解缺失**（多轮必出问题）——已立项：装配层重写、默认关、失败降级原文、落盘记原文的审计口径都想好了；
2. **memory 注入疑似零消费**——「先证后修」：spy provider 实证矩阵先行，不猜着改；
3. **worker 单飞只在进程内 dict**——多副本部署的边界我有清单（multi-replica-verify 8 条目先例）。

讲完补一句路线图：「这五份 SPEC 按 1→5 排序，图谱重同步钉在最后——因为前四项还会动拓扑，最后追一次最省。」这句话本身就在展示工程判断力。

---

## 7. 时长分层剧本

| 时长 | 用哪些方向 | 目标 |
|---|---|---|
| 2 min 电梯版 | ① 五层一句话/层 + ②五幕骨架 | 「我做过生产级编排，且知道每层防什么」 |
| 10 min 架构版 | ② 五幕展开 + ③挑 2 个取舍 + ④挑 1 个失败场景 | 主战场，戏眼在 fail-closed 与 HITL |
| 30 min 深挖版 | 全六个方向，由面试官追问驱动 | ⑤⑥ 兜底，追问到哪层有哪层的 file:line |

---

## 8. 本篇关联资产清单

| 资产 | 位置 |
|---|---|
| Step 0–14 全流程证据链（备课真源） | `/tmp/lg_rag_supervisor_lifecycle.md`（落盘备份） |
| 5 份后续 SPEC（方向⑥弹药） | `ops-desk-api/docs/spec/{query-coref-rewrite, memory-injection-consumer, scenario-stage-rewire, delegation-naming-boundary, tech-graph-flow-resync}/` |
| 图谱对拍差异（防翻车清单） | 本仓审核会话 · SPEC tech-graph-flow-resync 文首 |
| 承重墙框架 | `08_agent-essential-modules-deepdive_v1_zh.md` |

---

## 修订记录

| 日期 | 说明 |
|---|---|
| 2026-10-19 | v1：基于当日 supervisor 全流程审核产出；裁定两方向必要不充分，补③④⑤⑥ |
