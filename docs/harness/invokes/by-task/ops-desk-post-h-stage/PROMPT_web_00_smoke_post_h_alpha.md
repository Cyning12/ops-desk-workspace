# PROMPT · web 00 · H α 合入后冒烟（无新功能）

> **Open Folder**：`ops-desk-web/`  
> **角色**：web 仓 00（或维护者本机手测）· **只测不改业务码**  
> **日期**：2026-09-17  
> **上游**：api PR [#138](https://github.com/Cyning12/ops-desk-api/pull/138) 已合入 `master`；workspace 简报 `ops-desk-workspace/docs/05-plan/05_post_h_stage_brief_v1_zh.md`

---

## 复制区（整段粘贴为新窗首条用户消息）

`````text
你是 Ops Desk web 仓 00（冒烟闸）。

Open Folder = ops-desk-web/ 仓根。
本波 = 阶段 H α 合入后冒烟：只验证、不改 src 业务实现（无新功能、不改 SSE freeze）。

════════════════════════════════════
背景
════════════════════════════════════
api 阶段 H · 波次 α（capability 契约硬化）已 CLOSE 且已合入 master（PR #138）。
H 零 SSE 契约变更 → 前端无强制改码；但须确认现网 Chat 主路径仍健康。

════════════════════════════════════
必读
════════════════════════════════════
1) docs/checklists/CHECKLIST_lg_rag_sse_joint_release_v1.md（若存在则按清单抽测）
2) src/composables/useLgRagSse.ts · LG_RAG_STREAM_PATH
3) src/stores/chat.ts（sendMessage → lg-rag SSE）
4) 上游简报（只读）：../ops-desk-workspace/docs/05-plan/05_post_h_stage_brief_v1_zh.md §1–§3

════════════════════════════════════
冒烟步骤（须真跑或明确标「环境不可用」）
════════════════════════════════════
1. 确认本机/联调 API 指向已含 H α 的后端（master / 部署实例）。
2. 打开主 Chat：发一条只读问句（一问一答）。
3. DevTools Network：流请求必须是 POST /api/ops/lg-rag/stream（或等价经 proxy 的同路径）；禁止回退到旧 /chat/stream。
4. 观察：SSE 正常结束（done/无未捕获崩）；若有 tool/subtask 过程帧，可见即可，不要求新 UI。
5. 可选：再发一条会触发 lookup 的问句（Issue/PR 号）；确认图不垮、答案或结构化错误可展示。

════════════════════════════════════
产出（落盘建议）
════════════════════════════════════
在 docs/harness/invokes/by-task/ 或 docs/checklists/ 写短 invoke：
  - PASS / FAIL / BLOCKED（环境）
  - Network 路径实录
  - 失败现象与是否怀疑 H α 回归

禁止：改 Vue 业务码、改 SSE 契约、开阶段 T/W、commit/push（除非维护者另令）。

完成后把结论回传 workspace 总 00（本窗可只写 invoke，不跨仓改码）。
`````

---

## 维护者备注（勿粘贴）

- 冒烟 PASS 后，总 00 再拍：开 H β **或** 阶段 T 立项（T 仍须第二租户试点数据）。
- 本 Prompt 不授权 web 30。
