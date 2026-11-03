# Invoke · 10 帽 · CLOSE 归档（stage-w-e2e-join-acceptance）

| 字段 | 值 |
|------|-----|
| **帽** | `10`（task/文档 · CLOSE 归档棒 · 纯文档轨零业务码） |
| **时间** | 2026-11-03 |
| **task** | `docs/tasks/done/task_stage_w_e2e_join_acceptance.md`（CLOSE 归档后路径 · 三闸 approved 终态） |
| **分支** | `docs/e2e-close-archive`（base：`main`） |
| **CLOSE 决策** | **维护者 2026-11-03 拍板 CLOSE**（授权在案 · 10 承接执行）——对齐阶段 T CLOSE 先例（commit `808e817`） |
| **证据锚** | `invoke_20261102_10_c8_evidence_archive.md`（C1–C8 联调全证据）+ `invoke_20261103_10_final_acceptance.md`（A4②/A5 复测勾销 · F14/F15 追加） |

---

## §1 · CLOSE 决策记录

- **拍板**：维护者 2026-11-03 拍板 CLOSE（验收 A1–A8 全勾后 · 授权在案）。
- **前置已齐**：
  - 三闸 approved（HG-TASK-DRAFT 维护者签收 · HG-AUDIT-R1 / HG-E2E-ENV 维护者授权 00 代录 · 2026-10-30 · 闸表 status 终态不动）；
  - 20-R1 / 20-R2 闭环（审查文 `docs/harness/reviews/task_stage_w_e2e_join_acceptance_audit_R1_20261030.md` + `_R2_20261030.md`）；
  - CLOSE 阻塞注记（2026-11-02 维护者裁决）两项解阻条件均达成：F12/F13 由 api `task_api_w_join_gap_fix`（PR [#307](https://github.com/Cyning12/ops-desk-api/pull/307) · merge `3168b3b` · 2026-11-03 01:08 UTC）修复，A4②/A5 复测实证勾销（web 侧 PR [#85](https://github.com/Cyning12/ops-desk-web/pull/85)）；
  - **40 自检 PASS-WITH-NITS · NIT-1 闭环**：NIT 三处微修（commit `b0b99b8` · §C7 截图资产分支说明 / §C5 receipt_id 点明 / F8 锚点修正）；NIT-1（C7 过期态括注「不可达 F12」→「已复现 · F12 经 PR #307/#85 修复可达」）由 commit `b8605c7` 闭环，随 workspace PR [#21](https://github.com/Cyning12/ops-desk-workspace/pull/21) 合入 main；api 侧终验截图资产 PR [#310](https://github.com/Cyning12/ops-desk-api/pull/310) MERGED 2026-11-03 07:23 UTC。

## §2 · 归档动作清单（本棒执行）

1. `git mv docs/tasks/active/task_stage_w_e2e_join_acceptance.md docs/tasks/done/`（rename 保历史）。
2. task 文内状态迁移：
   - 头部状态行 `active` → `done`（「CLOSED 2026-11-03 维护者拍板 · 三闸 approved · 20-R1/R2 闭环 · 验收 A1–A8 全勾 · 证据 invoke_20261102_10_c8_evidence_archive + invoke_20261103_10_final_acceptance」）；
   - 自检结论表：lint 路径随迁 `done/`（PASS 行补「2026-11-03 · CLOSE 归档棒路径随迁复跑 PASS」）；结论改 CLOSE 终态；
   - A8 lint 路径随迁 `done/`；
   - 修订记录 +1 行（CLOSE 归档棒 · 40 自检 PASS-WITH-NITS NIT-1 闭环 · PR #21/#310 合入回执 · 闸表 status 未动）。
3. 活指针随迁（§3）。
4. 本 invoke 落盘（CLOSE 决策与处置真值）。
5. `npx spec-wave task lint --file docs/tasks/done/task_stage_w_e2e_join_acceptance.md` 复跑 **PASS** 后 commit → push → PR（base main）。

**红线复核**：零业务码（diff 仅 workspace 文档/证据路径）· 闸表 status 未动 · 历史 invoke/审查文（invoke_20261030_00 / invoke_20261030_10_task_draft / invoke_20261102_c8 / invoke_20261103_final / 20-R1/R2 审查文）内文与 `active/` 路径原样不动（历史如实原则）。

## §3 · 指针处置清单

| 指针 | 处置 |
|------|------|
| `docs/tasks/active/README.md` | **活指针随迁**：active 表清空，留「当前无 active task · 已于 2026-11-03 CLOSE 迁 `../done/task_stage_w_e2e_join_acceptance.md`」（对齐阶段 T 先例） |
| `docs/05-plan/05_post_h_stage_brief_v1_zh.md` §1「阶段 T / W / P」行 | **活指针随迁**：「双轨端到端联调验收 task 在途（active/ · PR #14 · HG-TASK-DRAFT approved）」→「已 CLOSE（2026-11-03 维护者拍板 · 验收 A1–A8 全勾 · done/ · 证据锚 invokes/）」；修订表 +1 行（落实 task `wiki_delta` 约定：CLOSE 时在 05 简报阶段 W 行补「已 CLOSE · 证据锚」） |
| `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261030_*.md` / `invoke_20261102_*.md` / `invoke_20261103_10_final_acceptance.md` | **历史记录不动**：内文 `active/` 路径与「待 CLOSE」表述保持原样（历史如实原则） |
| `docs/harness/reviews/task_stage_w_e2e_join_acceptance_audit_R1_20261030.md` / `_R2_20261030.md` | **历史记录不动**：同上 |
| 子仓指针（api/web task 档、契约、06/07 计划文） | 扫描无指向本 task `active/` 路径的活指针（全仓 grep `task_stage_w_e2e_join_acceptance` / `active/task_stage_w` 仅命中上述两处活指针 + 历史 invoke/审查文）· 无需处置 |

## §4 · 最终验收快照（A1–A8 · 全勾终态）

| 验收 | 终态 | 证据锚 |
|------|------|--------|
| **A1 · approve 全链** | ✅ | invoke_20261102 §C1–§C3（run `f9453b7f…` · 单据 `hitl_ef414f4a2b464bd69bbb` · seq15-25 全链 · 回执 `98d28309f55f4f58`）· 截图 `c7-resumed.jpg` / `tc9-list-approved.jpg`（api 仓 screenshots/） |
| **A2 · reject 路径** | ✅ | invoke_20261102 §C4（run `03d500d2…` · 三单全 rejected · 零回执 fail-closed · 驳回答复落帧） |
| **A3 · 审计链可串** | ✅（有限制） | invoke_20261102 §C5（`approval_id` 串 decide→resume→`capability_write_approval_consumed`→回执；span 级不可验 F5 langfuse OTLP 403 如实标注） |
| **A4 · 跨租户负样本** | ✅ | ① 消费链 live 实测（守卫真空坐实=N-R2-1+F3 缺陷发现 · invoke_20261102 §C6）② F4 只读面空集复测 **PASS**（F13 修复 PR #307 W-fix-2 · 截图 `a4-2-cross-tenant-pulls-empty.jpg` · invoke_20261103 §A4）③ 头/session 403 **PASS**（`tenant_header_mismatch` · api `router.py:376-384`） |
| **A5 · TC9 回填** | ✅ | invoke_20261103 §A5（F12 修复 PR #307 W-fix-1 后 TTL 90s 短窗复现 · `hitl_a285ff2ff195429ea8ab` 409 `approval_expired` → DB `approved→expired` 06:57:21Z · web 行级红字渲染 PR #85 · 截图 `a5-expired-row-prompt.jpg`）· 四态截图齐 · web task 文档轨回填 |
| **A6 · 真人 decide** | ✅ | invoke §6（decide ×7 全维护者真人 · 时间戳列明 · resume 非 decide · 00 curl 补位一次已备案 · auto_resume 未触发） |
| **A7 · 缺陷处置合规** | ✅ | 发现 F1–F15 + N-R2-1 全数落 invoke §2 清单 · fix task 建议 ×10（独立 task 起草属后续棒）· 本 task diff 仅 workspace 文档/证据路径（api PR #310 纯截图资产 · web PR 纯 task 文档轨 · 零业务码） |
| **A8 · 闸与 lint** | ✅ | 三闸 approved（闸表为准 · 终态）· lint 路径随迁 done/ 复跑 **PASS**（2026-11-03 CLOSE 归档棒） |

## §5 · 遗留与后续（非本 task 范围 · 如实移交）

- **fix task 建议 ×10**（invoke_20261102 §7 清单 · 含 N-R2-1 守卫真空 = 消费侧租户守卫 / delegation 守卫真空 F3 / F13 已修待回归断言 等）：独立 task 起草属后续棒，**不**阻塞本 CLOSE（A7 合规 = 缺陷均已落清单并互链建议，本 task 不修码）。
- **F14 / F15**（2026-11-03 复测期新发现 · 已追加 backlog）：F14 审批页批准后 chat 浮层卡片状态不联动（F1/F10 同族 UI 状态同步缺口）· F15 审批卡片创建时间 UTC 未本地化（UX minor）——后续 fix task 候选。
- **P 轨**：未开（进入条件未达 · 05 简报阶段行已如实标注）；F13 类只读面租户谓词为 P 轨 canary 前置项。
