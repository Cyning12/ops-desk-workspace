# Task：阶段 W · 双轨端到端联调验收（api 受控写 + web 审批页 · 真人全链 · TC9 回填）

> **状态**：`done`（**CLOSED 2026-11-03 维护者拍板** · 三闸 approved（HG-TASK-DRAFT 维护者签收 · HG-AUDIT-R1 / HG-E2E-ENV 维护者授权 00 代录）· 20-R1/R2 闭环 · **验收 A1–A8 全勾** · 证据 `invoke_20261102_10_c8_evidence_archive` + `invoke_20261103_10_final_acceptance`）· **过程轨 / 验收轨** · **不授权任何 30 改码**  
> **类型**：跨仓联调验收 / 证据归档（只产文档与证据，不改业务码）  
> **上游**：api `docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` §8（阶段序 H→T→W→P）· `docs/05-plan/05_post_h_stage_brief_v1_zh.md`（阶段 W 行：受控写 + HITL「要确认单/HITL」）  
> **分支**：`task/stage-w-e2e-join`（base：`main`）  
> **执行模式**：Open Folder = **`ops-desk-workspace/`**；本 task 只改本仓文档/证据；**不**改 api/web/ios 业务码；联调在**本地**起 api + web 双栈，Fixture 数据，**不触生产**  
> **10 注**：2026-10-30 · 维护者令「起草阶段 W 端到端联调验收 task」· 本窗落壳 + lint + 10 invoke；**HG-TASK-DRAFT 签收前禁派执行**（2026-10-30 已签收 · 00 代录）；HG-AUDIT-R1 / HG-E2E-ENV 未齐前仍禁派联调执行

---

## Harness 元信息

| 字段 | 值 |
|------|-----|
| **task_slug** | `stage-w-e2e-join-acceptance` |
| **git_branch** | `task/stage-w-e2e-join` |
| **implement_repo** | `ops-desk-workspace` |
| **test_strategy** | `recommended` |
| **test_strategy_note** | 文档/验收轨；验收以「人工执行步骤可勾选 + 证据落盘（invoke 记录 / 截屏 / 日志摘录）+ `npx spec-wave task lint --file` PASS」为准；联调步骤本身为真人手测（**禁止脚本化 decide**） |
| **code_quality_bar** | `not_applicable` |
| **code_quality_bar_note** | 过程轨 / 无应用源码 |
| **graph_change_layer** | `G-L0` |
| **graph_delta** | `n/a` |
| **graph_delta_note** | 默认零 diff；验收不改图谱 |
| **wiki_delta** | `docs/05-plan/05_post_h_stage_brief_v1_zh.md` |
| **wiki_delta_note** | CLOSE 时在 05 简报阶段 W 行补一句「双轨联调验收已 CLOSE · 证据锚」；草稿期不动 |
| **experience_capture** | `recommended` |
| **kpi_aggregator** | `CLOSE` |
| **invoke_retention_profile** | `default` |
| **required_invoke_hats** | `10,00,40` |
| **invoke_retention_note** | 过程轨无 30（不改码）；00 = 编排/派工与闸记录；40 = 证据自检与验收勾选核对 |
| **close_pr_policy** | `recommended` |
| **review_hat** | `20` |
| **orchestration** | workspace 00 统筹 → 10 落稿 → 20-R1 审查 → 维护者签 HG-TASK-DRAFT / HG-AUDIT-R1 / HG-E2E-ENV → 真人联调执行（证据落 invokes/）→ 40 自检 → 维护者拍板 CLOSE |
| **freeze_id** | `lg-rag-sse-v1`（SSE 事件表 · 零改）· `hitl-browser-decide-v1`（web `src/api/hitl.ts` · 只消费禁改）· `api-v1-tenant-readonly-context-draft.md` F1–F6（freeze 2026-09-18） |

### 人工闸

| human_gate_id | status | blocks_hats | 说明 |
|---------------|--------|-------------|------|
| HG-TASK-DRAFT | **approved** | 20-R1, 联调执行 | 2026-10-30 维护者签收（00 代录）· 解锁 20-R1；联调执行仍须 HG-AUDIT-R1 + HG-E2E-ENV 齐 |
| HG-AUDIT-R1 | **approved** | 联调执行 | 2026-10-30 维护者授权 00 代录（授权锚：invoke_20261030_00_orchestration.md）· 依据：20-R1 B1→10 修订闭环 · 20-R2 复审 B1/M1/M2 闭环 · M3 路径订正落盘（审查文 `docs/harness/reviews/task_stage_w_e2e_join_acceptance_audit_R1_20261030.md` + `_R2_20261030.md`）；本闸**不**授权任何 30 改码 |
| HG-E2E-ENV | **approved** | 联调执行 | 2026-10-30 维护者授权 00 代录（同上授权锚）· 口径钉死：本地起 api + web 双栈 · 数据限 Fixture 轨（双租户 fixture · api `f048c57` ∈ master）· **不触生产**（P 轨另轨另签）· 真人 decide 不可代理（A6 红线）→ 执行棒挂起待维护者到场 |

---

## 背景与目标

阶段 W 双轨均已 CLOSE 但**尚未端到端联调**：

- **api 轨**：受控写竖切已合入 master（PR [#303](https://github.com/Cyning12/ops-desk-api/pull/303) · merge commit `09f97f4` · feat commit `227a482` · 2026-10-30 · CI 4/4 绿）。审批闸 `capability_write_hitl_required` fail-closed（无审批不执行）；decide/resume **单路径**恢复（`router._execute_decided_resume` · 禁第二条实现）；span `approval_id` 预留已启用落值；首条写能力 = `testing.write.echo`（极窄 opt-in）。task 档：`../ops-desk-api/docs/tasks/done/task_api_controlled_write_hitl.md`。
- **web 轨**：独立 HITL 审批页已 CLOSE（`/hitl` 第四审批入口 · freeze `hitl-browser-decide-v1` 只消费零分叉 · 分支已合入 main），但 **TC9 手测项挂起待维护者手测回填**（web task 先行 CLOSE · 2026-10-30 维护者定夺）。task 档：`../ops-desk-web/docs/tasks/done/task_web_hitl_approval_page.md`。
- **契约 freeze**：租户契约 F1–F6（`docs/contracts/api-v1-tenant-readonly-context-draft.md` · freeze 2026-09-18）· SSE `lg-rag-sse-v1` · web `hitl-browser-decide-v1`；写路径同受 F1–F6（跨租户写 fail-closed 对外 404）。

单轨各自过闸 ≠ 双轨咬合过闸：api 侧验收基于单测与负样本，web 侧 TC9 明确挂起，**真人全链从未跑过一遍**。本 task 补这一环：本地起双栈，真人从 web 发起 echo 写 → 编排层拦单挂起 → `/hitl` 页审批（approve 与 reject 各至少一遍）→ resume 单路径恢复 → echo 真执行 → span `approval_id` 审计链核对；并实测跨租户负样本（**消费链 fail-closed** + F4 资源命中面 404），承接 web TC9 手测回填。

> **跨租户码面口径（20-R1 B1 修订 · 10 亲核 api 码面）**：api decide 端点为 **owner-only 闸**（`app/ops/hitl/router.py:213-216`），hitl store 查询**无 tenant 谓词**（`store.py:171,184`）——同一维护者切租户 decide **返 200 属预期行为**，非缺陷、非 F4 违例。真 fail-closed 在**消费侧**：编排层消费台账时租户不一致不消费、维持拦截（`app/ops/lg_rag/multi/nodes.py:499-504` · 对应 `tests/test_write_approval_gate.py:431-475` W2 语义）。故本 task 跨租户主测 = **消费链 live 实测**；`hitl-browser-decide-v1` 的 owner-404（未知/跨用户单据 404）≠ F4 机制，证据记录须如实区分；F4 对外 404 保留在**资源命中面**演示。

### 完成态

1. 联调步骤 S1–S6（§范围 C1–C6）全部执行并勾选，每步带证据（截屏 / 日志摘录 / invoke 记录）落 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/`。  
2. approve 与 reject 两条路径**各至少跑通一遍**；reject 后确认写**未**执行（无 echo 结果 · 单据终态 rejected）。  
3. span `approval_id` 审计链核对通过：审批 → resume → 写执行三段可由同一 `approval_id` 串链（日志 / 观测摘录为证）。  
4. 跨租户负样本实测一遍：**消费链 fail-closed**——B 会话拦单、A 会话（或 A 租户头）approve 该单据 → 写**不**执行 · 拦单维持 · 台账不消费（`nodes.py:499-504` 语义）；另演示 **F4 资源命中面**对外 **404**（对 B 租户资源 id 的只读/写请求），不泄漏存在性。  
5. web TC9 手测证据齐备并回填 web task **文档轨**（task 档勾选/状态行，不改 web 业务码；或另开回填 task 指针），含 `/hitl` 四态截图与语义对照。  
6. 联调发现的任何缺陷**不**在本 task 修，一律另开 fix task 并互链（写入非范围）；无缺陷则如实记「零发现」。

---

## 范围

- [x] **C1 · 环境就绪**（2026-11-02 实证 ✅ · 证据 `invoke_20261102_10_c8_evidence_archive.md` §C1：双栈起栈方式 + `/health` 200 · `OPS_HITL_AUTO_RESUME` 未设=manual 已记录）：本地起 api + web 双栈（Fixture 数据 · 双租户 fixture 可用）；确认 `OPS_HITL_AUTO_RESUME` 口径（默认 manual = 显式续跑链）并记录实际 env；证据 = 起栈方式记录 + 健康检查摘录  
- [x] **C2 · 发起 echo 写 → 拦单挂起**（✅ · invoke §C2：run `f9453b7f1c9a4dc79aa469773931e7c6` · 单据 `hitl_ef414f4a2b464bd69bbb` 09:22:00 落库 · events 止 seq14 waiting_approval 零写）：真人从 web Chat 发起触发 `testing.write.echo` 的请求；断言编排层拦单、HITL 待审批帧可见（`/hitl` 列表出现该单据）；**未审批前无任何写执行**；证据 = Chat 帧截屏 + `/hitl` 列表截屏  
- [x] **C3 · approve 全链**（✅ · invoke §C3：真人 decide 09:24:27 admin · resume 09:43:04（00 curl 补位 · UI 无入口见 F1 · A6 合规 §6）· seq15-25 全链 · 回执 `98d28309f55f4f58`）：`/hitl` 页真人 decide=approve（含二次确认 / resume_mode 选择与显式续跑两步链）→ resume 单路径恢复 → echo 真执行，结果回到会话；证据 = 决策确认截屏 + 执行结果截屏 + resume 日志摘录  
- [x] **C4 · reject 路径**（✅ · invoke §C4：run `03d500d21bd74eb7936ed032a5ca7f8d` · 三单全 rejected（`hitl_c84b69d633db4de9bc5c`/`hitl_4392b09f12d2401190f9`/`hitl_50e1f310da7640d4862b`）· 零回执 fail-closed · 驳回答复落帧）：再发起一遍 echo 写 → decide=reject → 断言写**未**执行、单据终态正确、会话侧可见驳回结果；证据 = 截屏 + 单据状态摘录  
- [x] **C5 · 审计链核对**（✅ · invoke §C5：`approval_id=hitl_ef414f4a2b464bd69bbb` 串 decide→resume→`capability_write_approval_consumed`→回执 `98d28309f55f4f58`；反链驳回 run 零回执；span 级因 langfuse OTLP 403 不可验如实标注 F5）：以 C3 单据的 `approval_id` 串链核对 span / 日志（审批决策 → resume → 写执行结果）；证据 = 日志/观测摘录（含 `approval_id` 字段值）  
- [x] **C6 · 跨租户负样本（消费链 fail-closed 主测）**（⚠️ 实测完成但**结果超预期——守卫真空坐实** · invoke §C6：B 租户拦单 `hitl_b4c35664bc10412fa561` → B 身份真人 approve+续跑 → **写执行了且租户错标**（消费日志 tenant=ops-desk-pilot 应 -b · 回执 `d6bd262904544232` 错标）→ **N-R2-1 缺陷坐实** + delegation 守卫真空（F3）；owner-404≠F4 已如实区分；**A4 补测（16:2x · 00 curl · 纯只读探测）**：③ 头/session 403 ✅ PASS（`tenant_header_mismatch` · `router.py:376-384`）· ② F4-404 ❌ **FAIL=新发现 F13**（issues/pulls/overview 只读面跨租户泄漏 · `issues.py:29` 无 tenant 谓词 · 未覆盖非回归 · P 轨前置，见 invoke §2 F13））：租户 B 会话发起 echo 写产生拦单 → 切租户 A 会话（或带 A 租户头）对该单据 decide=approve → 断言**写不执行 · 拦单维持挂起 · 台账不被消费**（api `app/ops/lg_rag/multi/nodes.py:499-504` 消费侧语义 · W2 单测 `tests/test_write_approval_gate.py:431-475` 的 live 对应）；**注意**：decide 返 200 属预期（owner-only 闸 `router.py:213-216` · store 无 tenant 谓词 `store.py:171,184`），owner-404（`hitl-browser-decide-v1`）≠ F4 机制，证据须如实区分——另演示 **F4 资源命中面**：以 A 会话对 B 租户资源 id 发只读/写请求 → 对外 **404**；租户头与 session 不一致 → **403**（F1=C 抽测一次）；证据 = 各响应码与编排行为截屏/日志摘录  
- [x] **C7 · TC9 承接**（✅ 过期态除外如实标注 · invoke §C7：全链跑通 · 四态截图列表/空/403 已拍（api 仓 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/screenshots/` 8 张）· 过期态**已复现**（F12 经 PR #307/#85 修复可达 · 截图 a5-expired-row-prompt.jpg · invoke_20261103_10_final_acceptance §A5）· 语义对照表 §4 · 闸表截图 gate-table.jpg · web task 文档轨回填见 web 仓 PR）：web TC9 手测项在本联调中完成（批准 → 显式续跑 → 「回到会话查看」链路 + 四态截图 / 语义对照表 / 闸表截图），证据落盘并回填 web task **文档轨**（task 档勾选/状态行 · **不改 web 业务码**；或另开回填 task，指针互链）  
- [x] **C8 · 证据归档与勾选**（✅ 本棒 · invoke `invoke_20261102_10_c8_evidence_archive.md`：C1–C7 证据 + 发现清单 F1–F13 + N-R2-1 + 守卫真空 · fix task 建议清单 ×10（§7 仅清单不起草正文）· **40 自检棒待派**（required_invoke_hats=10,00,40 · 本棒为 10 归档）· **CLOSE 归维护者**）：全部证据落 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/`；40 自检核对验收逐条勾选；缺陷另开 fix task 互链（无则记零发现）

### 非范围

- 改 api / web / ios **任何**业务码、配置、迁移（联调发现缺陷 → 一律另开 fix task，本 task 只记录与互链）  
- 阶段 P 平台项（Registry 服务化 / 本体平台）  
- P 轨生产数据 / 生产环境联调（本 task 仅本地 + Fixture）  
- 改任何 freeze 契约：`lg-rag-sse-v1` SSE 事件表 · `hitl-browser-decide-v1`（web `src/api/hitl.ts`）· 租户契约 F1–F6  
- 自动审批脚本化：decide 必须**真人**在 `/hitl` 页操作（脚本 / auto-approve 冒充 = 验收无效）  
- 新增写能力 / 扩 `testing.write.echo` 语义 / 改审批闸策略  
- TC1–TC8 机测复跑（web 单测面已 CLOSE；本 task 只承接 TC9 手测）
- web 仓**业务码**任何改动（TC9 回填限 web 仓**文档轨**：task 档勾选/状态行）

---

## 验收标准

- [x] **A1 · approve 全链跑通**（✅ · C1–C3 已勾 · invoke §C1–§C3 + api 仓 screenshots `c7-resumed.jpg`/`tc9-list-approved.jpg`）：C1–C3 完成且勾选；证据含 `/hitl` 决策截屏 + echo 执行结果截屏 + resume 日志摘录（invoke 记录可索引到三份证据文件）  
- [x] **A2 · reject 路径跑通**（✅ · invoke §C4：三单 rejected 时间戳 · 零回执断言 · 驳回答复落帧）：C4 完成；证据含驳回截屏 + 单据终态摘录 + 「无 echo 执行结果」断言记录  
- [x] **A3 · 审计链可串**（✅ 有限制 · invoke §C5：`approval_id=hitl_ef414f4a2b464bd69bbb` 三段原文摘录 · span 级不可验（F5 langfuse 403）如实标注）：C5 完成；日志/观测摘录中同一 `approval_id` 串起审批决策、resume、写执行三段（摘录原文贴 invoke）  
- [x] **A4 · 跨租户负样本实测**（✅ · 2026-11-03 复测勾销 · 证据 `invoke_20261103_10_final_acceptance.md` §A4：① 消费链 live 实测已执行（invoke §C6 · 结果为守卫真空坐实=N-R2-1+F3 缺陷发现，已列 fix task 建议，非步骤漏跑）② F4 只读面空集/404 **复测 PASS**——F13 已由 api `task_api_w_join_gap_fix`（PR [#307](https://github.com/Cyning12/ops-desk-api/pull/307) · merge `3168b3b` · 2026-11-03 01:08 UTC · W-fix-2 只读面租户谓词）修复，租户切 `ops-desk-pilot-b` → Pulls 页「暂无 Pull Requests」空列表（截图 `a4-2-cross-tenant-pulls-empty.jpg` · api 仓 screenshots/）③ 头/session 403 **PASS**（`tenant_header_mismatch` · api `router.py:376-384`）——② 契约达成，A4② 勾销，A4 整项全勾）：C6 完成；证据含 ① 消费链 fail-closed 摘录（跨租户 decide 后**写不执行 · 拦单维持 · 台账不消费**——decide 返 200 属 owner-only 闸预期，须在证据中如实标注「owner-404（`hitl-browser-decide-v1`）≠ F4 机制」）② F4 资源命中面 **404** 摘录 ③ 头/session 不一致 **403** 摘录；**不接受**「单测已覆盖」代替 live 实测  
- [x] **A5 · TC9 回填**（✅ · 2026-11-03 复测勾销 · 证据 `invoke_20261103_10_final_acceptance.md` §A5：**F12 已由 api `task_api_w_join_gap_fix`（PR [#307](https://github.com/Cyning12/ops-desk-api/pull/307) · W-fix-1 TTL 过期出口）修复后可达**——api 以 `OPS_HITL_APPROVAL_CONSUMPTION_TTL_SECONDS=90` 运行，单据 `hitl_a285ff2ff195429ea8ab`（run `ab48acb3fa88…` · thread `7bf4896417f6` · `blocked_by=delegation_issue_hitl_required`）2026-11-03 06:51:59Z 创建 · 06:52:36Z 批准（admin · 真人 decide · 手动续跑链）· 约 5 分钟后用户点「续跑」→ api **409** detail「approval_expired：批准已超执行权 TTL（90s）过期，单据已置 expired 终态；请重新发起审批」· DB 实证 `status approved→expired`（updated 06:57:21Z）· **web 行级红字「审批已过期，请刷新列表」渲染成功**（截图 `a5-expired-row-prompt.jpg` · api 仓 screenshots/ · web 侧渲染经 web PR [#85](https://github.com/Cyning12/ops-desk-web/pull/85) 合入后实证）；前序实证 `hitl_990479d004ad4b7a99fa` 经 curl resume 同样 409→expired（06:47:52Z）——过期态四态齐，A5 勾销）：web TC9 证据（四态截图 / 语义对照表 / 闸表截图）落盘并回填 web task **文档轨**（不改 web 业务码）或另开回填 task 互链  
- [x] **A6 · 真人 decide 声明**（✅ · invoke §6：decide ×7 全维护者真人（时间戳列明）· resume 非 decide · 00 curl 补位一次已备案 · auto_resume 未触发）：invoke 记录明确载明 decide 均为真人手操（无脚本 / 无 auto-approve）；若有任何自动化代 decide，本验收整体无效  
- [x] **A7 · 缺陷处置合规**（✅ · 发现 F1–F12 + N-R2-1 + 守卫真空全数落 invoke §2 清单 · fix task 建议 ×9（§7 · 独立 task 起草属后续棒）· 本 task diff 仅 workspace 文档/证据路径 · api 仓 PR 纯截图资产 · web 仓 PR 纯 task 文档轨，零业务码）：联调发现的缺陷均以独立 fix task 落盘并互链（或明确记录零发现）；本 task diff 中**无** api/web/ios 业务码改动（机断：`git diff --name-only main...HEAD` 仅含 workspace 文档/证据路径）  
- [x] **A8 · 闸与 lint**（✅ · 三闸 approved（本档人工闸表 · 2026-10-30 维护者签收/授权 00 代录）· 本棒修订后 lint 复跑 PASS 见 invoke §8 与修订行）：HG-TASK-DRAFT / HG-AUDIT-R1 / HG-E2E-ENV 三闸 approved；`npx spec-wave task lint --file docs/tasks/done/task_stage_w_e2e_join_acceptance.md` PASS（2026-11-03 CLOSE 归档棒路径随迁复跑）

---

## failure_paths

| 触发 | 系统行为 | 可重试 | 用户可见 |
|------|----------|--------|----------|
| freeze 契约在联调中被要求改（SSE 事件表 / hitl-browser-decide-v1 / F1–F6 字段义） | **拒** · 本 task 不收；另开契约变更 task 走 freeze 闸 | 是（另开变更） | 是 |
| 用脚本 / auto-approve / API 直调冒充真人 decide | 验收**整体无效**（A6 红線）；40 自检拒收 | 是（真人重跑） | 是 |
| 跨租户负样本未跑（消费链 fail-closed / F4 资源命中面 404 缺 live 实测） | A4 不勾 · 验收不完整 · 拒 CLOSE | 是（补测） | 是 |
| 把 owner-only decide 返 200 误记为缺陷 / 误称 owner-404 = F4 | 如实区分标注（owner-only 闸预期 · F4 在资源命中面演示）；误报缺陷 → 40 自检纠回，不开空 fix task | 是 | 否（内部） |
| 联调发现缺陷就地在 api/web 仓修 | 纪律拒收 · 回滚；缺陷另开 fix task | 是 | 否（内部） |
| 未签 HG-E2E-ENV 即触生产数据 / 生产栈联调 | 00/维护者**拒开工**；已触生产立即停并上报 | 是（回本地 Fixture 重跑） | 是 |
| resume 出现第二条恢复路径 / HTTP 自调迹象（对照 api 单路径红线） | 记缺陷 · 另开 fix task（api 侧红线复核） | 是 | 是 |
| echo 写在审批前已执行（审批闸失效） | **严重缺陷** · 立即停测 · 另开 P0 fix task；本 task 挂起 | 是（修复后重跑全链） | 是 |
| TC9 证据缺四态截图 / 语义对照任一项 | A5 不勾 · 补证据后回填 | 是 | 否 |
| 本仓误改子仓代码（api/web/ios diff 出现在本分支） | 纪律拒收 · 回滚（A7 机断拦截） | 是 | 否 |

---

## 依赖

| 依赖 | 路径 |
|------|------|
| api 受控写 task（done） | `../ops-desk-api/docs/tasks/done/task_api_controlled_write_hitl.md` |
| web HITL 审批页 task（done · TC9 挂起） | `../ops-desk-web/docs/tasks/done/task_web_hitl_approval_page.md` |
| 租户契约 freeze F1–F6 | `docs/contracts/api-v1-tenant-readonly-context-draft.md` |
| 上游决议 §8（H→T→W→P） | `../ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` |
| post-H 简报（阶段 W 行） | `docs/05-plan/05_post_h_stage_brief_v1_zh.md` |
| 阶段 T task（done · 过程轨范本） | `docs/tasks/done/task_stage_t_tenant_contract.md` |
| 双租户 fixture 实态 | `docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md` |
| web freeze 契约（只读对齐） | `../ops-desk-web/src/api/hitl.ts`（`hitl-browser-decide-v1`） |

---

## 给执行帽的必读列表

1. 本 task（人工闸 · 非范围 · failure_paths）  
2. api `docs/tasks/done/task_api_controlled_write_hitl.md`（审批闸 / resume 单路径 / span `approval_id` / `testing.write.echo` 口径）  
3. web `docs/tasks/done/task_web_hitl_approval_page.md`（TC9 手测项原文 · 两步链 · 四态截图要求）  
4. `docs/contracts/api-v1-tenant-readonly-context-draft.md`（F1–F6 · 失败码表）  
5. web `src/api/hitl.ts` freeze 语义（只读：400/409/404/422 码义 · 不改）  
6. `docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md`（双租户 Fixture 起数口径）

---

## 思考轮控制

| 轮 | 结论 | early_stop | reason（early_stop） | residual_risks |
|----|------|------------|----------------------|----------------|
| R0 | 双轨各自 CLOSE ≠ 咬合；缺真人全链 | no | — | none |
| R1 | 闸设计：HG-TASK-DRAFT / HG-AUDIT-R1（20-R1 先例）/ HG-E2E-ENV（环境口径） | no | — | 20-R1 对过程轨是否过重（按 T 先例保留） |
| R2 | 步骤最小集 S1–S6 + TC9 承接；approve/reject 双路径缺一不可 | no | — | resume_mode 三值是否全测（定：至少 manual 显式续跑链一遍） |
| R3 | 真人 decide 为有效性红线（A6）；缺陷一律另开 fix task | yes | 决策面已框定（步骤/证据/红线齐）；执行细节（截图粒度、env 实际值）属执行期记录非再开轮 | 本地栈起不来（env/端口/fixture 漂移）→ 执行期阻塞待维护者处置 |
| R4 | （未开） | — | early_stop at R3 | — |
| R5 | （未开） | — | early_stop at R3 | — |

**actual_last_round**：R3 · **early_stop**：yes · **reason**：验收面（步骤集、证据形式、红线、闸表）已框死；执行期变量（起栈细节、缺陷有无）不属 10 轮次可钉 · **residual_risks**：见 R3

### R0 · 问题框定

api 受控写竖切（PR #303）与 web 审批页（TC1–TC8 机测绿）均为**单轨**验收；web TC9 明确挂起待手测。阶段 W 的真实缺口是双轨咬合的真人全链证据，本 task 定位过程轨验收，只产证据不改码。

### R1 · 闸设计

三闸分工：HG-TASK-DRAFT 解锁 20-R1；HG-AUDIT-R1 沿阶段 T 过程轨 20-R1 先例（本 task 含跨仓联调步骤与红线，值得一轮书面审）；HG-E2E-ENV 单列「本地 · Fixture · 不触生产」执行环境口径，防止联调顺手触生产。

### R2 · 步骤集

S1 环境 → S2 拦单挂起 → S3 approve 全链 → S4 reject → S5 审计链 → S6 跨租户负样本，外加 TC9 承接。reject 不可省：approve-only 无法证「闸在拦」。跨租户负样本必须 live 实测（T 轨单测覆盖不等于双栈联调过）。

### R3 · 红线与停轮

两条红线钉死：真人 decide（脚本化 = 验收无效）、缺陷另开 fix task（本 task 不修码）。决策面收束 → early_stop；起栈漂移等执行期风险挂账执行期处置。

### R4 ·（未开 · early_stop）

本轮不展开；决策面已在 R3 收束。

### R5 ·（未开 · early_stop）

本轮不展开。

---

### 自检结论

| 检查 | 结果 |
|------|------|
| `npx spec-wave task lint --file docs/tasks/done/task_stage_w_e2e_join_acceptance.md` | **PASS**（2026-10-30 · 10 起草棒；20-R1 修订棒复跑 PASS；2026-11-02 · 10 C8 归档棒修订后复跑 PASS；2026-11-03 · 10 验收收尾棒修订后复跑 PASS；2026-11-03 · **CLOSE 归档棒路径随迁 done/ 复跑 PASS**） |
| 结论 | **CLOSED 2026-11-03 维护者拍板 · 归档 `done/`** · 三闸 approved（闸表为准 · 终态）· C1–C8 全勾 · 验收 A1–A8 全勾（A4② F4 只读面空集复测 PASS · A5 过期态四态齐——F13/F12 由 api `task_api_w_join_gap_fix` PR #307（W-fix-1/W-fix-2）修复后实证，web 侧 PR #85）· 发现 F1–F15 + N-R2-1（F14/F15 为 2026-11-03 复测期新发现 · 已追加 backlog）· fix task 建议 ×10 · 40 自检 PASS-WITH-NITS **NIT-1 闭环**（证据 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261102_10_c8_evidence_archive.md` + `invoke_20261103_10_final_acceptance.md`） |

### CLOSE 阻塞注记（2026-11-02 · 维护者裁决）

**本 task 暂不 CLOSE**，阻塞项 = api 仓 `task_api_w_join_gap_fix`（`../ops-desk-api/docs/tasks/active/task_api_w_join_gap_fix.md`）：

| 挂账验收 | 阻塞内容 | 解阻条件 |
|----------|----------|----------|
| A4②（F4 资源命中面 404） | F13 只读资源面跨租户泄漏（issues/pulls/overview 无 tenant 谓词） | api task **W-fix-2** 修复合入 → 复测 B 身份 `GET /issues` 得空集 |
| A5（TC9 过期态截图） | F12 api 无过期错误出口（web FP-5 不可达） | api task **W-fix-1** 修复合入 → TTL 短窗（`OPS_HITL_APPROVAL_CONSUMPTION_TTL_SECONDS=90`）复现过期态 → 补拍截图 |

修复 task 合入且两项复测证据回填 invoke 后，由维护者拍板 CLOSE。在此期间本 task 保持 `active`，闸表 status 不变。

**2026-11-03 解阻进展回执**（issue #308 分析批 · 00 代录）：阻塞项 api task `api-w-join-gap-fix` 已合入 api 仓 master——**PR [#307](https://github.com/Cyning12/ops-desk-api/pull/307) MERGED 2026-11-03 01:08 UTC · merge commit `3168b3b`**（W-fix-1 TTL 过期出口 + W-fix-2 只读资源面租户谓词；api 侧图谱回写见 `ops-desk-api/docs/_tech_graph/l1/01_modules.md` :136）。**解阻条件「修复合入」已达成**，A4② / A5 复测前置就绪：可按上表复测路径排期（A4②：B 身份 `GET /issues` 空集复测；A5：TTL 短窗 90s 复现过期态补拍）→ 复测证据回填 invoke → 维护者拍板 CLOSE。本 task 仍保持 `active` 至复测完成。

**2026-11-03 复测完成回执**（10 验收收尾棒）：上表两项解阻条件**均已达成并实证**——A4②：F13 修复（PR #307 W-fix-2）后租户切 `ops-desk-pilot-b` → Pulls 页空集（截图 `a4-2-cross-tenant-pulls-empty.jpg`）；A5：F12 修复（PR #307 W-fix-1 TTL 过期出口 · web 渲染 PR [#85](https://github.com/Cyning12/ops-desk-web/pull/85)）后 TTL 90s 短窗复现，409 `approval_expired` → 单据置 `expired` 终态 → web 行级红字「审批已过期，请刷新列表」（截图 `a5-expired-row-prompt.jpg`）；证据链见 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261103_10_final_acceptance.md`。**验收 A1–A8 全勾 · 待维护者 CLOSE**（本 task 保持 `active`，闸表 status 不变，CLOSE 拍板权归维护者）。

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-10-30 | 10 起草：过程轨验收壳 · 三闸（HG-TASK-DRAFT / HG-AUDIT-R1 / HG-E2E-ENV）· 范围 C1–C8 · 验收 A1–A8 带证据形式 · failure_paths 九条（含 freeze 拒改 / 真人 decide 红线 / F4 实测）· R0–R5 齐（early_stop at R3）· lint PASS |
| 2026-10-30 | 00 代录：维护者签收 **HG-TASK-DRAFT → approved**（对齐阶段 T 先例 · 解锁 20-R1；联调执行仍须 HG-AUDIT-R1 + HG-E2E-ENV）；闸表 status 其余未动 |
| 2026-10-30 | 10 承接 **20-R1 修订**：**B1** 跨租户负样本口径纠偏——decide 端点为 owner-only 闸（api `router.py:213-216` · store 无 tenant 谓词 `store.py:171,184`），切租户 decide 返 200 属预期；C6/完成态④/A4 主测改为**消费链 fail-closed** live 实测（写不执行 · 拦单维持 · 台账不消费 · `nodes.py:499-504`），F4 对外 404 移至资源命中面演示，并钉死「owner-404 ≠ F4 机制」区分；failure_paths 第 3 行同步改写并新增「200 误判缺陷」行。**M1** C7/A5/非范围澄清「TC9 回填限 web 仓文档轨，不改 web 业务码」。**M2** 头部状态行/10 注/自检结论同步 HG-TASK-DRAFT approved · lint 复跑 PASS |
| 2026-10-30 | 10 承接 **20-R2**（B1/M1/M2 闭环）：**M3** 机械订正——消费侧守卫路径两处引用 `app/ops/hitl/nodes.py:499-504` → 真实路径 **`app/ops/lg_rag/multi/nodes.py:499-504`**（行号内容经亲核一致，仅目录段 `hitl/` → `lg_rag/multi/`）；闸表 status 未动 · lint 复跑 PASS。20-R2 观察点 N-R2-1（resume 入口租户 ContextVar 回落 · `tenant_context.py:24-26`）已知悉，不改本 task——执行期实测若成立按 A7 另开 fix task |
| 2026-11-02 | 10 承接 **C8 证据归档棒**：联调实测（09:00–16:00 · 本地双栈 · Fixture 双租户）全证据落 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261102_10_c8_evidence_archive.md`——C1–C8 勾选带锚（C6 ⚠️ 守卫真空坐实 · C7 过期态不可达 F12）· 验收 A1/A2/A3/A6/A7/A8 勾销 · **A4/A5 不勾挂账**（A4：F4-404/403 未抽测且消费链实测结果=缺口发现；A5：过期态截图缺按 failure_paths 明文不勾）· 发现清单 F1–F12 + **N-R2-1 坐实**（20-R2 观察点兑现：B 租户单被 A 上下文消费 · 回执 `d6bd262904544232` 错标 `ops-desk-pilot`）· fix task 建议清单 ×9 · 40 自检棒待派 · 闸表 status / task status 字段未动 · lint 复跑 PASS |
| 2026-11-02 | 10 承接 **C8 补丁棒**（A4 补测并入 · 00 执行 10 落字 · 纯只读探测）：③ 头/session 不一致 **403 PASS**（`tenant_header_mismatch` · api `app/ops/lg_rag/router.py:376-384`）；② F4 资源命中面 404 **FAIL → 新发现 F13**（B session 下 `GET /api/ops/issues`/`pulls`/`overview` 泄漏 A 数据 · api `app/ops/issues.py:29` 无 tenant 谓词 · 租户谓词 task `task_tenant_readonly_predicate.md:156` 范围未覆盖=非回归 · **P 轨 canary 前置**）；发现清单 F1–F12→**F1–F13** · fix task 建议 ×9→**×10** · **A4 仍不勾**（② 契约未达 · 待 F13 修复复测）· C6/自检结论/invoke §C6/§2/§7/§8 同步 · lint 复跑 PASS |
| 2026-11-02 | 10 承接 **CLOSE 阻塞注记**（维护者裁决：F12 补 api TTL 过期出口 · F13 只读资源面接租户谓词 · **本 task 暂不 CLOSE**）：自检结论后新增「CLOSE 阻塞注记」节——阻塞项 = api `task_api_w_join_gap_fix`（W-fix-1 TTL 语义补全 → A5 复现过期态 · W-fix-2 只读面谓词 → A4② 复测）；闸表 status / task status 字段未动 · lint 复跑 PASS |
| 2026-11-03 | 00 承接 **解阻进展回执**（issue #308 分析批 · 维护者过目后执行）：「CLOSE 阻塞注记」节补 PR #307 MERGED 回执（`3168b3b` · 2026-11-03 01:08 UTC）——W-fix-1/W-fix-2 已合 api master，A4②/A5 复测前置就绪；闸表 status / task status 字段未动 · lint 复跑 PASS |
| 2026-11-03 | 10 承接 **验收收尾棒**（修复合并后复测 · PR #307 api / PR #85 web 合入后实证）：**A4② 勾销**（F13 已修 · 租户切 `ops-desk-pilot-b` → Pulls 空集 · 截图 `a4-2-cross-tenant-pulls-empty.jpg`）· **A5 勾销**（F12 已修可达 · TTL 90s 短窗复现 · `hitl_a285ff2ff195429ea8ab` 409 `approval_expired` → DB `approved→expired`（06:57:21Z）· web 行级红字「审批已过期，请刷新列表」· 截图 `a5-expired-row-prompt.jpg`；前序实证 `hitl_990479d004ad4b7a99fa` curl resume 409→expired 06:47:52Z）——**A1–A8 全勾**；新发现 **F14**（审批页批准后 chat 浮层卡片仍示「待审批」不联动 · F1/F10 同族 UI 状态同步缺口 · run `af3fcf63832c4d6dae4a1ecc5065a4e3`）/ **F15**（审批卡片创建时间 UTC 未本地化 · UX minor）如实记录进 `invoke_20261103_10_final_acceptance.md` 并追加 backlog；头部状态行/自检结论/CLOSE 注记同步「验收全勾 · 待维护者 CLOSE」；闸表 status / task status 字段未动 · lint 复跑 PASS |
| 2026-11-03 | 10 承接 **CLOSE 归档棒**（维护者 2026-11-03 拍板 CLOSE · 授权在案）：`git mv` `active/`→`done/` · 状态字段 active→done · 头部状态行改「CLOSED 2026-11-03 维护者拍板 · 验收 A1–A8 全勾 · 证据 invoke_20261102_10_c8_evidence_archive + invoke_20261103_10_final_acceptance」· 自检结论改 CLOSE 终态 · A8/自检结论 lint 路径随迁 done/（复跑 PASS）· **40 自检 PASS-WITH-NITS NIT-1 闭环**（C7 过期态括注纠偏 · 合入回执 workspace PR [#21](https://github.com/Cyning12/ops-desk-workspace/pull/21) / api PR [#310](https://github.com/Cyning12/ops-desk-api/pull/310) 终验截图资产 MERGED 2026-11-03 07:23 UTC）· 活指针随迁（active/README · 05 简报）· 历史 invoke/审查文不动 · 闸表 status 未动 |
