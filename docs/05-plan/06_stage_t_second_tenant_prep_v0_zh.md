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
| H β（supervisor 预算） | **CLOSE · PR [#141](https://github.com/Cyning12/ops-desk-api/pull/141) MERGED** | api `docs/tasks/done/task_supervisor_budget_h_beta.md` · merge commit `4896701`（2026-10-30 复核一致）· 不阻塞本表契约测绿项 |
| 存在第二租户试点数据（非仅 `ops-desk-pilot`） | **Fixture 轨：是 · 生产 P 轨：否** | Fixture：api `f048c57` 已入 master（迁移 `alembic/versions/20260918_tenant_readonly.py` + 双租户 fixture）；真种子仍走 `07_stage_t_data_prep_runbook_v0_zh.md` §4 P 轨 |
| Principal↔Workspace 产品语义决议 | **本波已钉 · 契约 F1–F6 freeze** | 契约 `api-v1-tenant-readonly-context-draft.md`（F3：`workspace_id` 本波等同 `tenant_id`） |
| 跨租户负样本金样计划 | **负样本测绿 ✅ · eval 金样骨架挂账** | api task T4（A→B 404）· 2026-10-17 web hat40 联调 PASS（web PR #76） |
| 跨仓 task 壳 | **已 CLOSE 归档 `done/`** | api 2026-09-21 归档 · web 2026-10-17 CLOSE（PR #76）· §3 |

### GO / NO-GO（对 T 的 10/30）

**GO 开子仓 30（Fixture / 本地）** · 2026-09-18 维护者 F-SIGN。  
**生产 B 种子**：仍走 `07` §4 P 轨，不挡本地。  
**契约**：`HG-CONTRACT-FREEZE` ✅。

> **2026-10-30 复核**：Fixture/本地轨 30 已执行完毕并双双 CLOSE（api `done/` 09-21 · web `done/` 10-17 PR #76）；**生产 P 轨（迁移后真种子）仍 NO-GO**，其最小开工条 = D1+D2+D3 真种子齐（`07` §4），不随本表自动解闸。

---

## 2. 第二租户数据前置清单

目标：至少两个互不可见的只读租户语料/工单切片，供负样本与下推断言。

| ID | 前置项 | Owner 建议 | 状态 |
|----|--------|------------|------|
| D1 | 钉死租户 id 命名：`ops-desk-pilot`（A）+ `ops-desk-pilot-b`（B） | 维护者 | ✅ **2026-09-18** |
| D2 | B 的 Issue/PR（须先有 tenant 列） | api · 见 `07` 双轨 | ✅ **Fixture 轨**（2026-09-18 · 迁移 `20260918_tenant_readonly` + 双租户 fixture · api `f048c57` 入 master）；⏳ P 轨真种子另轨（`07` §4） |
| D3 | RAG chunk / Qdrant 带租户 | api · 见 `07` | ✅ **Fixture 轨**（RAG metadata 过滤 · 同 `f048c57`）；⏳ 生产 Qdrant 真种子另轨 |
| D4 | 负样本：A 查 B → 404/空 | api eval / 30 | ✅ api T4 负样本测绿（A→B 对外 404）· 2026-10-17 web hat40 联调 PASS（PR #76） |
| D5 | web 切换 UI + Playwright agent | 产品 | ✅ **本波必做**（2026-09-18）· 2026-10-17 CLOSE（PR #76） |

**最小可开工 30**：D1 ✅ + 维护者 **Fixture 轨 F-SIGN**（`07` §3）→ 签 `HG-STAGE-T-DATA`（已于 2026-09-18 approved，Fixture 轨 30 已跑完并 CLOSE）。  
**生产 P 轨仍 NO-GO**：最小开工条 = D1+D2+D3 **真种子**齐（`07` §4 迁移后真种子），另轨另签。

---

## 3. 跨仓拆分（task 壳已落 · 数据齐后再派 30）

> 2026-10-30 复核：Fixture 轨派工已按本表走完，api/web task 均已 CLOSE 并迁 `done/`；下表指针已改指 `done/` 实态路径。

| 仓 | task 文件 · slug | 依赖 | 30 |
|----|------------------|------|-----|
| workspace | [`docs/tasks/done/task_stage_t_tenant_contract.md`](../tasks/done/task_stage_t_tenant_contract.md) · `stage-t-tenant-contract` | D1 命名 · 契约定稿 | **CLOSE**（过程轨 · 2026-10-30 归档 `done/` · commit e651dfc） |
| api | [`../ops-desk-api/docs/tasks/done/task_tenant_readonly_predicate.md`](../../ops-desk-api/docs/tasks/done/task_tenant_readonly_predicate.md) · `tenant-readonly-predicate` | 契约 freeze ✅ · Fixture 轨 F-SIGN ✅ | **CLOSE**（Fixture 轨 30 完成 · `f048c57` 入 master · 2026-09-21 归档 `done/`） |
| web | [`../ops-desk-web/docs/tasks/done/task_web_tenant_context_chat.md`](../../ops-desk-web/docs/tasks/done/task_web_tenant_context_chat.md) · `web-tenant-context-chat` | 同上 · D5 含切换 UI | **CLOSE**（2026-10-17 · PR #76 · hat40 跨租户负样本联调 PASS） |
| ios | 非本波 | — | — |

**派工序**：契约 freeze ✅ → 维护者 F-SIGN（`07` §3）→ 签 `HG-STAGE-T-DATA` → api 20/30（含 DDL）→ web 30 → P 轨种子 → 联调。
（2026-10-30 复核：Fixture/本地轨与联调已按此序走完；剩余仅 `07` §4 P 轨真种子，另轨。）

---

## 4. 风险与非范围

- 禁止跳过 T 直接 W。  
- 禁止无联调闸改 SSE freeze。  
- H β 已 CLOSE；契约已 freeze；T 子仓 Fixture 轨 30 已 CLOSE（api/web `done/`）；生产 P 轨真种子仍另轨（见 `07` §4）。

---

## 5. 相关路径

| 文档 | 路径 |
|------|------|
| **数据前置 Runbook** | `docs/05-plan/07_stage_t_data_prep_runbook_v0_zh.md` |
| 契约 freeze | `docs/contracts/api-v1-tenant-readonly-context-draft.md` |
| workspace 过程 task | `docs/tasks/done/task_stage_t_tenant_contract.md`（已 CLOSE） |
| api / web task 壳 | 见 §3（已迁 `done/`） |
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
| 2026-10-30 | 10 复核纠偏至磁盘实态：D2–D4 Fixture 轨勾选（api `f048c57` 入 master · web PR #76 CLOSE）· §3 壳指针迁 `done/` · 生产 P 轨 NO-GO 语义保留 |
| 2026-10-30 | workspace 过程 task CLOSE 归档 `done/`（commit e651dfc）· §3/§5 指针随迁 · active README 清空 |
