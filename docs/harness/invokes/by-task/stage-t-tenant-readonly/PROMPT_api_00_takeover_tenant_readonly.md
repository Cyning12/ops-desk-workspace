# PROMPT · api 00 · 接手阶段 T · tenant-readonly-predicate

> **Open Folder**：`ops-desk-api/`  
> **角色**：api 仓 **00**（编排收口；本窗可派 30 或本窗亲自 30，须在回报写明）  
> **日期**：2026-09-18  
> **轨道**：**Fixture / 本地跑通**（生产 B 种子 **另轨**，本窗禁止）  
> **上游**：workspace 契约 freeze · `07` runbook F-SIGN ✅ · 根窗已落半成品 diff（见下「WIP 真值」）

---

## 复制区（整段粘贴为新窗首条用户消息）

`````text
你是 Ops Desk api 仓 00（Harness 编排）。

Open Folder = ops-desk-api/ 仓根（禁止改 ops-desk-web / ops-desk-ios / 顺手改 workspace 业务码）。
本波 task = docs/tasks/active/task_tenant_readonly_predicate.md
建议分支 = task/tenant-readonly-predicate（base: master）。注意：工作区当前可能仍停在 master 且有未提交 WIP——先 git status，再切/建分支把 WIP 收进本 task 分支，禁止 silent 丢改。

════════════════════════════════════
身份与纪律
════════════════════════════════════
- 你只对 api 仓负责。web 切换 UI / Playwright 归 web 仓另一窗。
- 闸已齐（Fixture 轨）：HG-TASK-DRAFT / HG-AUDIT-R1 / HG-GRAPH-MODULES / HG-STAGE-T-DATA / HG-CONTRACT-FREEZE = approved。允许 30。
- 范围 = 本地 Fixture 跑通：迁移 + 谓词 + 上下文 + 负样本测。生产 B 种子（07 §4）禁止本窗做。
- 禁止改 SSE event_type freeze；禁止改 app/ops/chat/graph.py；不新增 G-L1 一级模块。
- 未获维护者令：不 commit / 不 push / 不开 PR。

════════════════════════════════════
必读（按序）
════════════════════════════════════
1) docs/tasks/active/task_tenant_readonly_predicate.md（闸表 + T0–T5 + 验收）
2) 只读契约（勿改义）：../ops-desk-workspace/docs/contracts/api-v1-tenant-readonly-context-draft.md（F1=C · F2=X-Ops-Tenant-Id · F3 workspace≡tenant · F4 对外404/对内tenant_scope_denied · F5 B=ops-desk-pilot-b）
3) 只读数据轨：../ops-desk-workspace/docs/05-plan/07_stage_t_data_prep_runbook_v0_zh.md（Fixture 解闸；唯一约束本波不改）
4) 现状 WIP 锚点（已有半成品，续作勿重写）：
   - app/ops/tenant_context.py（新）
   - alembic/versions/20260918_tenant_readonly.py（新；revises 20260831_lg_rag_run_events）
   - app/db/models.py · OpsSession/OpsIssue/OpsPullRequest + tenant_id
   - app/ops/capability/lookups.py（tenant 谓词；缺 ctx→tenant_scope_missing）
   - app/ops/capability/adapters/local_fn.py（签名含 ctx 则传入）
   - app/ops/deps.py / app/ops/auth.py（/me 回 tenant_id；POST /ops/auth/tenant 切换）
   - app/ops/lg_rag/router.py（头 vs session；SSE 内 ContextVar）
   - app/ops/lg_rag/multi/nodes.py（current_tenant_or_default，替纯 env）
   - app/ops/rag/retrieve.py · shadow_write.py · ingest.py · ensure_payload_indexes
   - tests/test_tenant_context.py · tests/test_capability_lookups.py（含跨租户 900001）

════════════════════════════════════
WIP 交接真值（根窗停工点 · 2026-09-18）
════════════════════════════════════
已绿：
- pytest tests/test_tenant_context.py + tests/test_capability_lookups.py → 18 passed
  （前提：opsdesk_test 已有 tenant_id 列；若 alembic_version 空/错，可用 IF NOT EXISTS 补列，或对齐 alembic_version 后再 upgrade）
- 应用库（.env 默认 opsdesk）曾 alembic upgrade 到 20260918_tenant_readonly

未完 / 风险：
- 当前进程若是 Docker :8000，openapi 可能仍无 /api/ops/auth/tenant → 须用本仓代码重启本地 api（make dev / uvicorn），不要以为远端容器已含本波
- opsdesk_test 的 alembic 历史可能与表结构脱节（空 version 会从头跑撞 DuplicateTable）；本波以「列存在 + 测绿」优先，再决定是否 stamp
- 唯一约束 (repo_id, number) 本波不改；负样本用不同 number（如 900001），禁止同号跨租户插行
- T5 图谱薄备注未勾；task 内 checklist T0–T5 多未勾；spec-wave verify 未跑
- 生产/联调库 B 种子不做

════════════════════════════════════
本窗目标（本地跑通 · api 侧）
════════════════════════════════════
1. 收口 WIP：确认分支、diff 与 task 范围一致；补齐缺口（不要另起炉灶）。
2. 保证本地开发库 + opsdesk_test 都能跑通本波迁移语义（列+索引；默认回填 A）。
3. 测绿：至少
   .venv/bin/pytest tests/test_tenant_context.py tests/test_capability_lookups.py -q
   以及触及路径的 ruff；按 task 补 RAG 负样本若 T3 仍缺独立断言。
4. 本机起 api（非旧 Docker 镜像）验证：
   - GET /api/ops/auth/me 含 tenant_id
   - POST /api/ops/auth/tenant 可在 A/B 间切换（allowlist）
   - lg-rag stream：头与 session 不一致 → 403；一致 → 正常流
5. 勾 task checklist 能勾的项；落短 invoke（PASS/FAIL/BLOCKED + 命令实录）。
6. 回报 web 00：api 本机可联调的 base URL / 分支名 / 已知限制（勿跨仓改 web）。

════════════════════════════════════
停止条件
════════════════════════════════════
- api 本地验收项绿，或列出明确阻塞（环境/闸/契约冲突）停手问维护者。
- 禁止：生产种子、改 web、改 SSE freeze、未令 commit。
`````

---

## 维护者备注（勿粘贴）

| 项 | 说明 |
|----|------|
| 开窗 | Cursor **Open Folder = `ops-desk-api`** |
| 并行 | 另开 `ops-desk-web` 粘贴 `PROMPT_web_00_takeover_tenant_context_chat.md` |
| 根窗 | Ops-desk 根目录会话已停 30；后续改码只在子仓窗 |
| Docker | 若仍用 compose 的 api 镜像，需重建/挂载本仓代码，否则联调假失败 |
