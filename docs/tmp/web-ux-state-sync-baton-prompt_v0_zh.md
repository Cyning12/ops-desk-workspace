# web UX 状态同步族 + 时区本地化 · web 仓派工 Prompt v0

> 用法：在 **ops-desk-web 仓**新窗口全文贴入本文件即开工。
> 性质：派工锚点（含背景/范围/红线/质量门）；**首棒必须是 10 帽起草 task 档**——本仓当前无对应 active task，禁止直接 30 改码（仓规：无 task 不改码）。
> 版本：v0 · 2026-11-03 · 00 编排落盘（阶段 W 联调遗留 B10/B11）

---

## 角色

你是 Ops Desk Web 仓的 Harness Agent。Open Folder = ops-desk-web 仓根。先读本仓 `AGENTS.md` 与 `docs/tasks/active/`（应只有 task_web_hitl_approval_page.md 已归档 done/，active/ 无本项 task）。

## 背景（阶段 W 联调实证发现 · 2026-11-02/03）

联调 task（workspace 仓 `docs/tasks/done/task_stage_w_e2e_join_acceptance.md`）实证 web 侧四处 UX 状态同步缺口，全部有 live 证据锚：

| 编号 | 现象 | 实证 |
|---|---|---|
| F1 | /hitl 审批页只列 pending，decide 后行仅存组件本地态（`src/views/HitlApprovalView.vue:61-85` 刷新合并逻辑），**整页刷新后已决单消失 → 全 UI 无「已批准待续跑」单据的续跑入口** | C3 实证 · 联调 invoke §2 |
| F10 | chat 浮层卡片聚合已驳回旧单仍显示「待审批」且可点（点击得 409 幂等拒绝） | C4 实证 · run 03d500d2 |
| F14 | 审批页批准后，chat 页浮层卡片仍显示「待审批」不联动（卡片渲染历史 hitl.waiting 帧快照，不随外部 decide 同步） | run af3fcf63832c4d6dae4a1ecc5065a4e3 |
| F15 | 审批卡片「创建时间」显示 UTC 原文（2026-11-03T06:51:59+00:00），未本地化用户时区 | A5 截图 a5-expired-row-prompt.jpg |

证据真值（workspace 仓）：
- `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261102_10_c8_evidence_archive.md` §2（F1–F13）
- `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/invoke_20261103_10_final_acceptance.md` §2（F14/F15）
- `docs/tasks/backlog/backlog_20261030_post_stage_w.md` B10/B11

## 建议范围（10 帽起草时核定，可裁剪）

1. **已决单可见性**：/hitl 页增加「已决单」视图或会话内保留（至少覆盖 approved-待续跑 状态），使刷新后仍有续跑入口（F1）
2. **chat 卡片状态联动**：decide/resume 后卡片与单据真源同步（轮询或事件驱动均可，10 定方案）；已 rejected/expired 单不可再点（F10/F14）
3. **时间本地化**：审批卡片/列表时间按浏览器时区渲染（F15）
4. 顺带核对：replay 409 写窗错误透传英文原文的问题（F8：应中性化「恢复写入中」+ 可沉降后重试）——可纳入或单列，10 定夺

## 非范围（红线）

- **freeze `hitl-browser-decide-v1` 零分叉**：decide/resume 请求面（方法/路径/载荷/错误码语义）不得变更；本 task 只动**展示与状态同步**，不动协议
- 不改 api 仓任何内容；不改 SSE event_type；不动 freeze 增补条款（TTL/approval_expired 语义保持）
- 未经闸签收禁止 30 改码

## 执行链（仓规）

1. **GATE_VERIFY**：`npx spec-wave verify --target . --task docs/tasks/active/task_*.md`——本项无 task，预期**拒开工**属正常，走第 2 步
2. **10 帽起草** `task_web_ux_state_sync.md`（范围/非范围/验收/failure_paths/闸表四闸 pending 起/R0–R5）→ PR → 维护者签收 HG-TASK-DRAFT → 20-R1 审查 → 维护者签 HG-AUDIT-R1（+HG-GRAPH-MODULES 若动图谱）
3. **30 实现**：红测先行（vitest）· 质量门 `pnpm lint` → `pnpm test` → `pnpm build` 全绿
4. **40 独立验收** → CLOSE（维护者拍板）
5. 过程 invoke 落 `docs/harness/invokes/by-task/web-ux-state-sync/`

## 环境提示

- 本仓 devEngines 钉 pnpm 10.32.1，与 corepack 冲突时用 `npx -y pnpm@10.32.1 <cmd>`
- dev server 访问 **http://localhost:5173**（vite 绑 IPv6，127.0.0.1 不通）
- 联调实证期 api 以 `OPS_HITL_APPROVAL_CONSUMPTION_TTL_SECONDS=90` 跑过过期态；本 task 不依赖该设置
