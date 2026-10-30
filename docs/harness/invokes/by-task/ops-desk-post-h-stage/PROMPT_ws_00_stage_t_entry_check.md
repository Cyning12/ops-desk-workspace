# PROMPT · workspace 00 · 阶段 T 进入条件核对（立项壳 · 不授权 30）

> **Open Folder**：`ops-desk-workspace/`  
> **角色**：跨仓 00 · 契约先行 · **禁止** api/web/ios 业务改码  
> **日期**：2026-09-17  
> **何时用**：web 冒烟 PASS 后，维护者确认「核对 T 进入条件 / 起草契约」时再开

---

## 复制区（整段粘贴为新窗首条用户消息）

`````text
你是 Ops Desk 跨仓 00（阶段 T 进入条件核对 · 立项壳）。

Open Folder = ops-desk-workspace/。
禁止改 ../ops-desk-api、../ops-desk-web、../ops-desk-ios 的 app/src 业务实现。
本波只做：进入条件对照、契约草稿要点、跨仓 task 壳；不授权子仓 30；不代签子仓 HG-*（除非维护者本消息另授）。

════════════════════════════════════
目标
════════════════════════════════════
对照决议 H→T→W，判断「阶段 T · 只读多租户」是否可立项；若条件未齐，列出缺口与建议前置，而不是硬开实现。

════════════════════════════════════
必读
════════════════════════════════════
1) docs/05-plan/05_post_h_stage_brief_v1_zh.md
2) ../ops-desk-api/docs/discussions/2026-09-17_interview_gaps_adoption_and_landing_v0.md §8
3) docs/01-scope/02-cross-repo-communication.md
4) docs/contracts/README.md（现有契约索引）
5) 抽查 api：tenant_scoped / OPS_PILOT_TENANT_ID / ops-desk-pilot（构造性单租户 ≠ 第二租户）

════════════════════════════════════
进入条件核对表（须填）
════════════════════════════════════
| 条件 | 结论（是/否/未知） | 证据 |
|------|-------------------|------|
| H α schema/allowlist/tenant_scoped 测绿且已合入 | | |
| web 冒烟 PASS（lg-rag 主路径） | | |
| 存在第二租户试点数据（非仅 ops-desk-pilot） | | |
| Principal↔Workspace 产品语义已有决议/草稿 | | |
| 跨租户负样本金样计划（可后置但须挂账） | | |

若「第二租户试点数据」= 否：结论必须是「暂缓 T 的 30」；可继续写契约骨架与数据前置清单。

════════════════════════════════════
允许产出（过程文档）
════════════════════════════════════
1) docs/contracts/ 下只读多租户契约草稿（请求上下文租户头/字段、lookup/RAG 过滤语义、失败码）——先草稿，不 freeze SSE 除非显式开闸。
2) docs/tasks/active/ 跨仓 task 壳（api / web 拆分；ios 默认非本波）。
3) docs/harness/invokes/by-task/ops-desk-post-h-stage/ 下 invoke 与 handoff Prompt 草稿。

禁止：开阶段 W；跳过 T；改 SSE freeze；服务化 Registry / 完整本体（阶段 P）；子仓业务码。

════════════════════════════════════
结束时回传
════════════════════════════════════
- 进入条件表
- GO / NO-GO（对 T 的 10/30）
- 若 NO-GO：最小前置清单（数据 / 契约 / 冒烟）
- 若 GO：下一步交给 api 00 / web 00 的 Prompt 路径
`````

---

## 维护者备注（勿粘贴）

- 总 00 磁盘抽查（2026-09-17）：第二租户试点数据尚未见 → 默认 NO-GO 开 30。
- H β（supervisor 预算）为 api-only 可选并行，不替代本 Prompt。
