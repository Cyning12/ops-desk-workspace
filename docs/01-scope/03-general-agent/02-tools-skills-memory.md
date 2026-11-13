# 02 · 工具、技能与记忆

> 裁定议题：#23 议题3（工具生态）、议题5（记忆与上下文）。
> **v2（2026-11-13）：经实地代码调研修正**——初稿假设"工具/记忆体系待新建"，代码现实是两套体系已存在，本版改为复用与对齐。

## 1. 工具生态裁定（修订）

**裁定：ToolRegistry = 现役 Capability 体系，不另起炉灶。私有协议优先维持；MCP 仅作 client，适配器进 P2b；不做 MCP server。**

### 现状（inv-api 调研）

- `app/ops/capability/`（27 文件）已是完整工具体系：registry / gateway / manifest / policy / idempotency / receipts / circuit / fallback / budget / visibility / delegation / schema_validate。`gateway.py:1-26` 提供 register/list/`schemas_for_llm`（已为 bind_tools/ToolNode 预留）/invoke/ainvoke。
- 工具执行**不走模型原生 Function Calling**：supervisor 用 LLM 拆 plan（JSON 解析、≤4 子任务）→ tool_exec_node → capability `ainvoke`（`multi/nodes.py:38-44,101`）；`app/llm/` 内零 FC 代码；ToolNode 桥存在但注释"不接入主图"（`capability/extras/langchain.py:82-91`）。
- 写能力已上路一条：`ops.write.run_note` 窄写经 HITL→resume→执行链（`OpsCapabilityNote`，models.py:444-476）——可作模板。

### 裁定要点

1. **MCP schema 对齐对照现有 `CapabilitySpec` 字段**进行（替代初稿"ToolRegistry 与 MCP 字段级对齐"的新设计表述）。
2. **FC 主路径是开放裁定项**：现状 plan-JSON 路径稳定可用；若未来切模型原生 FC（bind_tools），`schemas_for_llm` 已预留。初稿的"SiliconFlow/百炼 tool_call 冒烟测试"**降级为引入 FC 时的前置**，不再是 P1 任务（当前架构下无的放矢）。
3. MCP client 适配器仍定 P2b（讨论 C1 裁定不变）：依赖配额纪律不变。

## 2. 权限词表裁定（修订）

**裁定：采用现役 side_effect 四档词表，废弃初稿的自创三档。**

`capability/types.py:23-24`：`SIDE_EFFECTS={none, read, write, irreversible}`，`WRITE_SIDE_EFFECTS={write, irreversible}`（挂 HITL）；另有 `execution_type` 三值（可撤销性）与 `risk_level` 维度——注释明确"risk_level 与 side_effect 是两个维度，不可互相代理"（types.py:7-12）。初稿的 read/write/admin 三档映射为：read→`read`，write→`write`，admin→`irreversible`。

## 3. Skill 裁定（不变）

最小 skill 加载器与 Skill 体系进 **P2b**（讨论 C2 多数裁定）：Markdown（YAML frontmatter）放 `ops-desk-workspace/skills/`，Git 分发，"文件即技能、启动加载、重启生效"；高级特性后置。platform 少数意见（P2a 含 50 行加载器）记录在 05 文档。

## 4. 记忆模型裁定（修订）

**裁定：三层结构维持，但 L2/L3 与现役实现对齐；"禁止自动写"落实为"抽取开关默认关 + 人工可审"。**

### 现状（inv-api 调研）

- **L1 会话**：lg_rag 三表族 + checkpointer（见 01 文档）。
- **L2 已有双表**：`ops_memory_facts`（models.py:520-590：kind fact|preference、**状态机 active|superseded|revoked|expired、不物理删**、embedding Vector(1024)）+ `ops_memory_episodes`（:593-648：plan_summary+tool_sequence+outcome run 级经验）。
- **抽取管线已建但默认全关**：`MEMORY_FACTS_ENABLED` / `MEMORY_FACTS_EXTRACT_ENABLED` / `MEMORY_EPISODES_WRITE_ENABLED` 默认 false（`memory/extract.py:62-64,160-173`、`continuity.py:143-151`）。
- 折叠摘要骨架已在：`ops_session_summaries`（:346-375，thread_id+chunk_hash 唯一、prompt_version/model，摘要与原文物理分表）——初稿"P3 才做折叠摘要"的表底座已存在。
- 管理端已有 `app/ops/admin/memory.py`，与"L2 可浏览可单条删除"需求部分重叠。

### 裁定要点

1. **"禁止 Agent 自动写长期记忆"软化为"默认关 + 人工可审"**（组织人裁定，对齐代码现实）：抽取开关维持默认 false；开启前必须在管理端提供逐条浏览/撤销（revoke）能力（admin/memory 端点盘点复用）。
2. 初稿的 `agent_notes` 单表双态（proposed/confirmed/rejected）**不作废但降级为可选增强**（B 方案）：若产品要"Agent 提议→用户确认"交互，在 `ops_memory_facts.status` 词表中加 `proposed` 并复用 HITL 确认卡片——列为 P3 产品化候选，非地基。
3. L3 口径修正：**Qdrant 为默认向量库**（`RAG_VECTOR_BACKEND=qdrant`，compose 已含 Qdrant v1.19），pgvector 仅降级路径。初稿"pgvector 现有底座/IVFFlat"表述作废。RAG 契约复用 `docs/contracts/rag-knowledge-contract-v1.md`（bge-m3、800 tokens、RRF 1:1、金样 G01-G05）。
4. 上下文窗口：P1 维持"滑动窗口 + issue 上下文重注入"；折叠摘要基于 `ops_session_summaries` 在 P3 启用。
5. 容量纪律保留：run_events append-only 大表需归档策略；知识库先只做 ops 域。所有新表含 `tenant_id`。
