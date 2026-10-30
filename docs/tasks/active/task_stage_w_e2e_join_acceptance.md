# Task：阶段 W · 双轨端到端联调验收（api 受控写 + web 审批页 · 真人全链 · TC9 回填）

> **状态**：`draft`（2026-10-30 · 10 起草落壳 · 人工闸均 `pending`）· **过程轨 / 验收轨** · **不授权任何 30 改码**  
> **类型**：跨仓联调验收 / 证据归档（只产文档与证据，不改业务码）  
> **上游**：api `docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` §8（阶段序 H→T→W→P）· `docs/05-plan/05_post_h_stage_brief_v1_zh.md`（阶段 W 行：受控写 + HITL「要确认单/HITL」）  
> **分支**：`task/stage-w-e2e-join`（base：`main`）  
> **执行模式**：Open Folder = **`ops-desk-workspace/`**；本 task 只改本仓文档/证据；**不**改 api/web/ios 业务码；联调在**本地**起 api + web 双栈，Fixture 数据，**不触生产**  
> **10 注**：2026-10-30 · 维护者令「起草阶段 W 端到端联调验收 task」· 本窗落壳 + lint + 10 invoke；人工闸均 `pending`；**HG-TASK-DRAFT 签收前禁派执行**

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
| HG-AUDIT-R1 | pending | 联调执行 | 20-R1 审查文 PASS 后签收（过程轨先例：阶段 T 走 20-R1 · `docs/harness/reviews/review_20261030_stage_t_tenant_contract_r1.md`）；本闸**不**授权任何 30 改码 |
| HG-E2E-ENV | pending | 联调执行 | **执行环境确认**：本地起 api + web 双栈 · 数据限 Fixture 轨（双租户 fixture · api `f048c57` ∈ master）· **不触生产**（P 轨生产数据另轨另签）；维护者签收后方可开跑 |

---

## 背景与目标

阶段 W 双轨均已 CLOSE 但**尚未端到端联调**：

- **api 轨**：受控写竖切已合入 master（PR [#303](https://github.com/Cyning12/ops-desk-api/pull/303) · merge commit `09f97f4` · feat commit `227a482` · 2026-10-30 · CI 4/4 绿）。审批闸 `capability_write_hitl_required` fail-closed（无审批不执行）；decide/resume **单路径**恢复（`router._execute_decided_resume` · 禁第二条实现）；span `approval_id` 预留已启用落值；首条写能力 = `testing.write.echo`（极窄 opt-in）。task 档：`../ops-desk-api/docs/tasks/done/task_api_controlled_write_hitl.md`。
- **web 轨**：独立 HITL 审批页已 CLOSE（`/hitl` 第四审批入口 · freeze `hitl-browser-decide-v1` 只消费零分叉 · 分支已合入 main），但 **TC9 手测项挂起待维护者手测回填**（web task 先行 CLOSE · 2026-10-30 维护者定夺）。task 档：`../ops-desk-web/docs/tasks/done/task_web_hitl_approval_page.md`。
- **契约 freeze**：租户契约 F1–F6（`docs/contracts/api-v1-tenant-readonly-context-draft.md` · freeze 2026-09-18）· SSE `lg-rag-sse-v1` · web `hitl-browser-decide-v1`；写路径同受 F1–F6（跨租户写 fail-closed 对外 404）。

单轨各自过闸 ≠ 双轨咬合过闸：api 侧验收基于单测与负样本，web 侧 TC9 明确挂起，**真人全链从未跑过一遍**。本 task 补这一环：本地起双栈，真人从 web 发起 echo 写 → 编排层拦单挂起 → `/hitl` 页审批（approve 与 reject 各至少一遍）→ resume 单路径恢复 → echo 真执行 → span `approval_id` 审计链核对；并实测跨租户负样本（F4 对外 404），承接 web TC9 手测回填。

### 完成态

1. 联调步骤 S1–S6（§范围 C1–C6）全部执行并勾选，每步带证据（截屏 / 日志摘录 / invoke 记录）落 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/`。  
2. approve 与 reject 两条路径**各至少跑通一遍**；reject 后确认写**未**执行（无 echo 结果 · 单据终态 rejected）。  
3. span `approval_id` 审计链核对通过：审批 → resume → 写执行三段可由同一 `approval_id` 串链（日志 / 观测摘录为证）。  
4. 跨租户负样本实测一遍：租户 A 会话对租户 B 单据 decide → 对外 **404**（F4），不泄漏存在性。  
5. web TC9 手测证据齐备并回填 web task（或另开回填 task 指针），含 `/hitl` 四态截图与语义对照。  
6. 联调发现的任何缺陷**不**在本 task 修，一律另开 fix task 并互链（写入非范围）；无缺陷则如实记「零发现」。

---

## 范围

- [ ] **C1 · 环境就绪**：本地起 api + web 双栈（Fixture 数据 · 双租户 fixture 可用）；确认 `OPS_HITL_AUTO_RESUME` 口径（默认 manual = 显式续跑链）并记录实际 env；证据 = 起栈方式记录 + 健康检查摘录  
- [ ] **C2 · 发起 echo 写 → 拦单挂起**：真人从 web Chat 发起触发 `testing.write.echo` 的请求；断言编排层拦单、HITL 待审批帧可见（`/hitl` 列表出现该单据）；**未审批前无任何写执行**；证据 = Chat 帧截屏 + `/hitl` 列表截屏  
- [ ] **C3 · approve 全链**：`/hitl` 页真人 decide=approve（含二次确认 / resume_mode 选择与显式续跑两步链）→ resume 单路径恢复 → echo 真执行，结果回到会话；证据 = 决策确认截屏 + 执行结果截屏 + resume 日志摘录  
- [ ] **C4 · reject 路径**：再发起一遍 echo 写 → decide=reject → 断言写**未**执行、单据终态正确、会话侧可见驳回结果；证据 = 截屏 + 单据状态摘录  
- [ ] **C5 · 审计链核对**：以 C3 单据的 `approval_id` 串链核对 span / 日志（审批决策 → resume → 写执行结果）；证据 = 日志/观测摘录（含 `approval_id` 字段值）  
- [ ] **C6 · 跨租户负样本**：切租户 A 会话，对租户 B 的待审批单据 decide（或直接命中 B 资源 id）→ 断言对外 **404**（对内日志可 `tenant_scope_denied`）；租户头与 session 不一致 → **403**（F1=C 抽测一次）；证据 = 响应码截屏/摘录  
- [ ] **C7 · TC9 承接**：web TC9 手测项在本联调中完成（批准 → 显式续跑 → 「回到会话查看」链路 + 四态截图 / 语义对照表 / 闸表截图），证据落盘并在 web task 回填（或另开回填 task，指针互链）  
- [ ] **C8 · 证据归档与勾选**：全部证据落 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/`；40 自检核对验收逐条勾选；缺陷另开 fix task 互链（无则记零发现）

### 非范围

- 改 api / web / ios **任何**业务码、配置、迁移（联调发现缺陷 → 一律另开 fix task，本 task 只记录与互链）  
- 阶段 P 平台项（Registry 服务化 / 本体平台）  
- P 轨生产数据 / 生产环境联调（本 task 仅本地 + Fixture）  
- 改任何 freeze 契约：`lg-rag-sse-v1` SSE 事件表 · `hitl-browser-decide-v1`（web `src/api/hitl.ts`）· 租户契约 F1–F6  
- 自动审批脚本化：decide 必须**真人**在 `/hitl` 页操作（脚本 / auto-approve 冒充 = 验收无效）  
- 新增写能力 / 扩 `testing.write.echo` 语义 / 改审批闸策略  
- TC1–TC8 机测复跑（web 单测面已 CLOSE；本 task 只承接 TC9 手测）

---

## 验收标准

- [ ] **A1 · approve 全链跑通**：C1–C3 完成且勾选；证据含 `/hitl` 决策截屏 + echo 执行结果截屏 + resume 日志摘录（invoke 记录可索引到三份证据文件）  
- [ ] **A2 · reject 路径跑通**：C4 完成；证据含驳回截屏 + 单据终态摘录 + 「无 echo 执行结果」断言记录  
- [ ] **A3 · 审计链可串**：C5 完成；日志/观测摘录中同一 `approval_id` 串起审批决策、resume、写执行三段（摘录原文贴 invoke）  
- [ ] **A4 · 跨租户负样本实测**：C6 完成；404（跨租户单据 decide / 资源命中）与 403（头/session 不一致）响应码各有摘录；**不接受**「单测已覆盖」代替 live 实测  
- [ ] **A5 · TC9 回填**：web TC9 证据（四态截图 / 语义对照表 / 闸表截图）落盘并回填 web task 或另开回填 task 互链  
- [ ] **A6 · 真人 decide 声明**：invoke 记录明确载明 decide 均为真人手操（无脚本 / 无 auto-approve）；若有任何自动化代 decide，本验收整体无效  
- [ ] **A7 · 缺陷处置合规**：联调发现的缺陷均以独立 fix task 落盘并互链（或明确记录零发现）；本 task diff 中**无** api/web/ios 业务码改动（机断：`git diff --name-only main...HEAD` 仅含 workspace 文档/证据路径）  
- [ ] **A8 · 闸与 lint**：HG-TASK-DRAFT / HG-AUDIT-R1 / HG-E2E-ENV 三闸 approved；`npx spec-wave task lint --file docs/tasks/active/task_stage_w_e2e_join_acceptance.md` PASS

---

## failure_paths

| 触发 | 系统行为 | 可重试 | 用户可见 |
|------|----------|--------|----------|
| freeze 契约在联调中被要求改（SSE 事件表 / hitl-browser-decide-v1 / F1–F6 字段义） | **拒** · 本 task 不收；另开契约变更 task 走 freeze 闸 | 是（另开变更） | 是 |
| 用脚本 / auto-approve / API 直调冒充真人 decide | 验收**整体无效**（A6 红線）；40 自检拒收 | 是（真人重跑） | 是 |
| 跨租户负样本未跑（F4 对外 404 缺 live 实测） | A4 不勾 · 验收不完整 · 拒 CLOSE | 是（补测） | 是 |
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
| `npx spec-wave task lint --file docs/tasks/active/task_stage_w_e2e_join_acceptance.md` | **PASS**（2026-10-30 · 10 起草棒） |
| 结论 | **draft · 三闸 pending · 待维护者签收 HG-TASK-DRAFT 后开 20-R1** |

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-10-30 | 10 起草：过程轨验收壳 · 三闸（HG-TASK-DRAFT / HG-AUDIT-R1 / HG-E2E-ENV）· 范围 C1–C8 · 验收 A1–A8 带证据形式 · failure_paths 九条（含 freeze 拒改 / 真人 decide 红线 / F4 实测）· R0–R5 齐（early_stop at R3）· lint PASS |
