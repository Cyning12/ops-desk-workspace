# 能力注册表 · 落地设计（老 OA 接入 Agent）

> 场景：给老 OA 加 Agent，需要一套「能力注册 → 可见集裁剪 → 授权 → 调用 → 审计」的机制
> 目标：**让 80% 的能力注册变成写配置，只留 20% 写代码**
> 已有资产：Capability Host / Agent Gateway / Policy 闸 / per-request HITL 快照 / side_effect_receipts

---

## 一、一句话答案

**注册表落地的三个支点：**
1. **一条能力 = 一份声明**（YAML），不是一段代码——字段设计决定成败
2. **一个通用 HTTP 适配器**吃掉 80% 的场景，剩下 20% 才写自定义 adapter
3. **调用链上模型完全不在场**——T1 到 T9 全部由代码决定

---

## 二、分层：谁拥有什么

| 层 | 拥有什么 | 谁改 | 变更方式 |
|---|---|---|---|
| **能力清单**（声明） | 有哪些能力、怎么调、什么风险、谁能用 | 平台 + 业务方 | **Git + PR + 人闸** |
| **注册表**（运行时索引） | 内存索引，供查询与裁剪 | 平台 | 启动加载 / 配置刷新 |
| **凭证** | OA 令牌、服务账号 | 运维/安全 | 保险箱，**不进代码库、不进日志** |
| **可见性策略** | 部门/角色/密级/项目 → 能力子集 | 安全 + 平台 | 配置，**变更同样走人闸** |
| **适配器**（代码） | 缓存、重试、幂等、错误归一 | 平台 | 代码发布 |

> **关键纪律：能力清单的变更必须走版本管理和人工 review。** 因为把 `risk_level` 从 `high` 改成 `low`，等价于把一道闸拆了——**这件事不能靠改数据库生效。**

---

## 三、一条能力记录长什么样（完整示例）

以「创建 OA 工单」为例：

```yaml
- capability_id: oa.ticket.create          # 命名规范：域.对象.动作
  kind: http
  title: 创建 OA 工单
  description: >
    当员工报告设备故障、环境问题、系统异常等需要后勤或 IT 处理的问题时使用。
    会在 OA 中真实创建一张单据，返回工单号和链接。
  when_to_use: 用户描述了一个需要被处理的具体问题，且属于后勤/IT/设施范畴
  when_not_to_use: 用户只是查询已有工单进度时，用 oa.ticket.query
  args_schema:
    type: object
    required: [category, title, description]
    properties:
      category:   { type: string, enum: [it, admin, facility, other] }
      title:      { type: string, maxLength: 60 }
      description:{ type: string }
      urgency:    { type: string, enum: [low, normal, high], default: normal }
  tags: [oa, ticket, write]
  risk_level: medium                       # low | medium | high
  side_effect: write                       # none | read | write | irreversible
  enabled: true
  visibility:
    departments: [all]
    roles: [employee, manager]
    classification_max: internal           # 密级上限
  http:                                    # ---- 绑定（通用适配器读这一段）----
    method: POST
    base_url: OA_BASE                      # 引用环境变量名，不写死
    path: /api/flow/submit
    auth: oa_service_token                 # 引用凭证名
    body_map:
      flowId: 1024
      subject: "{{title}}"
      content: "{{description}}"
      priority: "{{urgency}}"
    idempotency_key: "oa.ticket.create:{{_user_id}}:{{title}}:{{_date}}"
    timeout_ms: 8000
    success_when: { path: "$.code", in: [0, 200] }
    error_map:                             # 老 OA 业务码 → 稳定错误码
      "1001": args_schema_invalid
      "2003": policy_blocked
      "5001": upstream_error
  receipt:
    capture: ["$.data.ticketId", "$.data.url"]   # 副作用以收据为真
  hitl:
    required: true                         # 需要单次人工确认
    snapshot_fields: [capability_id, args, user_id]
```

### 这段声明里，每一块解决什么

| 字段块 | 解决 | 省掉的代价 |
|---|---|---|
| `capability_id` + 命名规范 | 稳定引用、审计可追溯 | 后面改名要全链路改 |
| `description` / `when_to_use` / `when_not_to_use` | **模型能不能选中**（这就是 L2 语义层） | 模型靠猜，选错能力 |
| `args_schema` | 结构校验；**但它不装业务不变式** | 加校验要改所有调用点 |
| `risk_level` / `side_effect` | 策略闸的输入 | 加闸要重新盘每个接口 |
| `visibility` | 可见集求值 | 权限只能事后拦，不能事先裁 |
| `http.*` | **让注册变成写配置** | 每个接口写一个 adapter |
| `error_map` | 把老 OA 的不稳定错误码挡住 | 模型看到一堆乱码 |
| `receipt.capture` | 副作用可对账 | 出事说不清做了什么 |
| `hitl.required` | 高危写走单次确认 | 要么全放开，要么全人工 |

> ⚠️ **业务不变式不要写进 `args_schema`**。`args_schema` 只管「形态对不对」；「这个金额能不能批」「这个人有没有权给这个部门报」属于业务不变式，**放 Policy 或 adapter 的代码里**。这是两件事。

---

## 四、注册表的三个落地形态

| 版本 | 形态 | 适用 | 局限 |
|---|---|---|---|
| **V1** | 进程内 dict，启动时从 YAML 加载 | **第一期就用这个** | 多实例下每个进程各一份 |
| **V2** | 配置存 Git，运行时定时拉取 + 版本号比对 | 能力开始变多 | 刷新有延迟窗口 |
| **V3** | 配置中心 + 订阅推送 + 版本一致性校验 | 多团队协作 | 复杂度高 |

**建议：V1 起步，但配置从一开始就放在 Git 里。** 这样 V1→V2 只是加一个拉取器，不用重构。

**多实例分叉的正确解法不是"消灭分叉"，而是"让分叉可被发现"**：
- 每个实例上报自己加载的**能力清单版本号**
- 版本不一致 → 告警（不阻断，但要可见）
- **行为契约用跨语言一致性 fixture 守住**——注册表可以短暂分叉，但「同一个 id + 同一组参数 → 同一套错误码」不能分叉

---

## 五、通用 HTTP 适配器：让 80% 的注册变成写配置

核心思路：**adapter 不写业务，只做"读声明 → 拼请求 → 发 → 归一化"**。

```python
class GenericHttpAdapter:
    def __init__(self, spec: CapabilitySpec, vault: CredentialVault):
        self.spec = spec
        self.vault = vault

    async def ainvoke(self, args: dict, ctx: InvokeContext) -> CapabilityResult:
        http = self.spec.http
        # 1. 参数映射：args → query / body / path / header
        rendered = render_templates(http.body_map, args, ctx)
        # 2. 凭证注入（按名字取，永不落日志）
        headers = self.vault.headers_for(http.auth)
        # 3. 幂等键（写操作必须）
        key = render_idempotency(http.idempotency_key, args, ctx)
        # 4. 发起调用（带超时、连接池、重试策略）
        resp = await self._call(http, rendered, headers, key)
        # 5. 成功判定 + 错误归一化（业务码 → 稳定错误码）
        return normalize(resp, http.success_when, http.error_map)
```

**这个 adapter 一旦写完，注册一个新 OA 接口 = 写 20–40 行 YAML。**

### 声明能覆盖的比例

| 接口形态 | 能否用通用适配器 | 占比（估计） |
|---|---|---|
| 单次 REST 调用，参数直传 | ✅ 纯配置 | ~60% |
| 单次调用，但响应要提取/映射 | ✅ 配置 + 少量表达式 | ~20% |
| 需多次调用才完成一个业务动作 | ❌ 自定义 adapter（业务级编排） | ~15% |
| SOAP / 私有协议 / 只有页面 | ❌ 自定义 adapter 或 RPA | ~5% |

---

## 六、什么时候必须写代码

写自定义 adapter 的四种情况，**判据是「一个业务动作 vs 一次 API 调用」是否等价**：

1. **粒度不匹配**：「创建请假单」实际要 查字典 → 查年假 → 查审批人 → 提交 → 触发流程。**业务动作是编排级的**，必须封装成一个能力。
2. **需要计算**：响应里没有现成字段，要算（如"剩余年假"要用总额减已用）。
3. **协议不对**：SOAP / WebService / 私有二进制。
4. **只有页面**：RPA / 浏览器自动化。

> **判据记法**：**如果让模型去调这个接口，模型需要知道"业务规则"，那就该封装；如果模型只需要知道"填什么参数"，那就可以纯配置。**

---

## 七、调用链：T1–T9（**模型完全不在场**）

```
模型产出 plan: { capability_id, args }
        ↓
┌──────────────────────────────────────────────┐
│  能力网关（这一段里没有模型）                  │
│                                              │
│  T1 查表        无此 id            → unknown_id
│  T2 启用检查    enabled=False      → disabled
│  T3 策略闸      risk/side_effect   → policy_blocked
│                 （高危需 ctx 带本次放行）
│  T4 参数校验    args_schema        → args_schema_invalid
│  T5 幂等+单飞   重复提交            → duplicate_id
│  T6 凭证注入    按名字取，不落日志
│  T7 调用        HTTP / adapter
│  T8 归一化      业务码 → 稳定错误码
│  T9 落回执      side_effect_receipts
└──────────────────────────────────────────────┘
        ↓
归一化结果 + 回执 id（模型重新在场，只读结果）
```

**每一步的责任分工：**

| 步 | 谁负责 | 模型能影响吗 |
|---|---|---|
| 产 plan | 模型 | ✅（但只能从已裁剪的名单里选） |
| T1 查表 | 代码 | ❌ |
| T2 启用 | 代码 | ❌（模型改不了 `enabled`） |
| T3 策略闸 | 代码 + Host 策略 | ❌（plan 里写 `allow_high_risk` 一律忽略） |
| T4 参数校验 | 代码 | ❌（只能决定填什么值，不能决定校验规则） |
| T5 幂等 | 代码 | ❌ |
| T6 凭证 | 保险箱 | ❌（模型看不到凭证） |
| T7 调用 | adapter | ❌ |
| T8 归一化 | 代码 | ❌ |
| T9 回执 | 代码 | ❌ |

> **面试可直接用这一句**：「从 T1 到 T9，模型已经不在调用里了。它能决定的只有两件事——**在名单里点哪个、参数长什么样**。」

---

## 八、可见集怎么算（**双保险：裁剪 + 拦截**）

**求值：**
```
可见集 = 用户可及集合  ∩  Agent 授权名单  ∩  本地且非高危
   ├─ 用户可及集合：由身份推出（部门 / 角色 / 密级 / 项目）
   └─ Agent 授权名单：该 Agent 被配置允许的能力（配置表，非模型产出）
```

**双保险：**
1. **裁剪（事前）**：构造给模型的工具清单时，就已经只放可见集内的能力 → **模型压根看不到不该调的**
2. **拦截（事中）**：T3 再验一次 → **即使模型幻觉出一个 id，也拦得住**

> **只做裁剪不够**（模型可能幻觉 id），**只做拦截也不够**（把全部能力暴露给模型，本身就是信息泄露 + 选择困难）。**两个都要有。**

**明确定义「空可见集」的行为**：如果某用户没有任何可用能力，**Agent 应该明确说"你没有可用操作权限"，而不是让模型硬答**。

---

## 九、写操作的四个必需品

| 必需品 | 解决什么 | 实现要点 |
|---|---|---|
| **幂等键** | 重复提交产生多张单据 | 键 = `能力id + 用户id + 关键参数哈希 + 日期` |
| **单飞锁** | 并发重复提交 | 按幂等键加锁，第二个请求直接返回第一个的结果 |
| **快照 + 单次确认** | 高危写必须有人批 | 冻 `{capability_id, args 哈希, user_id, subtask_id}` → 管理员批快照 → **执行前再验一次，参数变则作废** |
| **回执** | 副作用以收据为真 | 落 `side_effect_receipts`，capture 关键字段 |

**写操作的标配顺序**（缺一不可）：
```
参数校验(T4) → 幂等检查(T5) → 策略闸(T3) → 快照冻结 → 人工确认 → 执行前复验 → 调用 → 落回执
```

> ⚠️ **执行前复验要验全**：不只是「风险等级没被改低」，还要验「id 仍在 allowlist」「sandbox 没被关」「参数哈希一致」。**权限收窄的每种形式都要覆盖。**（这是 TOCTOU 防护的完整形态）

---

## 十、稳定错误码（**对模型永远同一套**）

不管底层 OA 返回什么，对模型只暴露这七个：

| 错误码 | 含义 | 模型该怎么办 |
|---|---|---|
| `unknown_id` | 能力不存在 | 换一个已知能力重试 |
| `disabled` | 能力已停用 | 告知用户该功能不可用 |
| `policy_blocked` | 策略拒绝 | 告知需要走审批，**不要重试** |
| `args_schema_invalid` | 参数不合法 | 按提示修正参数重试 |
| `duplicate_id` | 重复提交 | 告知已提交，返回既有回执 |
| `upstream_error` | 下游失败 | 可重试一次，再失败则转人工 |
| `permission_denied` | 无权限 | 告知不可用，**不要重试** |

**价值**：老 OA 的 200 里嵌业务码、错误字符串不统一、有的接口超时其实已成功——这些问题**全部被挡在 T8 这一层**。模型看到的永远是这七个。

---

## 十一、目录结构（可直接照搬）

```
capabilities/
  spec.py              # CapabilitySpec 数据类 + marshal 校验
  registry.py          # 加载 / 索引 / list_capabilities(filter)
  gateway.py           # T1–T9 调用链
  policy.py            # 策略闸判定
  errors.py            # 七个稳定错误码（枚举，不可扩展）
  visibility.py        # 可见集求值
  idempotency.py       # 幂等键 + 单飞锁
  receipts.py          # 回执落库
  vault.py             # 凭证引用解析（不落日志）
  adapters/
    base.py            # CapabilityAdapter 协议
    http_generic.py    # 通用 HTTP 适配器（配置驱动，覆盖 ~80%）
    oa_flow.py         # 老 OA 流程类自定义适配器（业务级编排）
  manifests/
    oa_readonly.yaml   # 只读能力（第一期）
    oa_draft.yaml      # 草稿能力（第一期）
    oa_write.yaml      # 写能力（第二期，需 HITL）
  tests/
    contract_fixture.json   # 跨语言行为契约（语言无关）
```

**关键接口签名：**

```python
def list_capabilities(filter: CapabilityFilter) -> list[CapabilitySummary]:
    """给模型看的清单——已经是裁剪后的，只含 id/title/description/args_schema"""

async def invoke(capability_id: str, args: dict, ctx: InvokeContext) -> CapabilityResult:
    """精确 id 调用。不走检索，不做模糊匹配。"""

async def ainvoke(...): ...   # 异步版本
```

> **`list_capabilities` 返回的必须是摘要不是全量 spec**——凭证配置、error_map、visibility 规则都不该给模型看到。

---

## 十二、六个「必须一开始定死」的约定

这些东西**事后补不上**，第一期就要写进规范：

1. **`capability_id` 命名规范**：`域.对象.动作`（`oa.ticket.create`）——稳定、可读、可审计
2. **七个稳定错误码枚举**——**不允许随手加第八个**
3. **`risk_level` / `side_effect` 的判定标准**：谁能定、变更走什么闸
4. **`args_schema` 必需**，且**业务不变式不许写进去**
5. **可见集的求值维度**：部门 / 角色 / 密级 / 项目，四个维度固定下来
6. **能力清单走 Git + PR + 人闸**，禁止运行时改生效

---

## 十三、落地节奏

| 周 | 做什么 | 验收标准 |
|---|---|---|
| **W1** | `spec.py` + `registry.py` + `http_generic.py`；注册 3 个只读能力 | 能通过 YAML 注册并成功调用一个 OA 只读接口 |
| **W2** | **可见集 + 审计 + 错误码归一** | 两个不同角色的用户看到**不同的能力清单**；调用留痕可查 |
| **W3** | 草稿类能力（预填但不提交） | 模型能产出表单草稿，用户确认后才走下一步 |
| **W4** | 第一个写能力 + 单次确认 | 快照 → 审批 → 执行 → 回执全链路打通 |
| **W5+** | 幂等 / 单飞 / 批量 / 跨系统 | 重复提交不产生第二张单据 |

### 自测清单（怎么证明它真的 work，而不是"看起来能跑"）

- [ ] 模型幻觉一个不存在的 `capability_id` → 返回 `unknown_id`，不报 500
- [ ] `enabled=False` 的能力 → 返回 `disabled`，且**不出现在给模型的清单里**
- [ ] 高危能力被 plan 里的 `allow_high_risk` 试图绕过 → 仍然 `policy_blocked`
- [ ] 同一次写操作提交两次 → 第二次返回 `duplicate_id` + 同一个回执
- [ ] A 部门用户问 B 部门的能力 → **清单里根本没有**，不是调用时才拒
- [ ] 底层 OA 返回 `200 + code=1001` → 对模型是 `args_schema_invalid`
- [ ] 审批期间参数被改 → 执行时哈希不符 → 拒绝执行
- [ ] 全链路日志里**搜不到凭证明文**

---

## 十四、面试怎么讲（30 秒版）

> 「注册表这件事，我的判断是**成败在声明层，不在代码层**。我想办法让 80% 的能力注册变成写一份 YAML——能力 id、面向模型的描述、参数 schema、风险等级、还有一段 HTTP 绑定，包括参数映射和错误码转换。剩下 20% 是那些「一个业务动作要调好几个接口」的，才写自定义适配器。
>
> 然后 `capability_id` 一旦注册，后面整条链路上模型就不在场了：查表、启用检查、策略闸、参数校验、幂等、凭证注入、调用、错误归一、落回执——**九步全是代码**。模型能决定的只有两件事：**在名单里点哪个、参数长什么样。**
>
> 第一版我会把能力清单直接放 Git 里走 review，因为**把 risk_level 从 high 改成 low，等价于拆掉一道闸**，这个不能靠改数据库生效。」

---

## 十五、对现有代码的改造清单（基于 `ops-desk-api` 实测）

> 读过的文件：`app/ops/capability/manifests/builtin.v1.yaml`、`manifest.py`、`types.py`、`policy.py`

### 15.1 现状（实测）

| 位置 | 现状 | 对 HTTP 的影响 |
|---|---|---|
| `builtin.v1.yaml` | **唯一一份 manifest**，5 个 `local_fn` 能力 | 没有第二份文件的先例 |
| `manifest.py` | `ALLOWED_KIND = "local_fn"` **硬编码单 kind** | **HTTP 无法注册** |
| `ADAPTER_PREFIXES` | 只允许 `local_fn:app.ops.capability.defaults:` / `...lookups:` | HTTP 不是"引用函数"，是"内联声明"，形态不同 |
| `BUILTIN_MANIFEST_PATH` | **单文件硬编码** | 多份文件需要改加载入口 |
| 加载语义 | **整文件失败**（校验完成前零 register） | ⚠️ 混装 = 一个 OA 条目写错，**5 个内置能力一起带崩** |
| `_reject_secret_keys` | 按**键名**拒绝：`api_key/apikey/secret/password/token/access_token/auth_token/credential(s)/private_key/secret_key` | ⚠️ `credential_ref` / `auth_token_ref` 会被拒 |
| `CapabilitySpec` | 字段：`capability_id/kind/description/args_schema/tags/risk_level/enabled/tenant_scoped` | **没有 `side_effect`** ← 最大缺口 |
| `policy.py` | 只判 `risk_level=="high"`、`kind in {sandbox,cli}`、`tenant_scoped` | ⚠️ **`risk_level=medium` 但会真写 OA 的能力，Policy 完全放行** |
| `reload_capability_manifest` | 按单文件 unregister + register | 多文件时会**误伤其他文件**的 id |
| 纪律 | 注释明写「不是 HTTP 钩子，禁止在请求路径调用」 | ✅ 这条要保留并强化 |

### 15.2 结论：**分文件，不分格式**

**一个 loader、多份 manifest、同一个注册表。**

```
manifests/
  builtin.v1.yaml        # 产品基线（local_fn）
  oa.readonly.v1.yaml    # OA 只读（http）
  oa.draft.v1.yaml       # OA 草稿（http）
  oa.write.v1.yaml       # OA 写（http · 需 HITL）
```

**分文件的五条理由（按重要性）**：

1. **失败域隔离（最硬）**：整文件失败语义下，混装 = 运维改错一个 OA 接口的 `path`，把 5 个内置能力一起带崩。**产品基线不该被接入配置的失误影响。**
2. **变更频率不同**：builtin 随代码发布，OA 清单随业务接入变。混装会导致**「接一个 OA 接口要发一次后端版本」**。
3. **权限边界不同**：builtin 由开发改；OA 清单涉及 `risk_level` / `visibility`，要安全或业务 review。
4. **生命周期不同**：builtin 是产品自带；OA 能力随项目整体上线/下线。
5. **自然分组**：分文件即"能力域"，便于按域做可见集与审计统计。

**必须统一的四条（不能变）**：
- ✅ **同一个 schema**（不发明第二套字段）
- ✅ **同一个注册表**（同一个 `register()`，不搞两个 registry）
- ✅ **同一个 loader 路径**（扩展 `load_capability_manifest` 支持多文件，**不是新写一个 loader**）
- ✅ **同样的整文件失败语义**（坏一份不带崩别的）

### 15.3 `manifest.py` 的六处改动

| # | 改动 | 说明 |
|---|---|---|
| 1 | `ALLOWED_KIND`(str) → `ALLOWED_KINDS`(frozenset) | `{"local_fn", "http"}`；将来加 `grpc`/`rpa` 不用改命名体系 |
| 2 | adapter 解析**按 kind 分派** | `local_fn` → `LocalFnAdapter`（现有逻辑不动）；`http` → `HttpAdapter(spec)`，**从 `spec.http` 读绑定，不需要 `adapter:` 字段** |
| 3 | 路径：单文件 → **显式文件列表** | ⚠️ **不要做"目录扫描"**——往目录丢个文件就生效 = 绕过 review。用配置里写死的列表 |
| 4 | `_reject_secret_keys` **加固**（见 15.4） | 不是放宽，是换成"校验值" |
| 5 | `_entry_from_raw` 按 kind 分别校验 | `http` 必须校验 `http` 块齐全 + `base_url` 是环境变量名 |
| 6 | `reload_capability_manifest` **按文件记 id 集合** | 否则 reload A 会把 B 文件的能力一起 unregister |

### 15.4 密钥字段纪律：**不是放宽，是换一层**

**冲突**：HTTP 能力必然要声明"用哪个凭证"，而现有拒绝列表会拦掉 `credential_ref` / `auth_token_ref`。

**解法两步**：

**① 字段命名**：用 **`auth`** 或 **`auth_ref`**（都不在拒绝列表里）。**不要用 `credential_ref` / `auth_token_ref`。**

**② 更重要的是加强值校验**（现在只查键名，不查值）：

```python
# 新增：值必须是「凭证名」，不是「凭证本身」
_AUTH_NAME_RE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")

def _validate_auth_value(value: str, *, loc: str) -> None:
    if not _AUTH_NAME_RE.match(value):
        raise ManifestError(f"{loc} auth 必须是凭证名（小写+下划线），不是密钥值: {value!r}")
    if any(s in value for s in ("bearer", "sk-", "ghp_", "-----begin")):
        raise ManifestError(f"{loc} auth 疑似写入密钥值: {loc}")
```

**③ `base_url` 同理**：**必须是环境变量名，不能是 URL 字面量**（防止把内网域名/端口写进 Git）：

```python
if "://" in base_url:
    raise ManifestError(f"{loc} base_url 必须是环境变量名，不能是 URL 字面量")
```

> 这两条比现有校验**更严**，同时支持了 HTTP——**是加固不是开后门。**

### 15.5 `CapabilitySpec` 扩字段（**最大缺口：`side_effect`**）

现在 `policy.py` 只按 `risk_level == "high"` 判断，**没有任何"这是写操作"的独立标识**。后果很具体：

> **一个 `risk_level: medium` 但会真写 OA 的能力，Policy 完全放行。**

`risk_level` 管的是"**危险程度**"，`side_effect` 管的是"**有没有副作用**"——**这是两个维度，不能互相代理**。

建议扩：

```python
@dataclass(frozen=True)
class CapabilitySpec:
    capability_id: str
    kind: str
    description: str
    args_schema: dict[str, Any] | None = None
    tags: tuple[str, ...] = ()
    risk_level: str = "low"
    enabled: bool = True
    tenant_scoped: bool = False
    # ---- 新增 ----
    side_effect: str = "none"        # none | read | write | irreversible
    when_to_use: str = ""            # 面向模型的选择依据
    when_not_to_use: str = ""
    http: dict[str, Any] | None = None    # kind=http 时的绑定声明
    hitl_required: bool = False
    receipt_capture: tuple[str, ...] = ()
```

**注意：不要急着加 `visibility` 字段。** `CapabilityFilter` 已有 `node_role` / `tags_any` / `kinds` / `deny_high_risk`——这是"按调用上下文过滤"的机制。**第一期用 `tags`（如 `oa`、`dept:finance`）配合 filter 就够**；等可见性维度超过 2 个再引入独立声明，避免过早抽象。

### 15.6 `policy.py` 要补一道

```python
if spec.side_effect in ("write", "irreversible") and not (
    host.get("allow_write") is True           # 该次调用已被批准
):
    return PolicyDecision(False, "policy_blocked: write_not_confirmed")
```

**同时把 `allow_write` 加进 `HOST_ONLY_POLICY_KEYS`**——否则这个键不在"模型禁止直写"的集合里，`plan_ctx_has_host_only_keys` 的单测覆盖不到它。

### 15.7 加载时机纪律（**要新增一条**）

现有注释已经写了「不是 HTTP 钩子，禁止在请求路径调用」——**保留**。

**新增**：**能力清单变更后必须重启或显式 reload，不允许自动热加载。**

理由：**热加载意味着"改配置即改权限"，那 review 就白做了。** 这条纪律和能力清单走 Git + 人闸是一套的。

### 15.8 面试可以直接说这一段

> 「我看了下我们现在的能力清单——`builtin.v1.yaml` 是一份五枚 `local_fn` 的清单，`manifest.py` 里 `kind` 是硬编码 `local_fn` 的，adapter 只能引用两个模块上的函数。
>
> 要接老 OA，我会做三件事：**第一，加一个 `kind: http` 和一个通用 HTTP 适配器**，让注册变成写声明而不是写函数引用；**第二，是把清单拆成多份**——因为现在是**整文件失败**，接一个 OA 接口写错一个字段，会把五个内置能力一起带崩，这个失败域必须隔开；**第三，是给 spec 加 `side_effect` 字段**——现在 Policy 只看 `risk_level`，一个 `medium` 但会真写 OA 的能力是直接放行的，**「危险程度」和「有没有副作用」是两个维度，不能互相代理**。
>
> 密钥这块我会**收紧而不是放宽**：`auth` 字段只允许写凭证名，值要匹配凭证名格式；`base_url` 必须是环境变量名。**不允许任何看起来像密钥的值进仓。**」

---

## 十六、W1 实施记录（**已落地 · 代码实测**）

> 状态：已改完并通过测试，**未提交**（留给 review）。
> 范围：`spec` 扩字段 + `registry` + `http_generic` + 加载期 V1–V8 + OA 只读清单 + 测试。

### 16.1 实际改动

| 文件 | 改动 | 规模 |
|---|---|---|
| `capability/errors.py` | **新增**：七个稳定错误码词表 + `format_error` | +2.3 KB |
| `capability/types.py` | `CapabilitySpec` 扩 6 字段；新增 `RISK_LEVELS`/`SIDE_EFFECTS`/`WRITE_SIDE_EFFECTS`；`CapabilityFilter` 加 `deny_write` | +37 |
| `capability/registry.py` | **修既有 bug**：`dataclasses.replace` 替代手工重建；`deny_write` 过滤 | +21 |
| `capability/policy.py` | `allow_write` 进 `HOST_ONLY_POLICY_KEYS`；新增写操作闸（闸序：危险程度→副作用→危险形态→输入完整性） | +34 |
| `capability/adapters/http_generic.py` | **新增**：`GenericHttpAdapter` + `HttpTransport` 协议 + `Fake`/`Urllib` 实现 + `CredentialVault` + JSONPath 子集 | +18.8 KB |
| `capability/manifest.py` | `ALLOWED_KINDS`；kind 派发；多文件 + 失败域隔离；密钥校验加固；V1–V8；按文件记 id | +362 |
| `manifests/builtin.v1.yaml` | 补 `side_effect` / `when_to_use` / `when_not_to_use` | +17 |
| `manifests/oa.readonly.v1.yaml` | **新增**：3 条只读能力 | +4.5 KB |
| `capability/defaults.py` | `_DEFAULT_SPECS` 补 `side_effect="read"`（与 YAML 对齐） | +5 |
| `capability/__init__.py` | 导出新符号；env 门控加载额外清单 | +34 |
| `tests/test_capability_manifest_http.py` | **新增** 27 项 | +14.8 KB |
| `tests/test_capability_http_adapter.py` | **新增** 27 项 | +11.8 KB |
| `tests/test_capability_manifest.py` | fixture 补必填字段（**断言未改**），加 1 项自检 | +55 |

**测试结果**：`-k capability` → **208 passed, 1 skipped**；全量 → **751 passed, 1 failed**（该失败是 `test_chat_ws.py` 的 asyncio 偶发问题，**已用 `git stash` 在原始代码上复现，与本次改动无关**）。

### 16.2 ⚠️ 测试抓到的五个问题（**本节最值钱**）

| # | 问题 | 性质 | 修法 |
|---|---|---|---|
| **1** | `registry.register` 规范化 id 时**手工重建 `CapabilitySpec`**，漏掉 `tenant_scoped` | **既有 bug**（潜伏） | 改 `dataclasses.replace(spec, capability_id=cid)`。加 6 个字段后手工重建的爆炸半径会急剧变大 |
| **2** | `invoke` 里 `_push_tenant` **在 `headers` 拷贝之后**调用 → 租户头写进 `rendered` 而 `headers` 是副本，**静默丢失** | **新代码 bug**，被 `test_tenant_predicate_is_actually_pushed_downstream` 抓到 | 调序：先下推，再取 headers |
| **3** | V7「仅 kind=http 可声明 http 块」写在 `spec.http` 上判，而它对非 http kind **恒为 None** → **规则是死代码，误配被静默忽略** | **新代码 bug**，被 `test_v7_...` 抓到 | 改在**原始数据**（`raw["http"]`）上判 |
| **4** | V4 最初对 **`local_fn`** 的 `tenant_scoped` 也要求 `tenant_param` → **加载 builtin 清单直接崩** | **新代码过宽**，跑测试第一次就暴露 | V4 限定 `kind == "http"`：进程内适配器直接拿 `ctx`，不存在「下推」 |
| **5** | `_call` 只捕 `HttpCapabilityError` → 第三方 transport 抛裸 `TimeoutError`/`OSError` 会**穿透到模型侧** | **新代码不够健壮**，被重试测试抓到 | 边界处归一化为 `upstream_error` |

> **问题 3 最值得记住**：一条校验规则如果写在**恒为空的字段**上，它不是"没生效"，而是**看起来生效了**——比没写更危险。

### 16.3 两处对前文的纠正

**纠正一（§15.4 写错了）**：我原先说「`credential_ref` / `auth_token_ref` 会被现有校验拒绝」——**这是错的**。既有 `_reject_secret_keys` 是**精确匹配** `_SECRET_KEYS` + 仅对 `password`/`secret` 做子串，所以这两个键名**原本能通过**。

本次**主动加固**为对 `password`/`secret`/`token`/`credential` 四个词做子串匹配，才真正拦得住。结论仍成立（字段名要用 `auth`），**但理由是「加固后才拦得住」，不是「本来就拦」**。文档与测试已按事实改写。

**纠正二（V4 适用范围）**：V4 不是「所有 `tenant_scoped` 都要 `tenant_param`」，而是「**`tenant_scoped` 且 `kind=http`**」——对 `local_fn` 不适用。

### 16.4 尚未做的部分（**必须说清，不能假装已打通**）

| 未做 | 后果 | 计划 |
|---|---|---|
| **`kind: rag`** | `ALLOWED_KINDS` 目前只有 `{local_fn, http}`。**制度问答仍在治理之外**——「能力清单 ≠ API 清单」的遗留 | W2+ |
| **幂等去重存储 / 单飞锁** | ⚠️ V1 只保证「**声明了**幂等键」；键会算出来、会作为 `Idempotency-Key` 发出去，但**还没有去重表**——重复提交仍可能产生第二张单据 | **W5** |
| **HITL 快照链路** | V2/V3 只强制「必须声明 `hitl_required`」，**审批链路本身没接**（冻快照 → 管理员审 → 执行前复验） | W4 |
| **可见集求值** | 只有 `CapabilityFilter.deny_write` / `deny_high_risk` 两个开关；按部门/角色/密级求交的 `visibility.py` 没做 | W2 |
| **审计与回执落库** | adapter 会**返回** `receipt`，但**没有落库**（`receipts.py` 未做） | W2 |
| **gateway 错误码迁移** | `errors.py` 建好了，但 gateway 对 `unknown_id` / `disabled` 仍返回**中文文案**而非稳定码 | W2 |

> 面试时**这一节主动讲**，比被问出来强得多。尤其是幂等那条：**「我确保了键被声明、被传递，但去重存储还没做——所以现在还不能说重复提交被彻底挡住了。」**

### 16.5 复现命令

```bash
cd ops-desk-api
./.venv/bin/python -m pytest tests/ -k capability -q

# 端到端：加载 OA 只读清单，看模型拿到的工具清单
OPS_CAPABILITY_EXTRA_MANIFESTS=app/ops/capability/manifests/oa.readonly.v1.yaml \
  ./.venv/bin/python -c "
from app.ops.capability import list_capabilities, schemas_for_llm
print([s.capability_id for s in list_capabilities()])
print(schemas_for_llm()[-1])
"
```

---

## 十七、W2 实施记录（**已落地 · 代码实测**）

> 提交：`287175c`（在 `6576cad` W1 之上）。分支 `task/capability-h4-http-and-write-gate`。

### 17.1 实际改动

| 文件 | 改动 | 规模 |
|---|---|---|
| `capability/visibility.py` | **新增**：`Principal` 求值 + 四维求交 + `hidden/reason` 摘要 | +141 |
| `capability/receipts.py` | **新增**：`Receipt` + `ReceiptSink` 协议 + `InMemory` / `NullSink` | +153 |
| `capability/types.py` | `Principal` + `CLASSIFICATION_ORDER` + `classification_rank` + `CapabilitySpec.visibility` | +47 |
| `capability/gateway.py` | `principal` 参数贯通；`capability_catalog_snapshot`；稳定码前缀；回执挂钩；span 补 `side_effect`/`receipt_id` | +108 |
| `capability/manifest.py` | `visibility` 块解析与形状校验；**V9** | +36 |
| `capability/policy.py` | 抽出 `write_allowed(ctx)`（写放行的**唯一判定点**） | +13 |
| `manifests/oa.readonly.v1.yaml` | 3 条补 `visibility`（密级维度真实取值：internal / public / internal） | +19 |
| `tests/test_capability_visibility_and_receipts.py` | **新增** 31 项 | +292 |
| `tests/test_capability_manifest_http.py` | 补 V9 测试与 visibility 形状校验 | +43 |

**测试**：全量 **773 passed, 1 skipped**，2 failed（仍是 `test_chat_ws.py` 既有问题，与本次无关）。

### 17.2 三个设计决策（都可被追问）

**决策一：可见集分成两层，顺序不可颠倒。**
`CapabilityFilter`（场景：kind / 风险 / 写副作用 / tags）在前，`visibility`（身份：部门 / 角色 / 项目 / 密级）在后。前者回答「这个场景该不该出现这类能力」，后者回答「**这个人**能不能看到这个能力」。上海邮电设计院那种「700+ 制度分单位隔离存储」靠的是第二层。

**决策二：失败方向分两种，不是一刀切。**
- **声明了限制而主体信息不足 → 不可见**（fail-closed）
- **未声明 → 不受限，但记 `visibility_undeclared` 留痕**

第二条是刻意的：如果未声明也 fail-closed，5 个既有 builtin 能力会对所有主体消失。所以选择「放行但留痕」——**把「该声明没声明」变成可度量项**，而不是静默放行、也不是一刀切搞挂存量。

**决策三：`kind=http` 必须声明 visibility（V9）。**
因为它是**接别人系统的入口**，不该有「默认全员可见」这种兜底；进程内的 `local_fn` 则沿用 filter 语义，不强制。这条是上面那条「留痕」策略的配套——**新接入的东西不许享受遗留待遇**。

### 17.3 ⚠️ 关键集成发现：**http 能力目前对 Agent 不可见**（待你决策）

实测（加载了 OA 清单之后）：

```
注册表总数:        8
builder 实际可见:  ['mock_get_issue_status', 'mock_get_deploy_info', 'utc_now_iso',
                    'get_issue_by_number', 'get_pr_by_number']      ← 只有 5 个 local_fn
模型工具清单 oa.*: ['oa.doc.search', 'oa.org.whois', 'oa.todo.mine']  ← 这里却有
```

原因：`app/ops/strategy/builder.py` 的 `BUILDER_CAP_FILTER` **硬编码 `kinds=frozenset({"local_fn"})`**，`lg_rag/multi/nodes.py` 的 `_SUPERVISOR_CAP_FILTER` 同理。

**后果**：两层不一致——`schemas_for_llm()` 会把 OA 能力暴露给模型，而 Builder 构 `allowed_capability_ids` 时会把它们当「不可见」**剔除掉**，于是 supervisor 一旦计划 `oa.doc.search` 就会被 strip。

**安全性上没问题**（是剔不是放），但**功能上等于没用**。

**这不是 bug，是一个必须由你拍板的开关**，因为改它会**改变 Agent 的实际行为**：

| 选项 | 做法 | 影响 |
|---|---|---|
| A | `kinds` 放开到 `{local_fn, http}` | OA 能力立刻可被模型调用（仍需 `OPS_CAPABILITY_EXTRA_MANIFESTS` 显式加载） |
| B | 保持现状，另开 `http` 专线（独立 filter / 独立图） | 存量 Agent 行为零变化，但要多维护一条线 |
| C | 放开但加 `tags` 白名单（如 `tags_any={"oa"}`） | 折中：按域放开，风险可控 |

**我倾向 C**：`tags_any` 已经是现成机制，按域逐批放开比一次性放开 `kind` 更稳；而且和 `OPS_CAPABILITY_EXTRA_MANIFESTS` 的「显式打开」纪律是一致的。

另有一处**未接线**：`strategy_builder_node` 目前**没有传 `principal`**，所以身份可见集只在显式传 `principal` 时生效。接线需要从 `state` 取主体信息（当前 `lg_rag/state.py` 里没有 tenant 字段），属于跨模块改动。

### 17.4 尚未做的部分（更新）

| 未做 | 后果 |
|---|---|
| **幂等去重存储 / 单飞锁** | 仍然只保证「键被声明、被传递」，**重复提交仍可能产生第二张单据** |
| **回执 DB 表 + alembic 迁移** | 只有进程内 sink；重启即丢 |
| **HITL 快照链路** | 只强制声明 `hitl_required`，审批链路未接 |
| **`kind: rag`** | 制度问答仍在治理之外 |
| **builder / supervisor 的 `kinds` 放开 + principal 接线** | 见 17.3，**等你决策** |

### 17.5 一句话面试版

> 「可见集我分了两层：一层是**场景**——这个场景该不该出现这类能力；一层是**身份**——这个人能不能看到。两层顺序不能反。而且失败方向我特意分成两种：**声明了限制但身份信息不足，就不给看**；**没声明，就给看但记一笔痕**——我不想为了安全把存量的五个能力一刀切搞挂，也不愿意静默放行，所以选『放行但可度量』。新接入的 http 必须声明，不许享受遗留待遇，这条是写在加载期校验里的。」

---

## 十八、W5 收尾：幂等防重（含租约）与异步路径

> 提交：`ops-desk-api` 见同日 commit；表结构迁移 `20260919_capability_receipts`。

### 18.1 口径先说清：不是"强幂等"

**目标不是"回放原始结果"，而是"同一个幂等键不在本层发出两次请求"。**

为什么不回放（三条，前两条是决定性的）：
1. **强幂等最该起作用的场景，它恰好无能为力**——第一次结果未知时（超时/崩溃），
   **没有结果可回放**，最后还是得去下游查。既然最后都要查，不如一开始就只查、不缓存。
2. **在旧系统之上叠一层权威缓存 = 建第二个真源**。OA 是唯一真源；缓存会和它不一致
   （有人手工删单、流程撤回、数据迁移），那时谁赢？
3. **扩大数据边界**：回放要求把下游原始结果落库，而它可能是薪酬/合同/客户信息。
   国企/车企合规语境下这一条往往直接否决方案。

### 18.2 状态机与租约

```
claim(key) ──┬─ 无记录 → 建 in_flight（租约=now+TTL）→ acquired
             ├─ done    → duplicate（不再执行，带 receipt_id）
             └─ in_flight
                  ├─ 租约未过期 → in_flight（拒）
                  └─ 租约已过期 → 接管（重新计时，attempts+1，告警）
```

**租约不是优化，是必需品**：没有它，"先插占位行"的做法会在进程崩溃后把该键
**永久**卡死——而且是静默的。租约取值必须 **> 该能力的 `timeout_ms`**，
否则正常执行中的请求会被误判为卡死。

### 18.3 `release` 的语义（**最容易做错的一处**）

「失败就释放」是错的：**超时不代表没成功**，释放会让重试建出第二张单。

| 情形 | 能否释放 | 理由 |
|---|---|---|
| 请求还没发出去（渲染/凭证/租户/头编码失败） | ✅ | 下游没见过这次请求 |
| 下游明确拒绝（`args_schema_invalid`/`policy_blocked`/`permission_denied`） | ✅ | 被拒 = 无副作用 |
| 超时 / 连接错误 / 未知业务码（`upstream_error`） | ❌ **不能** | 可能已生效，留给租约 |
| 成功 | ❌ | 直接 `complete` |

**失败方向一律 fail-closed**：宁可让该键在租约期内被拒，也不冒重复执行的风险。
代码里就是 `RELEASE_SAFE_ERROR_CODES` 这个白名单——**白名单，不是黑名单**。

### 18.4 完成的分工（实施中修正的一处设计）

第一版把 `complete` 全交给 gateway（因为回执 id 在那儿才有）。测试立刻暴露问题：
**直接用适配器的调用会永远卡在 `in_flight`**。

改为分工：
- **适配器**在成功时 `complete(key)` ——「执行完成了」是适配器掌握的事实
- **gateway** 落完回执后 `complete(key, receipt_id=...)` 补上关联（支持二次调用更新）

另：**命中幂等键（duplicated）的那次不留回执、不重复 complete**——
没执行就没有副作用，重复 complete 会把原回执 id 覆盖掉、`duplicate_of` 就对不上了。

### 18.5 异步路径（顺带修掉一个生产级问题）

`urllib` 是**阻塞**的，而 `gateway._adispatch` 在适配器没有 `ainvoke` 时会**同步调用
`invoke`** → **一次 8 秒的下游请求会把事件循环按住 8 秒**，期间所有请求排队。
单测串行执行看不出这个退化。

修：`GenericHttpAdapter.ainvoke` 用 `asyncio.to_thread` 把阻塞传输挪出事件循环。
测试用「3 个并发调用 vs 单次 0.3s」计时断言并发没有被串行化。

### 18.6 表结构（已落盘）

- `ops_capability_receipts`：写得成败都落；`captured` 存 `receipt.capture` 抓到的字段；
  有 `write_confirmed` 让审计能区分「是在放行下执行的」还是别的路径
- `ops_capability_idempotency`：**`(tenant_id, idempotency_key)` 唯一**（租户内唯一，
  跨租户不互相影响）；`status` / `lease_expires_at` / `attempts` / `receipt_id`

### 18.7 尚未做（诚实清单）

| 未做 | 后果 |
|---|---|
| ~~DB 版 `IdempotencyStore` / `ReceiptSink` 实现~~ | ✅ **已在 §19 完成** |
| ~~启动装配~~ | ✅ **已在 §19 完成**（`OPS_CAPABILITY_PERSISTENCE=db\|memory`） |
| **租约巡检任务** | 卡住的 `in_flight` 需要运维/定时任务扫出来人工确认下游状态（`DbIdempotencyStore.asnapshot()` 已提供查询面） |
| **`kind: rag`** | 制度问答仍在治理之外 |

> 顺序说明：**先把异步路径钉死，再接 DB**。否则 DB 版会接在一个会让事件循环阻塞的地基上。

---

## 十九、W6 持久化收尾：DB 版 store/sink + 显式装配

> 提交见 `ops-desk-api` 同日 commit。这一步把 §18.7 里"会让机制在生产静默失效"的两条补掉。

### 19.1 DB 版防重存储

`DbIdempotencyStore`：**跨实例防重生效**（进程内版做不到，这正是它存在的理由）。
`claim` 是原子的，三步全在一个事务里：

1. `INSERT ... ON CONFLICT (tenant_id, idempotency_key) DO NOTHING` —— 无记录则抢到执行权
2. 已有记录且 `in_flight` 且**租约已过期** → 接管（`RETURNING attempts`）
3. 否则读回状态：`done` → duplicate；`in_flight` → 拒绝（并累加 attempts）

**租约判定交给数据库时钟（`now()`），不用应用进程时钟**——
多实例部署下各机器时钟有偏差，用本地时钟判租约必然出错。这是很容易忽略的一点。

### 19.2 异步/同步的边界

- DB 版 store/sink **只提供异步接口**（`aclaim`/`acomplete`/`arelease`、`arecord`）。
  同步 `claim` 刻意**不暴露**——那会让人在事件循环里同步调 DB。
- `DbReceiptSink.record()`（同步）**直接抛错**并提示走异步，而不是悄悄阻塞。
- 适配器与 gateway 都做了"有异步就用异步，否则 `to_thread` 包同步"的分派：
  `_astore_call` / `arecord_receipt`。
- 新增 `_aok_result` / `_aerr_result`：异步路径的回执走异步 sink，
  与同步路径（`_ok_result` / `_err_result`）**共享 `_build_receipt` 的判定逻辑**，
  避免两套规则漂移。

### 19.3 装配：显式，不自动探测

`OPS_CAPABILITY_PERSISTENCE`：

| 值 | 防重存储 | 回执 sink | 适用 |
|---|---|---|---|
| `db` | `DbIdempotencyStore` | `DbReceiptSink` | **生产** |
| `memory` | `InMemoryIdempotencyStore` | `InMemoryReceiptSink` | 单实例 / 联调（**多实例防重无效**，日志告警） |
| 不设 | `NullIdempotencyStore` | `NullReceiptSink` | 开发；**不可上生产**（每次写都告警） |

**刻意不做"自动探测数据库可用性"**：悄悄换存储实现正是我们要避免的那类惊喜——
出问题时会表现为"防重时有时无"，极难排查。要 DB 就显式写 `db`。
写错值（如 `redis`）→ 按不防重处理**并打 error**，不悄悄退回某个实现。

### 19.4 实施中抓到的 bug（**测试又一次立功**）

改完后跑全量，`test_gateway_completes_key_with_receipt_id` 立刻失败：

> 同步路径的 `complete(key, receipt_id=…)` **没传 `tenant_id`**。
> 而防重键的作用域是**租户内**（`(tenant_id, idempotency_key)` 唯一），
> 不传就落到空租户上 → `complete` 找不到那一行 → **状态永远停在 `in_flight`**。

这是"给函数加参数时漏传"的经典形态，而且**失败是静默的**（调用不报错，只是没生效）。
教训：**给"按复合键定位"的方法加参数时，要专门检查每个调用点**。

### 19.5 测试

`tests/test_capability_persistence_db.py`（真 PostgreSQL · `opsdesk_test`，15 项）：

- **跨实例防重**：两个 store 实例（模拟两个进程）抢同一 key，只有一个拿到执行权 ★
- 租约接管、release 重试、**租户隔离**、**并发 6 个 claim 只有一个赢**（靠 DB 唯一约束，应用层无锁）
- 回执 jsonb 往返仍是结构化对象（收据要能被查询，不是一坨文本）
- **DB 版不暴露同步接口**、同步 `record()` 明确报错
- 端到端：异步路径真落库 + 键被标 `done` + **键↔回执 id 对得上**
- 装配四种情形（默认 / memory / db / 写错值）

> ⚠️ 写这类测试必须用 `async def`（`asyncio_mode=auto`）——
> conftest 的 `_reset_engine` 是按"每测试一个 loop"管理的，
> 自己在同步测试里 `asyncio.run` 会与连接池绑定冲突（表现为 `coroutine was never awaited`）。

**全量 820 passed / 1 skipped**；桩服务联调 26/26 无回归。
