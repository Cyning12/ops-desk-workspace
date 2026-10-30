# 契约 · 只读多租户请求上下文（阶段 T · v1 freeze）

| 项 | 内容 |
|----|------|
| **状态** | **`freeze`** · F1–F6 已齐 · **2026-09-18** · 不改 SSE 事件表 |
| **日期** | 2026-09-17 · **freeze 2026-09-18** |
| **阶段** | T · 只读多租户（**数据前置 D2–D3 仍挡子仓 30**） |
| **关联 task** | workspace `task_stage_t_tenant_contract` · api `task_tenant_readonly_predicate` · web `task_web_tenant_context_chat` |
| **freeze 闸** | `HG-CONTRACT-FREEZE` = **approved**（本文件字段义锁定；子仓 30 不得静默改义） |
| **非范围** | 写能力 / HITL（W）；服务化 Registry（P） |

---

## 1. 目标

在只读面实现租户封闭：Principal ↔ Workspace（或等价租户 id）下推到 Issue/PR lookup 与 RAG 检索谓词；跨租户查询 fail-closed。

## 2. 请求上下文（F1=C）

| 字段 | 来源 | 说明 |
|------|------|------|
| `tenant_id` | **session 为真源**；请求宜带 `X-Ops-Tenant-Id`，**若带则必须与 session 一致**，否则 **403** | F1=**C** |
| `workspace_id` | **本波等同 `tenant_id`**（不另字段） | F3 |
| `principal_id` | 已登录用户 id | 授权绑定 |

**失败码**

| 条件 | HTTP / 业务 | 备注 |
|------|-------------|------|
| 缺租户谓词且能力 `tenant_scoped` | 能力层已拒（H α） | T 须保证调用方必注入（session 有租户） |
| 跨租户资源 id | **对外 HTTP 404**；对内/日志可记 `tenant_scope_denied` | F4 · 不向客户端暴露他租户是否存在 |
| 租户头与 session 不一致 | **403** | F1=C 硬门 |

**切换语义（配合 web D5）**

1. UI 切换 → 调切换 API 写入 session `tenant_id`  
2. 随后 lg-rag / 只读请求带 `X-Ops-Tenant-Id: <session 同值>`  
3. Agent/Playwright：断言 UI 文案 + Network 头均等于所选租户  

## 3. 数据面下推

| 面 | T 要求 |
|----|--------|
| Issue/PR lookup | SQL/查询必带 tenant/workspace 谓词 |
| RAG ANN / chunk | 检索前 metadata 过滤语料集/租户 |
| SSE lg-rag | **默认不改 event_type**；租户仅 session + header，须另开联调闸才动 freeze |

## 4. 第二租户试点（数据前置 · 仍阻塞 30）

见：`docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md`（D1 ✅ · D2/D3 ⏳ · D5 ✅）

## 5. 字段决议总表（freeze）

| # | 项 | 决议 | 状态 |
|---|-----|------|------|
| F1 | `tenant_id` 真源 | **C · session 真源 + 头须一致** | ✅ |
| F2 | 头名 | **`X-Ops-Tenant-Id`** | ✅ |
| F3 | `workspace_id` | **本波等同 `tenant_id`** | ✅ |
| F4 | 跨租户失败码 | **对外 404** · 对内/日志 `tenant_scope_denied` | ✅ 2026-09-18 维护者接受建议 |
| F5 | 试点 B 名 | **`ops-desk-pilot-b`** | ✅（= D1） |
| F6 | web D5 | **含租户切换 UI**（直观可查看） | ✅ |

### F1 方案对照（归档 · 已选 C）

| 方案 | 行为 | 状态 |
|------|------|------|
| A · 仅 session | — | 未选 |
| B · 仅显式头 | — | 未选 |
| **C · 二者须一致** | session 真源；带头须一致否则 403；切换先写 session 再带头 | ✅ 已选 |

## 6. 修订

| 日期 | 说明 |
|------|------|
| 2026-09-17 | 总 00 骨架；冒烟 PASS · H β 已开壳后启动 T 条件核对 |
| 2026-09-18 | 挂三仓 task 壳 · 增 §5 待钉死表 · freeze 闸指针 |
| 2026-09-18 | §5 展开 F1 三方案对照 · F5/F6 维护者拍板 · 推荐 F1=C |
| 2026-09-18 | 维护者同意 C · 钉 F1=C / F2 / F3；F4 仍欠 |
| 2026-09-18 | 维护者接受 F4 建议 · **F1–F6 齐 · 本文件升 freeze** · `HG-CONTRACT-FREEZE` 00 代签 |
