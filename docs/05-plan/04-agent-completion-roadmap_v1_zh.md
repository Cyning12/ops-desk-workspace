# 04 · Ops Desk Agent 完善路线（v1）

| 项 | 内容 |
|----|------|
| **状态** | `active` |
| **日期** | 2026-07-29 |
| **总册** | `/Users/cyning/Desktop/cyning-ai-program/PLAN_dual_track_v1_zh.md` |
| **分册** | `cyning-ai-program/tracks/TRACK_A_ops_desk_v1_zh.md` |
| **Open Folder** | 本仓统筹；实现分别在 `ops-desk-api` / `ops-desk-web` |

> **边界**：本文件只规划 **线 A（应用 Agent）**。完整 HE Runtime → 程序总册线 B2，**不**在本 API 仓实现 coding agent 外壳。  
> **研发模式（H6）**：关键节点人主导（契约 / 首测 / 停条件）；AI 辅助样板与扩展。真值：`cyning-ai-program/docs/DEV_MODE_guided_human_v1_zh.md`。

---

## 0. 人必过节点（本路线）

| 节点 | 建议由人先完成 |
|------|----------------|
| Tool 契约 | 每个新 Tool：名称、参数、权限、错误语义一页 |
| 首条 scenario | 人写第 1 条断言；其余可 AI 仿写 |
| LangGraph 停条件 | 人定「何时结束 / 何时拒答」 |
| Demo 口述 | 人走通并录音或讲稿自检 |

## 0.5 澄清（2026-07-29 · 已齐）

- 主投应用岗；Demo=**生产**；program **已 git init**  
- P0 勾选：见 `cyning-ai-program/docs/P0_TOOL_SELECTION_v1_zh.md`（Core T1+T3+T4+T8+T13）  
- **Ops 内 RAG（P1）**，不以 Ink 作主路径  
- harness-web 不进 P0；不补 Java（口述 WHY_NOT_JAVA）  
- 关键 commit 前缀 `human-node:`  

---

## 1. 目标

把 Ops Desk Chat 从「可对话的 LLM 应用」推进到 **可演示的企业研发助手**：  
**工具化 Graph 节点**（M1）+ 仿真可测 +（P1）Ops 内 RAG；过程保障继续用已嵌入的 cyning-harness。

**用语**：P0 不称「Tool Calling / bind_tools」。  
**Demo**：生产环境上的 **候选增强**（须证据）。  
**主路径**：Issue #n → T1 → T4（可依赖 T3）→ T13 引用。  
**闸**：只读已批 → `cyning-ai-program/docs/GATE_HG_OPS_AGENT_TOOLS_readonly_v1_zh.md`。

---

## 2. 阶段

### P0 · 可演示 Agent

| ID | 项 | 建议落点 | 验收 |
|----|-----|----------|------|
| A-P0-0 | 契约页（P0-Core 合订） | workspace `docs/` · `human-node:` | H6 |
| A-P0-1 | T1+T3+T4+T8+T13 | `ops-desk-api` 节点 | scenario 断言 |
| A-P0-1b | Stretch T2+T6 | 同上 | 尽量同窗 |
| A-P0-2 | scenario ≥5（含故障） | tests 或 `docs/eval/` | 可复跑 |
| A-P0-3 | **生产** Demo 脚本 | 05-plan 或 interview | 主路径 T1→T4 |

### P1 · 生产感

| ID | 项 | 验收 |
|----|-----|------|
| A-P1-1 | SSE 停止 · error · fallback | 生产笔记 + 演示 |
| A-P1-2 | **Ops 仓内 RAG**（非 Ink）· 细化见 §P1-RAG | 检索增强可演示 |
| A-P1-3 | 观测字段手填模板 | 对齐 SPEC-evaluation-observation（已签 2026-08-07） |
| A-P1-4 | kind 本地 k8s 实操 · 细化见 §P1-K8S | kind 集群内服务跑通 |

### P1-RAG · Ops 仓内 RAG 细化（2026-08-07 增）

**语料**（v1 范围 · 已知组成 ≠ 已清洗）：英文 Issue/PR（多数）+ 中文 docs（05-plan / contracts / runbook）。v1 轻清洗（去 bot 评论、模板噪声）；chunk 粒度在 R-P0 契约页定。

**基础设施现状**：pgvector 扩展已预埋（docker-compose `pgvector/pgvector:pg15` · DDL/migration 带 `CREATE EXTENSION`）；**无向量表、无入库管线、无向量数据**。

| ID | 步骤 | 关键决策 / 产出 | 人节点 |
|----|------|----------------|--------|
| R-P0 | **契约页**（先于一切） | chunk 策略 + 元数据 schema + 引用约束/拒答条件 + **embedding 选型**（语料英文为主 + 中文提问 → 必须多语言：bge-m3 / multilingual-e5 / text-embedding-3） | `human-node:` 全项 |
| R-1 | 向量表 migration | `ops_knowledge_chunks`：`vector(N)` 的 N 由 R-P0 选型定；`metadata jsonb`；`content_zh_summary` 列备选（首轮评测数据决定是否启用跨语言增强） | 表结构人审 |
| R-2 | 入库管线 | 清洗 → chunk → embed → upsert；issue 变更增量重嵌 | — |
| R-3 | 检索节点入 LangGraph | 混合召回：pgvector 语义 + PG `tsvector` 关键词（口径：tsvector 替代 ES BM25 角色，方案同构）→ 融合排序 → 强制引用 + 拒答；**汇入现有 chat graph，不做旁路脚本** | 拒答条件人定 |
| R-4 | golden scenario 评测 | 四类：EN问→EN文档 基线 / **ZH问→EN文档 跨语言 ≥1/3** / ZH问→ZH文档 / 负样本拒答；recall@k 断言到文档 ID + 引用 ∈ 命中集 + 拒答正确率；报告对齐观测 SPEC（小样本老实标 confidence） | 首条 golden 人写 |
| R-5 | Demo 证据表 | 版本/输入/结果/错误（生产候选增强口径） | 人口述 |

**顺序纪律**：R-P0 契约未定不动 R-1（向量维度 / 元数据字段 / 中文摘要列全部由选型与 chunk 策略决定）。

### P1-K8S · kind 本地实操（2026-08-07 增）

| 项 | 内容 |
|----|------|
| 定位 | 面试防身术，非技能栈主线；时间盒 ≤2–3h/周；**RAG 上线后启动** |
| 载体 | **本机 kind 集群**（k8s in Docker）；**禁止**动生产 Lighthouse（保持 docker-compose 单机 · Demo 资产） |
| 对象清单 | Deployment / Service / liveness&readiness 探针 / resources limits / HPA / ConfigMap&Secret + 排查三板斧（`get/describe/logs`） |
| 实操作业 | ops-desk-api 部署进 kind → 集群内访问通 → 滚动更新一次 → 故意 OOM 一次读事件 |
| 简历纪律 | 完成前一字不写；完成后仅「熟悉 k8s 基础对象，kind 本地集群完成服务部署实操」；**永不写**生产 k8s 经验 |

### P2 · 受控扩展

| ID | 项 | 闸 |
|----|-----|-----|
| A-P2-1 | 写操作 / 真 GitHub API | `HG-OPS-AGENT-TOOLS`（见 cyning-ai-program/AGENTS.md） |
| A-P2-2 | 与纪律闸联合 Demo（verify 挡错误开工） | 录屏即可，不改 harness 产品边界 |

---

## 3. 测评纪律

- **自建** scenario eval；**不**用 BMH 跑 Ops Chat  
- 详见：`cyning-ai-program/docs/EVAL_and_BMH_boundary_v1_zh.md`

---

## 4. 非目标

- 在 api 仓实现完整 coding agent / sandbox  
- 把 BMH 或 kimi-code Runtime 并入本仓依赖  
- 全量 SWE-bench  

---

## 5. 与既有计划关系

| 文档 | 关系 |
|------|------|
| `00-migration-roadmap.md` | 迁移/上线主线；本文件为 **上线后 Agent 能力** 增量 |
| `03-post-go-live-hygiene-orchestration.md` | 卫生/编排；本文件偏产品 Agent |
| `01-epic-task-backlog.md` | 开具体 task 时从此处拆条 |

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-08-07 | P1 细化：§P1-RAG（契约先行 R-P0→R-5 · 多语言 embedding · 四类 golden）+ §P1-K8S（kind 实操 · 时间盒 · 简历纪律） |
| 2026-07-29 | 首版 · 对齐 cyning-ai-program |
