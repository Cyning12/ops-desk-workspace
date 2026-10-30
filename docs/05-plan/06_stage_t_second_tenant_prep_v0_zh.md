# 06 · 阶段 T · 进入条件核对 + 第二租户数据前置（v0）

| 项 | 内容 |
|----|------|
| **状态** | `active` · 过程文档 · **不授权子仓 30** |
| **日期** | 2026-09-17 |
| **Open Folder** | `ops-desk-workspace/` |

---

## 1. 进入条件核对表

| 条件 | 结论 | 证据 |
|------|------|------|
| H α schema/allowlist/`tenant_scoped` 测绿且已合入 | **是** | api PR #138 · task done · pytest 76（CLOSE 时） |
| H α 已部署 | **是** | GHA deploy-api run 35213144703 success |
| web 冒烟 PASS（lg-rag 主路径） | **是** | `../ops-desk-web/docs/harness/invokes/by-task/post-h-alpha-smoke/invoke_20260917_00_smoke_post_h_alpha.md` |
| H β（supervisor 预算） | **CLOSE · PR [#141](https://github.com/Cyning12/ops-desk-api/pull/141) MERGED** | api `docs/tasks/done/task_supervisor_budget_h_beta.md` · 不阻塞本表契约测绿项 |
| 存在第二租户试点数据（非仅 `ops-desk-pilot`） | **否（Schema 亦无 tenant 列）** | 见 `07_stage_t_data_prep_runbook_v0_zh.md` §0 |
| Principal↔Workspace 产品语义决议 | **部分 · 契约 F1–F6 已 freeze** | 契约 `api-v1-tenant-readonly-context-draft.md` |
| 跨租户负样本金样计划 | **挂账 · 随 api 30** | api task D4 竖切 |
| 跨仓 task 壳 | **已起草** | §3 · `HG-CONTRACT-FREEZE` ✅ · `HG-STAGE-T-DATA` 等 Fixture 轨签字 |

### GO / NO-GO（对 T 的 10/30）

**GO 开子仓 30（Fixture / 本地）** · 2026-09-18 维护者 F-SIGN。  
**生产 B 种子**：仍走 `07` §4 P 轨，不挡本地。  
**契约**：`HG-CONTRACT-FREEZE` ✅。

---

## 2. 第二租户数据前置清单

目标：至少两个互不可见的只读租户语料/工单切片，供负样本与下推断言。

| ID | 前置项 | Owner 建议 | 状态 |
|----|--------|------------|------|
| D1 | 钉死租户 id 命名：`ops-desk-pilot`（A）+ `ops-desk-pilot-b`（B） | 维护者 | ✅ **2026-09-18** |
| D2 | B 的 Issue/PR（须先有 tenant 列） | api · 见 `07` 双轨 | ⏳ Schema 缺口 · Fixture 轨可先解闸 |
| D3 | RAG chunk / Qdrant 带租户 | api · 见 `07` | ⏳ filter_payload 尚无 tenant · 同左 |
| D4 | 负样本：A 查 B → 404/空 | api eval / 30 | ⏳ |
| D5 | web 切换 UI + Playwright agent | 产品 | ✅ **本波必做**（2026-09-18） |

**最小可开工 30**：D1 ✅ + 维护者 **Fixture 轨 F-SIGN**（`07` §3）→ 签 `HG-STAGE-T-DATA`。  
**最小可联调发版**：另齐 `07` §4 P 轨（迁移后真种子）。

---

## 3. 跨仓拆分（task 壳已落 · 数据齐后再派 30）

| 仓 | task 文件 · slug | 依赖 | 30 |
|----|------------------|------|-----|
| workspace | [`docs/tasks/active/task_stage_t_tenant_contract.md`](../tasks/active/task_stage_t_tenant_contract.md) · `stage-t-tenant-contract` | D1 命名 · 契约定稿 | 过程轨（无业务 30） |
| api | [`../ops-desk-api/docs/tasks/active/task_tenant_readonly_predicate.md`](../../ops-desk-api/docs/tasks/active/task_tenant_readonly_predicate.md) · `tenant-readonly-predicate` | 契约 freeze ✅ · Fixture 轨签字后 | **NO-GO** 直至 `HG-STAGE-T-DATA` |
| web | [`../ops-desk-web/docs/tasks/active/task_web_tenant_context_chat.md`](../../ops-desk-web/docs/tasks/active/task_web_tenant_context_chat.md) · `web-tenant-context-chat` | 同上 · D5 含切换 UI | **NO-GO** 直至 `HG-STAGE-T-DATA` |
| ios | 非本波 | — | — |

**派工序**：契约 freeze ✅ → 维护者 F-SIGN（`07` §3）→ 签 `HG-STAGE-T-DATA` → api 20/30（含 DDL）→ web 30 → P 轨种子 → 联调。

---

## 4. 风险与非范围

- 禁止跳过 T 直接 W。  
- 禁止无联调闸改 SSE freeze。  
- H β 已 CLOSE；契约已 freeze；T 的子仓 30 等 Fixture 轨签字（见 `07`）。

---

## 5. 相关路径

| 文档 | 路径 |
|------|------|
| **数据前置 Runbook** | `docs/05-plan/07_stage_t_data_prep_runbook_v0_zh.md` |
| 契约 freeze | `docs/contracts/api-v1-tenant-readonly-context-draft.md` |
| workspace 过程 task | `docs/tasks/active/task_stage_t_tenant_contract.md` |
| api / web task 壳 | 见 §3 |
| 简报 | `docs/05-plan/05_post_h_stage_brief_v1_zh.md` |
| 决议 §8 | `../ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` |
| T 核对 Prompt | `docs/harness/invokes/by-task/ops-desk-post-h-stage/PROMPT_ws_00_stage_t_entry_check.md` |

## 修订

| 日期 | 说明 |
|------|------|
| 2026-09-17 | 总 00：冒烟 PASS · H β 开壳后落 T 条件表与数据前置 |
| 2026-09-18 | H β MERGED 纠偏 · 三仓 task 壳落盘 · §3 派工序与双闸 |
| 2026-09-18 | D1/D5 维护者拍板；F1/F2 方案对照落契约 §5；web 验收含 Playwright agent |
| 2026-09-18 | 维护者同意 F1=C；F2/F3 一并钉死；F4 仍欠 |
| 2026-09-18 | 维护者接受 F4 · 契约 freeze · `HG-CONTRACT-FREEZE` 代签；30 仍等 D2–D3 |
| 2026-09-18 | 实扫无 tenant 列 · 增 `07` 双轨 · 开工闸改为 Fixture F-SIGN |
