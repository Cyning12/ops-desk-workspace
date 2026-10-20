# 阶段三 · Agent 方向技术面作战手册（四）：三块「承重墙」模块深挖

> 承接 `05`（八问 Q1–Q8）· `06`（八问之外的十大细节方向）· `07`（记忆 / Prompt / 模块全景）。
> 07 篇指出你列的五个模块漏了三块最能拉开差距的，本篇把这三块**展开到可讲、可辩、能接追问**的深度：
>
> | # | 模块 | 一句话 | 本仓 |
> |---|---|---|---|
> | ① | **评测与红线层** | 我怎么证明它没退步 | R0–R15 十六条红线 + 九层验收 |
> | ② | **契约层** | 把模型的不确定性挡在边界外 | 参数 / 结果 / 步骤 + 模型侧四套 |
> | ③ | **人闸与幂等层** | 让写操作可逆、可对账 | HITL + 幂等租约 + 回执 |
>
> 三块的共同点是：**它们都在回答"凭什么敢上生产"，而不是"Agent 长什么样"。**
> 全部事实来自本仓只读核查（`ops-desk-api` / `ops-desk-mock-oa`），带 file:line。

---

## 0. 为什么这三块是「承重墙」

判据只有一条：**缺了会不会造成「不可逆的错」或「看不见的错」。**

| 模块 | 缺了会怎样 | 属于哪类错 |
|---|---|---|
| 评测与红线 | 不敢改（改了不知道好坏）；改坏了没人发现 | **看不见的错**（退化无感） |
| 契约 | 模型/工具带错数据继续往下走，没有任何环节报错 | **看不见的错**（静默传错） |
| 人闸与幂等 | 重复建单、越权写；出错后无法挽回、无法对账 | **不可逆的错**（副作用已发生） |

> **为什么这三块最能拉开差距**：绝大多数候选人能讲"我做了什么"（能力注册表、编排、RAG），
> **讲不了"我怎么证明它是对的、以及错了怎么收场"**。后者才是资深面真正在压的。
>
> **一句话记忆锚点**：
> 「**可逆的错误可以事后修，看得见的错误可以事后查；不可逆 + 静默的错误，你连"出过事"都不知道。**」
> 这三块就是专门对付第三种的。

---

## 1. 评测与红线层 —— 「我怎么证明它没退步」

### 1.1 它解决什么问题

三个真实痛点，每个都能对应到一次事故：

1. **改坏了不知道**：改一个节点的判定逻辑，可能让整个规划飘移，但单测全绿。
2. **"跑通就算过"**：验收只看"有没有报错"，于是"一律拒绝"也能过——**假通过**。
3. **加了一条永真的规则**：写了条防护，其实永远不会触发，但你以为有防护——**空真**。

本仓对这三个痛点各有一个针对性机制，而且**机制本身就是设计过的**（下面逐条讲）。

### 1.2 红线体系：本仓最值钱的资产

#### 1.2.1 清单的结构

文件：`evals/agent/redlines/capability_v1.yaml`（约 200 行）

```yaml
version: 1
layer: capability + supervisor
redlines:
  - id: R0
    severity: critical
    statement: 红线清单与实现必须一一对应（声明=实现）
    rationale: 清单漂移后就会变成废纸，而人会继续以为有防护。类比 V7 的死代码教训。
    source: 本文档自身
```

每条红线只有 **5 个字段**：`id` / `severity`（全部 `critical`）/ `statement`（守什么）/ `rationale`（为什么守 + 最容易写错的地方）/ `source`（**从哪次真实事故或评审来的**）。

> **`source` 这个字段是整套设计的灵魂**：它要求每条红线都能指回一次真实事故。
> 这不是形式——它挡住了"拍脑袋加规则"，因为**你没法给一条凭空想的规则填 source**。

#### 1.2.2 R0–R15 全表（16 条，编号连续无缺号）

| 编号 | 守什么 | 来源（省写） |
|---|---|---|
| **R0** | 红线清单与实现必须一一对应（声明 = 实现） | 本文档自身 |
| **R1** | 无写放行时，`side_effect ∈ {write, irreversible}` 必须被拒，**且下游零请求** | H4 写操作闸 |
| **R2** | 出站请求不得含未声明的模板变量，**也不得静默渲染成空串** | H4 校验 V5 |
| **R3** | 对外错误不得含下游原文，只能是稳定错误码 + 自研详情 | 错误归一 + 联调 D2 |
| **R4** | 含**非 ASCII** 参数的写调用必须成功（幂等键须 ASCII 安全化） | 联调实测（曾让所有含中文参数的写全部发不出去） |
| **R5** | 写操作**超时后不得重发**（对端被调用次数必须为 1） | 重试纪律 + 联调 C2b |
| **R6** | 出站请求**不得经环境代理**（除非显式配 `OPS_CAPABILITY_HTTP_PROXY`） | 联调实测（内网调用被代理劫持成看不懂的 502） |
| **R7** | 命中幂等键的那次**不得再发请求**，且不得留下第二条回执 | W5/W6 幂等防重 |
| **R8** | 防重存储**只有异步接口**时，同步 `invoke` 必须显式失败且下游零请求；`ainvoke` 须正常 | 2026-09-20 联调实测 |
| **R9** | 幂等命中必须**重放上次的业务结果**（回执 `captured` 字段），不能只回 `duplicated=True` | 联调 C1c（db 模式第二次 `ticketId=None`） |
| **R10** | 声明了 `output_schema` 的能力结果不符契约必须判失败；**未声明不得推测性拦截** | P0-1 结果契约（八问 Q2/Q4） |
| **R11** | 会话调用数 / 写数达上限须拦下（**零请求**）；kill switch 须停用；**被拦调用不计配额** | P0-2 会话配额 + kill switch（Q6） |
| **R12** | 「环境类」失败达阈值须熔断（零出网、60s 探测）；**业务类 / 本地装配不得计入** | P1 下游熔断（Q3） |
| **R13** | 降级必须**显式声明**；**写能力永不降级**；标记**必须写进工具输出本身** | P1 降级链（Q3 下半） |
| **R14** | 多步串联必须有**步骤契约**；未声明不得拦；校验须在**喂入前**且命中后**真的注入** | P1 步骤契约（Q4） |
| **R15** | 重规划须保住**不可变前缀**；**失败终态不进前缀** | P1 可恢复点（Q8） |

> **16 条红线 ≈ Q1–Q8 的可执行形态。** 这条对应关系值得背下来：
> Q1（选错/传错）→ R2/R3 · Q2（结果错）→ R10 · Q3（超时/限流/挂了）→ R5/R12/R13 ·
> Q4（步步错）→ R14 · Q6（失控）→ R11 · Q8（重规划）→ R15。

#### 1.2.3 三条元规则（写在文件头注释里，原文照录）

```yaml
# 本文件是**清单**（给人看的、可审计的）；实现在 tests/eval/test_capability_redlines.py。
# 两者必须一一对应：
#   - 清单里有、测试里没有 → 「声明了但没实现」→ 测试会 fail
#   - 测试里有、清单里没有 → 「实现了但没记录」→ 测试会 fail
# 这条对齐本身也是一条红线（R0）——否则清单会慢慢变成一张废纸。
```

```yaml
# 每条红线在测试里都要有**正向断言 + 反向对照**：
#   - 正向：该拦的拦住了
#   - 反向对照：该放行的放行了
# 只做正向会得到**假通过**——"一律拒绝"天然满足"未授权访问被拒绝"。
```

还有一条关于**为什么 R14/R15 要和 capability 放同一份清单**的设计判断：

```yaml
# 2026-09-20：R14 / R15 是**编排层**（supervisor 多步串联）的红线，不是 capability 层。
# 仍放在同一份清单里——红线是**否决项**，拆成两份就要两套 R0 对齐机制，
# 而"整体不通过"这件事本身不该分层。
```

> **这条特别好讲**：它体现了"**否决项的集合不应按代码分层**"的判断。
> 分层是按实现分的，否决是按后果分的——**后果不受目录结构管辖**。

### 1.3 防「假通过」：正向断言 + 反向对照

实现：`tests/eval/test_capability_redlines.py`

```python
def assert_redline(*, redline_id: str, holds: bool, control: bool, detail: str = ""):   # :74-82
    assert holds, f"[{redline_id}] 红线被突破：{detail}"
    assert control, (
        f"[{redline_id}] 反向对照不成立——该放行的被拦住了，"
        f"这条红线可能是'一律拒绝'造成的假通过：{detail}"
    )
```

**每条红线必须同时给两个断言**。以 R1 为例（`:194-202`）：

| 断言 | 内容 |
|---|---|
| `holds`（正向） | `blocked.ok is False and tx.calls == []` —— 该拦的拦住了，**而且下游零请求** |
| `control`（反向） | `allowed.ok is True and len(tx.calls) == 1` —— 该放行的**真的发出去了** |

> **注意 `tx.calls == []` 这个断言**：它断的不是"返回了拒绝"，而是**"请求根本没发出去"**。
> 这是本仓贯穿始终的口径：**"拒了但请求已经发出去"等于没拒。**
> 这句话可以直接当面试金句用。

### 1.4 防「空真」：变异检验（mutation）

7 处 `test_*_is_not_vacuous`（`:617`、`:743`、`:822`、`:948`、`:1105`、`:1570`、`:1663`）。做法是**把防护摘掉，看红色断言会不会翻**：

```python
    monkeypatch.setattr(gw, "_result_contract_verdict", lambda spec, output: None)
    ...
    assert res.ok is True, f"变异未翻转：契约被摘掉后仍然失败 err={res.error!r}"   # :617-633
```

> **口述要点**：「新加一条红线之后，我会**把行为改坏一次，确认它真的会 fail**。
> 不做这步，你可能加了条**永远为真的空规则**——它每天都绿，你还以为有防护。
> 我把这个做成了常规动作：每个关键机制都配一个 `*_is_not_vacuous` 测试。」

### 1.5 题集与确定性判分

#### 1.5.1 题集规模（真实数字）

| 题集 | 位置 | 规模 |
|---|---|---|
| RAG 金样 | `evals/golden/queries_v1.yaml` | **73 条**（zh2en 26 / zh2zh 20 / en2en 16 / **negative 11**） |
| capability 黑盒 | `evals/agent/golden/capability/` | **23 条** |
| router | `evals/router/labeled_router_v1.yaml` | **34 条**（实际：rag 19 / direct 9 / refuse 6） |
| 其他 | `evals/agent/golden/` | e2e 1 · router 3 · strategy_builder 2 · supervisor 2 |

> ⚠️ **负极样本是重点**：金样集里有 **11 条 negative**（词面零命中 + 语义零命中）。
> 被问到"你怎么防止评测集自己失真"时，这就是答案：**只准备正例的题集，会奖励"什么都答"的系统。**

#### 1.5.2 确定性 grader（**不靠 LLM 自评**）

生产与评测共用：`tests/eval/eval_agent_graders.py`（由 `run_experiment.py:28-35` import）

| grader | 判定方式 | 行号 |
|---|---|---|
| `eval_route_match` | **枚举相等** `int(actual == expect)`，且 `expect ∈ {rag, direct, refuse}` | `:30-34` |
| `eval_allowlist_match` | **集合相等** `int(set(actual) == set(expect))` | `:37-39` |
| `eval_plan_schema` | 逐项校验：非空 `id`/`input`、`type ∈ {rag,extract,tool}`、`tool` 非空 | `:57-76` |

supervisor 的 `acc.plan_match` 是**三项 AND**（`run_experiment.py:207-212`）：
**结构合规 ∧ 子任务类型序列相等 ∧ 所有 tool id 都在 allowlist 内**。

> **为什么这件事重要**：判分是**比特级确定**的，所以"规划有没有飘"是可测的、可复现的。
> 如果用 LLM 打分，你得到的是一个会漂移的分数，**没法判断"这次 0.82 和上次 0.85 的差别是真实退化还是打分抖动"**。

#### 1.5.3 热路径禁 LLM-as-judge

原注释：`app/ops/tracing.py:343`

```
Score 名须符合 ROADMAP §3.2（如 ``stab.fallback``）。热路径禁止 LLM-as-judge。
```

配套：
- `_judge_quality` 是**零额外 LLM 的确定性映射**（`app/ops/lg_rag/nodes.py:181-190`）——它叫 judge，但不调模型。
- 采样评分默认关：`_should_sample_eval_score` 里 `rate <= 0.0 → return False`（`tracing.py:330-337`）。
- 任务文档明确把"LLM-as-judge / `acc.answer_judge` 热路径"列入排除项（`docs/tasks/done/task_eval_online_sample_scores.md:73,131`）。

> **口述要点**：「我**不在请求路径上放 LLM-as-judge**。两个理由：一是延迟和成本会翻倍；
> 二是**它会把"可观测"变成"新的不确定性来源"**——你用一个会漂移的东西去判断另一个会漂移的东西。
> 判分放离线，且用确定性 grader。」

### 1.6 防「规划漂移」：基线 diff

实现：`evals/agent/golden/capability/runner.py:310-326`

```python
def diff_baseline(current, baseline) -> dict[str, Any]:
    """逐 case、逐字段给差异——覆盖 `expect` **没写**的字段。"""
    ...
    return {"added": added, "removed": removed, "changed": changed,
            "drift": bool(added or removed or changed)}
```

两个设计细节值得讲：

1. **覆盖 `expect` 没写的字段**——不只是"题集里声明过的字段对不对"，而是**全字段比对**。
   因为最常见的退化是"多了一个本不该有的字段"或"某个没断言的字段悄悄变了"，**只比对 expect 会漏掉它们**。
2. **基线更新必须显式 `--update-baseline`**（`:359-368`），注释是一句判词：
   > **"跑一遍自动覆盖 = 等于没有基线。"**

> **口述要点**：「基线最容易死的方式是**自动更新**——跑一遍就覆盖，那它永远等于当前状态，
> 测出来的"漂移"永远是 0。所以我把更新做成显式的：**你要么承认这次变化是有意的，要么就是退化。**」

### 1.7 九层验收（一键门禁）

脚本：`scripts/acceptance/capability_acceptance.sh`（`run_step` 顺序 `:133-165`；定义见 `:11-21`）

| 层 | 内容 | 证明什么 |
|---|---|---|
| 1 | 单测 `pytest tests -k capability` | 局部逻辑对 |
| 2 | 题集（黑盒 + **基线 diff**） | 行为没飘 |
| 3 | **红线** `pytest tests -m redline` | 否决项没破 |
| 4 | 失控兜底（配额 + kill switch） | 打不爆 |
| 5 | 熔断 | 下游挂了不拖死自己 |
| 6 | 降级 | 打不通时有兜底且**带标记** |
| 7 | 持久化（DB store / sink） | 真的落库了 |
| 8 | 编排（步骤契约 + 可恢复点） | 多步串联真的串上了 |
| 9 | 联调（**真桩服务** 26 项） | **真的发得出网吗** |

> **第 9 层的定位**（脚本注释 `:20` 原文）：**"桩服务联调 真的发得出网吗（唯一能证明这点的）"**。
> 这句话值得背——它说清了单测/桩测试与真联调的分工：
> **前面八层证明"逻辑对"，第九层证明"真的连得通"。**

**最新一份验收报告**（`.acceptance-reports/capability-acceptance-20260921-103111.md`）：

- 结论：**通过**（失败 0 · 跳过 0），九层全 PASS
- 明细：`354 passed, 1 skipped` · 题集 `28 passed` · 红线 **`57 passed`** · 联调 `26 项，失败 0`

报告字段固定（脚本 `:216-238`）：标题 / 时间 / 仓库 / 桩服务 / **结论** / 九层结果表 `| 层 | 内容 | 结果 | 说明 |` / 明细。

### 1.8 真进程联调：HITL 审批回路

脚本：`scripts/acceptance/hitl_approval_loop.sh` → 驱动 `hitl_approval_loop.py`

`.sh` 只负责：清端口 → 起 API(uvicorn) + mock-oa(Java jar) → **内容型就绪探针** → 调驱动（`:86-127`）。

**真实步骤链**（`.py:93-231`）：**9 个主步骤 + 2 个对照子步 = 11 个编号块，共 17 项断言（PG 模式 16 项）**

| # | 步骤 | 考什么 |
|---|---|---|
| 1 | 代理侧 `/hitl/runtime` 可达 + 真有持久化 + 密钥已配 | 环境真的对了（不是"以为配了"） |
| 2 | 造一条待批申请 | 申请真的落库 |
| 3 | mock-oa 拉待办（签名 GET） | 出站签名正确 |
| 4 | **缺凭据必须被拒** | 业务面守卫没被绕过 |
| 5 | mock-oa 批准（**中文审批人 → 进 body，不进头**） | R4 的同一类坑（头只能 latin-1） |
| 6 | 代理侧**真的收到了**（标注"**决定性证据**"） | 回调真的到达 |
| 7 | 重复回调必须 **409**，且要跟"申请丢了"区分开 | 语义区分 |
| 8 | 假签名 → **401** | 鉴权真的生效 |
| 9 | 恢复端点：**真驱动**，且不许假装成功 | 恢复真的跑起来了 |
| 9b | 对照：已批准但拿不到 `unlock_subtask_id` ⇒ 409，**与 503 区分开** | 错误语义不混淆 |
| 9c | 对照：还没决的申请不许恢复 | 状态机没被绕过 |

> **这段是"我真的跑过真进程"的最硬证据**，因为里面有 6 个"**不许假装失败/成功**"型的断言
> （第 1、6、9、9b 步）——**这些断言只有在真进程上才有意义**，桩测试写不出来。

### 1.9 常见追问 + 答法

| 追问 | 答法 |
|---|---|
| **"红线和大盘准确率什么关系？"** | **不是一回事，而且不能互补。** 红线是**否决项**：任一条被突破，整体不通过，**不能"用别处的高分补"**。准确率是连续的、可权衡的；红线是二值的、不可权衡的 |
| **"怎么防止红线清单变成摆设？"** | 靠 **R0 这条元红线**：清单里有测试里没有 → 声明了没实现 → fail；测试里有清单里没有 → 实现了没记录 → **也 fail**。**双向对齐**，否则清单会慢慢变成一张废纸——**而人会继续以为有防护** |
| **"你怎么知道红线不是空真？"** | 两道：① **反向对照**（`assert_redline(holds, control)` 两个断言都必过）——只做正向的话，"一律拒绝"天然满足；② **变异检验**（7 处 `*_is_not_vacuous`，把防护摘掉看红色断言会不会翻） |
| **"验收跑过就算过？"** | 九层是**门禁**不是报告：任何一层失败即整体不通过；且第 9 层必须是**真桩服务**——注释写明它是"**唯一能证明真的发得出网的**"那一层 |
| **"评测集会不会自己失真？"** | 有**负样本**（金样集 11 条 negative）。**只准备正例的题集，会奖励"什么都答"的系统** |
| **"你怎么测'规划飘了'？"** | **基线 diff**：逐 case 逐字段比对，**且覆盖 `expect` 没写的字段**；基线更新必须显式 `--update-baseline`——**跑一遍自动覆盖等于没有基线** |
| **"为什么不用 LLM-as-judge？"** | 热路径明确禁止。① 延迟成本翻倍；② **它把"可观测"变成"新的不确定性来源"**——用会漂移的东西判断会漂移的东西，你分不清是真实退化还是打分抖动 |
| **"评测和线上是什么关系？"** | 判分用**确定性 grader**（路由枚举相等 / 白名单集合相等 / 计划结构），所以"规划有没有飘"是可复现的；线上抽样评分**默认关**（`rate<=0`） |
| **"这套东西的成本高不高？"** | 成本在**离线**：跑一次九层验收是分钟级、零 LLM 调用（红线 57 项全是零 socket）。**热路径零成本**——这正是不把 judge 放热路径的收益 |

### 1.10 缺口（主动说）

| 缺口 | 位置 | 怎么说 |
|---|---|---|
| 红线测试文件有**整段重复定义** | `tests/eval/test_capability_redlines.py` 的 R10/R11 两个 block（`:562-765` 与 `:767-970`）逐字节重复，`@redline` 装饰器重复出现 | 「测试文件里有一处遗留的重复定义，**不影响 R0 对齐**（仍是集合比较），但我知道它是冗余，是清理项」 |
| router 题集注释与内容**不一致** | `evals/router/labeled_router_v1.yaml` 文件头声称 30 条，**实际 34 条** | 「这属于**注释漂移**，正好说明我为什么给红线清单加了 R0——**注释没人守，就会漂**」 |
| 没有 SLO / 告警 | — | 见 07 篇 L9：**量级没到，先不做** |

### 1.11 口述稿（90 秒）

> 「评测这块我的核心主张是：**验收必须是"否定性"的，不能是总分制的。**
>
> 我有一份红线清单，**R0 到 R15 十六条**，每条都写清楚四件事：守什么、为什么守、
> **最容易写错的地方**，以及**它是从哪次真实事故来的**。最后那个 `source` 字段是关键——
> 它挡住了拍脑袋加规则，因为**你没法给一条凭空想的规则填来源**。
>
> 而且这套东西有**三层防伪**：
> 第一层，**R0 元红线**——清单里有测试里没有要 fail，测试里有清单里没有**也要 fail**。
> 双向对齐，否则清单会慢慢变成废纸，**而人会继续以为有防护**。
> 第二层，**正向断言 + 反向对照**——每条红线既要证明"该拦的拦住了"，也要证明"该放行的放行了"。
> 只做正向会得到假通过，因为**"一律拒绝"天然满足"未授权访问被拒绝"**。
> 第三层，**变异检验**——新加一条红线之后，我会**把行为改坏一次，确认它真的会 fail**。
> 不做这步，你可能加了条**永远为真的空规则**。
>
> 另外两条我很想说的：一是**验收是九层门禁**，最后一层必须是**真桩服务**——
> 前面八层证明"逻辑对"，只有第九层能证明"**真的发得出网**"。
> 二是**热路径禁 LLM-as-judge**，判分用确定性 grader，
> 因为用一个会漂移的东西去判断另一个会漂移的东西，**你分不清是真实退化还是打分抖动**。」

---
## 2. 契约层 —— 把模型的不确定性挡在系统边界外

### 2.1 它解决什么问题

**这是"工程化"和"调 prompt"的分水岭。**

调 prompt 的思路是「让它更准」；契约的思路是「**让它错了也在边界上被挡住**」。
前者是在降低错误概率，后者是在**切断错误传播**。生产系统必须先做后者——
因为概率再低，跑够多次一定会发生，而**发生在边界上的错是可拦的，发生在链路中间的错是不可拦的**。

本仓有四套契约（比常见认知多一套）：

| 契约 | 管什么 | 时机 | 位置 |
|---|---|---|---|
| **参数契约** `args_schema` | 参数**形态** | 加载期 + 出门前 | `manifest.py` + `schema_validate.py` |
| **结果契约** `output_schema` | 结果**业务完整性** | 拿到结果后 | `result_contract.py` |
| **步骤契约** `produces`/`consumes`/`depends_on` | 上一步产出**能不能满足**下一步 | 喂入前 | `multi/step_contract.py` |
| **模型侧契约** 结构化输出 | 模型输出**是不是合法结构** | 解析时 | `structured_output/` |

> **一条贯穿的纪律**：**只对显式声明了契约的对象做校验；未声明的一律不拦。**
> 原因在 §2.4 和 §2.5 都会出现，可以总结成一句：
> **「契约是显式声明出来的，系统不替你猜。」**
> 猜出来的契约会变成一种隐形的硬编码——**改起来没人敢动**。

### 2.2 参数契约：`args_schema`

#### 2.2.1 能力声明的完整字段（`CapabilitySpec`）

`app/ops/capability/types.py:71-118`（`@dataclass(frozen=True)`）：

| 字段 | 类型 | 含义 |
|---|---|---|
| `capability_id` | `str` | 能力唯一 id |
| `kind` | `str` | 适配器类型（`local_fn` / `http` / `sandbox` / `cli` / `mcp`） |
| `description` | `str` | 面向模型的能力描述 |
| **`args_schema`** | `dict \| None` | **参数 JSON 形态** |
| `tags` | `tuple[str, ...]` | 标签（用于基线按域放开） |
| `risk_level` | `str` | `low`/`medium`/`high` —— **做错后的危险程度** |
| `enabled` | `bool` | 是否启用 |
| `tenant_scoped` | `bool` | invoke 必须含租户谓词 |
| **`side_effect`** | `str` | `none`/`read`/`write`/`irreversible` —— **写操作闸的唯一挂钩点** |
| `when_to_use` / `when_not_to_use` | `str` | 面向模型的选择依据（正反都给） |
| `http` | `dict \| None` | 绑定声明（**只存环境变量名 / 凭证名，不存密钥值**） |
| `hitl_required` | `bool` | 是否必须人工确认 |
| `hitl_snapshot_fields` | `tuple[str, ...]` | ⚠️ 声明了但**全仓无消费点**（见 §3.11） |
| `receipt_capture` | `tuple[str, ...]` | 副作用回执捕获的 JSONPath |
| **`output_schema`** | `dict \| None` | **结果契约** |
| `visibility` | `dict \| None` | 可见范围 |
| `fallback` | `dict \| None` | 降级声明（`None` = **不降级**） |

> **`risk_level` 与 `side_effect` 是两个维度**，别混：
> 前者是**做错后的危险程度**，后者是**有没有副作用**。
> 写操作闸挂在 `side_effect` 上，**不靠 `risk_level` 代理**——这是设计纪律。

#### 2.2.2 真实声明长什么样

`app/ops/capability/manifests/oa.readonly.v1.yaml:39-49`：

```yaml
    args_schema:
      type: object
      required: [keyword]
      properties:
        keyword:
          type: string
          description: 检索关键词（文件标题、编号或内容片段）
        top_k:
          type: integer
          default: 10
          description: 返回条数上限
```

#### 2.2.3 校验时机：**加载期 + 调用期，两者都做**

**加载期**（`manifest.py:513-517`）——注意最后那句，它是一条硬纪律：

```python
    args_schema = raw.get("args_schema")
    if args_schema is not None and not isinstance(args_schema, dict):
        raise ManifestError(f"{loc} args_schema 必须是 mapping")
    if args_schema is None:
        raise ManifestError(f"{loc} 缺 args_schema（无 schema 的能力无法进 FC 目录）")
```

**调用期**（`gateway.py:361-364`）：

```python
    # provide 无 args；invoke 有 schema 才校验（force 预留：无 schema 时亦拒绝写路径）
    if mode == "invoke":
        schema_err = validate_capability_args(args, spec.args_schema)
```

校验器 `schema_validate.py:14-27`，**只支持一个子集**：`type`（含 union list）/ `properties` / `required` / `additionalProperties`（`:1-7` 明确声明这是有意收窄的）。

失败返回（`gateway.py:367-374`）：

```python
        if schema_err is not None:
            result = CapabilityResult(
                ok=False,
                error=schema_err,                       # "args_schema_invalid: 缺必填字段: keyword"
                capability_id=cid,
                duration_ms=0.0,
                meta={"kind": spec.kind, "args_schema_invalid": True},
            )
```

错误串形状由 `schema_validate.py:27` 构造：`f"args_schema_invalid: {detail}"`，
detail 例如 `缺必填字段: keyword`（`:80`）、`禁止额外字段: [...]`（`:99`）。

#### 2.2.4 设计约定：**业务不变量不进 schema**（CODING P-16）

`docs/standards/CODING_BACKEND_L2_v1_zh.md:68-72`：

```markdown
### P-16 Capability 契约纪律

- `CapabilitySpec.args_schema` 只描述参数 JSON 形态；业务不变量留在领域代码 / Policy。
- 文档与注释称进程内「注册表」；禁止写成已上线「注册中心 / 跨进程发现服务」。
- 详见 `app/ops/capability/` 包注释与 `schema_validate.py`。
```

> **这条规则值得单独讲**，因为它是很多团队的常见坑：
> 「`args_schema` 我**刻意只描述参数形态**，业务不变量不放进去——比如"结束日期不能早于开始日期"、
> "这个工单必须处于某状态才能关闭"。原因是**两个消费者对它的要求不同**：
> schema 是给**模型**看的（决定它怎么填参数），业务不变量是给**系统**用的（决定这次调用合不合法）。
> 混在一起会让模型试图去满足它不该管的条件，而且**schema 一旦承载业务语义，改业务就得改 schema，改 schema 就动到工具目录**。」
>
> 顺带一个细节也能加分：**同一条 CODING 规则里还写了"禁止把进程内注册表写成已上线的注册中心"**——
> 这说明我对"对外表述的准确性"是有纪律的，不是随口说。

### 2.3 结果契约：`output_schema` / `result_contract`

#### 2.3.1 它校验哪 8 类问题

`app/ops/capability/result_contract.py`，`validate()` 在 `:77-155`：

| # | 问题 | 报什么 | 行号 |
|---|---|---|---|
| 1 | required 路径缺失 | `缺字段 {expr}` | `:96-100` |
| 2 | required 字段为 `None` | `字段为 null {expr}` | `:101-104` |
| 3 | required 命中「空」 | 记入 `empty_hit`（**不立即失败**） | `:105-106` |
| 4 | min_items 路径缺失 | `缺字段` | `:112-117` |
| 5 | min_items 值类型不符 | `{expr} 不是列表（{type}）` | `:118-123` |
| 6 | min_items 配置非法 | `min_items 配置非法` | `:124-131` |
| 7 | **条数不足** | `{expr} 条数={n} < {need}` | `:132-141` |
| 8 | **空且声明为可疑** | `空结果可疑 ...` | `:143-153` |

#### 2.3.2 「空是不是可疑」—— 一个很细的设计

```python
def _is_empty(value: Any) -> bool:                    # :66-74
    """什么叫"空"——**None 与缺失不算空**，那是"没这个字段"，由 required 管。"""
    if value is None or value is MISSING:
        return False
    if isinstance(value, (str, bytes)):
        return len(value) == 0
    if isinstance(value, (list, tuple, dict, set)):
        return len(value) == 0
    return False
```

判定（`:143-153`）：`empty_hit` 非空 **且** `empty_is_suspicious=True` → `ok=False, suspicious=True`。

> **这个三分解法是本节最值得讲的一点**，因为它说明作者想清楚了"空"的三种情况：
>
> | 情况 | 判据 | 谁来管 |
> |---|---|---|
> | 没这个字段 | `MISSING` | `required` |
> | 字段在但是 `null` | `None` | required 的 null 检查 |
> | **字段在、类型对、但是空的** | `len == 0` | **`empty_is_suspicious` 开关** |
>
> 为什么要分开？**因为"空列表"在业务上可能是正常的（今天没有待办），也可能是可疑的（应该有三条却返回零条）。**
> 这两种情况从数据上分不出来，**只能由声明它的人来定**——所以它是个开关，不是默认规则。

#### 2.3.3 失败时报什么、写在哪

**错误码复用 `upstream_error`，不新造码**（`gateway.py:558-569`）：

```python
            error=format_error(UPSTREAM_ERROR, verdict.error_detail()),
            ...
            meta_extra={
                "result_contract_violated": True,
                "result_contract_reason": verdict.reason,
            },
```

- detail 拼法（`result_contract.py:61-63`）：`f"{PREFIX}: {self.reason}"`，
  最终形如 **`upstream_error: result_contract: 缺字段 $.data.ticketId`**
- 判定结果写进 **`meta`**（`result_contract_violated` / `result_contract_reason`）；
  另有一处"成功但空"：`meta["result_empty"] = True`（`gateway.py:580-584`）

**设计理由（注释原文，`gateway.py:555-557`）**：

```
★ 结果不符合契约 = 这次调用**不能用**。宁可判失败，也不让残缺结果混进后续规划
（Q2/Q4：错了还报成功，会把整条链路带偏）。
```

> **为什么错误码复用而不新造？** 因为错误码是**给模型看的词表**，有"七个不增"的纪律（见 06 篇 §4.5）：
> 新失败只能落既有码 + 用 detail 区分。**词表一膨胀，模型就开始乱选。**

#### 2.3.4 「未声明不得推测性拦截」

`gateway.py:496-502`：

```python
def _result_contract_verdict(spec: CapabilitySpec, output: Any) -> Any:
    """未声明契约 → ``None``（**不做任何推测性拦截**，契约是显式声明出来的）。"""
    if spec.output_schema is None:
        return None
    return validate_result_contract(
        spec.output_schema, _contract_payload(spec, output)
    )
```

对应红线 R10（`capability_v1.yaml:96-107`），其 `rationale` 里有一句极重要的两句对照：

> ①「工具返回缺字段、类型变了、列表为空，过去**一律 ok=True**——这是唯一一处
> "**错了还报成功**"的口子：Agent 拿着残缺结果继续规划，整条链路从这里开始错，**而没有任何环节报错**。」
> ②「反向那半句同等重要：契约是**显式声明**出来的，不是系统替你猜的——
> **没声明就擅自拦截，等于把"能用"变成"随机不可用"。**」

### 2.4 步骤契约：`produces` / `consumes` / `depends_on`

这是**四套契约里最容易被忽略、但最能体现"多步串联真的串上了"**的一套。

#### 2.4.1 它管哪些字段

`app/ops/lg_rag/multi/step_contract.py`：

| 概念 | 含义 | 行号 |
|---|---|---|
| `produces` | 本步**承诺产出**哪些字段 | `:106-108` |
| `consumes` | 本步**要吃的字段**，形如 `{前驱别名: [字段]}` | `:111-124` |
| `depends_on` | 显式依赖 | 闸门 `:210` |
| 别名重映射 / 解析 | `remap_consumes` / `resolve_consumes` | `:127-140` / `:143-162` |
| **喂入前闸门** | `gate()` | `:195-248` |
| 确定性绑定 | `bind_args` / `render_context_block` / `bind_input` | `:288-298` / `:301-326` / `:329-340` |

#### 2.4.2 三种拦截原因，只有一种叫人

```python
BLOCKED_PREFIX_TOUCH = "prefix_touch_required"          # :55-67
BLOCKED_REASONS = (BLOCKED_PREDECESSOR_FAILED, BLOCKED_CONTRACT_MISSING, BLOCKED_PREFIX_TOUCH)
# 只有这个原因需要人来批：它意味着"要满足新计划，得重跑一个已执行的步骤"
HITL_REASONS = frozenset({BLOCKED_PREFIX_TOUCH})
```

| 原因 | 含义 | 要不要人 |
|---|---|---|
| `predecessor_failed` | 前驱是失败终态 | ❌ 不叫人，只是本步不执行 |
| `contract_missing_field` | 前驱输出缺后继声明的字段 | ❌ 不叫人 |
| **`prefix_touch_required`** | **要改不可变前缀**（= 换幂等键 = **新的写**） | ✅ **叫人** |

处置（`nodes.py:620-636`）：**本步不执行、下游零请求**——不加入 `ready`，写一条错误终态进 `done`，使后继同批级联停。

> **"只有一种情况叫人"是本仓最漂亮的设计判断之一**，值得单独一段口述：
> 「**审批是有成本的，到处挂 HITL 等于没有 HITL。** 我的人闸只有**一条**触发原因：
> **要改动一个已经执行过、且不可撤销的步骤**。因为那意味着**换幂等键 = 一次新的写 = 新的副作用**。
> 前驱失败、缺字段这些拦截**不需要人**——它们只是"这一步不执行"，没有产生任何新的副作用。

#### 2.4.3 依赖判定：非法依赖必须"不派工人"

`depends_on` 的合法值只有两种：**已签发的 `subtask_id`**，或**唯一解析到某一项的别名**。
三类非法（`nodes.py:286-313` / `:316-338`）：

```python
        if token == own or token == row.get("alias"):
            return [], "depends_on 指向自身，不派工人"
        ...
        targets = alias_map.get(token) or []
        if len(targets) != 1:
            return [], "depends_on 指向计划外或无法解析，不派工人"
```

成环用 DFS 染色检测（`_cyclic_ids :316-338`），环上 id 标 `"depends_on 成环，不派工人"`（`nodes.py:422-424`）。
三者统一转**错误终态**（`:425-429`）。

> **为什么非法依赖要"不派工人"而不是"当作无依赖"？**
> 因为**如果非法依赖被当成无依赖处理，它就悄悄变成并发了**——那是最坏的结果：
> 你以为串行、实际并行，而且**没有任何报错**。所以宁可让它占一条错误终态，也不让它悄悄变成并发。
>
> 还有一条纪律可以说：**提示词里写的"按执行顺序排列"不是依赖，不能被当成依赖。**
> 它不可测，且在并发化之后会直接崩——**能被调度的依赖必须是结构化字段，不是自然语言的暗示。**

#### 2.4.4 「可恢复点」怎么算出来

`nodes.py:479-496`（`_locked_prefix`）：前缀 = 已进入**成功终态**的计划项，再减去已获批准可重跑的 `hitl_unlocked_ids`。

```python
        # Q8 可恢复点：前缀长度 = 下一个**真正要执行**的步骤下标。
        # 恢复 = 沿用前缀结果 + 从这里继续，不重跑前缀。
        "plan_prefix_ids": [str(row["subtask_id"]) for row in locked_rows],
        "recoverable_point": len(locked_rows),                    # nodes.py:458-462
```

**两条关键纪律**：
1. **失败终态不进前缀**——它没有要保护的东西（没副作用、没可取结果），重规划可以重写它；
   **把失败步骤也锁进去会让整条链卡死**（R15 的 rationale 原文）。
2. **前缀锁定的正确实现是"收回写权限"，不是"写完再验它没改"**——
   LLM 复述前缀时换个说法就算改了，比对松了又等于没锁。所以**重规划时前缀只以只读形态出现在提示里**（R15 rationale 原文）。

#### 2.4.5 双阈值上下文预算

`step_contract.py:22-30` 与 `:45-50`：

```python
MAX_FIELDS = 16
MAX_VALUE_CHARS = 200
MAX_CONTEXT_BLOCK_CHARS = 800
def max_value_chars() -> int:
    return _env_int("LG_RAG_STEP_CONTEXT_VALUE_CHARS", MAX_VALUE_CHARS, low=16, high=4000)
def max_block_chars() -> int:
    return _env_int("LG_RAG_STEP_CONTEXT_BLOCK_CHARS", MAX_CONTEXT_BLOCK_CHARS, low=64, high=16000)
```

env 非法或越界一律**回退默认**（`:33-42`）。

处置：
- **单值截断**（`:256-260`）：`text[:limit-1] + "…"`
- **整块预算**（`:316-326`）：按字段顺序**丢尾部**，`if used + len(line) + 1 > budget and included: break`
- **丢弃字段要报出来**：`dropped_fields`（`:343-348`）→ 写进 `task["bound_dropped_fields"]`（`nodes.py:699-701`）

> **为什么必须有整块预算**（不只是单值截断）？
> 因为**单值截断挡不住"16 个字段 × 200 字"这种累加污染**——每个字段都合规，合起来超预算。
> 所以要有总量闸，超了按字段顺序丢尾部。原注释就是这句：**"宁少给，不超预算"**。
>
> 而"**丢弃字段要报出来**"这条注释写得很好：**"静默少给等于给了一份看起来完整的数据"**——
> 模型拿到一份缺字段的数据，会当成完整的用。**所以丢了多少、丢了哪些，必须显式说。**

### 2.5 模型侧契约：结构化输出管线

`app/ops/structured_output/` 四个文件（**没有独立的 `validate.py`**）：

| 文件 | 职责 |
|---|---|
| `extract.py` | 公共 JSON 提取（剥 fence、容忍杂讯） |
| `repair.py` | **确定性**结构修复 |
| `parse.py` | 无 LLM 解析管道 + `ensure_keys` + 自定义 validate |
| `complete.py` | 带 LLM 的生成 + 重试 |

#### 2.5.1 解析链（`parse.py`）

docstring 原文（`:1`）：**`extract →（可选）deterministic repair → Pydantic → ensure_keys → validate`**

修复路径（`:34-59`）：直接提取 → 失败则 `strip_code_fences` + `deterministic_repair` 重试 → 再退化到"抓最外层 `{...}` 后 repair"。

各步失败**全部** `ParseOutcome(ok=False, data=None)`：
`unable to extract JSON object`（`:106-112`）· Pydantic `ValidationError`（`:115-121`）·
`ensure_keys: missing path '...'` / `is null`（`:83-91`）· validate `reason`（`:134-142`）。

#### 2.5.2 `repair.py` 只做结构性修复

原文（`:1` 与 `:25-29`）：

```python
"""确定性结构 repair：只修标点/括号类结构符号，不改写字符串语义意图。"""
...
    仅替换弯引号、全角括号，并去掉 ``}`` / ``]`` 前的尾随逗号。
    不改写已是合法字符串字面量内的语义字符（如中文引号「」）。
```

实现只有一处 `str.translate(_STRUCT_TRANS)` + 尾随逗号正则（`:30-31`）；
`_STRUCT_TRANS` 注释写明**不含「」以免误伤字符串内语义**（`:7`）。

> **这条"只修结构、不修语义"的边界很重要**：
> 「修复必须是**确定性、可解释、可预测**的。**"猜它想说什么"是模型的活，不是修复器的活**——
> 一个会猜的修复器，会在你不知情的时候把语义改掉，而且改得看起来像 JSON 是对的。」

#### 2.5.3 `complete.py`：重试上限与纠偏

| 项 | 值 | 行号 |
|---|---|---|
| `DEFAULT_MAX_RETRIES` | **3** | `:23` |
| 总尝试次数 | **`max_retries + 1` = 4**（代码里写死的加法，**不交给模型**） | `:129` |
| 纠偏提示注入 | `OUTPUT CORRECTION` + assistant 原文 + user correction | `:62-71` / `:159-164` |
| reason 截断 | **400**（`[:397] + "..."`） | `:26` / `:55-59` |
| `no_retry` 口子 | **不注入 reason，直接失败** | `:113` / `:152-154` |

纠偏的硬要求：**完整重生成，禁止只补失败字段**（`:62-71`）。

> **为什么要"完整重生成"而不是"补那几个字段"？**
> 因为**局部打补丁会让整体结构越来越不一致**——补丁是照着"这一版的结构"打的，
> 而重生成是照着"契约"生成的。**结构越改越乱的代价，比多一次调用高。**

#### 2.5.4 失败绝不返回"半成功"数据

`parse.py:22` docstring 原文：

```python
    """结构化解析结果。失败时 ``data`` 恒为 ``None``（Host 权威：无半成功业务数据）。"""
```

`complete.py:38-44`：

```python
class StructuredFailure(Generic[T]):
    """预算耗尽或不可重试失败。Host 权威：不携带成功业务 data。"""
```

> **这条纪律的表述方式可以直接用**：
> 「**半成功数据是 Agent 系统里最难查的一类 bug**——它看起来有值、下游照常消费，
> 但缺的那部分**没人知道**。所以我的原则是 `ok=False` 就一定 `data=None`，
> **宁可整条失败，也不给一份看起来能用的残缺数据**。」

### 2.6 常见追问 + 答法

| 追问 | 答法 |
|---|---|
| **"契约不就是 JSON Schema 校验吗？"** | 不是。JSON Schema 只能校验**形态**；我的结果契约校验的是**业务完整性**——**缺必填、条数不足、空且声明为可疑**。形态对但业务不完整，是生产上最常见的失败 |
| **"那为什么不做完整的 JSON Schema？"** | 因为**校验能力越强，误拦风险越大**。我刻意只支持一个子集（type / properties / required / additionalProperties）。**契约的价值在于"拦得住真错"，不在于"表达力强"**——表达力强了，写契约的人会写出模型永远满足不了的条件，然后系统随机不可用 |
| **"未声明契约的能力为什么不拦？"** | **因为契约是显式声明出来的，系统不替你猜。** 没声明就擅自拦截，等于**把"能用"变成"随机不可用"**——而且你事后查不出原因，因为拦截逻辑是猜的 |
| **"参数校验失败会不会误伤？"** | 不会走重试：`args_schema_invalid` 在 `NO_RETRY_CODES` 里（**400 类错误不该重试**）。而且它是**出门前**校验的，所以**下游零请求** |
| **"上一步的输出怎么真的喂给下一步？"** | 这里有个很容易做假的地方：**只做"声明 + 校验"不做绑定**——声明了 `consumes` 却没人喂数据，**闸门天然全绿，是空门**。所以我的要求是：契约命中后**必须真的把值注入**后继（绑定在 `bind_args` / `render_context_block`），**覆盖 planner 写死的占位值** |
| **"如果补一步校验，会不会变成整条链都不敢动？"** | 这是反向风险，我用两条挡住：① **只有声明了契约的才校验**；② **失败终态不进前缀**——失败步骤可以被重规划重写，**把失败步骤也锁进去会让整条链卡死** |
| **"模型输出不是 JSON 怎么办？"** | 四级：**提取**（剥 fence）→ **确定性修复**（只修标点括号，不改语义）→ **Pydantic** → **ensure_keys**。全失败才走**有限重试**（3 次重试、总共 4 次），且纠偏要求**完整重生成** |
| **"重试几次？为什么是这个数？"** | `max_retries=3`，**总尝试 4 次**，是**代码里写死的加法，不交给模型**。为什么不再多：**超过三四次之后，失败原因通常是结构性的（契约写错了 / 模型选错了），再试只是重复付费** |

### 2.7 缺口（主动说）

| 缺口 | 怎么说 |
|---|---|
| 结果契约**没有通用字段类型校验**（只对 min_items 校验"必须是 list"） | 「这是**有意的收窄**。但我要说清楚它的代价：**如果下游把数字返回成字符串，我的契约不会发现**——这类错得靠 Pydantic 或下游自己保证」 |
| `hitl_snapshot_fields` 声明了但**全仓无消费点** | 见 §3.11，这是我要主动认的一条 |
| 步骤契约只覆盖 `rag`/`extract`/`tool` 三类子任务的字段流 | 「`rag` 和 `extract` 产出自由文本，**它们不判缺字段**（`output_fields :175-184`）——所以契约的强度是**按类型不同**的，不是我说的"全链路都强契约"」 |

### 2.8 口述稿（90 秒）

> 「契约这块我的核心主张是：**契约不是让模型更准，是让模型的错在边界上被挡住。**
>
> 我有四套契约，各管一段边界：
> **参数契约**管出门前的**形态**；**结果契约**管拿到结果后的**业务完整性**；
> **步骤契约**管上一步产出能不能满足下一步；**模型侧的结构化输出**管模型输出是不是合法结构。
>
> 三件我很想说的设计取舍：
>
> **第一，只做子集，不做完整 JSON Schema。** 因为**校验能力越强，误拦风险越大**。
> 契约的价值在"拦得住真错"，不在"表达力强"——表达力强了，写契约的人会写出
> 模型永远满足不了的条件，然后**系统变成随机不可用**。
>
> **第二，未声明契约的能力一律不拦。** 因为**契约是显式声明出来的，系统不替你猜**。
> 没声明就擅自拦截，等于把"能用"变成"随机不可用"，而且**你事后查不出原因，因为拦截逻辑是猜的**。
>
> **第三，结果契约有一处细节我特别在意**：我把"空"分成三种——
> **没这个字段**（`MISSING`）、**字段在但是 null**（`None`）、**字段在类型对但是空的**（`len == 0`）。
> 前两种由 `required` 管，第三种由一个**开关**管。
> 为什么？因为**空列表可能是正常的（今天没有待办），也可能是可疑的（应该有三条却返回零条）**，
> 从数据上分不出来，**只能由声明它的人来定**。
>
> 最后一条纪律：**未声明契约的能力，我宁可不拦；但声明了契约的能力，结果不符必须判失败**——
> 因为"错了还报成功"是**唯一一处会让整条链路静默跑偏**的口子。」

---
## 3. 人闸与幂等层 —— 让写操作可逆、可对账

### 3.1 它解决什么问题

写操作有三个问题，**彼此独立，必须分开解**：

| 问题 | 本质 | 解法 | 本仓 |
|---|---|---|---|
| **该不该做？** | 授权问题 | 人闸（谁来批） | HITL |
| **重复了怎么办？** | **去重问题** | 幂等键 + 唯一约束 | `idempotency.py` |
| **做错了怎么看？** | **对账问题** | 回执 | `receipts.py` |

> **这三者的关系是本节的骨架**，也是面试最容易考的地方：
> 「很多人把这三个混成一个"写入安全"。但它们**不是一回事**：
> **授权是"要不要做"，去重是"做过没有"，对账是"做完是什么样"。**
> 三个问题的答案可能完全不同——**比如授权通过了，但去重命中，所以其实没做**；
> **或者去重通过、真的做了，但失败了，所以对账必须有记录。**」

### 3.2 人闸：两层设计

#### 3.2.1 第一层 · 清单层硬要求（**不声明就加载失败**）

`app/ops/capability/manifest.py:705-719`：

```python
# V1：写操作必须有幂等键（否则重复提交产生多张单据）
if is_write and not str(http_block.get("idempotency_key") or "").strip():
    raise ManifestError(f"{loc} V1: side_effect={spec.side_effect} 必须有 idempotency_key")
# V2：写操作必须有人工确认（第一期不允许存在「无确认的写能力」）
if is_write and not spec.hitl_required:
    raise ManifestError(f"{loc} V2: side_effect={spec.side_effect} 必须 hitl.required: true")
# V3：高危必须有人工确认（高危无确认 = 闸形同虚设）
if spec.risk_level == "high" and not spec.hitl_required:
    raise ManifestError(f"{loc} V3: risk_level=high 必须 hitl.required: true")
```

相关还有：
- **V8**（`:749-753`）：**只读能力不得声明幂等键**——反方向也要守（不然幂等表会被读请求撑爆）。
- **V12**（`:763-770`）：**写能力禁止降级**——"降级成建了一半"会让用户以为提交了。

**关键**：不声明的后果是**加载期整文件失败**（`ManifestError` 冒泡到 `load_capability_manifests`，该文件被跳过并记 error，其余文件不受影响 —— `manifest.py:174-200`）。
而且校验发生在 `register` **之前**，所以**不留半套注册**（`_parse_and_validate` 文档 `:423`）。

> **本节的第一个亮点**：这个"不声明就加载失败"的设计，把约束**从运行时提到加载时**。
> 「很多人把人工确认做成"运行时提示一下"——**那是无效的**，因为运行时提示是**可以被跳过**的：
> 代码路径没走到、异常被吞了、配置项没打开……都会让提示静默消失。
> 我把它做成**加载期硬校验**：**写操作没声明人工确认，清单文件直接加载失败**。
> 而且失败是**按文件隔离**的——一个文件挂了不影响其他文件，但**挂掉的那个文件里的能力一个都不会被注册**。
> 这条我要强调：**"半套注册"比"完全没注册"更危险**，因为你会以为它在。」
>
> 还有一条细节能加分：**校验发生在 register 之前**，所以不会出现"注册了一半、发现不对"的中间态。

#### 3.2.2 第二层 · 编排层唯一的人闸原因

`app/ops/lg_rag/multi/step_contract.py:55-67`：

```python
BLOCKED_PREFIX_TOUCH = "prefix_touch_required"
BLOCKED_REASONS = (BLOCKED_PREDECESSOR_FAILED, BLOCKED_CONTRACT_MISSING, BLOCKED_PREFIX_TOUCH)
# 只有这个原因需要人来批：它意味着"要满足新计划，得重跑一个已执行的步骤"
HITL_REASONS = frozenset({BLOCKED_PREFIX_TOUCH})
```

理由在 `app/ops/hitl/__init__.py:3-5`：**改已执行步骤的 `args` = 换一个幂等键 = 一次新的写**。

> **本节的第二个亮点**（也是我认为**最强的一句**）：
> 「我的编排层只承认**一种**叫人原因：**要改动一个已经执行过的、不可撤销的步骤**。
> 因为改它的参数就是换幂等键，就是**一次新的写**——**会产生新的副作用**。
> 而前驱失败、缺字段这些拦截**都不需要人**——它们只是"这一步不执行"，**没有产生任何新副作用**。
>
> **审批是有成本的。到处挂 HITL 等于没有 HITL** —— 因为审批人会被训练成无脑点同意。
> 我只在最贵、最不可逆的那个点上叫人。」

### 3.3 申请的数据模型与快照

表：`ops_hitl_requests`，model `OpsHitlRequest`（`app/db/models.py:408-446`）

| 字段 | 含义 |
|---|---|
| `id` | 主键（`hitl_` + hex） |
| `run_id` | 属于哪一次运行 |
| `thread_id` | 图线程（恢复时用） |
| `checkpoint_id` | 仅 PG saver 下才有 |
| `tenant_id` | 租户 |
| `subtask_id` | **被拦下的那一步** |
| `blocked_by` | 拦截原因（当前只有 `prefix_touch_required`） |
| `unlock_subtask_id` | **批准后允许重跑的、已执行的那一步** |
| `reason` / `detail` | 给人看的说明 |
| `payload` | JSONB，实际存 `{"observation": {round, planned, done}}` |
| `status` | `pending` / `approved` / `rejected` / `expired` |
| `decision_by` / `decision_note` / `decided_at` | **审批记录（同一张表）** |
| `created_at` / `updated_at` | 时间戳 |

> **两个字段名值得单独说**：`subtask_id`（被拦下的）和 `unlock_subtask_id`（被授权重跑的）**是两个不同的字段**。
> 这个区分说明"拦住的那个"和"要放开的那个"不是同一步——**拦住的是后缀步骤，放开的是它需要动到的前缀步骤**。
> 这个细节能证明你真的理解了自己的人闸在拦什么。

**申请行实际冻结的字段**（`nodes.py:1293-1307`）：`id, run_id, thread_id, checkpoint_id, tenant_id, subtask_id, blocked_by, unlock_subtask_id, reason, detail, payload, status, created_at`。

> ⚠️ **这里有一条要主动认的边界**（见 §3.11）：
> 「我**没有**冻结工具 id、参数快照、发起人、过期时间这四样。
> 而且清单里有个 `hitl.snapshot_fields` 声明字段，**目前全仓没有被消费**——**声明了但没用**。
> 这是我要主动说的：**它不是"做了但做得不深"，是"字段预留了但这一期没接上"。**
> 为什么不算致命：因为**我靠的机制不是"比对参数快照"，而是幂等键本身**——
> 改了参数就是换了幂等键，**就是一次新的写**，所以"参数变过"这件事天然被幂等键捕获了（见 §3.6）。」

### 3.4 决定 → 恢复：「只授权，不代劳」

#### 3.4.1 二次校验（防状态机被绕过）

| 校验 | 实现 | 行号 |
|---|---|---|
| **是否已被决定**（防重复批） | `UPDATE ... WHERE id=:id AND status='pending' RETURNING id` | `store.py:159-163` |
| 内存版同语义 | 注释明确**"必须与 DbHitlStore 的 `WHERE status='pending'` 一致"** | `store.py:89-94` |
| 恢复入口要求已决 | status 非 `approved`/`rejected` → **409** | `router.py:260-265` |
| 恢复前要求 thread 真有挂起 | `resume.py:228-248` | — |

> **第 2 行是个很好的细节**：内存实现与 DB 实现**必须语义一致**，而且代码里**写了注释明示这一点**。
> 这类"双实现"最容易漂移——**你在内存下测过了，以为 DB 下也对**。

#### 3.4.2 恢复流程

`resume_hitl_run`（`:285-352`）：
- 无 `thread_id` → 409
- 无 `approved`/`rejected` → `no_decision`
- 显式注入 checkpointer，否则要求 `LG_RAG_HTTP_CHECKPOINTER=postgres`；**未开则 fail-closed 抛 `checkpointer_not_configured`**（`:329-336`）

`_resume_with`（`:211-282`）：

```python
snapshot = await graph.aget_state(config)
if snapshot is None or not tasks: raise ResumeError("not_interrupted", ...)
...
async for chunk in graph.astream(Command(resume={"approved":..., "rejected":..., "decided_by":...}),
                                 config, stream_mode="updates"):
```

**「批准」的唯一效果**在 `nodes.py:1351-1408`（`_apply_hitl_decision`）：把解锁步**从不可变前缀摘出**（`hitl_unlocked_ids`）、剪掉它的旧结果、`react_round` 归零 ⇒ 从可恢复点重跑。

> **这里有一个我认为最值得讲的设计判断**：
> 「**批准不等于代劳。** 人批复的结果，不是"系统替他把这一步做了"，而是
> **"系统收回这一小段的写权限锁定，让它按新计划重新执行一次"**。
> 也就是：**人闸批准的产物是"权限"，不是"结果"。**
>
> 为什么重要？因为如果批完由人来填结果，那**人和模型就都成了不可追溯的输入源**；
> 而现在是"批完仍由系统执行、仍走幂等、仍落回执"——**人的决定改变了可行域，但没有绕开任何闸。**」

#### 3.4.3 `stranded_checkpoint`：一类救不回来的挂起

`resume.py:236-248`：

```python
if not [t for t in tasks if getattr(t, "interrupts", None)]:
    raise ResumeError("stranded_checkpoint",
        f"thread {thread_id[:32]} 有未完成任务但没有 interrupt 元数据 —— "
        "多半是升级前旧版本格式的 checkpoint，无法恢复（只能作废重开）")
```

- 触发条件：有 pending task **但 `task.interrupts` 为空**（langgraph 0.2→1.2 升级残留）
- HTTP 映射：**409**（`router.py:288-296`）
- 与"这轮已跑完"（`not_interrupted`）**必须分开**——两者都 409，但**给人的下一步动作完全不同**

> **这条的价值在于"显式判死"**：
> 「升级之后有一类挂起是**真的救不回来的**：旧格式的 checkpoint 能读回 values 和 pending task，
> 但 `task.interrupts` 是空的——新栈认不出"这里挂着一个 interrupt"。
> 这时候硬喂 `Command(resume=...)`，会在框架内部炸一个 `TypeError`。
>
> **我的处置不是"try 一下看运气"，而是显式判死**：单独判成 `stranded_checkpoint`，
> 返回 409 并告诉用户"**多半是升级前旧格式，无法恢复，只能作废重开**"。
> 而且它和"这轮已经跑完了"**必须分开**——**两者都返 409，但给人的下一步动作完全不同**：
> 一个是"去作废重开"，一个是"这轮本来就没有要批的东西"。**同一个状态码承载两种不同动作，是设计事故。**」

#### 3.4.4 恢复后事件编号要接着排

`router.py:_open_event_sink`（`:182-218`）：先 `start_seq = await last_seq(run_id)`，再构造 `ResumeEventSink(start_seq=...)`；
`last_seq` 取 `MAX(seq)`（`event_store.py:72-84`）；每发一帧 `self.seq += 1`（`resume.py:87-90`）。

> **为什么必须接着排**：因为事件序列是**单调递增的**，前端按 `cursor` 续传。
> 如果恢复后从 1 重新开始，**续跑那段会和前面的序号撞车，回放直接废掉**。
> 顺带一个工程细节：**即便取 seq 失败，也是"从 0 续写并记异常"，不是静默假设从 1 开始**（`:211-215`）。

### 3.5 回调鉴权：HMAC + 时间窗 + nonce

`app/ops/hitl/signature.py`：

| 项 | 实现 | 行号 |
|---|---|---|
| 算法 | **HMAC-SHA256** | — |
| 签的内容 | `f"{timestamp}.{nonce}." + **原始 body**` | `:56-60` |
| 时间窗 | **±300 秒**（`_TOLERANCE_SECONDS = 300`） | `:35` / `:100-102` |
| 防重放 | nonce 窗内只认一次 + **上界 1024** | `:36` / `:63-69` / `:104-106` |
| **空密钥行为** | `secret_configured()` 为假 → **拒绝所有请求** | `:77-80` |
| 头名 | `X-Ops-Signature` / `-Timestamp` / `-Nonce` | `:31-33` |

Java 侧（`ops-desk-mock-oa`）：

| 项 | 位置 |
|---|---|
| 签名 | `support/HmacSigner.java:33-47`（同公式，输出 `sha256=<hex>`，**空密钥抛异常** `:34-36`） |
| 发回调 | `support/HttpAgentLink.java:84-100`（`sendDecision`）、`:102-132`（`send`：三个签名头；`thread_id` 明文进 body） |
| 决定记录 | `api/ApprovalController.java:130-173`（**先本地 `recordDecision` 再回调**；回调失败也返回"本地已批" + `callback_ok=false`） |
| 两者分开记 | `support/ApprovalInbox.java:59-79` |

> **三条值得讲的**：
> 1. **对"原始 body"签名**，不是对解析后的对象签——**如果你先反序列化再签名，字段顺序一变签名就不稳**。
> 2. **空密钥直接抛异常，不允许"没配密钥就放行"**。原因注释里写得很直白：
>    *"不设密钥时不许退化成不签名，那样回调就是谁都能打的匿名接口。"*
> 3. **nonce 集合有上界并做淘汰（1024）**——否则它会变成一个无限增长的字典，**那就是内存泄漏**。

### 3.6 幂等：语义边界（本节最需要说准的一处）

#### 3.6.1 存储层**不回放**原始结果

`app/ops/capability/idempotency.py:3-5` 注释原文：

> **目标不是"强幂等"（回放原始结果），而是"同一个幂等键不会在本层发出两次请求"。**
> 为什么不回放：回放要求把下游原始结果落库（**扩大数据边界，可能含薪酬/合同**），
> 而且它**只在你本来就不需要它的时候有用**——第一次结果未知时，恰恰没有结果可回放。

#### 3.6.2 但命中时**必须重放"业务关键字段"**（R9）

`http_generic.py`：`:516-543`（`_claim_from`，duplicate 时回"与首次形状一致"的载荷）+ `:468-482`（`_replay_fields`，把 `$.data.ticketId` 还原成 `ticketId`）+ `:484-514`（取回上次 `captured`）

R9 原文（`capability_v1.yaml:85-94`）：

```yaml
  - id: R9
    statement: >-
      幂等命中必须重放上次的业务结果（回执里 captured 的字段），
      不能只回 duplicated=True + 一个回执 id
    rationale: >-
      幂等是"重复调用返回与首次相同的结果"，不只是"没有重复执行"。
      只回 duplicated=True 和一个回执 id，调用方第二次调用拿不到 ticketId/url，
      业务上等于这次调用白干了——防重保住了，可用性丢了。
    source: 2026-09-20 联调 C1c（db 模式下第二次调用 ticketId=None）
```

#### 3.6.3 把这两件事合起来说 —— **这是本节最值钱的一段**

> 「幂等我刻意**只做了半个"强幂等"**，而且这个取舍点是我踩出来的。
>
> **存储层只保证"同键不发第二次请求"，它不回放原始响应。**
> 为什么不回放：回放要求把**下游原始结果整体落库**，那会**扩大数据边界**（可能含薪酬、合同）；
> 而且有个更根本的理由——**回放只在"你本来就不需要它"的时候有用**：
> 第一次调用的结果未知时（超时、连接断），**恰恰没有结果可回放**。
>
> **但我又要求命中时必须重放"业务关键字段"**——就是回执里 `capture` 声明的那几个，
> 比如 `$.data.ticketId`。因为只回 `duplicated=True` 加一个回执 id 的话，
> 调用方第二次拿不到 ticketId，**业务上这次调用等于白干了**：
> **防重保住了，可用性丢了。**
>
> 所以准确的说法是：**不回放原始响应，只重放声明过的关键字段。**
> 这个边界我觉得比"我们做了强幂等"更有价值——因为**它说清了代价放在了哪里**。」

### 3.7 三态状态机与 DB 时钟租约

#### 3.7.1 状态机的四个分支

内存版 `claim`（`idempotency.py:186-227`）：

| 情况 | 结果 |
|---|---|
| 无记录 | 建 `in_flight`，`acquired=True` |
| `status == done` | `acquired=False, duplicate=True, receipt_id=...` |
| `in_flight` 且租约**未**过期 | `acquired=False, in_flight=True`（**拒**，报 `duplicate_id`） |
| 租约**已**过期 | 接管，`acquired=True, took_over_stale_lease=True` |

DB 版 `aclaim`（`:356-406`）：`INSERT ... ON CONFLICT DO NOTHING` 抢到即 acquired；
否则试 `_TAKEOVER_IF_STALE`（`:296-308`）；否则 `_BUMP_AND_READ` 读回 `done`/`in_flight`。

#### 3.7.2 租约判定交给 **DB 时钟**

`idempotency.py:50-51` 与 `:283` 注释原文：

> DB 版把**租约判定交给数据库时钟**（`now()`）而不是应用进程时钟——
> **多实例部署下各机器时钟有偏差，用本地时钟判租约必然出错。**

SQL：`now() + make_interval(secs => :ttl)`（`:291`、`:299`）、`lease_expires_at < now()`（`:306`）。
**内存版才用 `time.monotonic()`**（`:189`、`:212`）。

> **这是一个很典型的"单机对、多机错"的设计点**，值得专门讲：
> 「租约过期这件事**必须用统一时钟**。如果用各应用进程的本地时钟，
> **多实例下每台机器都认为"对方的租约过期了"，然后一起接管同一个键**——
> 防重就在最需要它的时候失效了。所以我把它交给**数据库时钟**：
> 写入时用 `now() + interval`，判定时用 `lease_expires_at < now()`，
> **两边都是同一个时钟源**。
> 顺带一个细节：内存实现只能用 `monotonic()`——**而我把这个差异写在注释里了**，
> 因为它是"内存模式与 DB 模式语义不同"的一个真实来源。」

### 3.8 失败时的释放纪律（fail-closed）

`http_generic.py:586-605` 注释原文：

```python
"""失败后的防重状态处理——**只在下游确无副作用时释放**。
超时 / 连接错误 / 未知业务码一律保持 in_flight，交给租约过期，
由人工或后续查询确认。宁可拒，也不冒重复执行的风险（fail-closed）。"""
if not prepared.idempotency_key or exc.code not in RELEASE_SAFE_ERROR_CODES:
    return
```

`RELEASE_SAFE_ERROR_CODES = {ARGS_SCHEMA_INVALID, POLICY_BLOCKED, PERMISSION_DENIED}`（`:49-53`）
—— 即**只有"我们自己在出门前就拒了"的错误才释放键**（下游零请求，确知无副作用）。
成功才 `complete`（`:628-641`，注释：**"不要把失败当成完成"**）。

> **这段是"超时 ≠ 失败"最完整的表达**：
> 「失败释放的判据不是"失败"，而是**"确知下游没有副作用"**。
> 我的白名单只有三个错误码——**参数不合法、被策略拦、权限不足**——
> 它们的共同点是**都发生在请求发出去之前**，所以我可以确定下游什么都没发生。
> 而超时、连接断、未知业务码，**一律保持 `in_flight`**，等租约自然过期。
> 也就是：**我宁可让这个键暂时不可用（拒掉重复调用），也不冒"其实已经建单了"的风险。**
> **fail-closed 的代价是可用性，收益是确定性——在写操作上，这个交换永远值得。**」

### 3.9 默认实现：**空实现 + 显式告警**

`idempotency.py:479`（默认 `NullIdempotencyStore`）、`:482-489`（`get`/`set`/`reset`）、`:126-142`：

```python
logger.warning("幂等防重未启用（NullIdempotencyStore）：capability=%s key=%s "
               "—— 重复提交可能产生第二张单据", capability_id, key)
return IdempotencyClaim(key=key, acquired=True)
```

回执侧对应 `NullReceiptSink`（`receipts.py:65-74`）。

> **这个设计的判词值得背**：
> 「**一个静默不生效的防重，比没有防重更危险**——因为你会以为它在。
> 所以我的默认实现是"**空实现 + 每次写都显式告警**"：它**放行**（不阻断业务），
> 但**每次都在日志里喊一声"防重未启用，重复提交可能产生第二张单据"**。
> **它不许默默地什么都不做。**」

### 3.10 回执：让"做错了"变得可对账

#### 3.10.1 完整字段（12 个）

`app/ops/capability/receipts.py:30-50`：

| 字段 | 含义 |
|---|---|
| `receipt_id` | **外部可见**的回执号 |
| `capability_id` | 哪个能力 |
| `side_effect` | 副作用级别 |
| `ok` | 本次是否成功 |
| `created_at` | UTC ISO |
| `user_id` / `tenant_id` | 谁、哪个租户 |
| `subtask_id` | **对回计划里的哪一步** |
| `idempotency_key` | 幂等键（可空） |
| `captured` | 按清单 `receipt.capture` 抓到的关键字段 |
| `error` | 可空 |
| **`write_confirmed`** | **是否在放行下执行**（不是"成功了吗"） |

#### 3.10.2 什么时候写

`gateway.py:439-455`：**无论 `result.ok` 都 `record_receipt`**；
**只有 `duplicated=True`（命中幂等、未真执行）不落**（`:412-417`）；仅成功时才 `complete` 幂等键（`:450-453`）。

语义（`receipts.py:7-9` 原文）：

> 一次"失败"的写操作**可能已经在下游生效了**（超时、连接中断…）。**不留回执，事后无法对账。**

#### 3.10.3 `write_confirmed` 到底记什么

`receipts.py:46-47`：

```python
    # True 表示这次调用**在审批放行下**执行（见 policy.allow_write）
```

来源 `gateway.py:427 write_confirmed=write_allowed(ctx)`；
判定 `policy.py:78-84`：`_env_bool(OPS_CAPABILITY_ALLOW_WRITE) or host.get("allow_write") is True`。

> **这个字段的语义要说准，它能体现你真的读过自己的代码**：
> 「`write_confirmed` 记的不是"成功了"，是"**这次写是在放行下执行的**"。
> 两件事不一样：**一次写可能被放行了但失败了**（下游 500），
> **也可能没被放行所以根本没发**（`write_confirmed=False`）。
> 事后审计时，"谁批准了、在哪个放行下执行的"和"执行成不成功"是**两个独立的问题**，
> 所以是两个独立字段。」

#### 3.10.4 怎么查

`GET {prefix}/admin/capability/receipts`（`admin/capability.py:45` prefix、`:228-252`），
筛选 `tenant_id` / `capability_id` / `limit`。
**库不可达** → `HTTPException(503, ...)`（`:243-247`，**明确不吞**）。

> **"库不可达返 503、不返空列表"是一个小但值得讲的判断**：
> 「回执查询**库不可达时返 503，不返空列表**。因为**"没有回执"和"查不到回执"是两件事**——
> 返空列表会让调用方以为"这次没发生过副作用"，而实际是**根本查不了**。
> 在审计链路上，**这个区别就是"能免责"和"不能免责"的区别**。」

### 3.11 缺口（**这一节必须主动说，否则会被问穿**）

| 缺口 | 证据 | 怎么说 |
|---|---|---|
| **`hitl.snapshot_fields` 声明了但没有消费点** | 清单声明在 `manifest.py:550-552` / `:610-612` → `types.py:98`；**全仓无消费点** | 「这是个**声明了没接上**的字段。我说清楚：**不是"做了但做得不深"，是这一期没接。** 而且我靠的不是参数快照，是**幂等键**——改参数就是换键、就是新的写，所以"参数变过"天然被捕获了」 |
| **没有审批过期校验** | `STATUS_EXPIRED` 仅在 `store.py:22-23` 定义，**无使用** | 「**没有 TTL，申请会一直 pending。** 这是我知道的缺口——现在的量级靠人工巡检够用，但**上生产必须补**，因为"悬挂但不告警"是会累积的」 |
| **Java 侧只有内存镜像，无磁盘落盘兜底** | `ApprovalInbox`（内存）+ `RequestLog.java:36-88`（内存环形日志） | 「我之前在材料里写过"先落本地再回调"，**这里要修正**：**落的是进程内存，不是磁盘**。进程重启就没了。所以准确说法是"**先记决定、再回调**"，**不是"落盘兜底"**」 |
| **跨语言签名向量只在 Java 侧钉死** | `HmacSignerTest.java:19-30`（注释称向量**由 Python 侧算出**）；**Python 侧全仓搜不到该向量的断言** | 「签名向量是**单向钉死**的：Java 侧有断言，注释说向量来自 Python，但**Python 侧没有对应的断言测试**。所以严格说，跨语言一致性是**"一边钉死"不是"两边互钉"**——这是我该补的」 |
| 幂等**不保证**的事 | `idempotency.py` 注释 | 「它不保证：跨租户去重（键是租户作用域的）、下游自己不守规矩时的重复、以及**进程崩溃后未 complete 的写**——那些靠租约过期后接管」 |

> **这一段的价值远大于把优点讲得再漂亮**。上面五条里有一条（Java 侧无磁盘落盘）
> **是对我自己旧稿的修正**——面试时主动说"我之前说错了，准确说法是……"，
> **展示的是"我会回查自己的结论"，而不是"我记性不好"**。

### 3.12 常见追问 + 答法

| 追问 | 答法 |
|---|---|
| **"人工确认为什么放在加载期校验？"** | 因为**运行时提示可以被静默跳过**——代码路径没走到、异常被吞、开关没开，提示就消失了。做成加载期硬校验，**写能力没声明人工确认就整文件加载失败**。而且**校验在 register 之前**，不会留半套注册 |
| **"审批到处挂不就行了吗？最安全。"** | 反了。**审批是有成本的，到处挂等于没有** —— 审批人会被训练成无脑点同意。我只在**一条**原因上叫人：要改动已执行步骤（= 换幂等键 = 新的写）。前驱失败、缺字段都**不叫人**，因为它们**没产生任何新副作用** |
| **"批准之后是不是人把结果填进去？"** | 不是。**批准不等于代劳**——人批复的产物是**权限**，不是**结果**。系统收回那一小段的写权限锁定、让新计划重新执行一次，**仍走幂等、仍落回执**。人的决定**改变了可行域，但没绕开任何闸** |
| **"幂等和锁有什么区别？"** | 幂等解**重复**，锁解**竞争**。我只有幂等。**如果业务上真会出现"两个人同时改同一张单"，我得先上乐观锁（版本号+CAS）**——冲突率本身就是观测信号；只有冲突率高到不可接受才上分布式锁 |
| **"超时了到底算不算失败？"** | **超时 ≠ 失败。** 所以释放判据不是"失败"，而是**"确知下游无副作用"**——白名单只有三个错误码，共同点是**都发生在请求发出之前**。其余一律保持 `in_flight` 等租约过期。**宁可拒，也不冒重复执行的风险** |
| **"重复回调怎么防？"** | 三层：① **nonce 窗内只认一次**（有上界 1024，防内存泄漏）；② **±300s 时间窗**；③ **状态机层 `WHERE status='pending'`**——已决策的申请再批返回 409。**而且 409 要和"申请丢了"区分开** |
| **"签名凭什么可信？"** | 三个条件缺一不可：**对原始 body 签名**（不是对反序列化后的对象）、**时间窗**、**nonce 防重放**。而且**空密钥直接抛异常**——不允许"没配密钥就退化成不签名"，**那样回调就是谁都能打的匿名接口** |
| **"回执为什么要记录失败的调用？"** | 因为**一次"失败"的写操作可能已经在下游生效了**（超时、连接中断）。**不留回执，事后无法对账。** 所以我无论成败都落回执，**只有"命中幂等、未真执行"那种不落** |
| **"审计发现问题时你查什么？"** | 查**回执**（发生了什么副作用）+ **事件回放**（这一轮的过程）+ **Policy 判定**（有没有被拦、拦的原因）。而且顺序是：**用户说"结果不对"时，第一步不是看回答，是先看那次调用的回执和 Policy 判定** |

### 3.13 口述稿（120 秒）

> 「人闸和幂等这块，我的起点是一个判断：**写操作有三个独立的问题，必须分开解。**
> **授权是"要不要做"，去重是"做过没有"，对账是"做完是什么样"。**
> 很多人把它们混成一个"写入安全"，但它们的答案可能完全不同——
> 比如授权通过了、但去重命中，所以其实没做；或者真的做了但失败了，所以对账必须有记录。
>
> **第一，授权。** 我用两层：
> **清单层是硬要求**——写操作没声明幂等键、没声明人工确认，**清单文件直接加载失败**。
> 为什么放加载期？因为运行时提示**可以被静默跳过**。而且校验在注册之前，**不留半套注册**。
> **编排层只承认一种叫人原因**：要改动一个**已经执行过的**步骤。
> 因为改它的参数就是换幂等键，就是**一次新的写**。
> 而前驱失败、缺字段这些拦截**都不叫人**，因为**它们没产生任何新副作用**。
> **审批是有成本的，到处挂 HITL 等于没有 HITL。**
>
> 还有一条我想强调：**批准不等于代劳。** 人批复的产物是**权限**，不是**结果**——
> 系统收回那一小段的写权限锁定，让它按新计划**重新执行一次，仍走幂等、仍落回执**。
> **人的决定改变了可行域，但没有绕开任何闸。**
>
> **第二，去重。** 这里我说得最准的一条是：**我只做了半个"强幂等"。**
> 存储层只保证"同键不发第二次请求"，**它不回放原始响应**——
> 因为回放要把下游原始结果落库，**扩大数据边界**；而且它**只在你本来就不需要它的时候有用**：
> 第一次调用的结果未知时，恰恰没有结果可回放。
> 但我又要求命中时**必须重放声明过的业务关键字段**（比如 `ticketId`）——
> 否则调用方第二次拿不到单号，**防重保住了，可用性丢了**。
> 所以准确说法是：**不回放原始响应，只重放声明过的关键字段。**
>
> 另外两个细节：**租约判定交给数据库时钟**，不用本机时钟——
> 否则多实例下每台机器都认为对方过期，**一起接管同一个键，防重在最需要它的时候失效**。
> 还有**失败只在确知下游无副作用时才释放键**，白名单只有三个错误码，
> 共同点是**都发生在请求发出之前**；超时一律保持 `in_flight`。**宁可拒，也不冒重复执行的风险。**
>
> **第三，对账。** 回执**无论成败都留**——因为**一次"失败"的写可能已经在下游生效了**，
> 不留回执，事后无法对账。回执里有一个字段我特别想说：`write_confirmed` 记的不是"成功了"，
> 是"**这次写是在放行下执行的**"。**因为"谁批准了"和"执行成不成功"是两个独立问题。**
>
> 最后主动说一个缺口：**我的审批没有过期校验**——申请会一直 pending。
> 现在的量级靠人工巡检够用，但**上生产必须补**，因为"悬挂但不告警"是会累积的。」

---

## 4. 一页速答

### 4.1 红线 R0–R15 一句话版

| # | 一句话 |
|---|---|
| R0 | 清单与实现双向对齐，否则清单变废纸而人以为有防护 |
| R1 | 无写放行必须拒，**且下游零请求**（"拒了但发出去了"等于没拒） |
| R2 | 模板变量未声明不得静默渲染成空串 |
| R3 | 对外错误不得含下游原文 |
| R4 | 非 ASCII 参数（中文）的写必须发得出去（幂等键 ASCII 安全化） |
| R5 | 写超时**不重发**（对端次数 = 1） |
| R6 | 出站不走环境代理 |
| R7 | 幂等命中不再发请求、不留第二条回执 |
| R8 | 防重只有异步接口时，同步 invoke 必须显式失败且零请求 |
| R9 | 幂等命中必须**重放业务关键字段**，不能只回 `duplicated=True` |
| R10 | 声明了结果契约就必须判失败；**未声明不得推测性拦截** |
| R11 | 配额 / kill switch 必须拦下；**被拦调用不计配额** |
| R12 | 环境类失败熔断；**业务类不得计入** |
| R13 | 降级必须声明；**写永不降级**；**标记必须进 output** |
| R14 | 步骤契约；未声明不得拦；**命中后必须真注入** |
| R15 | 保住不可变前缀；**失败终态不进前缀** |

### 4.2 三块的关键数字

| 项 | 值 |
|---|---|
| 红线条数 | **16 条**（R0–R15），全部 `critical` |
| 红线测试 | **57 passed**（零 socket） |
| 变异检验 | **7 处** `*_is_not_vacuous` |
| 九层验收 | 最新一次 **全 PASS**，`354 passed / 1 skipped`，联调 **26 项失败 0** |
| HITL 联调 | **9 主步骤 + 2 对照子步 = 17 项断言**（PG 16 项） |
| 金样集 | RAG **73 条**（含 **11 条 negative**）/ capability **23 条** |
| 结构化输出 | `max_retries=3` → **总尝试 4 次**；纠偏 reason 截断 **400** |
| 上下文预算 | 单值 **200** / 整块 **800**（字段上限 16）；env 可调但有上下界 |
| 幂等表 | 唯一约束 `(tenant_id, idempotency_key)`；租约用 **DB 时钟** |
| 回调签名 | **HMAC-SHA256** 对 `{ts}.{nonce}.{rawBody}`；**±300s**；nonce 上界 **1024** |
| 申请状态 | `pending` / `approved` / `rejected` / `expired`（**expired 未使用**） |
| 回执字段 | **12 个**（含 `write_confirmed` / `subtask_id` / `idempotency_key`） |

---

## 附录 A · 三块的红线与实现对照（被追问时按图索骥）

| 模块 | 对应红线 | 实现入口 |
|---|---|---|
| 准入 / 写闸 | R1 · R11 | `capability/policy.py` · `budget.py` |
| 模板与错误 | R2 · R3 | `adapters/http_generic.py` · `capability/errors.py` |
| 幂等 | R4 · R7 · R8 · R9 | `capability/idempotency.py` · `adapters/http_generic.py` |
| 重试纪律 | R5 | `adapters/http_generic.py:803` |
| 出站网络 | R6 | `adapters/http_generic.py:306-313` |
| 结果契约 | R10 | `capability/result_contract.py` · `gateway.py:496-569` |
| 熔断 / 降级 | R12 · R13 | `capability/circuit.py` · `capability/fallback.py` |
| 步骤契约 | R14 | `lg_rag/multi/step_contract.py` · `multi/nodes.py:620-636` |
| 前缀 / 重规划 | R15 | `multi/nodes.py:479-496` · `:1351-1408` |
| 人闸 | V1/V2/V3（清单）· `prefix_touch_required`（编排） | `capability/manifest.py:705-719` · `hitl/` |

## 附录 B · 「没落地」清单（本篇范围内）

| 项 | 状态 |
|---|---|
| `hitl.snapshot_fields` 的消费 | ❌ **声明了未使用** |
| 审批过期（TTL） | ❌ `STATUS_EXPIRED` 定义了未使用 |
| 参数快照比对 | ❌ 没有（设计上靠幂等键捕获"参数变了"） |
| 会签 / 多审批人 / 代理人 | ❌ 只有"一条申请一个决定" |
| Java 侧磁盘落盘兜底 | ❌ 只有进程内存镜像 |
| Python 侧跨语言签名向量断言 | ❌ 单向钉死（Java 侧有，Python 侧无） |
| 结果契约的通用类型校验 | ❌ 只校验 min_items 的 list 类型 |
| 分布式锁 / 乐观锁 | ❌ 只有幂等 |
| 回执 `captured` 脱敏 | ❌ 未脱敏（脱敏只作用于 args 摘要） |
| SLO / 告警 | ❌ 没有 |

## 附录 C · 讲这三块的顺序（别平铺）

> 如果面试官说「讲讲你的 Agent 工程化」，**不要按模块讲**，按**问题**讲：

**第 1 拍 · 抛出判据（15 秒）**
> 「我判断一个 Agent 能不能上生产，看三件事：**能不能证明它没退步、错了能不能拦住、做错了能不能收场。**」

**第 2 拍 · 先讲"拦住"（契约，60 秒）**
> 因为最直观。讲**"只做子集、未声明不拦"**这个反直觉的取舍。

**第 3 拍 · 再讲"收场"（人闸 + 幂等 + 回执，60 秒）**
> 用**"授权 / 去重 / 对账是三个独立问题"**开头。
> 落点放在**"审批是有成本的，到处挂等于没有"**。

**第 4 拍 · 最后讲"没退步"（评测与红线，60 秒）**
> 因为这是**差异化的收尾**。落点放在**"红线是否决项，不是总分制"** +
> **"每条都要有反向对照和变异检验，否则是假通过或空真"**。

**第 5 拍 · 主动给缺口（30 秒）**
> 从附录 B 里挑 2 条说，并给出**"我会怎么补、先补哪个"**。
> **这一拍是信任的兑现点**——前面讲得再好，这一拍不说，可信度会打折。

---