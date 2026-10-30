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
- HG-TASK-DRAFT 待维护者签收（签收后才开 20-R1）
- 20-R1 审查文未开（HG-TASK-DRAFT 阻塞）
- HG-E2E-ENV 待维护者确认本地 Fixture 轨口径
- TC9 回填最终落在 web task 原文还是另开回填 task，执行期定（A5 已写两可口径）
