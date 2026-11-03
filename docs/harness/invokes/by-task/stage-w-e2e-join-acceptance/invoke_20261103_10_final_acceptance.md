# Invoke · 10 帽 · 终验收尾（stage-w-e2e-join-acceptance）

| 字段 | 值 |
|------|-----|
| **帽** | `10`（task/文档 · 验收收尾棒 · 纯文档轨零业务码） |
| **时间** | 2026-11-03（复测窗口 06:47–06:57 UTC ≈ 14:47–14:57 Asia/Shanghai） |
| **task** | `docs/tasks/active/task_stage_w_e2e_join_acceptance.md`（三闸 approved · 过程轨） |
| **修复前置** | **复测由 PR [#307](https://github.com/Cyning12/ops-desk-api/pull/307)（api · merge `3168b3b` · 2026-11-03 01:08 UTC · `task_api_w_join_gap_fix` W-fix-1 TTL 过期出口 + W-fix-2 只读面租户谓词）/ PR [#85](https://github.com/Cyning12/ops-desk-web/pull/85)（web）合入后实证** |
| **环境** | 本地双栈（api `uvicorn :8000` + web `vite :5173` + PG/Qdrant 容器）· Fixture 轨双租户（`ops-desk-pilot` / `ops-desk-pilot-b`）· api 以 `OPS_HITL_APPROVAL_CONSUMPTION_TTL_SECONDS=90` 运行（A5 复现口径）· **不触生产**（HG-E2E-ENV 口径） |
| **截图资产** | api 仓 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/screenshots/`（新增 2 张 · 见 §A4/§A5） |

> **A6 合规声明（前置）**：本棒复测中 decide（批准 06:52:36Z）为维护者真人手操；`hitl_990479d004ad4b7a99fa` 的 curl resume 为续跑（非 decide），不构成脚本化审批。A6 红线未违。

---

## §A4② · 跨租户只读面复测 PASS（F13 修复实证）

- **复测步骤**：web 右上角租户下拉切 `ops-desk-pilot-b`（B 身份）→ Pulls 页
- **实测结果**：Pulls 页显示「暂无 Pull Requests」**空列表** ✅——B 租户不再泄漏 A 租户（`ops-desk-pilot`）数据
- **截图**：`a4-2-cross-tenant-pulls-empty.jpg`（api 仓 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/screenshots/`）
- **修复锚**：api `task_api_w_join_gap_fix` W-fix-2（只读资源面接租户谓词）· PR #307 合入 api master（merge `3168b3b`）——原缺陷 F13（`app/ops/issues.py:29` 等无 tenant 谓词 · invoke_20261102 §2 F13）已修复实证
- **判定**：A4② 契约达成（只读面空集/404 口径）→ **A4② 勾销**；① 消费链 live 实测（守卫真空坐实=N-R2-1+F3 缺陷发现）与 ③ 头/session 403 PASS 此前已完成（invoke_20261102 §C6 补测）→ **A4 整项全勾**

## §A5 · 过期态全链复测 PASS（F12 修复后可达实证）

- **单据**：`hitl_a285ff2ff195429ea8ab`（run `ab48acb3fa88…` · thread `7bf4896417f6` · `blocked_by=delegation_issue_hitl_required`）
- **时间链（UTC）**：
  - 2026-11-03 **06:51:59Z** 创建（拦单落库）
  - 2026-11-03 **06:52:36Z** 批准（decide=**维护者真人** · admin · 手动续跑链）
  - 等约 5 分钟后用户点「续跑」→ api 返回 **409**，detail 原文：「approval_expired：批准已超执行权 TTL（90s）过期，单据已置 expired 终态；请重新发起审批」
  - **DB 实证**：`ops_hitl_requests.status` `approved→expired`（updated **06:57:21Z**）
- **web 实证**：列表行级红字「审批已过期，请刷新列表」**渲染成功** ✅——web FP-5 过期态自 F12 修复后首次可达
- **截图**：`a5-expired-row-prompt.jpg`（同目录）
- **前序实证**：单据 `hitl_990479d004ad4b7a99fa` 经 curl resume 同样 409→expired（2026-11-03 **06:47:52Z**）——resume 链过期闸双侧（UI / API 直调）一致
- **修复锚**：api `task_api_w_join_gap_fix` W-fix-1（TTL 过期出口 · `STATUS_EXPIRED` 赋值链）· PR #307；web 侧过期态渲染 PR #85
- **判定**：TC9 四态（列表 / 空 / 403 / 过期）截图齐 → **A5 勾销**

---

## §2 追加 · 新发现 F14 / F15（如实记录 · 不在本 task 修 · A7 合规）

| # | 现象 | 定位 | 严重度 | 去向 |
|---|------|------|--------|------|
| F14 | 审批页批准后，chat 页浮层卡片仍显示「待审批」不联动（渲染历史 `hitl.waiting` 帧快照）——与 F1/F10 同族 **web UI 状态同步缺口** | 实证 run `af3fcf63832c4d6dae4a1ecc5065a4e3`；web Chat 浮层渲染历史帧快照（同 F1/F10 族 · invoke_20261102 §2） | ux | web fix task（建议与 F1/F10/F15 合并为 web UX task · 见 backlog） |
| F15 | 审批卡片「创建时间」显示 UTC（`2026-11-03T06:51:59+00:00`）未本地化为北京时间 | web 审批卡片时间渲染 | ux minor | 同上（建议合并 web UX task） |

> F14/F15 均**不阻塞**本 task 验收勾销（A4②/A5 实证独立成立）；按 A7 已在 workspace backlog（`docs/tasks/backlog/backlog_20261030_post_stage_w.md` B10/B11）登记，不在本 task diff 修任何业务码。

---

## §3 · 指针与遗留

- **修复实证指针**：复测全部基于 PR #307（api）/ PR #85（web）**合入后**环境；PR #307 merge commit `3168b3b`（2026-11-03 01:08 UTC）。
- **验收终态**：A1–A8 **全勾**（A4②/A5 本次勾销 · 详见 task 档验收表）；C1–C8 全勾（此前）。
- **40 自检棒**：`required_invoke_hats=10,00,40`；本棒为 10 收尾归档，40 证据自检与勾选核对按 orchestration 链待派。
- **CLOSE 归维护者**：本棒不动 task status 字段、不做 done/ 归档；task 档已更新为「验收全勾 · 待维护者 CLOSE」。
- wiki_delta（CLOSE 时）：`docs/05-plan/05_post_h_stage_brief_v1_zh.md` 阶段 W 行补「双轨联调验收已 CLOSE · 证据锚」。

---

### 修订

| 日期 | 说明 |
|------|------|
| 2026-11-03 | 10 帽验收收尾棒：A4②（F13 修复 · B 租户 Pulls 空集 · 截图 `a4-2-cross-tenant-pulls-empty.jpg`）/ A5（F12 修复 · TTL 90s 短窗 · `hitl_a285ff2ff195429ea8ab` 409 `approval_expired` → DB `approved→expired` 06:57:21Z · web 行级红字 · 截图 `a5-expired-row-prompt.jpg`；前序 `hitl_990479d004ad4b7a99fa` curl 409→expired 06:47:52Z）证据链 · 新发现 F14/F15 如实记录 · PR #307（api）/#85（web）合入后实证指针 |
