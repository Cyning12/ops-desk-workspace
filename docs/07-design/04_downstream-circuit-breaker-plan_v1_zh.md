# 下游熔断链落地方案（P1 · 八问 Q3）v1

> 本文只写**准备怎么落地**，不含已实现代码。落完会把状态回写到
> `03_agent-tool-reliability-8q-gap-analysis_v1_zh.md` 的「落地状态」。
>
> 术语约定：本文的「熔断」= **downstream circuit breaker**（下游集成点熔断）。
> `lg_rag/multi/nodes.py` 里那个 rewrite 熔断是**规划层**的（限制重规划次数），
> 两回事，不要混。

> **状态命名（先对齐，否则整篇会读反）**：业界与 pybreaker 的语义是——
> - **closed** = 电路**闭合** = 正常放行（"通"）
> - **open** = 电路**断开** = 熔断中、不放行
> - **half-open** = 恢复探测中（**瞬时**状态）
>
> 中文直觉里「关闭」容易被读成"停"，这里正好相反。全文按上面的标准语义写。
> 实质行为（你描述的）是：**open 持续 60s 后放行一次探测 → 成功回 closed、失败回 open**。

---

## 0. 结论先行

**Q：接 Redis 是不是需要再单独加个服务？**

**A：不需要。** 三个理由：

1. 熔断状态是 capability 层的**存储后端选择**，不是一项业务能力。
   pybreaker 自带 `CircuitRedisStorage`，接上 redis 客户端即可跨实例共享——
   它共享的就是 Redis 里的几个 key，不需要中间再插一个决策进程。
2. 唯一值得单起服务的场景是：**跨语言进程共享 + 集中人工干预（强制 open/close）+ 运维看板**。
   当前只有 Python 一侧、且人工干预已经有 kill switch（`budget.py`）在做，不值得。
3. Redis 本身是**基础设施**（docker-compose 起一个实例），不是我们写的微服务。
   真接的时候加的是依赖和连接串，不是服务。

所以本次落地 = **两步**：

| 步 | 内容 | 本次做不做 |
|---|---|---|
| ① | pybreaker 三态熔断（closed / half-open / open，恢复 60s），进程内状态 | **做** |
| ② | 状态存储后端抽象：`memory` / `redis` / `mock-unavailable`，**当前默认 mock 不可用**，验证回落路径 | **做接口 + mock** |

「保留 Redis 查询服务状态能力」= 暴露 `service_status()` 接口：现在读进程内状态、
标注 backend；将来换成读 Redis 共享状态时**调用方一行不改**。

---

## 1. 现状盘点（只认在调用路径上的机制）

| 已有 | 位置 | 能解决什么 |
|---|---|---|
| 七个稳定错误码 + `RETRYABLE_CODES={upstream_error}` | `errors.py:20-44` | 模型侧统一口径 |
| GET 重试 1 次；**写操作绝不自动重试** | `http_generic.py:772` | 偶发抖动 |
| 超时/网络/HTTP 错误归一 | `http_generic.py:263,267,271,789` | 不外泄原始异常 |
| 下游业务码 → 稳定码映射 | `http_generic.py:819-829` | 不外泄下游文案 |
| 结果契约 `output_schema` | `result_contract.py` + R10 | "错了还报成功" |
| 会话配额 + kill switch | `budget.py`，`gateway.py:283,707` | 失控兜底（Q6） |

**缺的是什么（本次要补的洞）**：

下游连续故障时，**每一次调用都要再付一次完整超时**（`timeout_ms` 现为 8000）才能知道
「还挂着」。三个后果：

1. **慢**：一步 8s，32 步预算里能被一个死下游吃光。
2. **放大下游负载**：下游已经在挣扎（5xx/超时），我们还在按节奏继续打——
   熔断的意义正是"别再往一个正在恢复的系统上加压"。
3. **重试纪律失效**：GET 会重试 1 次（`http_generic.py:772`），
   下游挂掉时等于每个调用打 2 次。

---

## 2. 设计决策

### D1 · 三态与参数

closed →（连续 `fail_max` 次**环境类**失败）→ open →（`reset_timeout` 到点）→
half-open →（探测成功）→ closed；（探测失败）→ open。

**half-open 是瞬时状态，不是驻留状态**。准确的行为描述（也是你的描述）：

```
open 且 now - opened_at >= 60s
    → 下一次调用放行一次（此刻标记 half-open）
    → 成功 → closed（恢复）
    → 失败 → open（opened_at 刷新，再等 60s）
```

它只在"这一次探测进行中"存在，探测结束立刻落回 open 或 closed。
这么做的好处：**不需要一个定时器去把 open 翻成 half-open**，
也就没有"状态机漏跑"的问题——状态转换由调用驱动，是 lazy 的。

| 参数 | 默认 | 理由 |
|---|---|---|
| `fail_max` | **5** | 太少会被偶发抖动误伤（一次网络抖就把能力停 60s）；太多会拖长故障期。5 是常见起点 |
| `reset_timeout` | **60s**（按你指定） | 短于下游常见恢复时间会白探测；长于则恢复慢 |
| `success_threshold` | **1** | 半开一次成功即关。探测次数越多，恢复期越长且越多真实请求打到刚恢复的下游 |

### D2 · 粒度：**per capability**（每个能力一个独立 breaker）

熔断的对象是**外部能力**——每个能力是一个独立集成点，失败率、超时、下游实现
各不相同。按能力独立，故障面就被限制在"出问题的那一个"。

| 方案 | 优点 | 代价 |
|---|---|---|
| **capability**（采用） | 精准；一个能力挂了不牵连同 host 的健康能力 | 同一 host 的 N 个能力要各付 5 次失败学费（首次故障期略长） |
| host | 学费只付一次；符合"熔断保护子系统"的经典定义 | **误伤**：A 接口 5xx 会把正常的 B 接口一起熔掉 |

选 capability 的关键理由：**误伤比学费贵**。同 host 的两个接口一个挂一个好是常态
（OA 网关上 `/doc/search` 和 `/ticket/create` 压根是两套实现），
把没坏的也熔掉，等于把局部故障放大成整体不可用——这正是熔断本该避免的事。

（`host` 仍作为 `OPS_CAPABILITY_CB_SCOPE` 的可选项保留，留给"整站确实一起挂"的场景。）

### D3 · 失败分类（★ 整个方案里最容易被写错的一处）

**不能只看错误码。** `upstream_error` 这一个码里同时混着三种完全不同的东西：

| 构造点 | 实际是什么 | 该不该熔 |
|---|---|---|
| `http_generic.py:271` `请求超时` / `:267` `网络错误` / `:789` `传输失败` | **传输层故障**（下游不响应） | ✅ 熔 |
| `http_generic.py:263` `HTTP {code}`（5xx）/ `:829` `HTTP {status}` | **HTTP 状态码** | ✅ 5xx、429 熔 |
| `http_generic.py:829` 兜底 `HTTP 200` | 下游 200 + 未识别的**业务码** | ❌ 不熔 |
| `http_generic.py:157,172,727` 缺凭证/缺租户谓词 | 我们这边配置/参数问题 | ❌ 不熔 |
| `http_generic.py:801` 未配置 base_url / `:522` 存储接口不匹配 | **本地配置问题** | ❌ 不熔 |
| `args_schema_invalid` / `permission_denied` / `duplicate_id` / `policy_blocked` | 业务/闸 | ❌ 不熔 |
| R10 结果契约不符 | 下游活着、响应了、结构不对 | ❌ 不熔（R10 已判失败，不叠加熔断） |

一句话判据：**「下游活着并回答了」就不该熔；只有「不响应 / 5xx / 过载(429)」才熔。**

**落地方式：不解析错误文案，改成结构化字段。**

给 `HttpCapabilityError`（`http_generic.py:103`）加两个**可选**字段（默认 None，向后兼容）：

```python
class HttpCapabilityError(Exception):
    def __init__(self, code, detail="", *, http_status=None, cause=None): ...
    # cause ∈ {"transport", "http_status", "business", "local"}
```

各构造点补齐 `cause`（约 10 处，机械改动）。熔断层只读字段，不碰文案。

> 为什么必须这么较真：靠 `detail.startswith("HTTP 5")` 判定的话，
> **文案一改，熔断就静默变成"永远不熔"或"什么都熔"**——
> 后者更可怕：用户填错 5 次参数，整个能力停 60s。这和 V7 死代码是同一类问题。

### D4 · 接入位置：Policy 之后、**配额之前**

`gateway._prepare_call`（`gateway.py:216`）现有顺序是 `lookup → enabled → Policy → budget`。
熔断插在 **Policy 之后、`budget_check`（`gateway.py:283`）之前**：

```
lookup → enabled → Policy → 【熔断 check】→ 配额 check → 计数 → 执行 → 记录成败
```

- **熔断拦截 = 零出网 + 不计配额 + 不落回执**（没执行就没有副作用，与 R11「被拦下的不计入配额」同一原则）。
- 熔断优先于配额：下游已经不健康，先谈"别打了"，再谈"打几次"。

**成败怎么记给 pybreaker（asyncio 的两个坑）**：

1. pybreaker 的 `call_async` 是 **Tornado-only**（源码里是 `@gen.coroutine`），
   **不能用于 asyncio**。
2. 已实测可行：asyncio 里用上下文管理器形式包住 `await`——
   ```python
   with breaker.calling():
       result = await adapter.ainvoke(args, ctx=ctx)
   ```
   pybreaker 只在**抛异常**时计失败，所以「返回了但不健康」要在块内 `raise` 一个内部哨兵异常，
   外层捕获后照常返回真实错误（失败原因不能丢）。
3. `throw_new_error_on_trip=False`：跳闸那一次**保留原始错误**，
   否则 pybreaker 会把真实原因换成 `CircuitBreakerError`（等于把根因吞了）。

接入点：同步 `_dispatch`（`gateway.py:693`，adapter 调用在 `:717`）、
异步 `_adispatch`（`gateway.py:768`）。

### D5 · 错误码：仍是七个、不增

open 期间返回 **`upstream_error: circuit_open: <host> state=open 剩余 42s`**，
meta 带 `blocked: "circuit"`。

- 为什么是 `upstream_error` 而不是 `policy_blocked`：根因在下游（下游不健康），
  不是我们的闸。模型侧按 `upstream_error`（`RETRYABLE_CODES` 里唯一可重试的码）处理，
  但被熔断挡着**不会真的出门**，安全。
- 与 kill switch 的区分写进 detail：`kill_switch=` vs `circuit_open=`。

---

## 3. Redis 方案（接口先落地，当前 mock 不可用）

### pybreaker 自带的能力

```python
pybreaker.CircuitRedisStorage(state, redis_object, namespace=None,
                              fallback_circuit_state="closed", cluster_mode=False)
```
需要 `redis` 包（`pybreaker.HAS_REDIS_SUPPORT`）。存储接口是
`CircuitBreakerStorage`：`state / counter / success_counter / opened_at` —— **可自定义子类**。

### 两个真坑（先说清，免得将来踩）

1. **同步客户端阻塞事件循环**：`CircuitRedisStorage` 用的是同步 `redis` 客户端。
   在 asyncio 里每次熔断判定都同步读写 Redis = 阻塞事件循环。
   真接时要 `asyncio.to_thread` 包一层 storage，或自己实现 async storage。
   （本次 mock 阶段不触发，但接口要留好。）
2. **Redis 挂了会怎样**：pybreaker 的 `fallback_circuit_state` 是「假设 closed」= **fail-open**。
   我们要的不是这个——是**回落到进程内内存**，并且在观测里**显式标注 degraded**，
   不能假装还是分布式的。

### 落地形态：`app/ops/capability/circuit_storage.py`

| backend | 触发条件 | 行为 |
|---|---|---|
| `memory` | 默认（未配置 Redis） | 进程内；观测标 `scope: process-local` |
| `redis` | 配了 `OPS_CAPABILITY_CB_REDIS_URL` 且 `redis` 包可用 | 共享；观测标 `scope: shared` |
| `mock-unavailable` | **本阶段默认** | 显式返回不可用 → 立即回落 `memory`，观测标 `degraded` + 原因 |

回落规则：Redis 抛错/连不上 → 立刻回 memory，并**记住** `redis_error`（最近一次原因），
`/runtime` 里报出来。

**「查询服务状态能力」的接口**（本次就落地，调用方将来不用改）：

```python
def service_status() -> dict:  # 每个 breaker: state / opened_at / 剩余恢复秒数 / backend / scope
```

---

## 4. 配置（全部 env，可热改的不做——改了要重启，同清单纪律）

| 环境变量 | 默认 | 含义 |
|---|---|---|
| `OPS_CAPABILITY_CB_ENABLED` | `1` | 总开关（出问题时一键摘掉，比改代码快） |
| `OPS_CAPABILITY_CB_FAIL_MAX` | `5` | 连续几次环境类失败才开 |
| `OPS_CAPABILITY_CB_RESET_TIMEOUT` | `60` | 恢复时长（秒） |
| `OPS_CAPABILITY_CB_SUCCESS_THRESHOLD` | `1` | 半开探测成功几次才关 |
| `OPS_CAPABILITY_CB_SCOPE` | `capability` | `capability`（默认，每个能力独立）/ `host` |
| `OPS_CAPABILITY_CB_HALFOPEN_WRITES` | `0` | 写能力是否参与半开探测（**默认否**，见 §9） |
| `OPS_CAPABILITY_CB_BACKEND` | `mock-unavailable` | `memory` / `redis` / `mock-unavailable` |
| `OPS_CAPABILITY_CB_REDIS_URL` | 空 | 接 Redis 时用 |

---

## 5. 观测

`/runtime` 增加 `circuits`：

```json
{"backend": "memory", "redis_error": null, "scope": "process-local",
 "breakers": [{"name": "host:127.0.0.1:18080", "state": "open",
               "fail_counter": 5, "fail_max": 5, "reset_timeout": 60,
               "opened_at": "...", "seconds_until_half_open": 42,
               "blocked_calls": 17}]}
```

**观测口径（对应 §D1「half-open 是瞬时状态」）**：

pybreaker 在 `reset_timeout` 到点后**不会自己把 `current_state` 改成 half-open**，
要等下一次调用的 `before_call` 才转（实测确认）。所以观测端不能只回显
`current_state`——那样会出现「显示 open、实际下一次就放行」。

观测里对 open 的 breaker 额外算 `seconds_until_half_open = reset_timeout - elapsed`，
并在 `elapsed >= reset_timeout` 时把状态显示成 **`open`（可探测）**。

**运维看到的状态必须和实际行为一致**——显示"还没恢复"但实际已经放行，
会诱导人去手动干预一个正在自愈的系统，比没观测更糟。这条写进代码注释和红线。

metrics 增加「被熔断挡下的调用数」，与配额拦截并列。

---

## 6. 红线 R12（新增）

**正向**：连续 5 次环境类失败 → open → 后续调用**零出网**；拨表 60s 后 → half-open
放行 1 次；探测成功 → closed；探测失败 → 回 open。

**反向对照（三条，缺一条就是假通过）**：

| # | 对照 | 防的是什么 |
|---|---|---|
| a | 连续 20 次**业务类**失败（`args_schema_invalid` / 业务码）→ **始终 closed** | ★ 防「把用户填错参数熔了整个能力」 |
| b | 熔断 host A 不影响不同 host 的 B | 防「一个下游挂了全站熔断」 |
| c | open 期间**不计配额、不落回执** | 与 R11 同原则；没执行就没副作用 |

**变异检验**：把分类器改成「所有失败都算环境类」→ 对照 (a) 必须 fail。
（不改实现、只改判定，验证这条红线不是空真。）

**时间怎么办**：测试里**不 sleep 60s**，直接拨 `storage.opened_at`
（已实测有效：拨表后下一次调用即进入 half-open 探测）。

---

## 7. 落地步骤（4 个 commit，每步可独立 revert）

1. **依赖 + 结构化失败分类**：`pybreaker>=1.4,<2` 进主依赖（`redis` 走 extra，本阶段不装）；
   `HttpCapabilityError` 加 `http_status` / `cause`，约 10 处构造点补齐；
   分类器 `classify_failure()` + 单测。
2. **熔断内核**：`circuit.py`（breaker 注册表 + 判定 + 观测）+ `circuit_storage.py`
   （memory / redis / mock-unavailable 三后端 + 回落）。
3. **接入与观测**：`gateway` 接 check（Policy 后、配额前）与成败记录；
   `/runtime.circuits`；metrics。
4. **证据**：R12 红线（正 + 三反 + 变异）、题集 +2 用例、验收脚本加「熔断」层
   （配置级：按下故障注入 → 连续失败 → open → 零出网）。

---

## 8. 明确不做 & 已知边界

- **不做降级链 `fallbacks`**（Q3 的另一半）。熔断解决「别再打坏的下游」，
  降级链解决「打不通时给什么」，是下一步，不要混在本次一起做。
- **不做三层拦截**（§9）——那是「该不该做」的闸，与熔断「能不能发出去」正交，
  排在熔断之后单独做。
- **进程内计数边界**：与 budget 同源，多实例各一份（Redis 接上后才跨实例）。
  观测里显式标 `scope`，不假装是全局的。
- **Redis 真接**留到下一步：要解决同步客户端阻塞事件循环的问题（见 §3 坑 1）。

---

## 9. 写能力放行 · 与熔断的关系 · 三层拦截

> **本节是未来架构设计方案，本次不实现。**
> 本次只落地 §1–§8 的熔断。三层拦截单独排期，且需要配套一个 Java 服务
> （见 §9.5），那是另一块工作——这里先把它想清楚，免得将来只剩口头约定。

### 9.1 现状：现在到底有几个写能力

| 范围 | 写能力 | 说明 |
|---|---|---|
| **生产清单** | **0 个** | `builtin.v1.yaml`(5) + `oa.readonly.v1.yaml`(3) 全部 `side_effect: read` |
| 联调 | 1 个（**不在清单里**） | `oa.ticket.create`，由 `ops-desk-mock-oa/scripts/agent-integration-smoke.py:185` **内联构造**（`side_effect=write`, `risk_level=medium`, `hitl_required=True`），只用于验证写链路（幂等/回执/R5 超时不重发） |

即：**写链路的代码全部就绪并被测着，但还没有任何一个写能力进入生产清单。**
（`gateway.py` 顶部那句"本仓尚无写能力实现"就指这个。）

### 9.2 熔断和「写是否放行」有关系吗：正交，只有两个交点

两者回答的是不同问题，不要混：

| | 回答什么 | 谁决定 |
|---|---|---|
| 熔断 | **这个下游现在还打得通吗** | 自动，按失败率 |
| 写放行 / 审批 | **这个操作该不该做** | 规则 / LLM Judge / 人 |

真正的交点只有两个：

1. **open 期间写能力一样不放行**（和读能力同规则，零出网）。
   这是"别往正在挣扎的下游继续加压"，与操作是否高危无关。
2. **半开探测如果是写，会真的产生副作用**。
   这是唯一需要特殊处理的地方：

   → **默认 `OPS_CAPABILITY_CB_HALFOPEN_WRITES=0`（写能力不参与探测）**。
   理由：写能力的探测失败代价不对等——读探测失败只是白跑一趟，
   写探测失败要占用幂等键租约、留一条失败回执、让人工去看"这张单到底建没建"。
   **让读能力先把路探开，写能力等 closed 再走**，代价只是晚 60s，收益是少一地鸡毛。
   （写能力强制 `idempotency_key`，即使放行也不会建第二张单——但能不探就不探。）

反过来也要说清：**审批通过了不代表下游健康**。审批后再被熔断挡住是正确行为，
返回 `upstream_error: circuit_open: …`，人和模型看到的都是"下游现在不健康，稍后再试"。

### 9.3 三层拦截：现状盘点（先看清楚已经有什么）

| 层 | 现状 | 证据 |
|---|---|---|
| L0 声明 | ✅ 有 | `hitl_required` / `hitl_snapshot_fields`（`types.py:96,98`）；V2 写能力必须 `hitl.required`、V3 high risk 必须 `hitl.required`（`manifest.py:596,602`） |
| L1 规则 | ⚠️ 只有"形态闸"，无业务规则 | `policy.py:87` 有 `high_risk` / `write_not_confirmed` / `sandbox` / `cli` / `tenant_scope_missing`；**没有**金额、白名单、敏感字段这类规则 |
| L2 LLM Judge | ❌ 没有 | — |
| L3 人工审批 | ⚠️ 只有入口，没有流程 | `_host_policy.allow_write`（`policy.py:78`）= "单次人工确认通过"的语义入口，Host 侧塞进来即可放行；但**没有审批单、没有审批状态、没有超时/撤销** |

**最该先说的一件事**：`hitl_required` 目前是**死字段**——
它只在加载期被校验（V2/V3），**运行期没有任何一处消费它**
（`grep hitl_required app/` 除 types/manifest 外零命中）。

也就是说：清单里写着"这个能力需要人工审批"，系统实际**不会拦**。
这正好是 V7 那类教训（声明了但没被调用 = 死代码），而且比死代码更危险——
它会让人以为已经有审批了。

### 9.4 三层怎么接（建议形态）

```
invoke
  → Policy（现有形态闸）
  → L1 规则引擎（纯代码，零 LLM，零延迟）
       命中 "deny"  → policy_blocked
       命中 "need_approval" → 进 L2
       未命中       → 放行
  → L2 LLM Judge（仅 L1 说"需要评估"时才调）
       risk=low  → 放行（记 audit）
       risk=high → 进 L3
  → L3 人工审批（签发 approval_id，落审批单）
  → 熔断 check → 配额 → 执行
```

三个必须在设计时就定的点：

1. **L1 的规则写在哪**：建议**声明在 manifest**（`approval.rules: [{field: $.amount, op: ">", value: 1000, action: need_approval}]`），
   加载期校验形状，运行期由纯代码求值。理由：规则是会变的业务知识，
   应该走清单（Git + PR + 人闸），而不是硬编码在 policy.py 里。
   硬编码的后果和 `risk_level` 一样——改一条规则要发一次版。
2. **LLM Judge 不是"更聪明的闸"，是"更慢且会错的闸"**：
   - 它只在 L1 说"需要评估"时才调（**你的分层是对的**，省掉 99% 的调用）
   - 它的输出必须是**结构化枚举**（`risk: low|high` + 理由），不能是自由文本判断
   - **Judge 超时/不可用 → fail-closed 升级到 L3**，不能默认放行
     （否则"Judge 挂了"就等于"审批形同虚设"，而且是很隐蔽的那种）
3. **L3 的 `approval_id` 要打通到回执**：现有回执已预留 `approval_id`
   （`gateway.py` 顶部注释），审批通过签发 id → 随 ctx 下发 → 回执落库。
   否则事后审计只能看到"有个写操作成功了"，看不到"是谁批的"。

**与熔断的分工一句话**：熔断管"能不能发出去"，三层拦截管"该不该做"。
**三层拦在熔断之前**（先决定该不该做，再看打不打得通）——反过来会先消耗下游探测，
顺序错了会让一个本该被拒的高危操作去触发半开探测。

### 9.5 配套：工单查询 / 结果反馈的 Java 服务（未来）

三层拦截落地时，光有"拦得住"不够，**审批这件事得有人能看见、能操作、能回执**。
需要配套的 Java 服务承担两件事：

| 能力 | 干什么 | 为什么不能只在 Python 侧做 |
|---|---|---|
| **查询工单** | 按 `approval_id` / 时间 / 状态 / 申请人 检索待办审批单与已决审批单 | 审批台是给人用的，查询形态（分页、筛选、导出）与 Agent 侧完全不同 |
| **反馈工单结果** | 审批通过/驳回 → 回调 Agent 侧，把 `approval_id` 与结论落回 | 结果要能被**已有企业流程**（OA 审批、IM 通知）消费，这部分在 Java 侧 |

关键设计约束（现在就写下来，将来别跑偏）：

1. **`approval_id` 是两侧唯一契约**：Java 服务签发 → 随 ctx 下发 → capability 回执落库。
   Python 侧**不自己生成**审批 id，也不认没有 id 的"口头放行"。
2. **结论必须是三态且带时效**：`approved / rejected / expired`。
   **过期必须存在**——审批单挂三天没人批，不能一直停在"待批"当成"可以等"，
   那等于把拒绝变成了无限期挂起。
3. **回调要幂等**：同一 `approval_id` 被重复回调（网络重试/用户重复点击）不能重复放行。
   复用既有幂等语义，不要另写一套。
4. **Java 服务挂了 → fail-closed**：查不到审批结论时按"未批准"处理，
   不能因为审批台不可用就放行（否则攻击面就是"把审批台打挂"）。

（是否复用 `ops-desk-api-java-gateway` 还是新起服务，届时按它当时的职责边界定；
本文档不预设结论。）
