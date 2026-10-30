# Task：阶段 T · 只读多租户契约定稿 + 第二租户数据前置

> **状态**：`active` · **过程轨** · **不授权子仓 30**  
> **类型**：契约 / 数据前置 / 跨仓编排  
> **上游**：`docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md` · `docs/05-plan/05_post_h_stage_brief_v1_zh.md` · api `docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` §8  
> **分支**：`task/stage-t-tenant-contract`（建议；base：`main`）  
> **执行模式**：Open Folder = **`ops-desk-workspace/`**；只改本仓文档/契约；**不**改 api/web/ios 业务码  
> **00 注**：2026-09-18 · 维护者令「起草」· 本窗落壳；人工闸均 `pending`；D1–D3 齐前禁止派子仓 30

---

## Harness 元信息

| 字段 | 值 |
|------|-----|
| **task_slug** | `stage-t-tenant-contract` |
| **git_branch** | `task/stage-t-tenant-contract` |
| **implement_repo** | `ops-desk-workspace` |
| **test_strategy** | `recommended` |
| **test_strategy_note** | 文档仓；验收以契约可勾选 + `npx spec-wave task lint --file` + 可选 `./scripts/graph-compile.sh` 为准 |
| **code_quality_bar** | `not_applicable` |
| **code_quality_bar_note** | 过程轨 / 无应用源码 |
| **graph_change_layer** | `G-L0` |
| **graph_delta** | `docs/_tech_graph/00_main.graph.yaml`（可选一句阶段 T 锚点备注） |
| **graph_delta_note** | **不**填满契约图；仅总图可加「阶段 T 进行中」备注；默认可零 diff |
| **wiki_delta** | `docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md` · `docs/05-plan/07_stage_t_data_prep_runbook_v0_zh.md` · `docs/contracts/api-v1-tenant-readonly-context-draft.md` · `docs/05-plan/05_post_h_stage_brief_v1_zh.md` |
| **wiki_delta_note** | 进入条件纠偏（H β MERGED）· 契约草稿→定稿路径 · 跨仓 task 指针 |
| **experience_capture** | `recommended` |
| **kpi_aggregator** | `CLOSE` |
| **invoke_retention_profile** | `minimal` |
| **required_invoke_hats** | `10,00` |
| **close_pr_policy** | `recommended` |
| **review_hat** | `20` |
| **orchestration** | workspace 00 统筹 → 数据前置（维护者）→ 契约定稿 → 再派 api/web 30 |

### 人工闸

| human_gate_id | status | blocks_hats | 说明 |
|---------------|--------|-------------|------|
| HG-TASK-DRAFT | **approved** | 20-R1, 派子仓 30 | 2026-10-30 维护者签收；解锁 20-R1；**不**因签收本闸而开子仓 30 |
| HG-AUDIT-R1 | **approved** | 本仓若有图谱大改 | 2026-10-30 · 20-R1 审查文 PASS 无 blocker（`docs/harness/reviews/review_20261030_stage_t_tenant_contract_r1.md`）· 过程轨薄改 **00 代签**（维护者 2026-10-30 授权「00签收后续文档」）|
| HG-GRAPH-MODULES | pending | 改总图时 | 默认零 diff 可跳；若改 `00_main` 须签 |
| **HG-STAGE-T-DATA** | **approved** | **派 api/web 30** | 2026-09-18 维护者同意 Fixture 轨 · **本波只跑本地** · 生产 P 轨另做 |
| **HG-CONTRACT-FREEZE** | **approved** | api/web 30 联调语义 | 2026-09-18 · F1–F6 齐 · 契约升 freeze · 00 代签（维护者接受 F4） |

---

## 背景与目标

阶段 H α/β 已 CLOSE 并合入 api `master`（#138 · #141）。下一串行产品波是 **阶段 T · 只读多租户**：把 H 已落地的 `tenant_scoped` 从「构造性单租户注入」推进到 **真实第二租户封闭 + 请求上下文契约**。

本 task **只做过程面**：钉死进入条件、数据前置清单、契约字段表、跨仓拆分指针。**不**实现 lookup/RAG 下推码；**不**改 SSE freeze。

### 完成态

1. `06_stage_t_*.md` 进入条件表与 H β 状态与磁盘一致；D1–D5 状态可维护。  
2. `api-v1-tenant-readonly-context-draft.md` 升级路径清晰：至少钉死 §2 请求上下文字段策略（头 vs session）与跨租户失败码口径草案。  
3. 子仓 task 壳已落盘且互链：api `tenant-readonly-predicate` · web `tenant-context-chat`。（2026-10-30 注：已被磁盘实态超越——壳不仅落盘且已 30 完成 CLOSE，分别迁 api/web `done/`。）  
4. **HG-STAGE-T-DATA** 未批前：任何子仓 30 **拒开工**（写进本 task 与 06）。

> **2026-10-30 复核**：完成态 1–4 磁盘面已齐；**HG-TASK-DRAFT 已 approved（2026-10-30 维护者签收）**；下一棒 20-R1；CLOSE 决策归维护者。

---

## 范围

- [x] **C1 · 进入条件纠偏**：06 表 H β → **CLOSE + PR #141 MERGED**（2026-10-30 复核与磁盘一致 · merge commit `4896701`）；**NO-GO 30** 语义保留于生产 P 轨（Fixture 轨 30 已 CLOSE）。  
- [x] **C2 · 数据前置跟踪**：D1–D5 勾选表已刷新（2026-10-30：Fixture 轨全 ✅ · 证据入 06 §2）；最小开工条 = D1+D2+D3（对生产 P 轨真种子仍生效）。  
- [x] **C3 · 契约定稿推进** → **freeze**：  
  - [x] `tenant_id`：**F1=C**（session 真源 + 头须一致）· 2026-09-18  
  - [x] 头名：`X-Ops-Tenant-Id`（F2）  
  - [x] `workspace_id` 本波等同 `tenant_id`（F3）  
  - [x] 跨租户：**对外 404** · 对内/日志 `tenant_scope_denied`（F4）  
  - [x] **显式**：默认不改 lg-rag SSE `event_type`  
  - [x] `HG-CONTRACT-FREEZE` approved · 2026-09-18 |  
- [x] **C4 · 跨仓指针**：壳已随子仓 30 CLOSE 迁 `done/`（api 09-21 归档 · web 10-17 CLOSE · PR #76），互链已更新（§依赖改指 `done/`）。  
- [ ] **C5 ·（可选）** 总图一句备注；非硬门。（2026-10-30：按默认零 diff 跳过）

### 非范围

- api/web/ios **任何**业务码、迁移、fixture 落库实现（数据可由维护者手工/脚本另做，不在本 task 30）  
- 阶段 W（写 / HITL）· 阶段 P（Registry / 本体平台）  
- 改 SSE freeze / idle keepalive  
- 租户切换完整产品 UI（见 web D5；本波可只定「头/session 注入」）

---

## 验收标准

- [ ] 06 进入条件表：H β = CLOSE+MERGED；第二租户数据 = 否（或已齐则改是并签 HG-STAGE-T-DATA）  
- [ ] 契约文档含可勾选「待钉死」清单；未 freeze 前标题/状态仍标明 draft  
- [ ] api/web task 壳路径写入 §依赖；slug 与 06 §3 一致  
- [ ] `npx spec-wave task lint --file docs/tasks/active/task_stage_t_tenant_contract.md` PASS  
- [ ] 人工闸表：`HG-STAGE-T-DATA` / `HG-CONTRACT-FREEZE` 语义写清 blocks  
- [ ] CLOSE 时：若数据仍未齐，task 可转 `blocked` 或保持 active，但 **不得** 伪称已授权子仓 30

---

## failure_paths

| 触发 | 系统行为 | 可重试 | 用户可见 |
|------|----------|--------|----------|
| D1–D3 未齐却派 api/web 30（生产 P 轨真种子口径；Fixture 轨已 CLOSE） | 00/verify **拒开工** | 是（先数据） | 是 |
| 契约未 freeze 子仓静默改字段义 | 20/40 拒收 | 是 | 否（内部） |
| 跳过 T 直接开 W task | 总 00 拒收 | 是 | 是 |
| 为 T 改 SSE event_type 无联调闸 | 拒收 | 是 | 是 |
| 本仓误改子仓代码 | 纪律拒收 · 回滚 | 是 | 否 |

---

## 依赖

| 依赖 | 路径 |
|------|------|
| 阶段 T 前置 | `docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md` |
| 数据 Runbook | `docs/05-plan/07_stage_t_data_prep_runbook_v0_zh.md` |
| 契约草稿 | `docs/contracts/api-v1-tenant-readonly-context-draft.md` |
| post-H 简报 | `docs/05-plan/05_post_h_stage_brief_v1_zh.md` |
| 决议 §8 | `../ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` |
| api 子壳（已 CLOSE） | `../ops-desk-api/docs/tasks/done/task_tenant_readonly_predicate.md` |
| web 子壳（已 CLOSE） | `../ops-desk-web/docs/tasks/done/task_web_tenant_context_chat.md` |
| H α done | `../ops-desk-api/docs/tasks/done/task_capability_contract_hardening.md` |
| H β done | `../ops-desk-api/docs/tasks/done/task_supervisor_budget_h_beta.md` |

---

## 给执行帽的必读列表

1. 本 task（人工闸 · 非范围）  
2. `docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md`  
2b. `docs/05-plan/07_stage_t_data_prep_runbook_v0_zh.md`  
3. `docs/contracts/api-v1-tenant-readonly-context-draft.md`  
4. api 讨论稿 §8  
5. 子仓 task 壳（只读对齐依赖，不改码）

---

## 思考轮控制

| 轮 | 结论 | early_stop | reason（early_stop） | residual_risks |
|----|------|------------|----------------------|----------------|
| R0 | T = 只读封闭 + 契约；本仓只过程 | no | — | none |
| R1 | 阻塞闸拆 HG-STAGE-T-DATA / HG-CONTRACT-FREEZE | no | — | 维护者未拍 D1/D5 |
| R2 | 子仓壳并行落盘但 30 串行等数据 | no | — | 壳与实现漂移 |
| R3 | SSE 默认不动；头/session 策略待钉 | yes | 决策面已框定；字段钉死属维护者闸非再开轮 | D5 UI 范围未拍 |
| R4 | （未开） | — | early_stop at R3 | — |
| R5 | （未开） | — | early_stop at R3 | — |

**actual_last_round**：R3 · **early_stop**：yes · **reason**：上游 H→T→W 与 06 已钉；本 task 只过程；再开轮无新增决策面 · **residual_risks**：见 R3

### R0 · 问题框定

阶段 T 的真阻塞是 **第二租户数据 + 请求上下文契约**，不是缺另一份实现 task。workspace 负责定稿与闸，避免子仓抢跑。

### R1 · 闸设计

「NO-GO 30」必须落到具名闸 `HG-STAGE-T-DATA`，避免仅写在 06 正文被忽略。

### R2 · 壳与派工

api/web 壳可先落 active（便于联调读序），但闸表写死：数据未齐 = 拒 30。

### R3 · 契约边界

T 不改 SSE freeze；租户只进 body/header/session。停轮把字段钉死交给维护者签 `HG-CONTRACT-FREEZE`。

### R4 ·（未开 · early_stop）

本轮不展开；决策面已在 R3 收束。

### R5 ·（未开 · early_stop）

本轮不展开。

---

### 自检结论

| 检查 | 结果 |
|------|------|
| `npx spec-wave task lint --file docs/tasks/active/task_stage_t_tenant_contract.md` | **PASS**（2026-10-30 · 10 帽对定稿复跑） |
| 结论 | **完成态 1–4 磁盘面已齐 · HG-TASK-DRAFT approved（2026-10-30 维护者签收）· 待 20-R1 · 生产 P 轨真种子未授权** |

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-09-18 | 10 起草：过程轨壳 · 双阻塞闸 · 互链 api/web |
| 2026-10-30 | 10 完成态①②：06 纠偏至磁盘实态（H β merge `4896701` 复核 · D2–D4 Fixture 轨完成 · §3/§依赖 指针迁 `done/`）· 契约 freeze 复核维持 · C1/C2/C4 勾选 · lint PASS；闸表 status 未动 |
| 2026-10-30 | 00 记录：维护者签收 **HG-TASK-DRAFT → approved**（解锁 20-R1 · 不因本闸开子仓 30）；其余闸 status 未动 |
| 2026-10-30 | 20-R1 minor：failure_paths 第 1 条括注「生产 P 轨真种子口径；Fixture 轨已 CLOSE」，消除表观冲突 |
| 2026-10-30 | 20-R1 审查 PASS（无 blocker · minor×1 已修）· 00 代签 **HG-AUDIT-R1 → approved**（维护者授权）；HG-GRAPH-MODULES 图谱零 diff 跳过 |
