# 阶段 W 后夜间 backlog（2026-10-30 · 11 项）

> **性质**：backlog 记录文档（非 task · 不派工 · 不改码）。每项含：背景 · 触发条件/进入条件 · 阻塞闸 · 建议帽链 · 证据锚。
> **落盘背景**：阶段 W api/web 双轨 CLOSE、PR #14 合入 main 后，挂起棒与未决风险集中归档，防丢失、防空转。本档只登记；任何一项要启动均须按 Harness 流程另开 task（`10-task` 起草 → 20 审查 → 维护者签闸）。
> **索引**：[`../README.md`](../README.md) 同层 `backlog/README.md`。

---

## B1 · 阶段 W 联调执行棒（挂起中）

- **背景**：`docs/tasks/active/task_stage_w_e2e_join_acceptance.md` 三闸（HG-TASK-DRAFT / HG-AUDIT-R1 / HG-E2E-ENV）已于 2026-10-30 全 approved（维护者授权 00 代录 · 20-R1/R2 审查闭环）。范围 C1–C8（环境就绪 → approve/reject 全链 → 跨租户消费链 fail-closed 实测 → 证据归档），验收 A1–A8。同时承接 web TC9 手测（见 B8）。
- **触发条件/进入条件**：维护者到场，真人执行 C1–C8（本地起 api + web 双栈 · Fixture 数据 · 不触生产）；真人 decide 不可代理（A6 红线 · 禁止脚本化 decide）。
- **阻塞闸**：无新增闸——三闸已 approved；阻塞物是**真人在场**（decide 步骤不可代理）。
- **建议帽链**：00 编排/记录 → 真人执行联调（decide 手动）→ 40 证据自检与验收勾选核对 → 维护者拍板 CLOSE。
- **证据锚**：
  - task 档：`docs/tasks/active/task_stage_w_e2e_join_acceptance.md`（人工闸表 · C1–C8 · A1–A8）
  - 20-R1/R2 审查文：`docs/harness/reviews/task_stage_w_e2e_join_acceptance_audit_R1_20261030.md` · `_R2_20261030.md`
  - 00 授权锚 invoke：`docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261030_00_orchestration.md`（代签授权记录）
  - api 侧已合入：PR [#303](https://github.com/Cyning12/ops-desk-api/pull/303) · merge `09f97f4` · feat `227a482` · CI 4/4 绿

## B2 · N-R2-1 api 缺陷：resume 入口不设租户 ContextVar（**已关账 · 2026-11-04**）

- **状态更新（2026-11-04 · 关账）**：**已修复并复测全绿**——fix task `api-w-hitl-tenant-fix`（api issue #311 → PR #312 task 档 / PR #313 30 改码 merge `7800b2b`）关账归档（api `docs/tasks/done/task_api_w_hitl_tenant_fix.md`）。复测证据：`docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261104_10_c6_retest.md`——B 链消费日志/回执 `f14068d3b77c40f7` tenant=`ops-desk-pilot-b`（旧错标 `d6bd262904544232` 不再复现）、跨租户 resume 403、历史空租户单 409 fail-closed、A 正样本零变化。附带观察 O1（sync invoke 无事件帧致 decide 404 · 预存在 · 非本修复引入）已另立 api issue #315。
- **状态更新（2026-11-03 · 10 验收收尾棒注记）**：**联调已坐实**——2026-11-02 C6 跨租户负样本实测：B 租户拦单 `hitl_b4c35664bc10412fa561` 经 B 身份真人 approve+续跑后，消费日志 `tenant_id=ops-desk-pilot`（应 `-b`）、回执 `d6bd262904544232` 错标，N-R2-1 由「疑似」转「坐实缺陷」（高优先 · 审计失真），证据见 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261102_10_c8_evidence_archive.md` §C6/§2 · 已列 fix task 建议 #1（§7）。**待立 fix task**（走完整闸链：10 起草 → 20 审查 → HG-AUDIT-R1 → 30）。
- **背景**：20-R2 审查发现（N-R2-1）：api `app/ops/hitl/resume.py` 全文无 tenant 引用，resume 入口不设置租户 ContextVar；`app/ops/tenant_context.py:24-26` `current_tenant_or_default()` 在 ContextVar 为 None 时回落默认 `TENANT_A`（`"ops-desk-pilot"`）。~~推论：B 租户自己 approve + resume 的链路，恢复执行时疑似也按 TENANT_A 消费。该疑似尚未经 live 实测，勿先改码。~~（**2026-11-02 联调实测已证实**，见上方状态更新）
- **触发条件/进入条件**：B1 联调执行到 **C3（resume 单路径恢复实测）** 时用 B 租户账号跑 approve → resume 链，观察恢复后 tool_exec 实际消费租户；若证实回落 TENANT_A → 另开 api fix task（走完整闸链：10 起草 → 20 审查 → HG-AUDIT-R1 → 30 改码）。
- **阻塞闸**：无（属实测观察项）；若实测成立则新 fix task 自带全套闸。
- **建议帽链**：B1 联调中真人实测记录证据 → 00 汇总 →（若成立）10 起草 api fix task → 20-R1 审查 → 维护者签闸 → 30。
- **证据锚**：
  - 审查文：`docs/harness/reviews/task_stage_w_e2e_join_acceptance_audit_R2_20261030.md`（N-R2-1 发现）
  - 码面：`../ops-desk-api/app/ops/hitl/resume.py`（无 tenant 引用 · 2026-10-30 grep 亲核）· `../ops-desk-api/app/ops/tenant_context.py:24-26`（`current_tenant_or_default` 回落 TENANT_A）
  - 对照既有口径：decide 端点为 owner-only 闸（`app/ops/hitl/router.py:213-216`），消费侧 fail-closed 在 `app/ops/lg_rag/multi/nodes.py:499-504`

## B3 · 30 未决风险 #2：非编排直调 gateway.invoke/ainvoke 不过 HITL 审批闸

- **背景**：api 受控写 30 invoke 记录的未决风险 #2：直接 `gateway.invoke/ainvoke` 调写能力**只受 Policy 写闸约束，不过 HITL 审批闸**。这是既有设计边界（审批闸在编排层，镜像委派消费门分层纪律），非缺陷；但直调面若需覆盖审批，属阶段 P 平台项。
- **触发条件/进入条件**：出现需要「编排层之外的直接 gateway 调用也受 HITL 审批约束」的真实场景（如开放能力直调入口给第三方/其他通道），再立项评估。
- **阻塞闸**：阶段 P 未开（见 B5）；立项时按 api 流程自带 HG-AUDIT-R1 等闸。
- **建议帽链**：（立项时）10 起草 api 平台项 task → 20 审查 → 维护者签闸 → 30。
- **证据锚**：`../ops-desk-api/docs/harness/invokes/by-task/api-controlled-write-hitl/invoke_20261030_30_implement.md` §未决风险 #2（「如需覆盖属阶段 P 平台项 · task 非范围」）

## B4 · 30 未决风险 #3：write_intent.args_summary 为脱敏摘要，全文参数审计走 span/receipt

- **背景**：`write_intent.args_summary` 是脱敏摘要（secret/token 等键打 `***` · 超长 sha256 截断），审计取完整参数走 span/receipt 既有通道。当前口径满足既有审计需求。
- **触发条件/进入条件**：若审计口径升级要求**全文参数**直接可查（合规/取证场景），需另议方案（全文落库 vs span/receipt 通道扩容 vs 受控解密）。
- **阻塞闸**：无现闸；属需求未至项。
- **建议帽链**：（若触发）10-spec 先明确审计口径需求 → 10 起草 task → 20 审查 → 维护者签闸。
- **证据锚**：`../ops-desk-api/docs/harness/invokes/by-task/api-controlled-write-hitl/invoke_20261030_30_implement.md` §未决风险 #3

## B5 · 阶段 P 平台项缓开（防登记后空转）

- **背景**：阶段序 H→T→W→P 中 P = 面试 B 档平台项：服务化 Registry、本体治理、多 Agent 委派等。其进入条件钉死为「**真出现多团队注册冲突再开**」，当前未达。B3（直调面审批覆盖）亦归 P。
- **触发条件/进入条件**：真出现多团队注册冲突（或多通道直调需审批覆盖等同级平台诉求）。
- **阻塞闸**：进入条件未达 = 实质阻塞；缓开是**维护者口径决定**，登记以防遗忘与空转，不代表欠账。
- **建议帽链**：（触发时）00 评估进入条件 → 10-spec 起草阶段 P SPEC → 20 审查 → 维护者签 HG-SPEC-SIGNOFF。
- **证据锚**：`../ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` §8.1（P 行：「真出现多团队注册冲突再开」）· §修订注记 2026-10-30（W 的 api 侧已完成，P 未开）

## B6 · P 轨真种子（维护者运维轨）

- **背景**：阶段 T 数据前置 Runbook 双轨定义：Fixture 轨（已齐 · 2026-09-18 签 HG-STAGE-T-DATA · 仅授权子仓开 30）与 **Pilot/Prod 种子轨（P 轨 · 生产数据另轨另签 · 迁移上试点/生产后执行）**。HG-E2E-ENV 亦钉死「不触生产 · P 轨另轨另签」。
- **触发条件/进入条件**：迁移已上试点/生产后，由维护者定数据窗口并**亲签 HG-STAGE-T-DATA（P 轨）**（与 Fixture 轨的签同名不同轨，语义为运维授权）。
- **阻塞闸**：HG-STAGE-T-DATA（P 轨）未签——须维护者定夺数据窗口并签。
- **建议帽链**：维护者定窗口 + 签闸 → 00 编排运维执行 → 证据落 invokes/。
- **证据锚**：`docs/05-plan/07_stage_t_data_prep_runbook_v0_zh.md` §4（Pilot/Prod 种子轨清单 · 解联调）· §5（生产联调 CLOSE 另等 §4 P 轨）；Fixture 轨签记录：`docs/tasks/done/task_stage_t_tenant_contract.md` 人工闸表

## B7 · web main ahead 1 未 push（CLOSE commit 200c447 仅本地）

- **背景**：web 仓 `task_web_hitl_approval_page` CLOSE commit `200c447` 仅存在于本地 main（`main...origin/main [ahead 1]`）；web 仓纪律为「全程本地零 push」，故 CLOSE 留痕未上远端。
- **触发条件/进入条件**：维护者定夺是否推送（推则 web main 远端同步；不推则保持本地留痕纪律）。
- **阻塞闸**：无 Harness 闸；决策权在维护者（纪律变更或一次性推送均须维护者拍板）。
- **建议帽链**：维护者定夺 →（若推）00 执行 push 并记录 invoke。
- **证据锚**：web 仓 `git log` 尖 = `200c447 docs(tasks): CLOSE web-hitl-approval-page（…全程本地零 push）`；`git status` = `main...origin/main [ahead 1]`

## B8 · web TC9 手测（/hitl 四态截图 + 语义对照）

- **背景**：web `task_web_hitl_approval_page` 已 CLOSE，但 TC9（手测 + PR 材料）明确挂起：本地起 ops-desk-api + 构造挂起 run，手测 批准 →（required 时）显式续跑 → 「回到会话查看」链路；材料含 `/hitl` 四态截图（列表 / 空 / 403 / 过期错误）、与 HitlApprovalCard 的语义对照表、Harness 闸表截图。回填限 web 文档轨（task 状态不再改 · 补注即可）。
- **触发条件/进入条件**：维护者到场手测（与 B1 联调同一场次可合并执行：B1 C1 起栈后即可顺手跑 TC9）。
- **阻塞闸**：无闸；须真人手测。
- **建议帽链**：真人手测 → 00 回填 web task TC9 勾注（文档轨）→ 证据截图落 web invokes/。
- **证据锚**：`../ops-desk-web/docs/tasks/done/task_web_hitl_approval_page.md`（TC9 行 · 「TC9 待维护者手测回填 · 维护者定夺 2026-10-30」）

## B9 · web 仓文档卫生 sweep（8 条 stale-minor · 0 blocker）

- **背景**：2026-10-30 夜 00 只读巡检 web 仓文档面，发现 8 条 stale-minor（0 blocker），均不阻塞使用但持续腐蚀文档真值：
  1. `volatile.md`「本波 active」滞留 ≥10 个已 CLOSE 条目；`:21` progressive-reveal 误写「30 实现中」；12 处 `active/` 断链指针（task 已迁 `done/`）；
  2. `done/README.md` web 表缺最近 4 笔关账登记（hitl_approval_page / graph_anchor_profile_fix / hitl_approval_overlay_ux / hitl_resume_chase_ux）；
  3. `_views/done.md:14`「进行中 → in_progress.md」断链；
  4. `README.md:17` 页面清单缺 5 个已上线页（LC Evidence / LG RAG / Obs / Capability Catalog / HITL）；
  5. `_tech_graph/l2/indexes/by_path.yaml` 缺 HitlApprovalView.vue / CapabilityCatalogView.vue 两条目；
  6. `CHECKLIST_lg_rag_sse_joint_release_v1.md:5` 双 task 指针断链；
  7. TC9 证据落点写「PR 描述」但 web 全程零 push 未开 PR，落点待重定义；
  8. TC9「构造挂起 run」无配方（可引 web-hitl-decision-surface `invoke_20261017_40_live.md`）。
- **处置口径（00 已定）**：**本仓（workspace）不动 web 文档**；移交 web 仓窗口处置——下一窗口开 `task_web_doc_health_sweep`（纯文档轨）一次性清理 ①–⑥；⑦⑧ 两处 TC9 瑕疵随 TC9 回填棒（B8）同改。
- **触发条件/进入条件**：web 仓开下一文档窗口时立项；⑦⑧ 随 B8（维护者手测 TC9）一并处置。
- **阻塞闸**：无现闸；立项时 web 仓自带闸链（纯文档轨 · 不越仓执行——本仓不改 web 文档）。
- **建议帽链**：web 仓窗口 10 起草 `task_web_doc_health_sweep` → 20 审查 → 维护者签闸 → 30（纯文档）→ 40 核对；⑦⑧ 并入 B8 回填。
- **证据锚**：巡检全证据在 00 侧会话（2026-10-30 夜 · 可索）；受影响文件路径均相对 `../ops-desk-web/`；TC9 配方候选：`../ops-desk-web/docs/harness/invokes/by-task/web-hitl-decision-surface/invoke_20261017_40_live.md`

## B10 · F14：审批页批准后 chat 浮层卡片仍示「待审批」不联动（web UX 状态同步族）

- **背景**：2026-11-03 联调验收收尾复测新发现 F14：审批页批准后，chat 页浮层卡片仍显示「待审批」不联动（渲染历史 `hitl.waiting` 帧快照）· 实证 run `af3fcf63832c4d6dae4a1ecc5065a4e3`。与 F1（已决单无续跑入口 / Chat 浮层渲染 `hitl.waiting` 历史帧快照仍示「待审批」）/ F10（陈旧可点卡片聚合历史帧）**同族 web UI 状态同步缺口**。**处置建议：与 F1/F10/B11（F15）合并立一个 web UX task**（Chat 浮层卡片与 `/hitl/pending` 对账 + 已决态联动 + 时区本地化一并设计），不越仓执行——本仓只登记，fix task 在 web 仓立。
- **触发条件/进入条件**：web 仓开下一 UX 修复窗口时立项（可并入既有 F1/F10 fix 建议 · invoke_20261102 §7 #6）。
- **阻塞闸**：无现闸；立项时 web 仓自带闸链（本仓不改 web 业务码）。
- **建议帽链**：web 仓窗口 10 起草 web UX task（合并 F1/F10/F14/F15）→ 20 审查 → 维护者签闸 → 30（web）→ 40 核对。
- **证据锚**：`docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261103_10_final_acceptance.md` §2 F14（run `af3fcf63832c4d6dae4a1ecc5065a4e3`）· 同族 F1/F10：`invoke_20261102_10_c8_evidence_archive.md` §2（web `src/views/HitlApprovalView.vue:61-85` · Chat 浮层渲染逻辑）

## B11 · F15：审批卡片「创建时间」UTC 未本地化（时区本地化 · UX minor）

- **背景**：2026-11-03 联调验收收尾复测新发现 F15：审批卡片「创建时间」显示 UTC（`2026-11-03T06:51:59+00:00`）未本地化为北京时间 · UX minor。**处置建议：并入 B10 的 web UX task**（时区本地化与浮层状态同步一并在 web 仓设计），不越仓执行——本仓只登记。
- **触发条件/进入条件**：随 B10（web UX task）一并处置；若单独动则为 web 仓纯前端小改。
- **阻塞闸**：无现闸；立项时 web 仓自带闸链（本仓不改 web 业务码）。
- **建议帽链**：并入 B10 帽链（web 仓 10 起草 → 20 审查 → 维护者签闸 → 30 → 40）。
- **证据锚**：`docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261103_10_final_acceptance.md` §2 F15（截图 `a5-expired-row-prompt.jpg` 卡片时间字段可见 UTC 原文）

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-10-30 | 10 帽（文档）落盘：阶段 W 后 8 项 backlog 集中归档（B1 挂起棒 · B2 疑似缺陷待实测 · B3/B4 30 未决风险 · B5 阶段 P 缓开 · B6 P 轨真种子 · B7 web 本地零 push · B8 web TC9）· 每项证据锚亲核（api/web/workspace 三仓码面与文档面）· 纯文档零改码 |
| 2026-10-30 | 10 帽追加 B9（00 移交）：web 仓文档卫生 sweep · 8 条 stale-minor（0 blocker）· 处置口径=本仓不动 web 文档 · 移交 web 仓窗口开 task_web_doc_health_sweep · TC9 两处瑕疵随 B8 同改 |
| 2026-11-03 | 10 帽验收收尾棒追加：**B10（F14 web UX 状态同步族 · 审批后 chat 浮层不联动 · 建议与 F1/F10/F15 合并立 web UX task）**· **B11（F15 审批卡片创建时间 UTC 未本地化 · 建议并入 B10）**；**B2 标注「联调已坐实 · 待立 fix task」**（2026-11-02 C6 实测 N-R2-1 兑现 · 回执 `d6bd262904544232` 错标实证）；头部计数 9→11 项 · 纯文档零改码 |
| 2026-11-04 | **B2 关账**：api fix task `api-w-hitl-tenant-fix` 修复（PR #313 `7800b2b`）+ 复测全绿（invoke_20261104_10_c6_retest · 消费日志/回执 tenant=B · 跨租户 403 · 空租户 409 · A 正样本零变化）→ task 关账迁 done/（api PR #314 回填 + #316 关账）；附带观察 O1（sync invoke 无事件帧致 decide 404）另立 api issue #315 · 纯文档零改码 |
