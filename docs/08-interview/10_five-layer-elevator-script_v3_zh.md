# 阶段三 · Agent 方向技术面作战手册（十）：五层架构电梯版讲书稿 v3

> 承接 `09`（六方向叙述框架）方向①的落地讲稿。本篇 = **2min 电梯版五层口述全稿 + 试讲批改 + 五问详解**。
> 真值基准：2026-10-20 代码复核（master，含 PR #282）；全部 file:line 经当次只读核查。
> 孤儿补偿接线：2026-10-20 完成（口径见 §3.5；实际挂点 file:line 待补全后回填）。

---

## 0. 结论先行

五层电梯版的讲法不是报菜名，是**每层只讲「防什么错」**——分层即隔离失败域，错误必须显式展示，不允许静默无痕。
全稿约 550 字 / 2 分钟，戏眼三个：**编排层 fail-closed、能力层写操作闸、传输层执行与传输解耦**。

---

## 1. 口述全稿 v3（约 2min · 正常语速）

### 【定场 · 15s】

「这个系统纵向五层，我的设计原则是**每层的防范设计先于功能设计**——错误必须显式展示，不允许静默无痕。每层我只讲它防什么错。」

### 【1 · 编排层 · 30s】

「supervisor-first 编排：strategy_builder 先不用 LLM 把工具菜单收窄，supervisor 再做任务划分、Send 并发派给子 agent 工人，aggregator 节点流式聚合，critic 收尾。编排失败走 **fail-closed**：显式返回带 stage 的错误，**绝不静默退化为通用回答、造成任务完成的假象**（在我们的实现里，具体就是不偷偷退回单 rag 粗答）——假成功比真失败更危险，因为观测上规划器换了，用户却不知道。」

> 拓扑真值（白板只认这个）：`START → strategy_builder → supervisor → subtask_join → (Send 工人/observe) → aggregator → critic`，`app/ops/lg_rag/multi/graph.py:96-104`。图谱 flow 文档滞后（仍画 intent_node），勿照旧图讲。

### 【2 · 能力层 · 30s】

「所有工具过七层纯代码闸控，无 LLM 参与：令牌验签、注册表查找、开关、Policy、熔断、配额、参数 schema。层层递进，一层不过带拒绝码当场返回。Policy 层五条规则里最有讲究的是**写操作闸**——副作用为写的能力默认拒绝，放行信号只认环境变量或人工批准的单次授权，模型自己写的授权字段一律无效。」

> 闸链真值：`app/ops/capability/gateway.py:337-468`（`_prepare_call`）；Policy 五条：`app/ops/capability/policy.py:87-116`。

### 【3 · 模型供给层 · 20s】

「工厂模式统一对接模型，熔断、退避重试、usage 落表是所有 Provider 自动继承的边界。usage 落表就是把每轮 token 消耗末帧落库——无帧不落、不写假账、落表失败不挡主答。」

> 真值：`app/llm/providers/base.py:39-156`（`__init_subclass__` 边界包装）；usage 落表 `base.py:177, 211-258` → `ops_llm_usage` 表。

### 【4 · 数据层 · 25s】

「三张业务表加 LangGraph checkpointer，我按证据面和执行面分：证据面是会话、轮次、事件帧三张表——事件逐帧落盘，replay 不需要重跑模型就能原样取证；执行面是 checkpointer 状态快照，支撑 HITL 真挂起、批准后同一 run 续跑。跨进程恢复走 Postgres saver——而内存 saver 下恢复入口会显式报错，不假装恢复成功，这也是 fail-closed。」

> 三表：`ops_lg_rag_threads / ops_lg_rag_turns / ops_lg_rag_run_events`（`app/db/models.py:294/306/324`）；saver 闸：`app/ops/lg_rag/checkpointer.py:27-38`。

### 【5 · 传输层 · 25s】

「SSE 加单飞 RunWorker，核心设计是**执行与传输解耦**：SSE 连接只是事件流的只读订阅者，前端断连等于退订，worker 照常跑完、事件照落，重连按序号 replay 续看；进程崩溃有孤儿补偿兜底——周期扫描发现既无终帧又无活跃 worker 的 run，补一帧 disconnected 终帧，让 replay 不永久卡住。防的是断连即丢答案。」

> RunWorker：`app/ops/lg_rag/run_worker.py:185-238`（补偿函数）；**接线挂点 file:line 待 2026-10-20 补全后回填**。

### 【收尾钩子 · 10s】

「五层一句话：每层有自己的失败域，错在哪层哪层显式收场。这是静态结构；动态上我可以按一个 query 的五幕生命周期展开——从入口装配到 critic 收尾。」

---

## 2. 提词锚点与时长控制

- **手背版**：`fail-closed → 写闸 → 切面落表 → 三表+CP（证据面/执行面）→ 解耦+补偿`。
- 超时砍单：每层括号内实例化句（如"具体就是不偷偷退回单 rag 粗答"）可砍；戏眼句不可砍。
- 数字出场位：七层闸链（能力层）、300s stale 阈值（传输层）、无帧不落不写假账（模型层）。

---

## 3. 五问详解（2026-10-20 试讲追问 · 全部带真值）

### 3.1 Policy 闸五条规则（能力层深挖）

`app/ops/capability/policy.py:87-116` `check_invoke`，闸序 = 危险程度 → 副作用 → 危险形态 → 输入完整性：

| # | 规则 | 默认 | 放行条件 |
|---|---|---|---|
| 1 | `risk_level=high` | ❌ blocked | env 或 Host `allow_high_risk` |
| 2 | **写操作闸** `side_effect ∈ {write, irreversible}` | ❌ blocked（`write_not_confirmed`） | env 或 Host **单次** `_host_policy.allow_write` |
| 3 | `kind=sandbox` | ❌ blocked | env/Host `allow_sandbox` |
| 4 | `kind=cli` | ❌ blocked | env/Host `allow_cli` |
| 5 | `tenant_scoped` 缺租户谓词 | ❌ blocked | 注入 `tenant_id`/`_host_tenant` |

- **规则 2 与 risk_level 独立**：`medium + write`（普通提交）也默认拒——只看危险程度会漏掉"中危但会写"（policy.py:6-10 设计理由）。
- `allow_*` **键全部 Host-only**（`HOST_ONLY_POLICY_KEYS`，policy.py:23-33）：模型 plan 顶层写了不生效。这就是 HITL「批准只授权不代劳」的落点——人工批准 = Host 构造一次性 `allow_write`，只对这一次调用有效。
- 加分点·闸链三个顺序注释（`gateway.py`）：验签先于 lookup（"无有效令牌连注册表都不查" :347）；熔断先于配额（"下游不健康，先谈别打了，再谈打几次" :406）；配额在 Policy 后（"被 Policy 拦的不计配额，否则反复被拒会打满配额误伤正常调用" :423）。

### 3.2 usage 落表（模型层深挖）

LLM 流式响应的**末帧 usage**（token 计数）→ `LlmUsage.from_provider_usage` 解析 → 落 `ops_llm_usage` 表（models.py:629）。三条纪律：**无 usage 帧不落、不写 0 假账；解析失败/落表故障不挡主答**（只 warning，base.py:242-258）。英文表述：*usage metering / token accounting*。用途：成本观测 + 预算闸数据源。

### 3.3 三表 + checkpointer 关系与快照复现（数据层深挖）

**框架：证据面 vs 执行面，职责正交，thread_id/run_id 关联。**

| 存储 | 回答的问题 |
|---|---|
| `ops_lg_rag_threads` | 会话属于谁（跨用户 404 校验源） |
| `ops_lg_rag_turns` | 对话内容是什么（6+2 历史窗口装配源；role ∈ user/assistant/system摘要） |
| `ops_lg_rag_run_events` | 这次 run 发出了哪些帧（`run_id+seq` 唯一约束；replay 真源，**replay 不重跑 LLM**） |
| checkpointer | 图执行到哪、中断点在哪、怎么接着跑（HITL 挂起/恢复真源） |

**快照复现**：LangGraph 每个 super-step 按 `thread_id` 写全量 state 快照；`interrupt()` 保存「挂在哪个节点 + 当时 state」；恢复 = 同一 thread_id 重新进图从挂起点继续，批准决定作 resume 输入注入。

**两种 saver（被追问"换进程怎么继续"的答案）**：

- `InMemorySaver`（默认）：进程内存 dict，重启全丢，仅够同进程同 thread_id 续写；
- `AsyncPostgresSaver`（`LG_RAG_HTTP_CHECKPOINTER=postgres` 闸开）：同库写 `checkpoints / checkpoint_writes` 等框架表（checkpointer.py:14）；supervisor 模式由 RunWorker 挂（run_worker.py:138-142）。**跨进程恢复 = 新进程同 DSN 建 saver、同 thread_id 取最新快照**。
- 默认关的理由（checkpointer.py:33-36 注释原文精神）：每请求建 saver 有成本；内存 saver 下跨请求恢复根本不可能，**恢复入口把"没开开关"当显式失败报出，不假装恢复成功**——fail-closed 哲学的又一次复现，讲数据层时主动呼应。

> **补录（2026-10-20 追问）— saver 互斥关系与 PG 四张框架表**
>
> **互斥（不双写）**：`run_worker.py:138-142` 是 if-else——开关开且 supervisor 模式 → PG saver；否则（含 basic/router 模式）→ InMemorySaver。`router.py:11-17` 注释钉死原因：「stream 与 invoke 读同一把闸……interrupt 挂起那一刻 checkpoint 必须已落盘，否则批准请求找不到恢复点」——闸的意义就是保证恢复点可信。
>
> **PG 四张框架表**（langgraph-checkpoint-postgres 包，非自建）：
>
> | 表 | 存什么 |
> |---|---|
> | `checkpoints` | 主表：PK = thread_id+checkpoint_ns+checkpoint_id；`checkpoint` JSONB = state channel_values（消息、context、plan 全在里面）；`parent_checkpoint_id` 串版本链；`metadata` 记 step/source |
> | `checkpoint_blobs` | channel 大对象的序列化字节（外键关联） |
> | `checkpoint_writes` | 中断点的 pending writes——恢复时补放，避免重放已完成的副作用 |
> | `checkpoint_migrations` | 框架自身的 schema 版本管理 |
>
> **写入时机**：每个 super-step（每个节点执行完）+ interrupt 挂起时。**恢复路径**：新进程用同一 DSN 建 saver → 按 thread_id 取最新 checkpoint → 沿父链重建 → 重放 pending writes → 从挂起点继续。金句：「状态全在 PG 里，进程只是无状态执行器——新实例捡起 thread_id 就能接着跑」。

### 3.4 委派令牌三档（能力层 · 灰度叙事）

`gateway.py:277-334` `_delegation_gate`：

| 档 | 行为 |
|---|---|
| `off`（默认） | 闸门短路，零 diff |
| `observe` | **完整验签只记不拦**：审计行带 `would_block=True`，放行 |
| `enforce` | 真拦：`ok=False + permission_denied + 六类拒绝码`，**不落回执**（被拦=没执行=不留回执） |

- 触发口径：仅 ctx 携 `_delegation_required=True`（tool_exec_node 注入的委派链路标记）才强制；非委派调用零影响（gateway.py:285-286）。→ 目标态准确口径 = **委派链路常开 enforce**，不是全局要令牌。
- 叙事：三档是灰度路径 off → observe（先量误伤率）→ enforce；「默认 off」= 有计划的灰度，不是没做完。
- env：`LG_RAG_DELEGATION_TOKEN_MODE`（非法值回退 off，delegation.py:95-100）；TTL 默认 600s。

> **补录（2026-10-20 追问）— observe 档存在的两个目的**
>
> 1. **量化误伤面**：直接 enforce 时，签发链路任何一个 bug（令牌没签、集合没填）都会变成线上 `permission_denied` 误伤正常流量。observe 让你先看「会拦多少、拦的是谁」。
> 2. **验证签发侧**：验签失败大概率不是攻击，而是签发 bug。would_block 日志按六类拒绝码分布直接定位——过期多 → 改 TTL；集合不匹配 → 改签发逻辑。
>
> **切换标准**：would_block 率收敛到 ≈0（或仅剩预期内的拒绝）→ 切 enforce。这是「先量后闸」的灰度方法论——和 checkpointer「默认关到显式开」同一条纪律。

### 3.5 传输层补偿机制（含 2026-10-20 接线口径）

- **执行与传输解耦**（*connection-execution decoupling*）：RunWorker 进程内 asyncio.Task 持 astream 只写 event_store；HTTP 断连只 cancel subscriber 不 cancel worker。
- **孤儿补偿**：`scan_orphan_runs_for_compensation`（run_worker.py:185-238）——stale 默认 **300s**（`LG_RAG_ORPHAN_STALE_SECONDS`）、跳过活跃 worker、已闭跳过，补 `done{status:disconnected}` → `run_stream_closed` 真 → replay 不再永久 409。
- **接线**：2026-10-20 完成周期接线（lifespan 挂点）；⚠️ 回填位：实际挂点 file:line = 【待补全后填写】。
- 历史背景（勿在面试讲，仅备自查）：接线前该函数全仓仅 tests 调用（2026-10-14 两份审计钉案）。

### 3.6 capability 声明面与放行语义（2026-10-20 三轮追问汇总）

**三层落地**（「高危默认关」的精确形态）：声明层 = YAML 清单自报风险面 → 上架层 = 显式注册进同一注册表 → 闸层 = 代码 Policy + env/Host 放行键。
金句：**「清单只能声明危险，不能豁免危险」**——yaml 里没有任何键能关掉 Policy 的默认拒。

**① 声明维度四组**（CapabilitySpec 全字段，types.py:72-137）：

| 组 | 字段 | 回答的问题 |
|---|---|---|
| 身份与选择 | id / description / when_to_use / when_not_to_use / tags | 模型凭什么选中它（选择依据不是给人看的注释，types.py:88-91） |
| 风险面 | risk_level / side_effect / kind / tenant_scoped / enabled / visibility | **双管**：可执行（Policy 闸）+ 可见（视野裁剪） |
| 执行保障 | idempotency_key / hitl_required / hitl_snapshot_fields / receipt_capture / reversibility 四字段 | 重复提交 / 人工确认 / 副作用以收据为真 / 可撤销 |
| 失败语义 | output_schema / fallback / http.error_map | 成功长什么样 / 打不通给什么 / 错误按稳定码词表区分 |

- 亮点：`risk_level` 与 `side_effect` **两维度不可互代**（types.py:7-13 历史缺口：medium+write 曾被完全放行；side_effect 是写闸唯一挂钩点，必须首次注册就声明）。
- `fallback=None` = 未声明 = **不降级、明确失败**——「不降级」是要显式改掉的默认（types.py:131-137）。
- 错误区分：error_map 值必须落稳定错误码词表（STABLE_ERROR_CODES，加载期强校验）；`output_schema` 区分「查到 0 条」vs「被限流返回空」。

**② 注册时机 = 部署行为**（__init__.py:106-112 模块级装配，import 即执行）：

`ensure_default_capabilities()`（builtin yaml，缺文件回退硬编码）→ MCP client 闸（默认不注册）→ extra manifests（`OPS_CAPABILITY_EXTRA_MANIFESTS` 显式列出，默认空）→ 防重回执落库闸（默认不开）。此后每请求只读注册表。
纪律：禁每请求/HTTP 钩子、**禁热加载**（manifest.py:17-19「热加载 = 改配置即改权限，review 就白做了」）、**禁目录扫描**（manifest.py:57「往目录丢个文件就生效 = 绕过 review」）。金句：**「注册是部署行为，不是运行行为」**。

**③ 可见 ≠ 可执行（两个独立轴）**：

| 轴 | 决定者 | 默认 |
|---|---|---|
| 可见（模型菜单） | `baseline_filter()`（baseline.py:50-63，Builder/Supervisor 共用防漂移） | `deny_high_risk=True` + `deny_write=True`（裁剪阶段就挡，理由 baseline.py:57-59：只裁剪防不住幻觉 id，只拦截则暴露写能力给模型） |
| 可执行（invoke 过闸） | Policy 五规则 + 放行信号 | 高危/写/sandbox/cli/缺租户谓词默认拒 |

放开路径：

| 对象 | 可见层 | 执行层 |
|---|---|---|
| medium+write | `OPS_CAPABILITY_ALLOW_WRITE_TAGS`（逗号分隔 tag，**只豁免 deny_write 一层**） | `OPS_CAPABILITY_ALLOW_WRITE=true`（全局）或 HITL 单次注入 |
| high（含 high+write） | ❌ **无豁免通道**——deny_high_risk 判序在前永不豁免（baseline.py:36） | `OPS_CAPABILITY_ALLOW_HIGH_RISK` / host 键；只能 Host 直调 |

⚠️ 生效时机：filter 是模块级常量 import 时固化，env 须在 import app 前设置（baseline.py:37-39）。
金句：**「高危能力对模型恒不可见——它被执行的唯一路径是 Host 直调 + 显式放行 + HITL 确认，模型连幻觉出它的机会都没有。」**

**④ 放行信号与 HITL 强制绑定**：

- 写放行**仅两来源**（policy.py:6-10）：env 全局 / Host `_host_policy.allow_write`（单次确认语义，只对这一次调用有效）；模型 plan 顶层写 allow_* 一律不生效（HOST_ONLY_POLICY_KEYS，policy.py:23-33）。
- 加载期强校验：V1 写必须幂等键（manifest.py:829-831）；V2 写必须 hitl.required（:833-835「第一期不允许存在无确认的写能力」）；V3 高危必须 hitl（:837-839「高危无确认 = 闸形同虚设」）；`hitl_snapshot_fields` 防「批 A 执行 B」（types.py:106-107）。
- ⚠️ **红线**：`_host_policy.allow_write` 读侧生效（policy.py:83-93）但**注入侧 lg_rag 链路无 writer**（契约在、未接线）；supervisor 实际在跑的 HITL 是子任务级：委派签发审批（nodes.py:968-986）+ 契约闸（:918-919）→ hitl_pending 汇总（:1645-1657）。

**⑤ 重复提交三场景 × 三层机制**：

| 场景 | 机制 |
|---|---|
| ① HITL 批准后 replan 孪生步（同一写以新 sid 再现） | 编排层 `write_replay_guard_skip`：异 sid 同 canonical 已成功 → 不派发，output 照抄 + replay_of 台账（nodes.py:925-967） |
| ② 传输重试（下游已执行、响应丢失） | 适配器发前查防重 store：同键已成功 → 直接返回上次捕获不再打下游（previous_captured，http_generic.py:544-645）；幂等键**透传下游**（:618-619） |
| ③ 调用方重入（双击/断连重发/worker 重试） | 声明层 V1 强制幂等键；http 缺键**直接拒发**：ARGS_SCHEMA_INVALID「写操作缺 idempotency_key」（http_generic.py:769-773） |

⚠️ 红线：防重落库 store 由 `OPS_CAPABILITY_PERSISTENCE=db|memory` 闸控，**默认不启用**（__init__.py:111-112）——默认部署靠编排层 guard + 键透传给下游自身去重。

**⑥ 七层闸链 vs Policy 五闸（两个粒度，被问先反问澄清）**：

七层 = `gateway._prepare_call`（gateway.py:337-466）：

| # | 闸 | 锚点与意图 |
|---|---|---|
| 1 | 委派令牌验签 | :347-350，在 lookup **之前**——无有效令牌连注册表都不查 |
| 2 | lookup 存在性 | :351-360，未知 id → UNKNOWN_ID |
| 3 | enabled | :363-378，被禁报「未找到」**同款文案**——不暴露存在性 |
| 4 | **Policy（=五闸那一层）** | :380-403 |
| 5 | 下游熔断 | :405-420，先于配额「先谈别打了，再谈打几次」；写能力不参与半开探测 |
| 6 | kill switch + 会话配额 | :422-442，在 Policy **之后**——被拦的不计配额，防反复被拒打满配额误伤正常调用 |
| 7 | 参数校验 | :444-466，args_schema 最后把关 |

五闸 = 第 4 层内部（policy.py:95-114，闸序：危险程度→副作用→危险形态→输入完整性）：high_risk → write → sandbox → cli → tenant_scope_missing。
锚点：**「七层是链路，五条是其中一层的内部规则」**。

---

## 4. 报错去哪了（方向④素材 · 「后续怎么看」）

| 层 | 报失去向 | 查看方式 |
|---|---|---|
| 编排层 | `error{stage:supervisor_plan}` / `worker_failed` 作 SSE error 帧逐帧落 `ops_lg_rag_run_events`（sse_stream.py:306-317） | `POST /replay`（run_id+after_seq 或 cursor，router.py:372+）原样重放 = **线上取证**；SQL 按 `event_type='error'` 直查 |
| 能力层 | 闸拒 `ok=False+拒绝码` 不落回执；审计走 logger 结构化行 + tracing span（记动作不记内容）；真执行的写落 `ops_capability_receipts` | 日志/tracing 按拒绝码筛；工人节点内的拒绝反映在 run 事件流 |
| 模型层 | usage 落 `ops_llm_usage`；降级带 `degraded_*` 标记注入最终 output | 查表 + 答案帧 degraded 标记用户可见 |

一句话：**「业务面的错全部汇聚 run 事件流（每帧落盘是统一纪律），观测面的错走 tracing 结构化审计——前者给用户和 replay，后者给运维。」**

---

## 5. ⚠️ 未落地红线表（面试口径纪律 · 违者被追问戳穿）

| 条目 | 真值状态 | 面试口径 |
|---|---|---|
| ~~孤儿补偿周期扫描~~ | ✅ 2026-10-20 已接线（挂点 file:line 待回填） | 可放心讲 |
| 委派令牌 | 三档齐，**默认 off** | 「验签门常驻；令牌是 off→observe→enforce 灰度路径」 |
| LLM 预算三档/跨档降级 | 切面闸位在，**检查点默认 off 零直通**（base.py:44-47） | 「闸位已就位，默认关是灰度策略」 |
| PG checkpointer | 已实现，**闸控非默认**（默认 InMemorySaver） | 讲「真挂起」限定 supervisor 模式 + 闸开 |
| critic | 规则路由 **stub** | 「当前规则版，语义 critic 是下一步」 |

---

## 6. 预判追问（电梯版最常挨的刀）

1. **「为什么 LangGraph 不选 CrewAI/AutoGen？」** → 状态机显式可控：interrupt/resume 有 checkpointer 真挂起，Send 并发可审计；黑盒框架拿不到这些钩子（09 篇 §1.2）。
2. **「熔断为什么排配额前面？」** → 熔断挡故障放大、配额挡成本；故障期间配额计数无意义——顺序本身是设计点（gateway.py:406 注释可直接引用）。
3. **「supervisor 和 router 区别？」** → supervisor-first 后 router 降格为工人子图内部回环（rag 质量低→rewrite 重试≤2，`lg_rag/nodes.py:203-240`），不再是主路径。
4. **「怎么测这套 LLM 系统？」** → 假 LLM/spy provider 注入 + 契约断言 + 金样，不打真模型（方向⑤展开，09 篇 §5）。

---

## 修订记录

| 日期 | 说明 |
|---|---|
| 2026-10-20 | v1：试讲后修订。v2→v3 变更：编排层措辞通用化（"绝不静默退化为通用回答"，单 rag 降为实例）；数据层改「三表+checkpointer · 证据面/执行面」；传输层补回孤儿补偿（当日完成接线口径）；新增 §3 五问详解、§4 报失去向、§5 红线表 |
