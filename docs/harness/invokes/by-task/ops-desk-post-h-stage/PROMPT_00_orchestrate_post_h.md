# PROMPT · 00 · Ops Desk 总调度（H α 收口后 · 掌握成果 → 定下一刀）

> **Open Folder**：`ops-desk-workspace/`（不是单开 api）  
> **角色**：跨仓 00 · 不写 web/api/ios 业务实现码  
> **日期**：2026-09-17  
> **上游简报**：[`../../05-plan/05_post_h_stage_brief_v1_zh.md`](../../05-plan/05_post_h_stage_brief_v1_zh.md)

---

## 复制区（整段粘贴为新窗首条用户消息）

`````text
你是 Ops Desk 的跨仓 00 统筹（hat 00）。

Open Folder = ops-desk-workspace/ 仓根。
禁止在本窗直接改 ../ops-desk-api、../ops-desk-web、../ops-desk-ios 的业务实现（app/src 等）；实现交各子仓 Agent，经契约 + handoff Prompt 派发。

════════════════════════════════════
维护者意图
════════════════════════════════════
阶段 H 波次 α 已在 api 仓 CLOSE。请你：
  (1) 先掌握当前成果与更新方向（对照磁盘真值，纠正过期认知）；
  (2) 再提出「下一步」统筹方案（推荐下一刀 + 跨仓拆分 + 可复制子 Prompt）；
  (3) 未经维护者确认前，不要擅自开阶段 T/W 的 30 改码，也不要扩到 Coding Agent / 自动合 PR。

过程文档：可在 workspace 落简报修订、跨仓 task 壳、invoke、契约草稿。
人工闸代签：默认不代签子仓 HG-*；若维护者本消息另授「00 代签过程闸」再写入 invoke。本窗首要是对齐与规划。

════════════════════════════════════
必读（按序 · 先掌握再规划）
════════════════════════════════════
1) docs/05-plan/05_post_h_stage_brief_v1_zh.md          ← 本波简报（成果 A–F + 方向）
2) ../ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md
   重点 §5 进度、§8 H→T→W（α CLOSE；β 挂账；T/W 未开）
3) ../ops-desk-api/docs/harness/invokes/by-task/capability-contract-hardening/invoke_20260917_00_CLOSE_capability-contract-hardening.md
4) ../ops-desk-api/docs/harness/invokes/by-task/capability-contract-hardening/invoke_20260917_40_verify_capability-contract-hardening.md
5) ../ops-desk-api/docs/tasks/done/task_capability_contract_hardening.md
6) docs/05-plan/04-agent-completion-roadmap_v1_zh.md     ← 线 A 完善（只读 Demo/RAG 水位）
7) docs/01-scope/02-cross-repo-communication.md          ← 契约先行
8) AGENTS.md（本仓）+ 父目录 Ops-desk/AGENTS.md 开 Folder 纪律

抽查（掌握用，不必改码）：
  - api：capability schema_validate / tenant_scoped / allowlist 配置是否在分支未合入 master
  - web：主 Chat 是否仍只打 /ops/lg-rag/stream（H 零契约则无强制改 UI）

════════════════════════════════════
你必须先输出的「掌握确认」表（首条回复）
════════════════════════════════════
用表格回答（对照磁盘，勿背简报空转）：

| 项 | 你的结论 | 证据路径 |
|----|----------|----------|
| H α 是否 CLOSE | | |
| A–F 各一句 | | |
| commit/PR 是否已合入 main/master | | |
| H β / T / W 状态 | | |
| 前端对 H 是否必须改码 | | |
| 与 04-agent-completion 的关系（并行/串行） | | |

若发现简报与磁盘冲突：以 invoke/CLOSE/done task 为准，并列出冲突点。

════════════════════════════════════
掌握后的规划产出（第二条或同条后续）
════════════════════════════════════
1) 推荐下一刀（只能主推一个）：
   - 选项 A：维护者合入 H α PR + web 冒烟（无新功能）
   - 选项 B：api 开 H β（supervisor 预算）
   - 选项 C：workspace 立项阶段 T（只读多租户）——须列进入条件是否满足（第二租户试点数据？）
2) 给出跨仓拆分表：workspace / api / web / ios（ios 默认非本波）
3) 风险与非范围：禁止跳过 T 直接 W；禁止 SSE 无联调闸就改 freeze
4) 产出 1～2 份「可复制 Prompt」交给子仓 00 或 10（路径建议落在本仓 docs/harness/invokes/by-task/ops-desk-post-h-stage/）

════════════════════════════════════
硬约束
════════════════════════════════════
- 遵守契约先行：跨仓接口先写 docs/contracts/ 或等价草稿
- 不实现子仓业务码；不扩阶段 P（服务化 Registry/完整本体）除非维护者点名
- 简历/对外口径：注册表 ≠ 注册中心；写能力未交付
- 维护者未令 commit/push → 不 push 各仓

当前棒：先读完必读 → 输出「掌握确认」表 → 再输出下一刀方案与子 Prompt。
`````

---

## 维护者备注（勿贴进复制区）

| 项 | 说明 |
|----|------|
| 开窗 | Cursor / Claude：**Open Folder = `ops-desk-workspace`** |
| 若要总 00 代签子仓闸 | 在粘贴后再加一句：`授权本窗 00 代签各子仓过程文档与 HG-*` |
| H α 未合入前 | 总 00 应优先提示「合入 + 冒烟」，再开 T |
| 与 api 单仓 00 | api 的 `capability-contract-hardening` 00 已 CLOSE；后续跨仓改由本 Prompt 接管 |
