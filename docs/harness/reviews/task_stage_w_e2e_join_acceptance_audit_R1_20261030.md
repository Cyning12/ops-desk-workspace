# 20-task-audit R1 审查文：阶段 W · 双轨端到端联调验收 task

| 项 | 值 |
|----|-----|
| **审查对象** | `docs/tasks/active/task_stage_w_e2e_join_acceptance.md`（slug `stage-w-e2e-join-acceptance`） |
| **审查帽** | 20-task-audit · R1（书面审查 · 只审不改 · 未代签任何 human_gate） |
| **日期** | 2026-10-30 |
| **分支** | `task/stage-w-e2e-join`（已核实当前在位） |
| **范本对照** | `docs/tasks/done/task_stage_t_tenant_contract.md`（过程轨先例）· `docs/harness/reviews/review_20261030_stage_t_tenant_contract_r1.md` |
| **上游真值** | api `docs/tasks/done/task_api_controlled_write_hitl.md` · api `docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` §8 · web `docs/tasks/done/task_web_hitl_approval_page.md` · `docs/contracts/api-v1-tenant-readonly-context-draft.md`（F1–F6 freeze 2026-09-18）· `docs/05-plan/05_post_h_stage_brief_v1_zh.md` |
| **码面抽验（只读）** | api `app/ops/lg_rag/multi/nodes.py` · api `app/ops/hitl/router.py` · api `app/ops/hitl/store.py` · api `tests/test_write_approval_gate.py` · web `src/api/hitl.ts` · web `src/router/index.ts` |
| **lint 复跑** | `npx spec-wave task lint --file docs/tasks/active/task_stage_w_e2e_join_acceptance.md` → **PASS**（2026-10-30 本棒复跑） |

---

## 结论摘要

| 面 | 结论 |
|----|------|
| **内容** | **不通过（blocker ×1）**：B1 —— C6/A4「跨租户单据 decide → 404」与码面实态矛盾（decide 端点为 owner 闸、无租户过滤），且把 owner-404 误标为 F4 语义；live 实测按字面不可复现或证据机制错标。退回 **10-task** 定向修补 C6/A4 后复审。 |
| **流程闸** | HG-TASK-DRAFT = approved（2026-10-30 维护者签收 · 00 代录 · 闸表为真值，本审查不代签）；HG-AUDIT-R1 = **pending**（本审查有内容阻塞，**不建议签收**，待 B1 修补后复审）；HG-E2E-ENV = pending（口径必要且无漏洞，可与 HG-AUDIT-R1 同修后一并签）。 |
| **lint** | PASS（见上）。 |
| **思考轮** | PASS（控制表 R0–R5 齐 · early_stop at R3 依据成立 · 回填闭合）。 |

**下一棒**：10-task（按 §回填清单 修 C6/A4，可顺带 M1/M2）→ 20-R2 轻量复审 → 维护者再签 HG-AUDIT-R1 / HG-E2E-ENV。**HG-AUDIT-R1 pending 期间本审查文不附任何执行 Prompt。**

---

## 逐项审查结论

### 1. 范围 C1–C8 / 非范围边界 —— PASS

- C1–C8 全部为「执行步骤 + 证据落盘」形态，零改码语义；非范围六条逐一点死：不改 api/web/ios 任何业务码（缺陷另开 fix task 互链）、不动三份 freeze 契约、不触 P 轨生产、禁脚本化 decide、不新增写能力、不复跑 TC1–TC8。
- 与已 CLOSE 两侧 task 边界清晰不重叠：api 轨（PR #303 · merge `09f97f4` · feat `227a482` · 已核实 ∈ master）验收基于单测与负样本；web 轨（分支已合 main · 实现 commit `a34c626`）TC1–TC8 机测绿、**TC9 明确挂起待维护者手测回填**——本 task C7/A5 恰承接 TC9，不重复 TC1–TC8。阶段序（讨论稿 §8.1 H→T→W→P）与 05 简报阶段 W 行（「要确认单/HITL」）核对一致。
- 附带观察见 M1（C7 回填 web 仓文档与「只改本仓」的表面张力）。

### 2. 人工闸表三闸闭环 —— PASS

- HG-TASK-DRAFT（approved · blocks 20-R1 + 联调执行）→ HG-AUDIT-R1（pending · blocks 联调执行）→ HG-E2E-ENV（pending · blocks 联调执行）：草稿→审查→环境→执行链闭合，blocks 语义互不重迭；过程轨无 30，闸表不写 blocks 30 是正确的（与 T 先例一致）。
- HG-E2E-ENV 口径必要：本 task 要真实起 api+web 双栈跑写路径，而仓内存在 P 轨生产数据另轨（06 文档 NO-GO 语义仍在）——单列「本地 · Fixture（双租户 fixture · api `f048c57` ∈ master，已核实）· 不触生产」环境闸可防止联调顺手触生产；failure_paths 第 5 行（未签即触生产 → 拒开工 + 已触即停并上报）兜住漏洞面。无漏洞。
- 附带观察见 M2（头部状态行与修订表未随 HG-TASK-DRAFT 签收刷新；闸表本身是真值且正确）。

### 3. 验收 A1–A8 可勾可机断 —— ISSUE（B1 涉 A4）

- A1/A2/A3/A5/A7/A8：每条均点名证据形式（截屏 / 日志摘录 / invoke 索引 / 回填指针），A7 附机断口径（`git diff --name-only main...HEAD` 仅含 workspace 文档/证据路径 · base=main 与头部一致），A8 = 三闸 + lint，均可勾可判。PASS。
- A6 真人 decide：可验证性本质是 invoke 自证 + 40 自检拒收 + failure_paths 红线（脚本冒充 = 验收整体无效），属「真人」类验收的固有形态，缓解措施到位，判 PASS（观察见 N1）。
- **A4：ISSUE → 见 B1**（跨租户 decide 404 的 live 可复现性不成立 / 机制错标）。

### 4. failure_paths 九条与三条红线自洽 —— PASS

- 三条点名红线逐一对号：freeze 契约拒改（行 1 · 另开契约变更 task）· 脚本冒充真人 decide（行 2 · 验收整体无效 + 40 拒收，与 A6 互锁）· 跨租户负样本未跑（行 3 · A4 不勾拒 CLOSE）。与非范围、验收条款无矛盾。
- 「审批前已执行 = P0 停测」（行 7）：判据可观察——echo 结果在任何审批动作之前回到会话 / 日志出现写执行而无 approved 单据，二者均可从截屏与日志摘录直接判定；与 api 侧 fail-closed 设计（`nodes.py` 无新鲜 approved 单据一律挂起）互为镜像。九条的可重试/用户可见列填写完整。

### 5. 思考轮 R0–R5 与 early_stop at R3 —— PASS

- 控制表 R0–R5 全行在位；R0 问题框定（单轨过闸 ≠ 咬合）→ R1 闸设计 → R2 步骤集（reject 不可省：approve-only 无法证「闸在拦」，论证成立）→ R3 红线钉死后 early_stop；R4/R5 回填「未开 · early_stop at R3」闭合；`actual_last_round`/`reason`/`residual_risks` 齐。
- early_stop 依据成立：验收面（步骤集 / 证据形式 / 红线 / 闸表）确已框死，起栈漂移等执行期变量挂账 residual_risks 属正确归口；与 T 先例（同 early_stop at R3）同构。思考审查通过。

### 6. lint 复跑 —— PASS

- `npx spec-wave task lint --file docs/tasks/active/task_stage_w_e2e_join_acceptance.md` → `LINT: PASS`（exit 0 · 2026-10-30 本棒复跑）。task 自检结论行所报 PASS 与本棒复跑一致。

### 7. 联调步骤 vs 码面实态抽验（只读）—— ISSUE（B1 涉 C6）· 余 PASS

抽验结果（全部只读，零改动）：

| task 步骤 | 码面锚点 | 核对 |
|-----------|----------|------|
| C2 拦单挂起 + `/hitl` 列表见单 | api `app/ops/lg_rag/multi/nodes.py:314`（`_BLOCKED_BY_CAPABILITY_WRITE = "capability_write_hitl_required"`）· `nodes.py:1868-1910`（无新鲜 approved 单据 → blocked → `_persist_hitl` 建 pending 单 → `interrupt`，`nodes.py:2356`）· 挂起载荷 `_hitl_interrupt_payload`（`nodes.py:2243-2266`，`reason: hitl_waiting`） | ✅ 一致（fail-closed · 审批前无写执行可观察） |
| C3 approve 两步链 + resume 单路径 | web `src/api/hitl.ts:94-106`（`decideHitlRequest` · inherit 不送键 :100）· `hitl.ts:109-113`（`resumeHitlRequest` 显式第二步）· api `app/ops/hitl/router.py:190-259`（decide 不自动 resume · resume_mode 白名单 400 :204-208） | ✅ 一致（对着真实端点） |
| C5 `approval_id` 审计链 | `nodes.py:505-530`（消费台账 + span `_record_span_metadata` 落 `approval_id`）· `nodes.py:1941-1946`（`cap_ctx["approval_id"]` 注入写执行） | ✅ 一致（三段可串链） |
| C7 `/hitl` 页 | web `src/router/index.ts:87-88`（`/hitl` 路由 · name `hitl` · AppLayout children 在位） | ✅ 一致 |
| 引用 commit | `f048c57` ∈ api master ✅ · `09f97f4` = PR #303 merge commit ✅ · `227a482` = feat commit ✅ | ✅ 字面全对 |
| **C6 跨租户负样本（decide → 404）** | api `app/ops/hitl/router.py:209-216`（decide 鉴权 = **owner-only**：`owner != str(user.id)` → 404，**无租户过滤**）· `app/ops/hitl/store.py:168-201`（aget/alist 的 WHERE 无任何 tenant 谓词，tenant_id 仅落库不滤）· 真正的跨租户写 fail-closed 在**消费侧**：`nodes.py:499-504`（capability_write 类单据 `tenant_id` 缺失或与当前租户不一致 → 不消费维持拦截），单测 `tests/test_write_approval_gate.py:431-475`（W2①②③ 均为「不消费」语义，**无一条测 decide 跨租户 404**） | ❌ **矛盾 → B1** |

---

## 阻塞项（blocker · 内容）

### B1 · C6/A4「跨租户单据 decide → 404」与码面实态矛盾（退回 10-task）

**事实链**（均为本棒只读核实）：

1. api decide 端点鉴权是 **owner-based**（`router.py:213-216`：run 归属他人/不可判定 → 404），**不查租户**；hitl store 查询无 tenant 谓词（`store.py:171,184`）。
2. 双租户 fixture 下「切租户 A 会话」最自然的读法 = **同一维护者用户切换 session 租户**（契约 F6 切换语义即写 session 再带头）。此时对租户 B 单据 decide：owner 相同 → **返回 200 置已决，不会 404**。C6 字面条文 live 不可复现。
3. 若改用「租户 A 用户 ≠ 租户 B 用户」读法，decide 确实 404——但那是 **hitl-browser-decide-v1 的 owner-404**（「未知/跨用户 → 404」），不是 task 标注的 **F4 租户 404**；机制错标。
4. F4 真正的跨租户写 fail-closed 落点在**审批消费侧**（`nodes.py:499-504` 租户不一致不消费 → 写维持拦截）与**资源命中侧**（F4 对外 404，阶段 T `test_tenant_context.py` 承接）——两者都可 live 实测，但都不是 C6 现在写的「decide → 404」。
5. A4 又红線「不接受单测已覆盖代替 live 实测」并要求「跨租户单据 decide 404 摘录」——条文自相顶死：按字面执行要么卡住、要么诱使证据凑数。验收条文与反造假红线互相打架，必须在 10 层修掉，不能留给执行期自由发挥。

**修补方向（建议 · 具体措辞由 10-task 定）**，三选一或组合：

- (a) C6 主测改为**消费链 live 实测**：B 会话造单并 approve → 切 A 会话再触发同写 / 观察 → 断言写**不执行**（维持拦单 · 台账 tenant 不一致）+ 拦单证据摘录；此与 `test_w2_cross_tenant_approval_not_consumed` 语义同构但为 live 双栈实证，满足 A4「不接受单测代替」红线。
- (b) 保留一条 404 但改指**资源命中**（A 会话直取 B 资源 id → F4 对外 404），机制标注为 F4；decide 的 owner-404 如要保留则单列并如实标注「owner 语义（hitl-browser-decide-v1）· 非同用户」。
- (c) A4 证据行同步改写，去掉「跨租户单据 decide 404」字面条文，替换为 (a)/(b) 的实际可观测证据。

**影响面**：仅 C6 / A4 两条措辞 + failure_paths 行 3 的同步对齐；不动闸表、不动其他验收条。

---

## 非阻塞项

### minor

- **M1 · C7/A5 回填面张力**：头部执行模式写「本 task 只改本仓文档/证据」，但 C7/A5 允许「在 web task 回填」——web 仓 `done/` 文档编辑虽不碰业务码，仍属跨仓写。建议 10 补一句澄清（如「回填限 web 仓 task 文档轨 · 禁碰 `src/`」），或收紧为「一律另开回填 task 指针互链」。
- **M2 · 状态行/修订表未随闸签收刷新**：头部第 3 行仍写「人工闸均 `pending`」，与闸表 HG-TASK-DRAFT=approved（2026-10-30 · 00 代录）不一致；修订表缺该签收的 00 代录行（T 先例有此行：`task_stage_t_tenant_contract.md` 修订表「00 记录：维护者签收 HG-TASK-DRAFT → approved」）。闸表本身是真值且正确，属文档卫生，随 B1 修补同棒刷掉即可。

### note（观察 · 不要求改）

- **N1 · A6 自证形态**：「真人 decide」的可验证性终归是 invoke 声明 + 40 核对 + 红线威慑，属该类验收固有形态；现缓解（验收整体无效 + 40 拒收）已到位。执行期建议 invoke 记录附操作者与时间戳粒度，增强可审计性（不强制）。
- **N2 · HG-E2E-ENV 与 HG-AUDIT-R1 可同修后并签**：两闸均 blocks 联调执行，B1 修补后一并签收不冲突；但**禁止**在 HG-AUDIT-R1 仍 pending 时先签 HG-E2E-ENV 开跑（闸序语义 = 内容先定稿再确认环境）。

---

## 回填清单（退回 10-task）

| # | task 小节 | 回填要求 |
|---|-----------|----------|
| B1 | §范围 C6 · §验收 A4 · §failure_paths 行 3 | 按上文 (a)/(b)/(c) 方向修「跨租户 decide → 404」条文，对齐码面真实 fail-closed 链（消费侧租户不一致不消费 / 资源命中 F4 404 / owner-404 如实标注）；failure_paths 行 3 同步 |
| M1 | §范围 C7 · §验收 A5 | 一句澄清回填 web 仓限 task 文档轨（或收紧为另开回填 task 互链） |
| M2 | 头部状态行 · §修订 | 状态行刷新为 HG-TASK-DRAFT approved；修订表补 00 代录签收行 |

修补后走 20-R2 轻量复审（仅核 B1/M1/M2 三处 diff），通过后再请维护者签闸。

---

## 维护者签闸（待 B1 修补 + R2 复审通过后执行 · 当前冻结）

- [ ] 已读 R1（及 R2 复审）审查结论
- [ ] 在 task 人工闸表将 HG-AUDIT-R1 改为 approved（维护者 · 日期）
- [ ] 在 task 人工闸表将 HG-E2E-ENV 改为 approved（维护者 · 日期 · 确认本地双栈 + Fixture 口径）
- [ ] commit task 文档或确认已签
- [ ] 再派联调执行棒（过程轨 · 无 30）

> 当前 HG-AUDIT-R1 = pending 且存在内容阻塞 B1：**不建议签收**；执行棒届时以 task 表为准，pending 必须拒开工（`docs/harness/prompts/TEMPLATE_30_gate_stop.md` 同口径）。

---

## 自检（本审查棒）

| 检查 | 结果 |
|------|------|
| 只审不改（task 实质 / 闸表 / 契约 / 码面零改动） | ✅ 本棒仅新增本审查文一个文件 |
| 代签 human_gate | ✅ 无（HG-AUDIT-R1 / HG-E2E-ENV 维持 pending，由维护者签） |
| lint 复跑留痕 | ✅ PASS（2026-10-30） |
| 码面抽验留痕 | ✅ 锚点见 §7 表（api nodes.py / hitl router.py / store.py / tests · web hitl.ts / router/index.ts） |
