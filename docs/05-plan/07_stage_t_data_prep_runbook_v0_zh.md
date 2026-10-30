# 07 · 阶段 T · 第二租户数据前置 Runbook（v0）

| 项 | 内容 |
|----|------|
| **状态** | `active` · 过程文档 · **不授权业务 30 改码**（本文件只定口径与清单） |
| **日期** | 2026-09-18 |
| **Open Folder** | `ops-desk-workspace/` |
| **上游** | `06_stage_t_second_tenant_prep_v0_zh.md` · 契约 freeze · api `task_tenant_readonly_predicate` |

---

## 0. 结论先行（磁盘实扫）

| 面 | 现状（2026-09-18） | 对 D2/D3 的含义 |
|----|-------------------|-----------------|
| `ops_issues` / `ops_pull_requests` | **无** `tenant_id` 列 | 无法「直接插一行带 B 租户」；D2 依赖 api 30 内 **迁移 + 回填** |
| lookup | 仅按 `number` 取最新，**无**租户谓词 | 负样本今日会串租；T2 必改 |
| `ops_knowledge_chunks` | 有 `metadata jsonb`；组合键 `(repo, source_type, source_id, chunk_index)` | 可把 `tenant_id` 写入 metadata，但检索下推须应用层/过滤改 |
| Qdrant `filter_payload` | **仅** `source_type/repo/source_id/chunk_index` | D3 完态须扩 payload + index（api 30 · T3）；禁止静默用 repo 冒充租户 |

**因此**：D2/D3 **不是**纯运维插数即可结案；最小路径 = **fixture 轨先齐（解 `HG-STAGE-T-DATA` 开工）** + **生产/试点种子轨在迁移后补齐（解联调发版）**。

---

## 1. 双轨定义

| 轨 | 目的 | 齐则签什么 | Owner |
|----|------|------------|-------|
| **F · Fixture 轨** | pytest / 本地可断言 A≠B | `HG-STAGE-T-DATA`（允许 api/web **开 30**） | api 10/30 设计 + 维护者勾选本 runbook §3 |
| **P · Pilot/Prod 种子轨** | 现网或试点库真有 B 数据 | 联调/发版闸（非挡 30 开工） | 维护者运维 + api 迁移后脚本 |

契约 F1–F6 已 freeze，与双轨无关。

---

## 2. Schema / 谓词设计（给 api 30 · 不得静默改义）

### 2.1 Issue / PR（D2）

| 项 | 钉死建议 |
|----|----------|
| 列 | `ops_issues.tenant_id text NOT NULL` · `ops_pull_requests.tenant_id text NOT NULL`（或等价）；默认回填 `ops-desk-pilot` |
| 索引 | `(tenant_id, number)` 或 `(tenant_id, repo_id, number)` 按查询形态 |
| lookup | `WHERE number=:n AND tenant_id=:tenant`；未命中 → 对外 **404** 语义（契约 F4；Gateway/`LookupError` 映射由 30 钉） |
| 唯一约束 | 现网 `uq_ops_issues_repo_number`：**同 repo 同号唯一**；多租户同号跨租户 → 须在 30 明确：同 repo 多租户是否允许同号（建议 **租户隔离后同号可并存**：改唯一为 `(tenant_id, repo_id, number)`） |

> **风险**：改唯一约束影响 sync upsert。30 须先写失败路径与回填策略，再动 DDL。

### 2.2 RAG（D3）

| 项 | 钉死建议 |
|----|----------|
| PG | `metadata.tenant_id` **必填**（ingest 写入）；可选生成列/索引 `metadata->>'tenant_id'` |
| Qdrant | `filter_payload` **增加** `tenant_id`；`ensure_payload_indexes` ALLOWED 扩字段 |
| 检索 | ANN/关键词路径 **必带** tenant filter；缺则拒或空（对齐 `tenant_scoped`） |
| 试点内容 | A/B 各 ≥1 chunk；B 的 `content` 含可辨识标记（如 `TENANT_B_MARKER`）便于负样本 |

### 2.3 Session / 头（已 freeze · 重申）

- F1=C · F2=`X-Ops-Tenant-Id` · 切换写 session 再带头  
- 本 runbook **不**实现切换 API；归 api task T1  

---

## 3. Fixture 轨清单（解 HG-STAGE-T-DATA）

维护者勾选后，00 可签 `HG-STAGE-T-DATA`（**仅**授权子仓开 30，不代表生产已有 B）。

| ID | 项 | 建议落点 | 状态 |
|----|-----|----------|------|
| F-D2 | 测试用 Issue：A 号 `N_a` · B 号 `N_b`（可同号不同 tenant，若唯一约束已按 §2.1 改） | `tests/fixtures/` 或 lookup 测内 inline | ⏳ |
| F-D3 | RAG：mock retriever 或 PG 测试库 A/B 各 1 chunk | `tests/test_*tenant*` | ⏳ |
| F-D4 | 负样本意图写进 api task 验收（A ctx 查 B → 404/空） | 随 api 30 | 可与 30 同竖切 |
| F-SIGN | 维护者确认 Fixture 轨解闸 | 本表 | ✅ **2026-09-18** · 本波只跑本地 |

**最小签字句（复制回复即可）**：

> 同意 Fixture 轨解 `HG-STAGE-T-DATA`：允许 api/web 开 30 做迁移+谓词+切换 UI；生产 B 种子另轨。

---

## 4. Pilot/Prod 种子轨清单（解联调）

在 **迁移已上试点/生产** 后执行。

| ID | 步骤 | 命令/动作（示意 · 30 落地后回填真命令） | 状态 |
|----|------|------------------------------------------|------|
| P0 | 确认迁移 head 含 tenant 列 / Qdrant payload | `alembic current` · payload index 列表 | ⏳ |
| P1 | 回填既有行 `tenant_id=ops-desk-pilot` | SQL / 一次性脚本 | ⏳ |
| P2 | 插入 B：≥1 Issue（建议独号，避免与 A 混淆） | fixture SQL 或 admin sync 标注 | ⏳ |
| P3 | ingest B 语料 ≥1 chunk（`metadata.tenant_id=ops-desk-pilot-b`） | `scripts/rag_ingest.py` 扩展后 | ⏳ |
| P4 | 手测：A session 查 B issue# → 404；B session 可查 | curl / Playwright | ⏳ |

**建议 B Issue 文案（种子）**

- title：`[pilot-b] tenant isolation canary`
- body：含字面 `ops-desk-pilot-b` 与 `TENANT_B_MARKER`
- number：选用现网未占用号，或测试库专用号段（如 ≥900000）

---

## 5. 与 task / 闸的接线

| 闸/task | 本 runbook 后 |
|---------|----------------|
| `HG-CONTRACT-FREEZE` | 已 ✅ |
| `HG-STAGE-T-DATA` | **等 §3 F-SIGN**（Fixture 轨）即可签 → 开 30 |
| api `tenant-readonly-predicate` | 30 首刀含：**DDL/回填设计实现** + lookup/RAG 谓词 + fixture 负样本 |
| web `web-tenant-context-chat` | 仍建议等 api T1 可联调；可与 api 并行做 UI 壳 |
| 生产联调 CLOSE | 另等 §4 P 轨 |

---

## 6. 非范围

- 本文件不改 `app/`、不做真实 DB 写入  
- 不跳过 T 开 W  
- 不用 `repo` 字段冒充 `tenant_id` 作为长期方案  

---

## 7. 相关路径

| 文档 | 路径 |
|------|------|
| 06 条件表 | `docs/05-plan/06_stage_t_second_tenant_prep_v0_zh.md` |
| 契约 freeze | `docs/contracts/api-v1-tenant-readonly-context-draft.md` |
| RAG 契约 | `docs/contracts/rag-knowledge-contract-v1.md` |
| api task | `../ops-desk-api/docs/tasks/active/task_tenant_readonly_predicate.md` |
| Qdrant filter | `../ops-desk-api/app/ops/rag/shadow_write.py` · `filter_payload` |
| lookup | `../ops-desk-api/app/ops/capability/lookups.py` |

## 修订

| 日期 | 说明 |
|------|------|
| 2026-09-18 | 首版：实扫无 tenant 列 · 双轨 D2/D3 · 解闸签字句 |
