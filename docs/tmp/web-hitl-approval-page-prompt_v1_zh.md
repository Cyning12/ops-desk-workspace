# Prompt · web 独立 HITL 审批页研发任务（v1）

> 交接对象：ops-desk-web 仓的研发 agent。本 Prompt 自包含，无需本对话上下文。
> 生成日期：2026-10-23 · 生成方：架构导师会话（doc 13 §7 P1 客户端轨）。

---

## 0. 角色与仓库

- 工作仓：`/Users/cyning/Desktop/Ops-desk/ops-desk-web`（Vue 3 + TypeScript + Element Plus + Pinia + vue-router，Open Folder = 仓根）
- 后端（只读参照，**禁止改动**）：`/Users/cyning/Desktop/Ops-desk/ops-desk-api`，HITL 路由 `app/ops/hitl/router.py`
- 本仓 Harness 纪律：**先读 `AGENTS.md` + `docs/tasks/active/`**。若 active task 不覆盖本工作，先走 10-task 流程建 task，GATE_VERIFY 通过后才动码；分支 `task/<short-description>`，PR 合并，禁直推 main/master。合并前 `pnpm lint` → `pnpm test` → `pnpm build` 全绿。

## 1. 任务一句话

新增**独立 HITL 审批页**（独立路由 + 导航入口）：聚合展示当前用户全部待审批项，支持批准/驳回与显式续跑，作为 Chat 页内联审批之外的第四入口，语义与既有契约零分叉。

## 2. 现状（已核实，直接采信）

- 路由表 `src/router/index.ts`：login/overview/obs/issues/pulls/graph/chat/lc-evidence/lg-rag/capability——**无审批页路由**。
- 现有审批面全在 Chat 页：`src/components/chat/HitlApprovalCard.vue`（消息流内联卡片，live 帧/replay/历史三入口同一渲染）、`src/components/chat-history/ChatHistoryPanel.vue:111`（侧栏「待审批」徽章）、`src/views/ChatView.vue:43,101`（进页一次性 pending 核对+手动刷新，**刻意不轮询**）。
- **冻结契约 `src/api/hitl.ts`（承接禁改·只准消费）**：
  - `fetchHitlPending(): Promise<HitlPendingResponse>` → GET `/ops/hitl/pending`（仅本人 owner 可见；非 maintainer 越界 403）
  - `HitlPendingItem = { id, run_id, thread_id, reason, blocked_by: unknown, created_at }`——字段族逐键对齐上游 `_PENDING_FIELDS`，**不自造字段**
  - `decideHitlRequest(requestId, decision: 'approved'|'rejected', resumeMode?)` → POST `/ops/hitl/requests/{id}/decide`；`resumeMode` 三值 `inherit`（默认·**不送键**）/`immediate`/`manual`，**禁臆造第四值**（后端 router.py:184 白名单 400）
  - `resumeHitlRequest(requestId)` → POST `/ops/hitl/requests/{id}/resume`，响应含 `replay{run_id, cursor, ...}` 提示
- **两步钉死**：decide 成功 ≠ 自动 resume；`HitlDecideResponse.resume.required` 为 true 时恢复是客户端**第二个显式动作**（除非 `resume_mode=immediate` 且响应带 `auto_triggered`）。
- 审批 TTL 3600s：过期项 decide 会失败，UI 须处理。

## 3. 功能需求

1. **路由与导航**：新增路由（建议 `/hitl`，name `hitl`）+ 主导航入口；未登录跳 login 沿用既有守卫。
2. **列表视图**：`fetchHitlPending()` 渲染 pending 列表；每行显示 reason、`blocked_by` 只读 JSON 快照（审批人必须看到「将要执行的确切内容」，对应后端 hitl_snapshot_fields 防批A执行B语义）、created_at 与已等待时长、thread_id/run_id 截断展示。
3. **状态完备**：loading / 空列表（「无待审批」）/ 错误（403 非 maintainer、网络失败、TTL 过期 decide 失败）三态齐备。
4. **决策动作**：批准/驳回需二次确认；`resume_mode` 三选 UI 与 HitlApprovalCard 同语义（默认 inherit 不送键）；决策中防重复提交。
5. **续跑动作**：decide 成功且 `resume.required=true` → 该行出现显式「续跑」按钮调 `resumeHitlRequest`；成功后按 `replay` 提示给出「回到会话查看」入口（携 thread_id 跳 Chat 页；若 Chat 页不支持 thread 定位参数，先核实现状再决定链接形态，不臆造路由参数）。
6. **刷新纪律**：手动刷新按钮，**不轮询**（与 ChatView.vue:101 既有裁定一致）；可选：页面 `visibilitychange` 回前台时刷新一次（须在 task 中声明）。
7. **零分叉**：decide/resume 交互语义对照 `HitlApprovalCard.vue`（resume_mode 三选、两步链、防重），不引入新语义、不改 `src/api/hitl.ts`。

## 4. 非范围（禁做）

- 改后端任何文件；改 `src/api/hitl.ts` 的契约语义（类型注释级完善可议，须在 PR 说明）。
- 自造 pending 字段、自造 resume_mode 第四值、新增审批相关后端调用。
- 轮询/WebSocket/全局通知中心（超范围，另立 task）。
- 重构 HitlApprovalCard / ChatView（本任务只做新页面，存量零触碰）。

## 5. 验收标准

1. `/hitl` 直达可见 pending 列表；空/加载/403/过期错误四态有明确 UI。
2. 批准→(required 时)显式续跑→成功后出现「回到会话查看」入口，链路可手测通过（可配 ops-desk-api 本地起服务+构造挂起 run 验证）。
3. 驳回路径、resume_mode=immediate 的 `auto_triggered` 分支 UI 均正确处理。
4. `pnpm lint` / `pnpm test` / `pnpm build` 全绿；新页面有组件级测试（列表渲染、决策确认、两步链、错误态）。
5. PR 描述含：路由截图（四态）、与 HitlApprovalCard 的语义对照表、Harness 闸表截图。

## 6. 上下文备注（面试叙事背景，不影响实现）

- 本页与 iOS 客户端审批 UI 消费**同一份冻结契约**，并行开发、互为互调对端——页面上线后的互调剧本：iOS 发起 run 吃 hitl.waiting → web 审批页 decide+resume → iOS 走 replay 续看。
- 后端锚点（只读）：`app/ops/hitl/router.py`（pending/decide/resume）、审批 TTL 3600s、owner-only 鉴权。