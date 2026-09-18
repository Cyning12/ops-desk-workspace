# Task：查询路径嵌入改为 SiliconFlow API（默认 ApiEmbedder）

> **状态**：`done`（workspace 总单归档 · **实现已在 api 完成**）  
> **类型**：feature / RAG 嵌入层 · 运维减负  
> **归档说明**：2026-09-18 核验 — api 仓 `docs/tasks/done/task_rag_embed_api_backend.md` 已 CLOSE（2026-08-17）；`get_query_embedder` + Chat/LC 两入口已接线；`.env.example` / `deploy/docker-compose.prod.yml` 已透传 `RAG_EMBED_BACKEND`。本文件为过期 active 副本，**勿再开工**。  
> **实现真值**：`ops-desk-api/docs/tasks/done/task_rag_embed_api_backend.md`  
> **上游记录**：`docs/04-infrastructure/04-rag-embed-cold-start_note_20260817.md`（workspace · 冷启动只记）  
> **契约对照**：`docs/contracts/rag-knowledge-contract-v1.md` Q3（bge-m3@1024；ApiEmbedder 为已备降级路径）  
> **先例**：`ops-desk-api` · `task_siliconflow_rerank_api`（精排已 HTTP）；`app/ops/rag/embedder.py` · `ApiEmbedder` 已存在  
> **实现仓**：`ops-desk-api/`（Open Folder 对准 api 仓根；**本 workspace task 为跨仓总单**，30 改码只在 api）  
> **建议分支**：`task/rag-embed-api-backend`  
> **编排**：workspace 出单 → api 仓复制/对齐 active task → 20-task-audit → 闸 → 30（api）→ 50 → CLOSE / PR  
> **无关**：勿与 `task_ops_sync_sender_migration`、已关账 `lc-evidence-chain-hardening` 混改。

---

## Harness 元信息

| 字段 | 值 |
|---|---|
| **task_slug** | `rag-embed-api-backend` |
| **git_branch** | `task/rag-embed-api-backend` |
| **implement_repo** | `ops-desk-api` |
| **test_strategy** | `required` |
| **test_strategy_note** | pytest mock `POST /embeddings`：维度/保序、缺 key/HTTP 失败可观测失败路径、`RAG_EMBED_BACKEND=local` 仍可走 ST（不强制 CI 加载真模型）；不打真实 SiliconFlow |
| **code_quality_bar** | `L2_backend` |
| **graph_change_layer** | `G-L1` |
| **graph_delta** | `docs/_tech_graph/l1/01_modules.md`（api 仓） |
| **graph_delta_note** | `rag` / `lc_evidence_chain` 备注补「查询 embed 默认可走 SiliconFlow HTTP」；不新增一级模块；不改 chat graph 边 |
| **wiki_delta** | `n/a` |
| **wiki_delta_note** | 行为真值在 env + G-L1；不改 coding_wiki |
| **review_hat** | `20` |
| **required_invoke_hats** | `10,30` |
| **invoke_retention_profile** | `default` |
| **orchestration** | 默认远程 embed（生产小机）；`local` 显式保留给有内存本机 / 离线 |

### 人工闸

| human_gate_id | status | blocks_hats | 说明 |
|---|---|---|---|
| HG-TASK-DRAFT | approved | 22-R1 | 实现已在 api CLOSE；本总单 2026-09-18 归档，不再待签 |
| HG-AUDIT-R1 | approved | 30 | 见 api `task_rag_embed_api_backend_audit_R1_20260817.md`；workspace 总单不再开工 |
| HG-GRAPH-MODULES | approved | 30 | api 真值 `docs/_tech_graph/l1/01_modules.md`；已含 SiliconFlow 默认查询 embed |

---

## 背景与目标

生产 2C4G 上，查询路径仍懒加载本地 `SentenceTransformerEmbedder`（bge-m3 ~2.3GB）。进程/容器首次（或 recreate 丢 HF 缓存后）retrieve 可达**分钟级**，并与 Nginx/前端 120s 超时叠加失败。精排已切 SiliconFlow；嵌入的 `ApiEmbedder` 类已写好但**未接到** Chat / LC Evidence 查询路径。

**完成态**：生产默认查询 embed 走 SiliconFlow `POST /embeddings`（模型名仍 `BAAI/bge-m3`，与库内 fingerprint 一致）；进程**不再**为答问冷加载本地 ST；`local` 后端可显式切回；失败路径可测、有日志。

---

## 范围（实现仓 ops-desk-api）

1. 统一查询侧 embed 工厂（建议抽到 `app/ops/rag/embedder.py` 或薄 `get_query_embedder()`）：按 env 返回 `ApiEmbedder` / `SentenceTransformerEmbedder`。  
2. 接线：  
   - `app/ops/lc_evidence_chain/retrieve.py`  
   - `app/ops/chat/rag_nodes.py`  
   二者改为走工厂，**禁止**继续硬编码仅 ST。  
3. env（建议名，30 可微调但须写进 `.env.example`）：  
   - `RAG_EMBED_BACKEND=siliconflow|local`（**默认 `siliconflow`** 对准生产小机）  
   - 模型：`RAG_EMBED_MODEL` 或复用现常量，默认 `BAAI/bge-m3`（须与 ingest fingerprint / 库维度一致）  
   - 复用 `SILICONFLOW_BASE_URL` + `SILICONFLOW_API_KEY`  
4. `ApiEmbedder`：缺 key / 超时 / 4xx·5xx → **明确失败**（打日志）；不要静默退回「再去加载本地 2.3GB」除非文档写明且可测的显式降级策略（本波**建议不做**隐式降级，避免又冷启动）。  
5. `.env.example` + 生产 compose（`ops-desk-workspace/deploy/docker-compose.prod.yml`）透传 `RAG_EMBED_BACKEND`（及模型键若新增）。  
6. 单测 mock httpx；不改 `hybrid_recall` SQL、不改 grader 闸、不改 Qdrant 契约。  
7. G-L1 一句 + api `./scripts/graph-compile.sh`。

---

## 非范围

- 全量重新灌库 / 改向量维度（必须保持 bge-m3@1024）  
- 改 ingest 默认仍可用本地 ST 灌库（本波可只改**查询**路径；若 30 顺手统一工厂，ingest 默认 `local` 须单独写清，避免 CI/灌库依赖云 API）  
- 启动 lifespan 预热本地模型（企业做法；本波以 API 消冷启动为主）  
- 挂 `HF_HOME` volume、升配机器、烘进 Docker 镜像  
- 换供应商（百炼 embeddings）  
- 改 Chat SSE / LC Evidence HTTP freeze  
- 改 `graph.py` 拓扑  
- Langfuse token UI / `t-` observation 404（观测另案）

---

## 依赖

| 项 | 说明 |
|---|---|
| 冷启动记录 | `ops-desk-workspace/docs/04-infrastructure/04-rag-embed-cold-start_note_20260817.md` |
| 契约 Q3 | `ops-desk-workspace/docs/contracts/rag-knowledge-contract-v1.md` |
| 现实现 | `ops-desk-api/app/ops/rag/embedder.py`（`ApiEmbedder` 已存在） |
| 调用方 | `lc_evidence_chain/retrieve.py` · `chat/rag_nodes.py` |
| 密钥 | 既有 `SILICONFLOW_API_KEY` |
| 编码规范 | `ops-desk-api/docs/standards/CODING_BACKEND_L2_v1_zh.md` |

---

## 实施步骤（建议 · api 30）

1. 增加 `get_query_embedder()`（或等价）：读 `RAG_EMBED_BACKEND`；默认 siliconflow → `ApiEmbedder`；local → ST。  
2. 改 LC / Chat 两处 `_get_embedder` 调用工厂；`asyncio.to_thread` 对 sync `embed` 保持。  
3. 缺 key：构造或首次 embed 失败路径清晰（对齐精排「score 路径失败」精神，**不要** import 期无条件炸全站）。  
4. `.env.example` + workspace compose 透传。  
5. pytest mock `/embeddings`：返回 1024 维假向量、index 保序；backend=local 路径可用 stub 替代真 ST。  
6. G-L1 + graph-compile；确认 `git diff` 不改 `app/ops/chat/graph.py`。

---

## 验收标准

- [ ] `RAG_EMBED_BACKEND=siliconflow`（或默认）：查询路径**不**调用 `SentenceTransformer(...)` / 不加载本地 bge-m3  
- [ ] mock `POST /embeddings`：返回向量进入 `hybrid_recall` 前形状正确（list[float]、维数与约定一致）  
- [ ] 缺 `SILICONFLOW_API_KEY` 或 HTTP 失败：可测失败（日志明确）；**不**隐式改加载本地 ST（本波）  
- [ ] `RAG_EMBED_BACKEND=local`：仍可走 ST（单测 stub，CI 不真下模型）  
- [ ] LC Evidence 与 Chat retrieve **两处**均已接线  
- [ ] `.env.example` + 生产 compose 透传相关键  
- [ ] `git diff`（相对合入基线）**不改** `app/ops/chat/graph.py` 拓扑  
- [ ] `ruff check` 触及路径 + 相关 pytest 绿；G-L1 一句 + `graph-compile.sh` exit 0  
- [ ] （人工）小机 recreate api **不**预热本地模型时，首次 LC Evidence 不再出现分钟级「loading embedding model」

---

## failure_paths

| 触发 | 行为 | 可重试 | 用户可见 |
|---|---|---|---|
| SiliconFlow 超时 / 5xx / 429 | 查询失败（本波不隐式回落本地 ST） | Y | Chat/LC 错误或 500（与现 retrieve 失败语义对齐） |
| 缺 API key | 同上；配 key | Y | 明确日志 |
| `BACKEND=local` 再 OOM / 冷启动 | 仅误开 local；默认路径不走 | Y | 运维改回 siliconflow |
| 模型名与库 fingerprint 不一致 | 向量空间错乱；验收/审查打回 | N | 召回质量崩溃 |
| 误改 graph / 升无关 freeze | 验收打回 | N | PR 拒绝 |

---

## 给执行帽必读（api 仓）

1. 本 task（复制到 `ops-desk-api/docs/tasks/active/` 后以仓内副本为执行真值）  
2. `docs/04-infrastructure/04-rag-embed-cold-start_note_20260817.md`（workspace）  
3. `app/ops/rag/embedder.py` · `ApiEmbedder` / `SentenceTransformerEmbedder`  
4. `app/ops/lc_evidence_chain/retrieve.py` · `app/ops/chat/rag_nodes.py`  
5. `docs/standards/CODING_BACKEND_L2_v1_zh.md`  
6. 精排先例：`app/ops/rag/reranker.py`（backend 切换 / compose 透传模式）

---

## 思考轮

### 思考轮控制

| 字段 | 值 |
|---|---|
| **actual_last_round** | R5 |
| **early_stop** | no |
| **residual_risks** | 查询改 API 后，ingest 若仍本地、查询远程，模型名必须同为 bge-m3@1024。隐式失败回落本地会再次引入冷启动，故本波禁止。多 worker + API 依赖外网与配额。 |

### R0
小机 retrieve 分钟级主因是查询路径本地 bge-m3 冷启动；ApiEmbedder 已存在未接线。

### R1
范围=查询路径默认 siliconflow + env + 两入口接线 + 单测 + compose；非范围=灌库改维、升配、预热 lifespan、隐式回落 ST。

### R2
工厂按 `RAG_EMBED_BACKEND`；默认远程；与精排切换模式对齐。

### R3
失败不静默加载本地；模型名锁 bge-m3；不改 graph。

### R4
mock embeddings + 断言不加载 ST；人工小机无预热抽检。

### R5
闸未签前禁 30；实现只在 api 仓。

---

### 自检结论

> workspace 10 起草 · api 开工前须复制 task 入 api active，并签 HG-TASK-DRAFT + HG-AUDIT-R1。

- [x] 验收 / failure_paths / 非范围 / 依赖齐全  
- [x] 思考轮 R0–R5 + 控制表已写  
- [ ] 复制到 `ops-desk-api/docs/tasks/active/task_rag_embed_api_backend.md`  
- [ ] api `task lint` PASS  
- [ ] HG-TASK-DRAFT approved  
- [ ] HG-AUDIT-R1 approved  

---

## 修订

| 日期 | 说明 |
|---|---|
| 2026-08-17 | workspace 首稿：查询默认 ApiEmbedder；冷启动记录仅指针 |
| 2026-09-18 | 核验：api 已 CLOSE 且代码/compose 已接线 → workspace active 副本归档至 done（勿再开工） |
