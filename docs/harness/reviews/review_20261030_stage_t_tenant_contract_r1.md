# 审查文 · task_stage_t_tenant_contract · 20-R1

| 项 | 内容 |
|----|------|
| **审查帽** | 20-task-audit（R1 · 书面审查 · 只核对不改实质） |
| **审查对象** | `docs/tasks/active/task_stage_t_tenant_contract.md`（HG-TASK-DRAFT 已于 2026-10-30 维护者签收 approved） |
| **本窗差异** | `docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md`（纠偏）· `docs/contracts/api-v1-tenant-readonly-context-draft.md`（+1 行复核）· task 本体（完成态/范围勾选/自检回填） |
| **上游真值** | `docs/05-plan/05_post_h_stage_brief_v1_zh.md` · api `docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` §8 |
| **磁盘证据** | api `docs/tasks/done/task_tenant_readonly_predicate.md` · web `docs/tasks/done/task_web_tenant_context_chat.md` · api git：`4896701`（Merge PR #141）· `f048c57`（阶段 T 租户谓词，**已核实 ∈ master**）· `alembic/versions/20260918_tenant_readonly.py` 存在 · web git：`ffff3ce`（PR #76 联调 PASS）· `88e83d9`（PR #77 CLOSE 关账迁 done/） |
| **分支核实** | `task/stage-t-tenant-contract` ✅（与 task 元信息一致） |
| **日期** | 2026-10-30 |
| **仓规条款一** | 本审查即流程类 task 的 20-R1 审查文，满足「禁用 --allow-no-review」条款 |

---

## 结论摘要

- **内容面**：**零 blocker**。八项清单七项 PASS，一项 PASS 附 minor（清单 7 连带发现契约 §4 一行过时，见下）。
- **流程闸**：`HG-AUDIT-R1` = **pending**（blocks：本仓若有图谱大改；task 注「过程轨薄改可 00 代签；默认无应用 30」）。按纪律，本审查文**不附 30 Prompt**，文末仅列维护者签闸清单。
- **建议**：维护者可签 `HG-AUDIT-R1`（或由 00 按 task 注代签）并 **CLOSE**；CLOSE 前建议 10 帽顺手修正契约 §4 一行（minor，非阻塞）。

---

## 逐项结论（对照审查清单）

### 1. 范围/非范围 — PASS

本窗 `git diff` 仅触及本仓三个文档（06 · 契约 · task 本体）+ 新增 `docs/harness/invokes/by-task/stage-t-tenant-contract/` 两个 invoke 记录（文档轨）。**无** api/web/ios 业务码改动；子仓既有代码（`f048c57` 等）为历史已入库事实，非本窗改动。符合「过程轨只改本仓文档/契约」非范围约束。

### 2. 人工闸表 — PASS

五闸 status 与 blocks_hats 语义一致：

| 闸 | status | 核对 |
|----|--------|------|
| HG-TASK-DRAFT | approved（2026-10-30 维护者签收） | ✅ 修订表有 00 签收记录；说明明确「解锁 20-R1 · **不**因签收本闸而开子仓 30」，与 HG-STAGE-T-DATA 双闸不冲突 |
| HG-AUDIT-R1 | pending | ✅ blocks「本仓若有图谱大改」，过程轨薄改可 00 代签 |
| HG-GRAPH-MODULES | pending | ✅ blocks「改总图时」，本窗总图零 diff（C5 按默认跳过） |
| HG-STAGE-T-DATA | approved（2026-09-18） | ✅ blocks 派 api/web 30，Fixture 轨授权语义清晰 |
| HG-CONTRACT-FREEZE | approved（2026-09-18 · 00 代签维护者接受 F4） | ✅ blocks api/web 30 联调语义 |

diff 证实 **10 帽未私动闸表**：本窗闸表唯一改动是 00 记录 HG-TASK-DRAFT 签收一行，修订表两条均注明「闸表 status 未动 / 其余闸 status 未动」。

### 3. 完成态 1–4 磁盘面 — PASS

1. **06 与磁盘一致** ✅：H β merge commit `4896701` = Merge PR #141 核实；D2 Fixture 证据 `f048c57` 经 `git merge-base --is-ancestor` 确认 **∈ api master**；迁移 `alembic/versions/20260918_tenant_readonly.py` 存在。
2. **契约 freeze 在文** ✅：标题「v1 freeze」· 状态行 `freeze` · §5 F1–F6 总表全 ✅ · freeze 闸指针在文。
3. **子仓壳指针指向 done/ 且真实存在** ✅：api/web done 文件均核实存在；web 壳 header 载「2026-10-17 CLOSE · 五闸全 approved · PR #76 · 归档 done/」，api 壳 header 载「2026-09-21 归档」。
4. **拒开工语义在文** ✅：完成态 4 + failure_paths 第 1 条 + 06 §1 GO/NO-GO 复核段三处一致。

### 4. failure_paths 五条 — PASS（附 note）

五条均与纠偏后实态自洽。第 1 条「D1–D3 未齐却派 api/web 30 → 拒开工」：Fixture 轨 D1–D3 已齐（该触发面对 Fixture 轨不再成立），但 task C2 与 06 §2 均明确「最小开工条 = D1+D2+D3 **对生产 P 轨真种子仍生效**」，故该 failure_path 作为 P 轨防护仍成立、无矛盾。**note**：未来修订可在第 1 条括注「（生产 P 轨真种子）」更精确，非阻塞。第 2–5 条（契约 freeze 静默改义 / 跳 T 开 W / 无联调闸改 SSE / 本仓误改子仓码）不受纠偏影响。

### 5. 思考轮 R0–R5 — PASS

控制表完整：五轮齐全，列（结论 / early_stop / reason / residual_risks）无缺；R3 `early_stop=yes`，reason「决策面已框定；字段钉死属维护者闸非再开轮」；`actual_last_round=R3` 已记录；R4/R5 标「未开 · early_stop at R3」。过程轨 task 决策面确已收束（上游 H→T→W 序与 06 进入条件已钉），停轮依据充分。

### 6. 验收标准六框 — 五框可勾 · 一框留 CLOSE

| # | 验收框 | 结论 |
|---|--------|------|
| 1 | 06 表 H β=CLOSE+MERGED；第二租户数据口径 | ✅ **可勾**（已按 Fixture/P 双轨拆分，HG-STAGE-T-DATA 已签） |
| 2 | 契约可勾选清单；未 freeze 前标 draft | ✅ **可勾**（已升 freeze，draft 标注要求仅适用 freeze 前；文件名留 `-draft` 不影响） |
| 3 | api/web 壳路径入 §依赖；slug 与 06 §3 一致 | ✅ **可勾**（done/ 路径核实存在；slug `tenant-readonly-predicate` / `web-tenant-context-chat` 两处一致） |
| 4 | lint PASS | ✅ **可勾**（本审查复跑 EXIT=0，见清单 8） |
| 5 | 闸表 blocks 语义写清 | ✅ **可勾** |
| 6 | CLOSE 时不得伪称已授权子仓 30 | ⏳ **留维护者 CLOSE 时勾**（现状合规：自检结论明确「生产 P 轨真种子未授权」，无伪称） |

### 7. 06 纠偏口径一致性 — PASS（连带发现 1 个 minor）

「Fixture 轨已走完 · 生产 P 轨仍 NO-GO（最小开工条 D1+D2+D3 真种子）」在 06（§1 复核段 · §2 表下双行 · §4 箓）与 task（C1/C2 · 自检结论）之间表述一致、无歧义。

**连带发现（minor）**：契约文件 §4（L48–50）仍写「数据前置 · **仍阻塞 30**」「D1 ✅ · **D2/D3 ⏳** · D5 ✅」，与纠偏后实态（Fixture 轨 D2–D4 ✅）不符；§6 复核行已声明「F1–F6 与磁盘实态一致 · freeze 维持」，但 §4 正文未同步。本窗契约 diff 只加了 §6 一行，§4 过时行属遗漏。**建议 10 帽一行修正**（如「Fixture 轨 D1–D5 ✅ · 生产 P 轨真种子另轨仍挡」）；不阻塞闸语义，是否随 CLOSE 一并处理由维护者定。

### 8. lint 复跑 — PASS

```
$ npx spec-wave task lint --file docs/tasks/active/task_stage_t_tenant_contract.md
LINT: PASS · task_stage_t_tenant_contract.md   (EXIT=0, 2026-10-30 20 复跑)
```

与 task 自检结论所记一致。

---

## 问题分级清单

| 级别 | 数量 | 明细 |
|------|------|------|
| **blocker** | **0** | — |
| **minor** | 1 | 契约 `api-v1-tenant-readonly-context-draft.md` §4 数据前置状态行过时（D2/D3 仍标 ⏳、「仍阻塞 30」），与 §6 复核行及 06 纠偏口径不一 → 退回 10 一行修正（不阻塞 CLOSE，维护者可定随 CLOSE 顺手处理） |
| **note** | 2 | ① failure_paths 第 1 条可括注「生产 P 轨真种子」更精确；② api `done/task_tenant_readonly_predicate.md` header 仍写「PR 未开、未合 master」，而 git 证实 `f048c57` 已 ∈ master——api 仓自身文档陈旧，**非本窗审查对象**，仅知会维护者（06 表述以 git 为准，正确） |

---

## 是否建议签 HG-AUDIT-R1 与 CLOSE

**建议**：是。内容面零 blocker，验收六框 1–5 已可勾；本 task 为过程轨、无应用 30，CLOSE 决策归维护者。`HG-AUDIT-R1` 可由维护者签 task 表，或按 task 注「过程轨薄改可 00 代签」由 00 代签。

## 维护者签闸（20 后 · CLOSE 前）

- [ ] 已读 R1 审查结论（本文）
- [ ] 在 task 人工闸表将 HG-AUDIT-R1 改为 approved（维护者 · 日期；或授权 00 按 task 注代签）
- [ ] （可选）令 10 修正契约 §4 一行过时状态（minor）
- [ ] 勾选验收框 1–5；CLOSE 时勾框 6（确认未伪称授权子仓 30 · 生产 P 轨真种子未授权）
- [ ] commit task 文档与审查文；CLOSE 决策与时机归维护者

本 task 无应用 30；按纪律（HG-AUDIT-R1 尚 pending）本审查文不附任何 30 Prompt。
