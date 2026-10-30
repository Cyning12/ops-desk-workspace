# Invoke · 10 起草 · stage-w-e2e-join-acceptance（2026-10-30）

> retention: default · required hats: 10,00,40 · 分支 task/stage-w-e2e-join

## 本棒范围
10-task 起草阶段 W 双轨端到端联调验收 task：落壳 `docs/tasks/active/task_stage_w_e2e_join_acceptance.md` + active README 指针 + 本 invoke。本窗未改任何业务码；未 commit（由本棒尾统一提交）。

## 背景真值核实（起草前亲读）
- api 受控写竖切 CLOSE：PR #303 · merge `09f97f4` · feat `227a482`（`../ops-desk-api/docs/tasks/done/task_api_controlled_write_hitl.md` 头行核实）· 审批闸 `capability_write_hitl_required` fail-closed · resume 单路径 `router._execute_decided_resume` · span `approval_id` 落值（gateway.py:1318 预留启用）· 首条写能力 `testing.write.echo`
- web 审批页 CLOSE：`../ops-desk-web/docs/tasks/done/task_web_hitl_approval_page.md` · /hitl 第四入口 · freeze `hitl-browser-decide-v1`（`src/api/hitl.ts`）· **TC9 挂起待维护者手测回填**（维护者定夺 2026-10-30）
- 契约 freeze：F1–F6（`docs/contracts/api-v1-tenant-readonly-context-draft.md` · freeze 2026-09-18 · F4 跨租户对外 404）· SSE `lg-rag-sse-v1`
- 上游：api 讨论稿 §8（H→T→W→P · W = 受控写 + HITL）· `docs/05-plan/05_post_h_stage_brief_v1_zh.md`（阶段 W 行「要确认单/HITL」）
- 范本对齐：`docs/tasks/done/task_stage_t_tenant_contract.md`（结构 / 闸表 / 修订表 / R0–R5 控制表）

## 10 裁定记录
1. **闸表三闸**：HG-TASK-DRAFT（blocks 20-R1/执行）· HG-AUDIT-R1（按阶段 T 过程轨 20-R1 先例保留——本 task 含跨仓联调步骤与红线，值得书面审）· 新增 **HG-E2E-ENV** 单列执行环境口径（本地起栈 · Fixture 数据 · 不触生产），防联调顺手触生产。
2. **范围八步**：C1 环境 → C2 拦单挂起 → C3 approve 全链 → C4 reject → C5 `approval_id` 审计链 → C6 跨租户负样本（404/403 live 实测）→ C7 TC9 承接 → C8 证据归档。reject 不可省（approve-only 无法证闸在拦）。
3. **红线**：真人 decide（脚本/auto-approve = 验收整体无效 · A6）；缺陷一律另开 fix task（本 task 不改业务码 · A7 机断 `git diff --name-only` 仅 workspace 路径）。
4. **invoke 留档**：profile `default` · required hats `10,00,40`（过程轨无 30；40 承载证据自检）。
5. **graph/wiki**：图谱零 diff（G-L0）；wiki_delta 仅 05 简报 CLOSE 时补一句，草稿期不动。
6. 不代签任何 human_gate；三闸均 pending。

## 交付
- `docs/tasks/active/task_stage_w_e2e_join_acceptance.md`（新落 · lint PASS）
- `docs/tasks/active/README.md`（active 指针）
- 本 invoke

## lint 结论
`npx spec-wave task lint --file docs/tasks/active/task_stage_w_e2e_join_acceptance.md` → **PASS**（2026-10-30）

## 未决项
- HG-TASK-DRAFT 待维护者签收（签收后才开 20-R1）→ **2026-10-30 已签收（00 代录）**
- 20-R1 审查文未开（HG-TASK-DRAFT 阻塞）→ 已开，结论驱动修订棒见下
- HG-E2E-ENV 待维护者确认本地 Fixture 轨口径（仍 pending）
- TC9 回填最终落在 web task 原文还是另开回填 task，执行期定（A5 已写两可口径）

---

## 20-R1 修订棒（2026-10-30 晚 · 00 派工）

### B1（blocker · 已修）
20-R1 指出 C6/A4 与 api 码面矛盾：decide 端点为 owner-only 闸（`app/ops/hitl/router.py:213-216`），hitl store 查询无 tenant 谓词（`store.py:171,184`），同一维护者切租户 decide 返 **200** 非 404；真 fail-closed 在消费侧（`app/ops/hitl/nodes.py:499-504` 租户不一致不消费维持拦截 · `tests/test_write_approval_gate.py:431-475` W2 语义）。10 按 00 裁定口径回填：
1. **C6 主测改消费链 live 实测**：B 会话拦单 → A 会话（或 A 租户头）approve → 断言写不执行 + 拦单维持 + 台账不消费；decide 返 200 标注为 owner-only 闸预期；
2. **F4 对外 404 移至资源命中面**演示（对 B 租户资源 id 的只读/写请求 404）；证据须如实标注「owner-404（hitl-browser-decide-v1）≠ F4 机制」；
3. **A4 / failure_paths 行 3 同步改写**；failure_paths 新增「200 误判缺陷」行（40 自检纠回 · 不开空 fix task）；
4. 背景节末追加「跨租户码面口径」引用块，钉死码面真值锚点。
差异面：背景节 + 完成态④ + C6 + A4 + failure_paths（改 1 行增 1 行）+ 自检结论 + 修订表。

### M1（minor · 已修）
C7 / A5 / 非范围 澄清「TC9 回填限 web 仓**文档轨**（task 档勾选/状态行），不改 web 业务码」，消除与头部「只改本仓文档/证据」的表面张力。

### M2（minor · 已修）
头部状态行 / 10 注 / 自检结论同步 **HG-TASK-DRAFT approved（00 代录）**；修订表补 00 代录签收行（对齐 T 先例）。HG-AUDIT-R1 / HG-E2E-ENV 仍 pending，闸表 status 未碰。

### lint 复跑
`npx spec-wave task lint --file docs/tasks/active/task_stage_w_e2e_join_acceptance.md` → **PASS**（2026-10-30 · 修订棒）
