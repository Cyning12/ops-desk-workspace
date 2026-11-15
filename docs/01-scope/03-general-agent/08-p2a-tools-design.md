# P2a 设计终稿 · 面板数据工具化复用 capability 体系（lead 整合稿 v1）

> 状态：v1 终稿（lead 整合 · 2026-11-16）——architect 初稿 + platform/product 双向评审 7 项 blocking 全部裁定关闭
> 基线：ops-desk-api @ master（P1 全链并入后 · 2120 passed/0 failed）
> 上游：roadmap 04 §P2a（:41-46）· 07-p1-goal-design.md（体例与既往裁定）
> 评审记录：/tmp/opsdesk-rfc/p2a-review-platform.md · /tmp/opsdesk-rfc/p2a-review-product.md（05 讨论日志 R6 节归档要点）

---

## 0. 一页结论

P2a 把四个面板视图的数据查询封装为四枚只读 capability，进默认面 builtin.v1.yaml + supervisor allowlist：**图零改动、SSE 零新帧、零新依赖、零新 DDL（含索引）、面板端点零改动**。四枚全 kind=local_fn、side_effect=read、risk_level=low，落 app/ops/capability/lookups.py（adapter 白名单 defaults:/lookups: 不扩，manifest.py:64-66）。

相对 architect 初稿的**七处整合修订**（评审 blocking 裁定）：

| # | 来源 | 裁定 |
|---|---|---|
| R1 | platform-B1 | schema_validate（schema_validate.py:1-100）不校验 enum/min/max → **词表/边界强制落 adapter**（显式校验，违规抛错由 gateway 转 ok=False），manifest 声明保留仅作 catalog 引导；闸矩阵用例改为断言 adapter 拒绝 |
| R2 | platform-B2 | when_to_use/when_not_to_use **从不进 supervisor prompt**（nodes.py:104-128 只渲染 id/description/risk/output_fields/args_schema）→ 使用引导全部落 **description + args_schema**；失败处置的「修 catalog 文案」=修 description |
| R3 | platform-B3 | gateway span payload **无 tenant_id**（gateway.py:1312-1342）→ graph 全局放行的签收条件：**T1 先行给 span payload 补 tenant_id 一行**（元数据补全，不动图） |
| R4 | product-B1 | 验收样例 3→**4**（补 query_issues 样例），判定 4/4 |
| R5 | product-B2 | 判定标准补 **(e) 归纳判断**——回答须含跨数据点的归纳（非数字复读），结论按**成立/部分成立/不成立**三级裁定 |
| R6 | product-B3 | 对照协议钉死：验收会话与面板登录**同租户**、以 as_of 为对照基准、允许 ≤1 个 sync 周期漂移、graph 双租户同答案属预期（全局口径） |
| R7 | product-B4+platform-B2 | **mock 罐头工具语义竞争**：判据补 **(f) 未误选 mock_***；处置=收窄 mock 两枚 description 标注 demo 用途（T1 随单，when_not_to_use 是空调杆不写） |

另纳 non-blocking 六项（§10）。

---

## 1. 四枚工具契约（终裁）

### 1.1 总表

| capability id | 数据源（本地表） | tenant_scoped | 适配器 |
|---|---|---|---|
| `query_issues` | OpsIssue（issues.py:30-92 同谓词集） | true | lookups.py |
| `query_pull_requests` | OpsPullRequest（pulls.py:30-90 同谓词集） | true | lookups.py |
| `get_overview` | OpsIssue+OpsPullRequest+OpsSyncRun+OpsScanSnapshot（overview.py:67-181 同口径） | true（sync/scan 段全局，docstring 钉口径） | lookups.py |
| `graph_snapshot` | OpsGraphSnapshot（graph.py:16-40 最新一条） | **false**（全局 repo 级） | lookups.py |

**改名裁定**：roadmap 名 `get_pr_metrics` → **`query_pull_requests`**（product N4 + architect §1.1 均支持；名实一致——实为列表查询非指标，与 query_issues 对仗；roadmap 名登记为曾用名）。`get_overview` 定名（动词前缀与 get_*_by_number 同族）。

四枚定档理由：全读本地 PG、无外部调用、无写路径，暴露面不超既有面板端点 → read/low。tags 统一 `panel`+域 tag+`readonly`。

### 1.2 query_issues

- args_schema（type:object · additionalProperties:**false**）：`state` enum[open,closed] · `label` · `scan_status` · `module`（module_tag 等值）· `page` ≥1 默认 1 · `page_size` 1..**20** 默认 **10**（面板上限 100 在 capability 面收紧，防 prompt 膨胀）
- 返回：`{items[{number,title,state,labels,module_tag,updated_at}], total, page, page_size}`——剔 uuid `id`（join 键是 number）；不带 body（详情走既有 get_issue_by_number）
- **adapter 强制校验**（R1）：page≥1、1≤page_size≤20、state 词表——违规抛 LookupError，gateway 转 ok=False；测试断言 adapter 拒绝而非 schema 拒绝

### 1.3 query_pull_requests

- args_schema：`state` enum[open,closed,merged] · `ci_status` · page/page_size 同 1.2
- 返回：`{items[{number,title,state,draft,ci_status,updated_at}], total, page, page_size}`
- **ci_status 词表**（product N1）：T1 勘察先核仓内既有值——可钉则 adapter enum 强校验，不可钉则 string 放行 + description 列已知值（防 vacuous pass）

### 1.4 get_overview

- 无参数（additionalProperties:false，properties:{}）
- 返回对齐 overview.py:169-180：cycle_time/review_time/issue_throughput/as_of/sync_status/sync_run/scan_snapshot/trend
- 裁剪：trend 30 天全量保留；`scan_snapshot.parsed_summary` 序列化 **>2000 字符截断**为 `{keys:[...], truncated:true}`；`as_of` 必带（每日 sync 新鲜度自证）
- **空数据口径进 output_schema**（platform 盲点）：无数据时字段为 null 的声明逐键写清
- **话术纪律**（product N5）：description 与全部文档禁「实时」字样

### 1.5 graph_snapshot

- args_schema：`view` enum[summary（默认）,modules,full] · `module`（可选，过滤子图）
- 统一外壳：`{view, scope:"global_repo", repo_id, created_at, summary{node_count,edge_count,module_count}, module_matrix?|截断, payload?|截断, truncated:bool}`
- 上限：summary 4000 / modules 8000 / full **12000** 字符；超出按 nodes→edges 顺序截断 + truncated:true + totals；过滤优先于截断
- **fail-visible 裁定**（platform 盲点）：`module` 过滤依赖 kimi-code 外部 payload 结构，过滤键缺失/结构漂移时返回 `warning:"module_filter_no_match"` + 未过滤摘要，**不静默空集**
- 截断函数=独立纯函数可单测；`truncated` 语义进 description（platform NB）

### 1.6 大小上限统一表

| 类型 | 上限 | 依据 |
|---|---|---|
| 自由文本（body 类） | 500 | lookups.py:20 先例沿用 |
| 列表页 | page_size≤20 | 新定 |
| 结构化聚合（trend/sync_run） | 全量（有界） | 数学有界 |
| 半自由 JSONB（parsed_summary） | 2000 | 新定 |
| 大 JSONB（graph payload） | 4000/8000/12000 | ≈3-4K tokens 上限 |

---

## 2. 租户口径（终裁）

1. **三枚 tenant_scoped:true**：强制 `_tenant_from_ctx`（lookups.py:58-66，缺 tenant → LookupError("tenant_scope_missing")）+ Policy 双保险（gateway.py:380）；禁从模型产出取 tenant。get_overview 的 sync_run/scan_snapshot 段无 tenant 列属全局——照面板现状返回，docstring 钉口径。
2. **graph_snapshot tenant_scoped:false + 全局返回 + 三重防线**：manifest 诚实声明；输出常量 `scope:"global_repo"`；**审计防线修正**（R3）——T1 先行给 `_write_span_metadata` payload 补 tenant_id 一行（gateway.py:1312-1342 区域，元数据补全不动图），此后全局数据每次被调有租户归因。**platform 以此为放行签收条件，已纳入 T1 验收**。
3. 否决「拒绝开放」：面板 graph.py:16-40 本就无隔离，拒绝≠消除暴露且使验证假设残缺。
4. 登记缺口（P2a 不修）：多租户放量前 Graph/sync/scan 三面须补 tenant 列或 repo→tenant 映射 → P4 前置清单。
5. tenant 生产恒有值口径：panel 强制租户（issues.py:47-51）与 chat 图内 ContextVar 回落试点 A（tenant_context.py:24-26）不一致——验收对照协议按 R6 锚定同租户。

---

## 3. FC 主路径（终裁：不触发重估，维持 plan-JSON）

1. 无新证据：四枚走既有 catalog 注入 + plan-JSON + tool_exec，零新机制；schemas_for_llm supervisor 不消费（仅测试/extras）。
2. P1 07 §0 已锁；roadmap:44「冒烟仅在前者被替换时前置」。
3. 关闭态触发条件（非开放项）：(a) T4 冒烟中 plan-JSON 选择失败样例 ≥1/4 且可归因表达力而非 description 文案；(b) P2b MCP 翻译器发现 CapabilitySpec 无法无损映射 bind_tools schema。

---

## 4. CapabilitySpec ↔ MCP 对齐评审（终裁）

- 一次评审产出对照表落盘 workspace `docs/01-scope/03-general-agent/09-p2a-capability-mcp-mapping.md`（**编号自初稿 08 调整为 09**，本稿占 08）；
- 逐字段标「无损/有损（损失什么）/MCP 无对应/Spec 无对应」；**专行登记两处有损映射**（platform T3 提醒）：output_schema→outputSchema、side_effect→readOnlyHint；
- 差距逐项三选一：P2b 翻译器需求 / 不采纳（记理由）/ P2b 再议；**P2a 冻结 CapabilitySpec 字段族**；
- 与 T1/T2 并行（T3 纯文档零代码 PR），映射坑回灌 T4 验收标准，不回改已落 manifest。

---

## 5. 测试策略（终裁）

1. **manifest 计数**：test_capability_manifest.py:83 钉死 5 → 随单 5→7→9；新条目全字段钉死面（description/tags/risk_level/tenant_scoped/args_schema/side_effect/output_fields）。
2. **双层范式**：InMemory 层（CI 恒跑，含 tenant_scope_missing 负样本×3、graph 无 ctx 放行、截断纯函数单测）+ 真 PG 层（_DB_MARK，双租户 seed：隔离空集/分页/graph 三档/sync-scan 全局同值）。**真 PG 裁定必需**（租户谓词+JSONB 截断离真 DB 无法证伪）。
3. **fixture 纪律**（platform NB）：InMemory fixture 须含 budget.reset()/circuit.reset()（对齐 test_stage_w_write_expand.py:51-69 并补漏）。
4. **闸矩阵修订**（R1）：args 越界用例断言 **adapter 拒绝**（schema 层不校验 enum/min/max 是既有事实）；补委派层用例（默认 off，delegation.py:100）。
5. **catalog 总长断言**（platform NB）：新增测试断言 _format_capability_catalog 输出 ≤6000 字符（现状 ~1K → 9 枚后 ~4K 前提：禁 per-prop description——四枚 manifest 的 args_schema 不写 per-prop description）。

---

## 6. 验证假设「Agent 读面板数据出结论」验收（终裁）

CI 结构断言 + **四个**验收会话样例人工冒烟（Langfuse 回放），双件制。

**样例**（真实 /api/ops/chat/stream supervisor 模式）：
1. 「最近 issue 吞吐怎么样？」→ 期望 get_overview，引用 issue_throughput.count/trend，自述 as_of；
2. 「open 的 PR 里哪些 CI 挂了？」→ 期望 query_pull_requests(state=open, ci_status=failing)，列举 number+title；
3. 「模块 X 依赖哪些模块？」→ 期望 graph_snapshot(view=modules 或 module=X)，引用 module_matrix；
4. 「现在有哪些 open 的 bug？」（R4 补）→ 期望 query_issues(state=open[,label=bug])，列举 number+title。

**判定标准**：4/4 同时满足——
- (a) Langfuse trace 可见 tool_exec 命中预期 capability id；
- (b) 数字/列表与面板 UI 同屏对照一致（**对照协议 R6**：同租户登录 · as_of 基准 · ≤1 sync 周期漂移容差 · graph 双租户同答案属预期）；
- (c) 含 as_of/updated_at 新鲜度声明；
- (d) 无幻觉 id 致 plan fallback；
- (e) **含归纳判断**（跨数据点的结论，非数字复读——R5）；
- (f) **未误选 mock_* 工具**（R7）。

**结论三级裁定**：成立（4/4 全过）/ 部分成立（(a)-(d)(f) 过但 (e) 不足——工具链路通、结论力欠）/ 不成立（(a)(b) 任一失败）。
**失败处置**：工具选择错 → 先修 description（R2：唯一真实杠杆）；mock 误选 → 收窄 mock description（T1 已预收窄，仍错再评估 mock 退役提前）；可归因 plan-JSON 表达力 → 触发 §3 重估；数据错 → 退回 T1/T2。
**落盘**：验收记录（会话链接 + trace 导出 + **用户视角截图**（product N3）+ 对照结论 + 三级裁定）进 workspace docs。四样例一次跑完（product N6）。

---

## 7. 任务切分（终裁）

| 单 | Scope | 验收 | 依赖 |
|---|---|---|---|
| **P2a-T1 列表双工具+闸基** | lookups.py 加 query_issues/query_pull_requests（_tenant_from_ctx 复用 · adapter 强校验 R1 · 裁剪纯函数）；builtin.v1.yaml +2；allowlist +2；**span payload 补 tenant_id**（R3 · gateway.py:1312-1342 区域一行）；**mock 两枚 description 收窄标注 demo**（R7）；ci_status 词表核实（§1.3）；测试：count 5→7 + 字段钉死 + 闸矩阵（adapter 拒绝口径）+ 双层 + catalog 6000 断言 | §5 全绿；跨租户空集；page_size=21 被 adapter 拒；span payload 含 tenant_id 实证 | 顺序第一；面板端点零改动；adapter 白名单不扩 |
| **P2a-T2 聚合双工具** | lookups.py 加 get_overview/graph_snapshot（三档 view 裁剪 + parsed_summary 2000 + scope 常量 + fail-visible module 过滤）；builtin +2；allowlist +2；测试：count 7→9 + 截断标志 + graph 无 ctx 放行 + PG 层全局口径 + 空数据 null 声明 | §1.4/§1.5 形状断言全绿；warning:"module_filter_no_match" 实证；truncated 语义实证 | 依赖 T1（同文件）；零新 DDL/索引 |
| **P2a-T3 MCP 对齐评审** | 纯文档 → workspace 09-p2a-capability-mcp-mapping.md（对照表 + 两处有损映射专行 + 差距三选一） | 覆盖 types.py:84-144 全字段族；每项有处置 | 与 T1/T2 并行；零代码 PR；Spec 字段冻结 |
| **P2a-T4 验证假设冒烟** | 回归 + 四样例一次跑完 + 验收记录落盘（含用户视角截图 + 三级裁定） | §6 判定 4/4；失败按 §6 分流 | 依赖 T1+T2；curl/pytest 既有基建 |

依赖序：T1 → T2 → T4；T3 并行。过闸体例同 P1（task 档+registry+invokes+HG-AUDIT-R1，每单 ≤1 PR；T3 task 档落 workspace 仓）。

---

## 8. 非范围（终裁 · 11 项 + 2 补）

1. MCP client / skill 加载器（P2b）；2. 写能力新增；3. 面板 UI/REST 端点改动（adapter 按同谓词集重写 ORM，不复用端点函数）；4. FC/bind_tools 切换与 supervisor 图改动（nodes.py 零改动）；5. SSE 新帧；6. 新依赖；7. 新 DDL 含索引（慢查询→单独立案）；8. tenant freeze F1-F6；9. CapabilitySpec 字段族增删；10. mock 工具退役（仅 description 收窄，去留 P2b 评审）与 EXTRA_MANIFESTS 通路；11. schemas_for_llm/extras/langchain.py 改动；**12. when_to_use/when_not_to_use 字段填充**（R2：不进 prompt 是空调杆，填充属无效功——P2b 若接 prompt 再议）；**13. budget/circuit 默认值调整**（platform 盲点登记：64/run 幻觉打满风险，验收观察不预防扩容）。

---

## 9. 红线自检

| 红线 | 落实 |
|---|---|
| 图零改动 | allowlist 是 config 数据；catalog 数据驱动；span 补 tenant_id 是元数据非图 |
| SSE 零新帧 | §8.5 |
| 零新依赖 / 零新 DDL | §8.6/§8.7 |
| tenant freeze 不动 | §2.3/§8.8 |

开放项：无。关闭态备查：§3 FC 重估两条；§8.7 慢查询立案；platform 登记「catalog 无总长闸」由 §5.5 测试断言临时兜底、正式闸列 P2b 前置。

---

## 10. 采纳的 non-blocking 修订登记

| # | 来源 | 处置 |
|---|---|---|
| N1 ci_status 词表 | product | §1.3 T1 先核后定 |
| N2 MVP 叙事 | product | 登记：P2a 给 agent「长眼」——看着面板答「现在什么情况」 |
| N3 工具可见性 | product | 现帧够用零新帧；验收附用户视角截图；工具可读标签列 backlog（progress_stream.py:78-113 + subtask_message.py:42-48 只显示自由文本） |
| N5 话术 | product | 禁「实时」，as_of 声明 |
| NB catalog 6000 闸 | platform | §5.5 |
| NB fixture 补齐 | platform | §5.3 |
| NB 映射专行 | platform | §4 |
| NB page≤20×MAX_SUBTASKS=4 交互 | platform | 登记观察，不裁定改动 |
