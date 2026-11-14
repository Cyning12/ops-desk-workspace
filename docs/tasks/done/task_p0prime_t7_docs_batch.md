---
task_id: task_p0prime_t7_docs_batch
type: docs
status: active
created: 2026-11-14
updated: 2026-11-14
wave: p0prime-t7-docs-batch
harness:
  hats_planned: [00, 20, 30, 40, 50]
  required_invoke_hats: [00, 30]
  invoke_retention_profile: minimal
  experience_capture: recommended
  close_pr_policy: direct-main
---

# task_p0prime_t7_docs_batch · P0' T7 文档与契约批

> **状态**：`done`

## Harness 元信息

| 字段 | 值 |
|------|-----|
| 授权 | 维护者 m00177「签收，开始」 · issue Cyning12/ops-desk-workspace#23 R4 开工就绪包 §2 任务卡 T7 · §5 明细五项 |
| 上游 | 06-kickoff-readiness.md（commit c7e4f3e） |
| **task_slug** | `p0prime-t7-docs-batch` |
| **wiki_delta** | `docs/01-scope/00-project-brief.md` · `docs/contracts/chat-stream-v1.md` · `docs/README.md` · `docs/_tech_graph/00_main.graph.yaml`（+`.md` 重编译）· `.gitignore` · `docs/04-infrastructure/00-local-postgresql-setup.md` · `docs/tmp/ios-00-agent-docking-prompt_v1_zh.md` |
| **wiki_delta_note** | T7 五项明细落盘 + 两处活引用修复；graph.json 移出跟踪（生成产物不入库） |
| **close_wiki_delta** | 与 wiki_delta 同面（close 仅 task 迁 done + invoke 50） |
| 跨仓 | 项 1–4 本仓；项 5 落 ops-desk-ios 仓（harness-only 3.5.0，另支提交） |

### 人工闸

| human_gate_id | status | blocks_hats | 说明 |
|---------------|--------|-------------|------|
| HG-TASK-DRAFT | approved | 30 | 维护者 m00177「签收，开始」覆盖 T1–T7 全链 |
| HG-AUDIT-R1 | approved | 30 | R1 审查（docs/harness/reviews/task_p0prime_t7_docs_batch_audit_R1_20261114.md）PASS |
| HG-GRAPH-MODULES | approved | 30 | 实体不适用（本仓无 01_modules 行级闸 · 承 task_workspace_specwave_upgrade_3_0_2 先例按惯例登记 approved）；项 4 为 tech_graph 清理+补边，graph 产物已重编译 check OK |

## 背景与目标

P0' 收尾任务卡 T7：简报刷新 + 契约修订五项（06-kickoff-readiness.md §5），消除「文档画像滞后于 lg-rag 上线后现实」的过时陈述与暗文档。验收（卡原文）：spec-wave verify 通过；无暗文档。

## 范围（§5 明细五项，逐项落位）

1. 改写 docs/01-scope/00-project-brief.md：多轮/ReAct 条款改「已随 lg-rag 上线」；L3 底座改 Qdrant 默认口径；面板降级标注「落地页已切 /chat、导航降级为 P3 路线项」；记旧 chat 410 下线。
2. docs/contracts/chat-stream-v1.md：追加「已被 lg-rag-sse-v1 + 03-general-agent 取代」状态行（整篇重写为 v2 另立 task，非本卡）。
3. docs/README.md：目录树补索引 01-scope/03-general-agent/。
4. docs/_tech_graph/：清理 shared/graph.json 残留；00_main.graph.yaml 补 runs/run_events 数据流边。
5. ops-desk-ios AGENTS.md:64：删除已 410 旧端点引用 /api/ops/chat/stream，改指 lg-rag 契约（ios 仓另支提交，本卡登记结果）。

## 非范围

- chat-stream-v1.md 整篇 v2 重写（另立 task）。
- 任何代码/迁移/端点变更；ios 仓代码面（仅 AGENTS.md 一行）。
- 03-general-agent 文档套内容修订（v2 已冻结，R5 另议）。

## 失败路径

| 风险 | 处置 |
|------|------|
| 简报改写越界成重构 | 仅四处定向修订，其余字节不动 |
| graph.json 残留实为活引用 | 清理前先 grep 全仓引用，确认死引用再删 |
| ios 仓工作区脏（他支 WIP） | 用独立 worktree 落 AGENTS.md，不触碰在途分支 |

## 验收标准

- [ ] 五项明细全部落盘（项 5 在 ios 仓另支，本卡登记 commit/PR 号）
- [ ] npx spec-wave verify --task 本卡通过
- [ ] grep 全仓无 /api/ops/chat/stream 活引用残留（docs 面）
- [ ] docs/README.md 可点击抵达 03-general-agent/（暗文档消除）

## 必读列表

- docs/01-scope/03-general-agent/06-kickoff-readiness.md §5（T7 明细原文）
- docs/01-scope/00-project-brief.md
- docs/contracts/chat-stream-v1.md
- docs/README.md
- docs/_tech_graph/shared/graph.json、docs/_tech_graph/00_main.graph.yaml

## 思考轮控制

| 轮 | 结论 | early_stop | reason（early_stop） | residual_risks |
|----|------|-----------|----------------------|----------------|
| R0 | 五项明细与仓内真值对齐（graph.json 产物属性 · ios :64 字面 · 简报过时节） | — | — | — |
| R1 | 审查 PASS（见审查文） | — | — | — |
| R2 | 简报仅四处定向修订防越界；批次决策面收束 | yes | 范围/非范围/验收/闸表已框死；docs-only 无代码/迁移面，R3–R5 无新信息可产 | 执行期：ios 仓在途分支脏文件（已用独立 worktree 规避） |
| R3 | （未开） | — | early_stop at R2 | — |
| R4 | （未开） | — | early_stop at R2 | — |
| R5 | （未开） | — | early_stop at R2 | — |

**actual_last_round**：R2 · **early_stop**：yes · **reason**：范围/非范围/验收/闸表已框死；docs-only 批次无代码/迁移面，R3–R5 无新信息可产 · **residual_risks**：ios 仓在途分支脏文件（已用独立 worktree 规避）；graph.json 产物属性已修正为「不入库」

### R0
对齐 §5 明细与真值：graph.json 为 graph-compile.sh 活产物（「残留」修正为「产物不入库」）；ios AGENTS.md:64 旧端点字面确认；简报四处过时点定位。

### R1
审查文 PASS：范围五项闭环、非范围划清、ios 跨仓处置（独立 worktree）明确。

### R2
简报改写限定四处定向修订；活引用两处修复纳入；决策面收束 → early_stop。

### R3 ·（未开 · early_stop）
### R4 ·（未开 · early_stop）
### R5 ·（未开 · early_stop）

### 自检结论

40 验证台账（2026-11-14）：

| # | 验证项 | 结果 |
|---|--------|------|
| 1 | 项 1 简报四处定向修订（多轮条款刷新 · L3 Qdrant · 面板降级/落地页 · 旧 chat 410） | ✅ 落盘，其余字节未动 |
| 2 | 项 2 chat-stream-v1.md 状态行「已被 lg-rag-sse-v1 + 03-general-agent 取代」 | ✅ |
| 3 | 项 3 docs/README.md 索引 03-general-agent/ | ✅ 暗文档消除 |
| 4 | 项 4a graph.json：git rm --cached + .gitignore（生成产物不入库）· graph-compile.sh 重跑 OK | ✅ |
| 5 | 项 4b 00_main.graph.yaml 补 pg 节点 + runs/run_events 落库边（kind=struct · store 非法已修正）· 重编译 check OK | ✅ |
| 6 | 项 5 ios AGENTS.md:64 改指 lg-rag 契约：ios PR #2 已 merge（独立 worktree 未触碰在途分支） | ✅ |
| 7 | grep /api/ops/chat/stream：两处活引用修复（infra curl 示例改 lg-rag · tmp 对接 prompt 加存档状态行）；其余命中均为历史/存档/已注记文档 | ✅ |
| 8 | npx spec-wave verify --task | ✅ VERIFY: PASS（体例修正五处：gate approved 登记 · task_slug/wiki_delta 元信息 · R3–R5 槽位+reason 点名 · 审查文结论节 · invoke 命名带 slug） |

偏差：① graph.json 实为 graph-compile.sh 活产物（调研「残留」判断修正为「产物不入库」而非删除脚本导出）；② graph kind 词表无 store，pg 节点用 struct；③ ios PR body 反引号被 bash 吞 → --body-file 修复。

## 实现备忘

- 简报：行 40 多轮条款加「已随 lg-rag 上线」刷新尾注；§5 增决策 11（L3 Qdrant 默认）/12（lg-rag 上线 · 旧端点 410 · 落地页 /chat · 面板降级 P3 路线项）。
- chat-stream-v1.md 文首加「已被取代」状态行；README 树补 03-general-agent/ 索引。
- tech_graph：graph.json git rm --cached + .gitignore（graph-compile.sh 每次重建 · 决策「废弃入库」）；00_main.graph.yaml 新增 pg 节点（struct）+ api→pg「runs/run_events 落库（P0' T4）」+ compose→pg 边，重编译 00_main.md 更新。
- ios：worktree /tmp/opsdesk-ios-t7（origin/master e456afb）改 AGENTS.md 开发约束行 → PR #2 squash merge。
- 活引用修复：04-infrastructure/00-local-postgresql-setup.md §7.2 curl 示例改 /api/ops/lg-rag/stream（query 字段）；tmp/ios-00 对接 prompt 加历史存档状态行。

## 测试策略（Harness）

- npx spec-wave verify --task docs/tasks/active/task_p0prime_t7_docs_batch.md
- grep 验收：/api/ops/chat/stream 活引用归零（docs 面）；README 索引可达。

## 修订记录

| 日期 | 修订 |
|------|------|
| 2026-11-14 | 初版（00 起草） |
