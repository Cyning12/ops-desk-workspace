# 20-task-audit R2 审查文 · 阶段 W 双轨端到端联调验收 task

- **审查帽**：Harness 20（task 书面审查 R2 · 轻量复审）· 只审不改 · 不代签任何 human_gate
- **审查对象**：`docs/tasks/active/task_stage_w_e2e_join_acceptance.md`（commit 3707ec8 · 10 承接 20-R1 修订棒；后续 f15e1af 仅动 invoke 文件，task 文件未再变）
- **派单范围**（00 派 · 2026-10-30）：仅核 R1 三项 B1 / M1 / M2 是否闭环（含与码面再对拍一次 `nodes.py:499-504` / `router.py:213-216` 引用准确性）+ lint 复跑
- **前序**：R1 审查文 `docs/harness/reviews/task_stage_w_e2e_join_acceptance_audit_R1_20261030.md`（B1 blocker 退回 10 · M1/M2 minor）
- **日期**：2026-10-30

---

## 总体结论

**B1 语义闭环 ✓ · 引用准确性未闭环（新 minor M3）· M1 闭环 ✓ · M2 闭环 ✓ · lint 复跑 PASS**

10 的回填方向、语义与结构均按 R1 修补意见落地且与码面机制一致；但回填引入一处新的引用路径错误（M3，两处全路径引用把消费侧文件写成 `app/ops/hitl/nodes.py`，真实路径为 `app/ops/lg_rag/multi/nodes.py`）。本 task 是证据纪律轨，引用块存在的意义即钉码面真值，**建议 10 修正两行路径后维护者并签 HG-AUDIT-R1 + HG-E2E-ENV**；不建议带错路径签闸。

---

## 逐项判定

### B1（跨租户负样本口径 vs 码面）—— 语义闭环 ✓ · 引用准确性 ✗（M3）

**语义面全部落地，且与码面机制一致**：

- 背景节新增「跨租户码面口径」引用块（task :58）：owner-only 闸 · store 无 tenant 谓词 · 切租户 decide 返 200 属预期 · 真 fail-closed 在消费侧 · owner-404 ≠ F4 · F4 404 移至资源命中面——与 R1 核对结论逐点对应 ✓
- C6 主测改消费链 live 实测（task :78）：B 会话拦单 → A 会话 decide=approve → 断言写不执行 · 拦单维持挂起 · 台账不被消费；decide 200 标注预期；F4 资源命中面 404 + 头/session 403（F1=C）抽测 ✓
- 完成态④（task :65）· A4 证据行三段改写（task :100：消费链摘录 / F4 资源命中 404 / 头 session 403 · 「单测已覆盖」不可替代红线保留）· failure_paths 行 3 同步改写（task :114）+ 新增「200 误判缺陷 / 误称 owner-404=F4 → 40 纠回不开空 fix task」行（task :115）✓

**C6 预期行为的机制真实性（R2 新增对拍）**：

- `app/ops/hitl/resume.py` 全文（384 行）**无任何 tenant 引用**——resume 入口（decide 后恢复执行路径）不设租户 ContextVar
- `app/ops/tenant_context.py:24-26` `current_tenant_or_default()` = `_current.get() or TENANT_A`（`TENANT_A="ops-desk-pilot"`）；`set_current_tenant` 仅在 `app/ops/lg_rag/router.py:398`（SSE 入口）与 `app/ops/lg_rag/run_worker.py:120` 设置
- 推论：C6 场景下 resume 路径租户回落默认 A ≠ 单据租户 B → `nodes.py:499-504` 租户不一致不消费 → 写不执行 / 拦单维持，与 C6 断言一致 ✓（机制成立，非纸面断言）

**引用准确性对拍**：

| task 引用 | 码面实态 | 判定 |
|---|---|---|
| `app/ops/hitl/router.py:213-216`（:58 · :78 · :205） | `router.py:213-216` = owner 取出 + `owner != str(user.id)` → 404 | ✓ |
| `store.py:171,184`（:58 · :78 · :205） | `app/ops/hitl/store.py:171` aget / :184 alist 查询均无 tenant 谓词 | ✓（同目录简写可解） |
| `tests/test_write_approval_gate.py:431-475`（:58 · :78） | :431 `test_w2_cross_tenant_approval_not_consumed` · :457 租户不符 · :474-475 缺租户行，全是「不消费」语义 | ✓ |
| **`app/ops/hitl/nodes.py:499-504`（:58 引用块 · :78 C6）** | **api 仓 `app/ops/hitl/` 下无 `nodes.py`**（目录仅 auto_resume/persistence/resume/router/signature/store）；真实文件 `app/ops/lg_rag/multi/nodes.py`，行号 499-504 内容正确（消费台账租户闸） | **✗ 路径错**（M3） |
| `nodes.py:499-504` 裸名简写（:65 完成态④ · :205 修订表） | 上下文可解，可不动 | △ 接受 |

### M1（TC9 回填限 web 仓文档轨）—— 闭环 ✓

三处全部澄清且口径互洽：

- 非范围（task :91）：「web 仓**业务码**任何改动（TC9 回填限 web 仓**文档轨**：task 档勾选/状态行）」
- C7（task :79）：「回填 web task **文档轨**（task 档勾选/状态行 · **不改 web 业务码**；或另开回填 task，指针互链）」
- A5（task :101）：「回填 web task **文档轨**（不改 web 业务码）或另开回填 task 互链」

与头部「只改本仓文档/证据」的表面张力已消除 ✓

### M2（闸态同步 + 修订表签收行）—— 闭环 ✓

- 状态行（task :3）：`HG-TASK-DRAFT approved（00 代录）· HG-AUDIT-R1 / HG-E2E-ENV pending · 20-R1 修订棒已回填 B1/M1/M2` ✓
- 自检结论（task :194-195）同步 ✓
- 修订表（task :204）补 00 代录签收行（对齐阶段 T 先例）·（task :205）20-R1 修订行 ✓

### lint 复跑 —— PASS

`npx spec-wave task lint --file docs/tasks/active/task_stage_w_e2e_join_acceptance.md` → `LINT: PASS`（exit=0 · 2026-10-30 R2 棒）

---

## 发现分级

- **blocker**：无
- **minor**：
  - **M3**：task :58 与 :78 两处全路径引用 `app/ops/hitl/nodes.py:499-504` 路径错误，应为 `app/ops/lg_rag/multi/nodes.py:499-504`（行号正确 · 目标文件唯一可定位 · 其余引用全对）。定级 minor 而非 blocker：语义面已闭环、错误不致误导执行结论（文件不存在会立即暴露、按行号可定位真文件）；但本 task 全程钉「证据如实 / 码面真值」，引用块本身的指针必须为真，签闸前应修正。
- **note**：
  - **N-R2-1（执行期观察点 · 非本 task 阻塞项）**：resume 入口不设租户 ContextVar（见 B1 机制对拍），意味着 **B 租户单据即便由 B 会话自己 approve + resume，消费侧租户也会回落默认 A 而不消费**——疑似 api 侧潜在缺陷（或有意设计）。本 task 执行期若实测到该现象，按既有口径处理：C6 场景（A 会话 decide）断言不变；「B 自己 approve 也不消费」属缺陷面 → 按 A7 记缺陷另开 fix task，**不在本 task 内修、不影响本 task 验收口径**。提示 40 执行棒留意区分两类观察。

---

## 签闸建议

- **HG-AUDIT-R1**：**暂缓，待 M3 修正后签**。M3 为纯机械路径订正（两处 `app/ops/hitl/nodes.py` → `app/ops/lg_rag/multi/nodes.py`），20 帽意见：修正属 R2 结论的直接执行，diff 目验即可，**无需再开 R3 全量复审**；若流程从严，R3 一句话确认亦可。
- **HG-E2E-ENV**：口径本身 R1 已判合格无漏洞，**与 HG-AUDIT-R1 同修后并签**；当前 HG-AUDIT-R1 pending 期间执行棒必须拒开工。
