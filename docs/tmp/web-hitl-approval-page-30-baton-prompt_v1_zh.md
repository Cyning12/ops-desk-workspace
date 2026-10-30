# 派工 Prompt · web 阶段 W 第一棒：HITL 审批页 30 开工（v1 · 2026-10-30）

> **用途**：在 **ops-desk-web** 仓开新窗口，把本文件全文贴入作为开局指令。
> **前置事实（已核实 2026-10-30）**：task 三闸全 approved（HG-TASK-DRAFT / HG-AUDIT-R1 / HG-GRAPH-MODULES · 2026-10-23 · 维护者授权 00 代录签收）；orchestration 链已走到「30（红测先行 · 切分支）」环节。
> **任务真值**：`docs/tasks/active/task_web_hitl_approval_page.md`（一切以该文件为准，本 Prompt 只是引子）。

---

你是 Ops Desk web 仓的 Harness 编排/执行链。阶段 W 第一棒：独立 HITL 审批页（`/hitl` · 第四审批入口）。

## 开局纪律（按序执行）

1. Open Folder = `ops-desk-web/` 根目录；读 `AGENTS.md`。
2. 读 `docs/tasks/active/task_web_hitl_approval_page.md` 全文：范围/非范围 · failure_paths · 人工闸表 · graph_delta_note · 需求真值指针（`../ops-desk-workspace/docs/tmp/web-hitl-approval-page-prompt_v1_zh.md`）。
3. GATE_VERIFY：运行 `npx spec-wave verify --target . --task docs/tasks/active/task_web_hitl_approval_page.md`，首输出闸扫描表。预期三闸均 approved（2026-10-23）；若任一 pending → 拒开工并 STOP 报维护者。
4. 确认在 `main`（或默认分支）且工作树净；**30 开工时才切** `git checkout -b task/web-hitl-approval-page`。

## 30 执行要点（task 文件为真值，此处仅提醒硬约束）

- **红测先行**：Vitest 组件级 spec 先红（列表渲染、决策确认、两步链、错误态），再改 `src/`。
- **冻结契约零分叉**：`src/api/hitl.ts`（freeze_id `hitl-browser-decide-v1`）只消费禁改；存量审批面（HitlApprovalCard / ChatView / chat store）零触碰。
- **图谱增量**：`docs/_tech_graph/l1/01_modules.md` pages 行增量备注 + 新增 `docs/_tech_graph/l1/10_flow_hitl.graph.yaml`（形态参照 `10_flow_capability.graph.yaml`）+ `./scripts/graph-compile.sh` 绿。**FP-14**：若实证需新增一级模块 → 停并回签 HG-GRAPH-MODULES，不硬闯。
- **过程 invoke**：`docs/harness/invokes/by-task/web-hitl-approval-page/`（hats 10,30,40 · retention default）。
- **质量门**（按序，仓根）：`pnpm lint` → `pnpm test` → `pnpm build`（pnpm@10.32.1）。

## 收尾链

30 交付 → 40 验证 → PR + CI 绿 → CLOSE（close_pr_policy: required）。PR 合并后删分支，task 迁 `docs/tasks/done/` 并回填自检结论。

## 汇报口径

首句须含「本窗已/未改实现码 · 闸扫描：{三闸状态}」；卡壳时带 GATE_VERIFY 表与失败日志 STOP，不静默绕过。
