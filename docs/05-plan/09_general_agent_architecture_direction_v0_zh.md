# 通用 Agent 架构方向思考 · Ops Desk 对照 Super-agent v0

| 项 | 内容 |
|----|------|
| **状态** | `draft` · 方向设想文档；**不构成改码授权**（先例：`08_collab_agent_graph_capability_draft_v0_zh.md`） |
| **日期** | 2026-11-02 |
| **Open Folder** | `ops-desk-workspace/`（跨仓统筹） |
| **输入** | ① DeepSeek Harness《Super-agent 设计探索》文章（2026-10-31）；② 开源原型 `dsh-superagent-prototype`（commit 6337fc8）深度调研报告（`agent-bench/report/07_dsh_superagent_prototype.md`）；③ Ops Desk api 实现级现状（master，file:line 锚点） |
| **定位** | 阶段 H→T→W 已收口（W：受控写+HITL，api PR #303，2026-10-30），P（平台项）未开。本文回答：**P 及更远，Ops Desk 往「通用 Agent」走的架构方向**。 |

---

## §0 一页结论

1. **Ops Desk 与 Super-agent 原型在「治理哲学」上已同构**：supervisor-first 编排 ≈ Router 确定性骨架 + 限权 LLM；七层闸链 ≈ Policy.gate + Mandate；先量后闸 ≈ accept mode 三档。** Ops Desk 缺的不是判断力约束，而是「生命形态」。**
2. **本质代差只有一个：Ops Desk 是请求-响应型，Super-agent 是事件驱动连续实体**。人发起、SSE 结束即终止 vs Trigger 入口、Ticket 级授权快照、后台执行、Effects 持久队列、外部 Watchdog。所有具体缺口（无触发、无后台、无跨信道、记忆默认关）都是这一句话的展开。
3. **方向不是推翻重做，而是「给现有 supervisor 图接上事件入口和后台躯干」**：Ops Desk 的编排、闸链、委派令牌、预算、HITL、replay、记忆闸是可直接复用的平台资产，原型的 Trigger/Ticket/Mandate/Effects 是要补的另一半。
4. **演进分四刀，每刀独立可验收**：GA-0 灰度开光 → GA-1 事件化 → GA-2 授权与多信道 → GA-3 多 Agent/A2A（远期冻结）。与既有纪律一致：**先量后闸、默认关、人签前不动线**。
5. **最大单点工程债是「进程内状态」**：熔断/配额/幂等/nonce/推理缓存/RunWorker 全在内存，`capability persistence 默认 null 不可上生产`。事件化的前提是持久化真值先落 DB——这与八大结论⑤「恢复的分水岭是持久化真值」互为印证。

---

## §1 输入与口径

### 1.1 Super-agent 侧（调研口径：开源原型，与文章/内部版本均有差异）

| 概念 | 原型真实形态 | 锚点 |
|------|-------------|------|
| Router | **确定性程序骨架 + 严格限权常驻 LLM Session**（bounded facts, never authority）；批处理批的是评估建票，非并行分派 | `src/core/ports.ts:49-53`；`src/core/app/evals.ts:71-119` |
| 三级过滤 | SourceScope → Policy.gate 3×3 准入表（默认 `{inferred,ignore,ignore}`）→ LLM assessment（每条规则恰好判一次） | `intake.ts:25-29`；`policy.ts:191` / `admission.ts:13` |
| Inline&Spill | 全链路 `capped()`：trigger≤4000 / assignment≤1500 / report≤600 字符；**无语义召回** | capped 全链路 |
| 授权 | **Mandate 不可变快照 + Policy 版本化（mandate-v3）+ Strength 单调（ignore<inferred<explicit）**；仅人 stop 撤回或 revalidation 吊销 | docs/001-domain.md、002 |
| 持久 | Effects 持久队列**先存后做** + SQLite WAL FULL + 全链路 `key()` 内容定址幂等 + Source 游标防重放 | 007-architecture |
| Worker 边界 | `danger-full-access`，真实边界=worker-bin shim（身份绑定+blockedCommands）+ worker-gitconfig 凭据链 + verifyDirectory；**明言非 OS 级边界** | environment.ts |
| 信道纪律 | IM 100 词**传输层硬拒绝**；注入防线六层文案；bot 评审每 PR≤3 轮；auto-merge<200 行 | prompts.ts:200 等 |
| Watchdog | 仅健康上报雏形；最接近=部署文档建议**另一 agent 每小时跑 status 脚本**（退出码 0/1/2/3） | 006:133-141 |

**文章有、代码无**：投机执行、Watchdog 外部控制回路、语义召回、多 Worker 分派、跨机存算分离、A2A。
**代码有、文章未展开**：完整授权体系 + `docs/001` Rejected concepts 表 15 条（原型最深的模块）。

### 1.2 Ops Desk 侧（api @ master 实现级）

- 主路径 `POST /api/ops/lg-rag/stream`（freeze lg-rag-sse-v1，默认 mode=supervisor）。
- 编排：**START→strategy_builder→supervisor→subtask_join→Send→observe→aggregator→critic**（`app/ops/lg_rag/multi/graph.py:79-105`）；intent_node 已摘除（PR #282，`multi/graph.py:82` 注释）。
- 阶段序：H α/β（契约硬化+预算）CLOSE → T（只读多租户）CLOSE → **W（受控写+HITL）CLOSE 2026-10-30** → P（平台项）未开（真值：`05_post_h_stage_brief_v1_zh.md` §1 修订行）。

---

## §2 同构性：Ops Desk 已经做对的五件事

> 这一节的价值：往通用 Agent 走**不需要重打地基**，需要的是把已验证的治理机制搬到新的生命形态上。

| # | Super-agent 概念 | Ops Desk 对应实现 | 锚点 |
|---|------------------|-------------------|------|
| 1 | Router=确定性骨架+限权 LLM（bounded facts, never authority） | **strategy_builder 纯规则无 LLM 先收窄菜单**（allowlist=Registry∩Policy 基线∩mode 静态表，MAX_SCOPE_IDS=64），supervisor 只在可见集内规划，越集整 plan 作废；规划失败 fail-closed 抛 `SupervisorPlanError` | `strategy/builder.py:118-154`、`builder.py:23`；`multi/nodes.py:1399-1625` |
| 2 | Policy.gate + Mandate（授权与裁决在工程层） | **Capability Gateway 七层闸链**：委派验签→lookup→enabled→Policy→熔断→配额→args_schema；`HOST_ONLY_POLICY_KEYS` 模型 plan 写不生效 | `capability/gateway.py:337-468`、`policy.py:87-116`、`policy.py:23-33` |
| 3 | accept mode 三档（off/observe/auto）先量后闸 | 委派令牌 `off\|observe\|enforce` **默认 off**；LLM 预算 `off\|observe\|enforce` 默认 off；A 类 10 项已实现默认关 | `capability/delegation.py:95-100`；`llm/budget.py`；`08-interview/13` gap 清单 |
| 4 | LLM 输出不可信，须结构化收口 | **SO Gateway**：parse_only（提取→确定性修复→Pydantic→ensure_keys）+ OUTPUT CORRECTION 重生成 ≤3 次；Host 权威无半成功数据 | `structured_output/__init__.py` |
| 5 | Effects 先存后做 / 持久化真值 | SSE 事件逐帧落盘（`run_is_terminal` 终态真源=事件表）、RunWorker 断连不丢执行、replay/断联续看、HITL 落库先于挂起 | `event_store.py:126`、`run_worker.py`、`router.py:503`、`multi/nodes.py:2144` |

**再加两条 Ops Desk 独有、原型没有的好东西**：
- **可恢复点 + 不可变前缀**（「锁定是收回写权限，不是写完再验」，prefix_touch→HITL）——原型的 Ticket 没有这一层（`07-design/06`；`multi/nodes.py` critic 回环裁剪）。
- **红线验收体系**（题集+确定性判分+一键五层脚本，「红线是否决项不能混进准确率」）——原型只有单测（`07-design/01/02`）。

---

## §3 本质代差：请求-响应型 vs 事件驱动连续实体

Super-agent 四特征（连续/高效/主动/持久）对照 Ops Desk 现状：

| 特征 | Super-agent | Ops Desk 现状 | 差距定性 |
|------|------------|---------------|----------|
| **连续** | Trigger 事件入口（GitHub 轮询 ETag/304、Feishu 长连接+回填）；Ticket 生命周期跨事件 | 入口仅同步 HTTP（invoke/stream）；run 结束即终止；`continue_from_run_id` 只注入草稿禁 resume | **无触发源、无任务生命周期** |
| **主动** | 三级过滤后主动建票、主动出站（IM/PR 评论） | 无任何主动出站；唯一「后台点火」是记忆抽取的 `create_task` | **无出站信道、无主动决策点** |
| **高效** | 直通省 37% 读缓存 token；批处理摊薄单次决定 6.4s→1.6s | 推理缓存默认关（且只缓存 structured 档）；无批处理概念 | 局部有机制、全局无架构 |
| **持久** | Effects 持久队列先存后做；SQLite WAL FULL；全链路幂等；Source 游标防重放 | 事件表/checkpoint 已持久；**但熔断/配额/幂等/nonce/缓存/RunWorker 全进程内**；`capability persistence 默认 null 告警「不可上生产」` | **一半持久、一半内存** |

### 3.1 缺口清单（对照通用 Agent 平台，按可治理性排序）

> 口径沿用 `08-interview/13`：「可见的缺口才是可治理的缺口」。

| # | 缺口 | 现状锚点 | 所属阶段 |
|---|------|----------|----------|
| G1 | **事件驱动触发**：无 scheduler/webhook/消息订阅 | 入口仅 HTTP | GA-1 |
| G2 | **后台执行框架**：RunWorker 进程内 MVP（`run_worker.py:5`「多副本 DB 租约另立」），无队列/优先级/租约 | `run_worker.py` | GA-1 |
| G3 | **授权体系**：委派令牌默认 off；无用户级 on-behalf-of 授权代理；HITL 只覆盖 prefix_touch 一类 | `delegation.py` | GA-2 |
| G4 | **跨信道**：仅 HTTP SSE + WS；无 IM/邮件/push 抽象与出站 | — | GA-2 |
| G5 | **长期记忆默认全关**（`MEMORY_FACTS_ENABLED`/`EXTRACT_ENABLED`/`EPISODES_WRITE_ENABLED` 均 false）；preference 有闸无抽取通路；episode 未接检索闭环 | `memory/` | GA-0 |
| G6 | **Skill 层薄**：仅关键词匹配 v0 top_k=3，无加载/执行/组合引擎；`provide(kind=skill)` 只是预留 | `skill_registry/registry.py:65,92` | GA-1 |
| G7 | **工具生态极小**：supervisor allowlist 仅 5 个（1 时间+2 mock+2 只读）；http 能力对 Agent 不可见（`07-design/00` §17.3 待决策） | `strategy/config.py:25-34` | GA-1 |
| G8 | **水平扩展**：熔断/配额/幂等防重/令牌 nonce/推理缓存全进程内；PG checkpointer 生产默认不开（HITL 恢复依赖它） | `capability/`、`lg_rag/graph.py:51-53` | GA-0 |
| G9 | **目标管理**：无 goal/任务生命周期；无定时/周期/长程任务 | — | GA-2 |
| G10 | **多 Agent 协作**：单图内三工人，无 agent 注册表/A2A/消息总线 | — | GA-3（远期冻结） |

---

## §4 架构方向：四刀演进路线

> 总原则：**不重写编排，只换生命形态**。每一刀独立立项、独立验收、默认可回退；进入条件与既有阶段序（H→T→W→P）同款纪律。每刀都遵守「先量后闸」：新机制第一版只做观测，数据够了再 enforce。

### GA-0 灰度开光 + 持久化补齐（平台硬化，P 阶段候选）

**目标**：把 A 类「已实现默认关」的能力按观测数据逐档打开；把进程内状态搬进 DB。这是后续一切的前提。

| 项 | 动作 | 验收 |
|----|------|------|
| 记忆三开关 | observe 档开启抽取与注入，量「注入被消费率」（治 B 类 #12「注入零消费」） | 注入消费率有数据；答题质量红线不退化 |
| capability persistence | `null → db`（DbIdempotencyStore+DbReceiptSink 已就绪，只是不默认） | 写能力回执可拉；防重重启后仍生效 |
| PG checkpointer | 生产显式开 `LG_RAG_HTTP_CHECKPOINTER=postgres` | HITL 挂起跨重启可 resume |
| 委派令牌 | `off → observe`，统计八类拒绝分布 | observe 报表；再决 enforce 时间点 |
| 进程内→DB | 熔断/配额/nonce/推理缓存给出共享存储实现（熔断已有 Redis 留口，`07-design/04` §3） | 多副本行为一致 |

**为什么先这一刀**：八大结论⑤「恢复的分水岭是持久化真值」。GA-1 的事件化会把任务寿命从「一次 HTTP 请求」拉长到「数小时~数天」，进程内状态在那种寿命下全是雷。

### GA-1 事件化（核心一刀：触发 + 后台躯干）

**目标**：给 Ops Desk 接上「事件驱动」的生命形态，但编排内核复用现有 supervisor 图。

| 组件 | 设计要点（对齐原型，落到 Ops Desk） |
|------|-----------------------------------|
| **Source/Trigger 抽象** | 新增 `app/ops/trigger/`：Source=轮询适配器（第一刀只做 GitHub ETag/304 轮询 + 站内定时器两个源，学原型「纯轮询无 webhook」的克制）；Trigger=事件→候选任务；**Source 游标落 DB 防重放**（学原型） |
| **准入裁决** | Trigger 进 supervisor 之前先过**确定性 Scope 过滤 + Capability Gateway 同款 Policy**，LLM 只在过了闸的候选上做 assessment——完全对齐「装配先于意图」「Router 限权」两条既有判断 |
| **Ticket=任务载体** | 复用 `OpsLgRagThread/Turn/RunEvent` 三表族，新增 task 状态机（七态可借原型：queued/assessing/running/waiting_approval/done/failed/cancelled）；**Ticket 携带授权快照**（见 GA-2 与委派令牌对齐） |
| **后台执行器** | RunWorker 升级：进程内 dict → **DB 租约 + 持久队列（先存后做）**；单飞语义用 DB 唯一约束而非内存 dict；orphan 补偿逻辑（`run_worker.py:185-238` 已有雏形）提升为一等机制 |
| **出口** | 第一刀出站只回写事件表 + 站内通知；**不接 IM**（GA-2 的事） |

**明确不做**（对齐原型 Rejected concepts 的判断）：不做 webhook 接收（先轮询）、不做语义召回（Inline 有界就够）、不做多 Worker 分派。

### GA-2 授权与多信道（主动性的闸门）

**目标**：让 Agent 能「主动做事」，但每一次主动都过授权体系。

| 组件 | 设计要点 |
|------|---------|
| **Mandate 对齐** | 原型 Mandate（不可变快照、Strength 单调 ignore<inferred<explicit、仅人可撤）与 Ops Desk 委派令牌（HMAC 自包含、TTL 600s、one_shot nonce、八类拒绝）做概念合并：**Ticket 签发时冻结授权快照，运行期权限变更必须过闸**（直接回应 `08-interview/13` C 类 #25「热加载不是技术问题，是改权限要不要过闸的问题」） |
| **HITL 审批中台化** | 从「只覆盖 prefix_touch 一类」扩展为通用危险动作审批面：写能力、出站消息、权限变更三类统一走 interrupt/resume；web 审批页已有（W 阶段合入） |
| **信道抽象** | `app/ops/channel/`：出站消息统一走 Channel 接口；第一刀接 1 个 IM（飞书优先，原型 lark-cli 模式可借鉴）；**100 词纪律做成传输层硬拒绝**（原型 prompts.ts:200 的教训：提示词限制不可靠，架构兜底） |
| **出站审计** | 每条出站消息落回执（复用 capability receipts 表族），声明 automated agent 身份（原型纪律） |

### GA-3 多 Agent / A2A（远期，当前冻结）

原型自己都没做（文章有、代码无）。Ops Desk 的协同 Agent 设想（`08_collab` draft：父图一次分仓 + subagent 各带只读本仓 Skill 回结构化摘录）是更现实的中间态。**GA-3 只保留一句判断：A2A 的上下文边界问题没有答案之前，不立项。**

### 路线总览

```text
阶段 W CLOSE（受控写+HITL，2026-10-30）✓
  → GA-0 灰度开光 + 持久化补齐      ← 推荐下一刀（P 阶段候选）
  → GA-1 事件化（Trigger + Ticket + 后台队列）
  → GA-2 授权中台 + 多信道出站
  → GA-3 A2A（冻结，等上下文边界有答案）
```

---

## §5 资产映射表：Ops Desk → Super-agent 五模块

| Super-agent 模块 | Ops Desk 已有资产（可直接搬） | 需新建 |
|------------------|------------------------------|--------|
| ① 双层架构（Router/Worker） | strategy_builder（无 LLM 收窄）+ supervisor（限权规划）+ 三工人节点；预算三闸；critic 回环 ≤1 | Ticket 生命周期；后台队列 |
| ② 事件驱动（Trigger/Thread） | SSE 事件表 + replay（事件溯源已成立）；step_contract 绑定权归代码 | Source/Trigger/准入三级过滤；Source 游标 |
| ③ 异步 Loop + 多信道 | RunWorker 断连不丢执行；HITL interrupt/resume；「继续回复」草稿注入 | DB 租约；Channel 出站抽象；IM 100 词硬拒绝 |
| ④ 存算分离 / 持久 | 事件表/checkpoint/thread 三族表；capability receipts（db 模式已就绪） | persistence 默认改 db；进程内状态外迁 |
| ⑤ Watchdog 外部控制回路 | 红线验收五层脚本 + 管理端点五件（runtime/catalog/receipts/idempotency/metrics）+ usage 落表 | 外部巡检 agent（原型做法：另一 agent 每小时跑 status，退出码 0/1/2/3）——**现有管理端点正好是现成探针** |

---

## §6 决策点与红线（立项前须人签）

| # | 决策点 | 背景 | 建议 |
|---|--------|------|------|
| D1 | http 能力是否对 Agent 可见 | `07-design/00` §17.3 遗留待决策；工具生态扩大（G7）的前置 | GA-1 立项时连同 Tool 契约人闸一并签 |
| D2 | 事件化的第一批 Source | GitHub 轮询 vs 站内定时器 vs 飞书 | 先站内定时器（零外部依赖、可测），再 GitHub |
| D3 | 委派令牌 enforce 时点 | observe 数据够了才谈 enforce | 随 GA-2 授权中台一并 |
| D4 | 记忆注入消费率达标线 | B 类 #12「注入零消费」 | GA-0 先量一个月，达标线届时定 |
| D5 | 权限变更通道闸化 | C 类 #25 | 并入 GA-2 Mandate 对齐，不单独开刀 |

**红线（任何阶段不许碰）**：
1. 写能力永不降级（B1，`07-design/05`）；降级永不发明结果（框架忠实执行清单声明）。
2. 静默降级比明确报错危险——所有降级显式标记 `degraded=True`。
3. SSE 词表 freeze lg-rag-sse-v1 不破；新增事件类型走契约评审。
4. 模型产出不参与身份构造；`HOST_ONLY_POLICY_KEYS` 模型写不生效。
5. 新机制第一版默认关/观测档，人签后才进 enforce——「可见的缺口才是可治理的缺口」。

---

## §7 参考

| 文档 | 路径 |
|------|------|
| 原型调研报告（全锚点） | `agent-bench/report/07_dsh_superagent_prototype.md` |
| Super-agent 文章 | DeepSeek Harness 团队《Super-agent 设计探索》2026-10-31（微信公众号） |
| 阶段简报（H→T→W→P 真值） | `docs/05-plan/05_post_h_stage_brief_v1_zh.md` §1 修订行 |
| Agent 完善线 | `docs/05-plan/04-agent-completion-roadmap_v1_zh.md` |
| 协同 Agent 设想（本方向的上游草案） | `docs/05-plan/08_collab_agent_graph_capability_draft_v0_zh.md` |
| gap 清单（A–E 类） | `docs/08-interview/13_*.md` |
| 能力注册/降级/契约等设计真值 | `docs/07-design/00–07` |
| Ops Desk 实测对照（八结论出处） | `agent-bench/report/01_records.md` |

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-11-02 | v0 首版：基于 Super-agent 原型调研（commit 6337fc8）与 api master 实现级现状的方向设想；不构成改码授权 |
