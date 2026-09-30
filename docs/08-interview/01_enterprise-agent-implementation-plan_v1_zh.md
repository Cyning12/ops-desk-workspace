# 企业 Agent · 落地实施方案（按调研扩充）

> 上游文档：《企业Agent-背景梳理与需求点全景》（做什么、为什么）、《能力注册表落地设计》（机制怎么设计）
> 本文回答：**具体做什么、按什么顺序、每个文件交付什么**
> 基线：`ops-desk-api/app/ops/capability/` 现有实现（`manifest.py` 单 kind、单文件、整文件失败）

---

## 一、范围与边界

### 第一期只做两件事

1. **只读能力**上线可用
2. **草稿能力**上线可用（产出表单草稿，**不落库**）

**明确不做**：任何真写入、任何跨系统写、任何主动推送。

> 依据：行业口径「**查询可以先放开，写入与审批必须留住人**」。这不是保守，是被验证过的最优路径。

### 一条纪律贯穿全期

**能力的机制层（F 类）必须与第一期同时开始。** 因为「谁有权调什么」必须在能力第一次被注册时定义好，事后补不上。

---

## 二、能力清单（需求点 → 可注册条目）

### 2.1 一个重要发现：能力清单 ≠ API 清单

**「制度问答」不是一次 HTTP 调用，它是一条 RAG 链。** 所以能力清单里至少要支持**三种 kind**：

| kind | 是什么 | 适配器 |
|---|---|---|
| `local_fn` | 进程内函数（现有） | `LocalFnAdapter` |
| `http` | 声明式 HTTP 调用（新增，覆盖 ~80%） | `GenericHttpAdapter` |
| `rag` | 检索增强生成链（**二期可先复用现有 RAG 图**） | `RagAdapter`（薄封装，指向现有图） |

> **这恰恰是"纳管层"的价值所在**：不同形态的能力（函数 / 接口 / 检索链）进的是**同一张注册表、同一套可见集、同一套策略闸**。如果只纳管 http，制度问答就会游离在治理之外。

### 2.2 只读类（8 项 · 第一期）

| capability_id | 对应需求 | kind | side_effect | risk | 备注 |
|---|---|---|---|---|---|
| `oa.doc.search` | A2 文档定位 | http | read | low | 返回候选列表 + 链接 |
| `oa.doc.fetch` | A2 取正文/附件 | http | read | low | 必须带权限校验 |
| `oa.policy.qa` | A1 制度问答 | **rag** | read | low | 复用现有 RAG 图；**制度要带版本与适用范围** |
| `oa.org.whois` | A3 找关系 | http | read | low | 项目负责人 / 流程审批人 / 对接人 |
| `oa.todo.mine` | A4 我的待办 | http | read | low | **`tenant_scoped: true`** |
| `oa.flow.progress` | A4 流程进度 | http | read | low | **`tenant_scoped: true`** |
| `oa.leave.balance` | A4 年假余额 | http | read | low | **跨系统**（HR），第一期先 mock |
| `oa.ticket.history` | A5 历史工单 | http | read | low | 沉淀复用 |

### 2.3 草稿类（4 项 · 第一期）

| capability_id | 对应需求 | kind | side_effect | risk | 备注 |
|---|---|---|---|---|---|
| `oa.leave.draft` | B1 请假预填 | http/local_fn | **none** | low | 只产出草稿对象，**不提交** |
| `oa.ticket.draft` | B2 报障建单 | local_fn | **none** | low | 分类/定级/派单建议 |
| `oa.expense.draft` | B3 报销整理 | local_fn | **none** | medium | 发票识别 + 科目匹配 |
| `oa.meeting.extract` | B5 纪要转待办 | rag | **none** | low | 抽取 action item |

**草稿类为什么 `side_effect: none`？** 因为它不产生副作用——**草稿不落库**。但它必须**在输出上带"未提交"标记**，否则会被当成已提交。这是一个容易忽略的语义：**草稿能力的危险不在副作用，在于被误读为已提交。**

### 2.4 写入类（5 项 · 第二期起，逐项开）

| capability_id | 对应需求 | side_effect | risk | 上线批次 |
|---|---|---|---|---|
| `oa.ticket.create` | C1 提交工单 | write | medium | **第二期第一项**（高频低危） |
| `oa.leave.submit` | C1 提交请假 | write | medium | 第二期 |
| `oa.flow.urge` | C2 催办 | write | medium | 第二期 |
| `oa.kb.update` | C4 知识库更新 | write | **high** | 第三期（影响全员，需管理员审批） |
| `oa.perm.request` | C5 权限申请 | **irreversible** | **high** | 第三期（最高危，**per-request HITL 主战场**） |

---

## 三、manifest schema 定稿

### 3.1 顶层结构

```yaml
version: 1                      # 必填，整数
domain: oa                      # 可选，能力域（用于统计与审计分组）
capabilities: [...]             # 必填，list
```

### 3.2 条目字段规范

| 字段 | 必填 | 类型 | 校验规则 |
|---|---|---|---|
| `id` | ✅ | str | `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){1,3}$`（`域.对象.动作`） |
| `kind` | ✅ | enum | `local_fn` / `http` / `rag` |
| `description` | ✅ | str | 面向模型；**说"解决什么问题"，不说"调用什么接口"** |
| `when_to_use` | ✅ | str | **模型选中的主要依据** |
| `when_not_to_use` | ✅ | str | 防误选（可选但强烈建议） |
| `tags` | ✅ | list[str] | 用于 filter 与分组（如 `[oa, readonly]`） |
| `risk_level` | ✅ | enum | `low` / `medium` / `high` |
| `side_effect` | ✅ | enum | `none` / `read` / `write` / `irreversible` |
| `enabled` | ❌ | bool | 默认 `true` |
| `tenant_scoped` | ❌ | bool | 默认 `false`；**true 时 `http` 块必须有 `tenant_param`** |
| `args_schema` | ✅ | mapping | JSON Schema；**只描述形态**（业务不变量不进这里） |
| `adapter` | kind=local_fn 时✅ | str | 仅允许 `local_fn:app.ops.capability.<mod>:<attr>` 白名单模块 |
| `http` | kind=http 时✅ | mapping | 见 3.3 |
| `rag` | kind=rag 时✅ | mapping | `{graph: <已注册图 id>, top_k: int}` |
| `hitl` | 条件必填 | mapping | `{required: bool, snapshot_fields: [...]}` |
| `receipt` | ❌ | mapping | `{capture: [...]}`，写操作建议填 |

### 3.3 `http` 块规范

| 字段 | 必填 | 校验规则 |
|---|---|---|
| `method` | ✅ | `GET` / `POST`（PUT/DELETE 需额外人工 review） |
| `base_url` | ✅ | **环境变量名**，含 `://` **直接拒** |
| `path` | ✅ | 以 `/` 开头 |
| `auth` | ✅ | **凭证名**，`^[a-z][a-z0-9_]{0,63}$`；拒绝含 `bearer`/`sk-`/`ghp_`/`-----begin` 的值 |
| `query_map` / `body_map` / `header_map` | ❌ | 模板映射，值形如 `"{{arg_name}}"` 或字面量 |
| `idempotency_key` | **`side_effect ∈ {write, irreversible}` 时✅** | 模板串 |
| `tenant_param` | **`tenant_scoped: true` 时✅** | 声明租户谓词**怎么传下去**（query/body/header） |
| `timeout_ms` | ❌ | 默认 `8000`，上限 `30000` |
| `success_when` | ✅ | `{path: "$.code", in: [0, 200]}` |
| `error_map` | ✅ | `{"<上游业务码>": "<稳定错误码>"}`，**值必须是七个稳定错误码之一** |

### 3.4 加载期强校验（**这是本文最实用的一节**）

**能在加载期发现，就不要留到运行期。** `_entry_from_raw` 要新增以下规则：

| # | 规则 | 拒绝理由 |
|---|---|---|
| **V1** | `side_effect ∈ {write, irreversible}` → **必须有 `idempotency_key`** | 没有幂等键的写操作 = 重复提交产生多张单据 |
| **V2** | `side_effect ∈ {write, irreversible}` → **必须有 `hitl.required: true`** | 第一期不允许存在"无人工确认的写能力" |
| **V3** | `risk_level == high` → **必须 `hitl.required: true`** | 高危无确认 = 闸形同虚设 |
| **V4** | `tenant_scoped: true` → **`http` 块必须有 `tenant_param`** | ⚠️ **否则租户谓词只在 Policy 里检查、没真的传到下游——检查了但没用** |
| **V5** | 所有 `{{var}}` 模板变量必须**出现在 `args_schema.properties`** 里，或以 `_` 开头（Host 注入，如 `_user_id` / `_date`） | **模板变量写错是配置错误，加载期就该拦** |
| **V6** | `error_map` 的值必须是**七个稳定错误码之一** | 防止随手发明第八个 |
| **V7** | `kind == http` → 必须有 `http` 块；`kind == local_fn` → 必须有 `adapter`；`kind == rag` → 必须有 `rag` 块 | 形态完整性 |
| **V8** | `side_effect == read` → 不允许有 `idempotency_key` | 只读不需要幂等，写了通常是抄错 |

> **V4 尤其值得注意**：现有 `policy.py` 只检查 `tenant_scoped` 时 ctx 里有没有租户谓词——**但那个谓词有没有真的传到 OA 请求里，现在没有任何机制保证**。V4 就是把它变成加载期可验证的约束。

### 3.5 `side_effect` 与 `risk_level` 是**两个维度**

| | `risk_level: low` | `risk_level: medium` | `risk_level: high` |
|---|---|---|---|
| `side_effect: none` | 纯计算 | 复杂计算 | — |
| `side_effect: read` | 普通查询 | **查敏感数据** | 查高密级数据 |
| `side_effect: write` | 记日志 | **普通提交** | **批量写入** |
| `side_effect: irreversible` | — | — | **权限变更 / 删除 / 归档** |

**现有 `policy.py` 只看 `risk_level`，所以「`medium` + `write`」这一格是**完全放行的**——这正是必须在第一期就补 `side_effect` 的原因。**

---

## 四、`GenericHttpAdapter` 实现骨架

### 4.1 主流程

```python
class GenericHttpAdapter:
    def __init__(self, spec: CapabilitySpec, vault: CredentialVault, client: HttpClient):
        self.spec, self.vault, self.client = spec, vault, client

    async def ainvoke(self, args: dict, ctx: InvokeContext) -> CapabilityResult:
        http = self.spec.http or {}
        # 1. 模板渲染：args + Host 注入变量 → query / body / header
        rendered = self._render(http, args, ctx)
        # 2. 凭证注入（按名字取，永不落日志）
        headers = {**self.vault.headers_for(http["auth"]), **rendered["headers"]}
        # 3. 租户谓词下推（V4 保证 tenant_param 存在）
        if self.spec.tenant_scoped:
            self._push_tenant(http["tenant_param"], rendered, ctx)
        # 4. 幂等键（写操作必有；V1 保证）
        key = self._idempotency_key(http, args, ctx)
        # 5. 调用
        resp = await self._call(http, rendered, headers, key)
        # 6. 成功判定 + 错误归一
        result = self._normalize(resp, http)
        # 7. 回执捕获
        if self.spec.receipt_capture:
            result.meta["receipt"] = self._capture(resp, self.spec.receipt_capture)
        return result
```

### 4.2 四条实现要点

**① 写操作绝不自动重试**

```python
RETRYABLE = {"GET"}          # 只有读才重试
if http["method"] not in RETRYABLE:
    retries = 0              # 超时不代表失败——可能已成功
```

> **这是最容易踩的坑**：写接口超时后重试，可能已经成功了 → 产生第二张单据。**写操作的"失败"必须靠幂等键 + 主动查询确认，不能靠重试。**

**② 模板渲染只允许词表内的变量**

```python
_VAR_RE = re.compile(r"\{\{(\w+)\}\}")

def _render(self, http, args, ctx):
    allowed = set((self.spec.args_schema or {}).get("properties", {})) | {
        "_user_id", "_date", "_tenant_id", "_subtask_id"
    }
    for m in _VAR_RE.finditer(json.dumps(http)):
        if m.group(1) not in allowed:
            raise InvokeError("args_schema_invalid", f"未声明变量: {m.group(1)}")
```

（加载期 V5 已拦一遍，运行期再拦一遍——**双保险，因为运行期的 ctx 变量集合可能因部署而异**。）

**③ 凭证永不落日志**

```python
def headers_for(self, auth_name: str) -> dict[str, str]:
    value = self._vault.read(auth_name)     # 从保险箱
    return {"Authorization": f"Bearer {value}"}
    # 注：日志层要有 secret scrubber，正则扫 "Bearer\s+\S+"
```

**④ 错误归一化**

```python
def _normalize(self, resp, http) -> CapabilityResult:
    ok = _jsonpath(resp.json(), http["success_when"]["path"]) in http["success_when"]["in"]
    if ok:
        return CapabilityResult(ok=True, output=resp.json())
    upstream_code = str(_jsonpath(resp.json(), "$.code"))
    stable = http["error_map"].get(upstream_code, "upstream_error")   # V6 保证映射值合法
    return CapabilityResult(ok=False, error=stable)
```

---

## 五、交付物与节奏

| 期 | 交付文件 | 验收标准（可测） |
|---|---|---|
| **W1** | `spec.py`（含 `side_effect` 等新字段）<br>`registry.py`<br>`adapters/http_generic.py`<br>`manifests/oa.readonly.v1.yaml`（3 项） | 通过 YAML 注册一个 OA 只读接口并调通；<br>**加载期 V1–V8 八条校验全部有单测** |
| **W2** | `visibility.py`<br>`errors.py`（七个稳定错误码）<br>`receipts.py`<br>审计埋点 | **两个不同角色看到不同的能力清单**；<br>底层 `200+code=1001` 对模型是 `args_schema_invalid` |
| **W3** | `manifests/oa.draft.v1.yaml`（4 项）<br>草稿输出契约（带"未提交"标记） | 草稿**不落库**；被误读为已提交的情况有显式标记兜住 |
| **W4** | `idempotency.py`<br>`manifests/oa.write.v1.yaml`（1 项：`oa.ticket.create`）<br>HITL 快照链路 | 快照 → 审批 → 执行 → 回执全链路通；<br>**审批期间参数被改 → 拒绝执行** |
| **W5** | 单飞锁、批量保护、`oa.leave.submit` | **同一次写提交两次 → 第二次返回 `duplicate_id` + 同一个回执** |
| **W6+** | `oa.kb.update` / `oa.perm.request`（高危）<br>`adapters/oa_flow.py`（业务级编排） | 管理员审批；**执行前复验覆盖"权限收窄"全部形式** |

### 第一期（W1–W3）结束时应能回答

- 能力清单长什么样？（可展示 YAML）
- 谁能用哪些能力？（可展示两个角色的清单差异）
- 模型看到的能力描述是什么？（可展示 `list_capabilities` 的摘要输出）
- 出错了模型看到什么？（可展示七个错误码）
- 草稿和提交怎么区分？（可展示"未提交"标记）

**这五问能答上，第一期就算立住了。**

---

## 六、风险与取舍（**面试能主动讲出来会非常加分**）

### 6.1 取舍一：凭证注入的位置

| 方案 | 好处 | 代价 |
|---|---|---|
| **A. 凭证注入在策略闸之后（T6，当前设计）** | 被拦的调用**压根拿不到凭证** | Policy **无法基于凭证身份**做细粒度判断 |
| B. 凭证获取在策略闸之前（T3 前） | Policy 可用服务账号身份做判断 | 被拦的调用也已经取到了凭证（内存里） |

**当前选 A**，理由是"最小暴露面"优先。**但如果 OA 侧有基于服务账号的细粒度授权，就必须改成 B。** 这个判断取决于对方 OA 的鉴权模型——**面试时可以把这个取舍抛给对方，等他们回答。**

### 6.2 取舍二：老 OA 的同步阻塞接口

有些老 OA 的提交流程接口会**同步跑完整条审批链**再返回，必然超时。解法：

- 优先找**异步提交 + 状态查询**接口（`oa.flow.progress` 正好是它）
- 拿不到就退化为：**提交接口超时视为"未知"，用幂等键去查询确认**，绝不重试

**这个退化路径必须显式写进 adapter，不能靠"运气好不超时"。**

### 6.3 取舍三：RAG 类能力要不要真的按 `kind: rag` 纳管

**第一期建议"薄纳管"**：`rag` 能力的 adapter 只是**指向已有 RAG 图**，不重写检索逻辑。

好处是快、不动存量；代价是**它的可见集与审计口径要靠适配器兜住**（因为图内部有自己的流程）。**这个折中要主动说明，不要假装已经打通。**

### 6.4 已知会被追问的三个点（诚实回答）

1. **多实例下注册表分叉** —— 现有是进程内 dict。**第一期靠"实例上报清单版本号 + 不一致告警"让它可见，不假装解决了。**
2. **没做过跨系统（ERP/HR）** —— 现有只接触过本库只读。**机制是现成的，场景没跑过。**
3. **没做过主动式（E 类）** —— 主动性 = 越权风险，**这一块我建议放到最后，且必须先有授权模型**。

---

## 七、面试怎么讲这份方案（60 秒）

> 「我的落地节奏是三段：**先只读、再草稿、最后才写**，因为行业上验证过的口径是「查询可以先放开，写入和审批必须留住人」。
>
> 但有一件事我要和第一期同时开始，就是**治理层**——可见集、策略闸、审计。因为「谁有权调什么」必须在能力第一次被注册的时候就定义好，事后补补不上。**这个我返工过一次。**
>
> 具体到清单，第一期是八项只读加四项草稿。这里有个我想特别说的点：**能力清单不等于 API 清单**——比如制度问答，它根本不是一次接口调用，是一条检索链。**所以注册表至少要能同时纳管「函数、接口、检索链」三种形态**，否则制度问答就会游离在治理之外，那这套纳管层就白做了。
>
> 另外我会在**加载期**就把该拦的拦掉：写操作没有幂等键、没有人工确认、标了租户但租户谓词没声明怎么下推——**这三种情况加载就直接失败，不留到运行期。**」