# 简报 · Ops Desk 阶段 H α 收口后 · 总 00 必读

| 项 | 内容 |
|----|------|
| **状态** | `active` · 给 **workspace 总 00** 的上下文简报 |
| **日期** | 2026-09-17 |
| **Open Folder** | `ops-desk-workspace/`（跨仓统筹） |

---

## 1. 当前水位（事实）

| 层 | 状态 |
|----|------|
| 迁移主线 | **已上线**（公网）；Chat 主路径 `POST /api/ops/lg-rag/stream`；旧 `/chat/stream` → 410 |
| 前端 Chat | web lg-rag SSE T2–T6 + subtask 过程可见 **已合入**；联调清单见 web `docs/checklists/CHECKLIST_lg_rag_sse_joint_release_v1.md` |
| **阶段 H · 波次 α** | **api CLOSE（2026-09-17）** · task → `ops-desk-api/docs/tasks/done/task_capability_contract_hardening.md` |
| H α 合入 | **已合入 `master`**：PR [#138](https://github.com/Cyning12/ops-desk-api/pull/138) · merge `48f0ac2`（含 `schema_validate.py`）· 本机 `master` ≡ `origin/master` |
| 阶段 H · 波次 β | **CLOSE + MERGED（2026-09-18）** · task → `ops-desk-api/docs/tasks/done/task_supervisor_budget_h_beta.md` · PR [#141](https://github.com/Cyning12/ops-desk-api/pull/141) |
| web 冒烟 | **PASS**（含维护者生产 Chat 无问题） |
| 阶段 T / W / P | ~~T：条件核对 + 数据前置 + task 壳已落（NO-GO 30）；W/P 未开~~ **2026-10-30 实态**：T 已 **CLOSE**（契约 F1–F6 freeze 2026-09-18 · api PR [#142](https://github.com/Cyning12/ops-desk-api/pull/142) · workspace PR [#13](https://github.com/Cyning12/ops-desk-workspace/pull/13) · Fixture 轨）；W 双轨单轨验收均 **CLOSE**（api 受控写 PR [#303](https://github.com/Cyning12/ops-desk-api/pull/303) merge `09f97f4` 2026-10-30 · web HITL 审批页已合 main · TC9 待维护者手测）；双轨端到端联调验收已 **CLOSE**（2026-11-03 维护者拍板 · 验收 A1–A8 全勾 · [`docs/tasks/done/task_stage_w_e2e_join_acceptance.md`](../tasks/done/task_stage_w_e2e_join_acceptance.md) · 证据锚 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/`）；P 未开（进入条件未达） |
| T 进入条件抽查 | H 契约测绿 ✓ · 冒烟 ✓ · **H β MERGED ✓**；**第二租户试点数据 ✗** → 见 `06_stage_t_second_tenant_prep_v0_zh.md` |
| T task 壳 | workspace `task_stage_t_tenant_contract` · api `task_tenant_readonly_predicate` · web `task_web_tenant_context_chat` |

> 修订注记（2026-10-30 · 文档健康巡检 night-1030）：本表「T 进入条件抽查 / T task 壳」两行、§3「下一候选」表、§4「推荐下一刀：web 冒烟」均为 2026-09-17/18 时点快照，已被后续阶段推进超越——当前实态以上表「阶段 T / W / P」更正行与文末修订表为准；§3 阶段序代码块（H→T→W→P）本身仍有效，不改。

---

## 2. 阶段 H α 已交付（验收 A–F）

真值：`ops-desk-api/docs/harness/invokes/by-task/capability-contract-hardening/invoke_20260917_40_verify_*.md` · `invoke_20260917_00_CLOSE_*.md`

| ID | 成果 |
|----|------|
| A | 默认 lookup / `utc_now_iso` 最小 `args_schema`；不合规 → `ok=False` / `args_schema_invalid` |
| B | `SubtaskItem.args`；`tool_exec` 优先 args、兼容 input |
| C | `agent_type`/`mode` allowlist；`None`≠全开；未知 key fail-closed `[]` |
| D | `tenant_scoped` + Policy；lookup 缺租户拒；tool_exec 试点注入 `tenant_id` |
| E | span：args 摘要、policy、`subtask_id`；`approval_id` 预留 |
| F | 「进程内注册表」口径；业务不变量不进 schema（P-16） |
| 门禁 | pytest 76 passed · ruff · graph-compile · verify PASS · `chat/graph.py` 零 diff |

**刻意未做：** 多 Workspace 产品、写能力/HITL、服务化 Registry、完整本体包、改 SSE freeze。

---

## 3. 更新方向（串行 · 勿跳）

决议真值：`ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` §8

```text
H α CLOSE ✓
  →（可选）H β supervisor 预算
  → 阶段 T 只读多租户（api + web 双仓）
  → 阶段 W 受控写 + HITL（api + web）
  → 阶段 P 平台项（按需）
```

| 下一候选 | 仓 | 前端？ | 备注 |
|----------|----|--------|------|
| ~~H 合入后冒烟~~ | — | — | **已 PASS** |
| ~~H β 预算~~ | — | — | **CLOSE + MERGED #141** |
| **阶段 T 数据前置（推荐下一刀）** | workspace + 运维 | 否（先） | D1–D3；签 `HG-STAGE-T-DATA` |
| **阶段 T 契约定稿** | workspace | 否 | F1–F6 · `HG-CONTRACT-FREEZE` |
| **阶段 T 实现** | api + web | **要**（默认仅请求注入；UI=D5） | 双闸齐后再 30 |
| 阶段 W | 同上 | **要**（确认单/HITL） | 禁止跳过 T |

**H 与前端：** 零 SSE 契约变更前提下 **无强制 web 研发**；合入后冒烟即可。

---

## 4. 总 00 首轮产出（掌握成果后）

1. ≤20 行「现状 + 缺口」确认（对照本简报，标出与磁盘不符处）  
2. 推荐下一刀：主推 **web 冒烟（A 残差）**；H β / 阶段 T 立项为备选（须列进入条件）  
3. 若推 T：先列 workspace 契约草稿要点 + api/web 子 task 拆分表（**先不改码**）；第二租户数据未齐则停在条件核对  
4. 产出可复制的子仓 00/10 Prompt（见 §5）

---

## 5. 关键路径速查

| 文档 | 路径 |
|------|------|
| 本简报 | `ops-desk-workspace/docs/05-plan/05_post_h_stage_brief_v1_zh.md` |
| 决议 H→T→W | `../ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md` |
| H CLOSE | `../ops-desk-api/docs/harness/invokes/by-task/capability-contract-hardening/invoke_20260917_00_CLOSE_*.md` |
| H done task | `../ops-desk-api/docs/tasks/done/task_capability_contract_hardening.md` |
| Agent 完善线 | `docs/05-plan/04-agent-completion-roadmap_v1_zh.md` |
| 跨仓沟通 | `docs/01-scope/02-cross-repo-communication.md` |
| web 联调清单 | `../ops-desk-web/docs/checklists/CHECKLIST_lg_rag_sse_joint_release_v1.md` |
| 总 00 冒烟 Prompt | `docs/harness/invokes/by-task/ops-desk-post-h-stage/PROMPT_web_00_smoke_post_h_alpha.md` |
| T 条件核对 Prompt | `docs/harness/invokes/by-task/ops-desk-post-h-stage/PROMPT_ws_00_stage_t_entry_check.md` |

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-09-17 | 首版：H α CLOSE 后给总 00 的掌握简报 |
| 2026-09-17 | 总 00 磁盘纠偏：PR #138 已合入 master；T 缺第二租户试点；下一刀主推 web 冒烟 |
| 2026-09-17 | 冒烟 PASS · H β 开壳 · T 条件 NO-GO 30 + 数据前置/契约草稿落盘 |
| 2026-09-17 | H β 全链 CLOSE（10→40·00）· 待维护者 commit/PR |
| 2026-09-18 | H β commit/PR [#141](https://github.com/Cyning12/ops-desk-api/pull/141) · CLOSE 补完（KPI/Hub） |
| 2026-09-18 | #141 MERGED 纠偏 · 阶段 T 三仓 task 壳落盘 · 下一刀改为 D1–D3 数据前置 |
| 2026-10-30 | §1 水位行更正：T 已 CLOSE（api PR #142 · workspace PR #13 · Fixture 轨 · F1–F6 freeze）· W 双轨单轨验收 CLOSE（api PR #303 merge `09f97f4` · web HITL 审批页合 main · TC9 待手测）· 双轨联调 task 在途（PR #14 · HG-TASK-DRAFT approved）· P 未开；§1 余行/§3/§4 时点快照加注（文档健康巡检 night-1030） |
| 2026-11-03 | §1「阶段 T / W / P」行更正：双轨端到端联调验收 **CLOSE**（维护者拍板 · 验收 A1–A8 全勾 · task 迁 `done/` · 证据锚 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/`）· 指针随迁 done/ |
