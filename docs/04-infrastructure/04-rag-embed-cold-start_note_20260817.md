# 记录：RAG 嵌入冷启动导致 retrieve 分钟级（2026-08-17）

> **类型**：问题记录（**只记录** · 本文件不实施改码）  
> **仓**：`ops-desk-workspace`  
> **实现仓**：`ops-desk-api`  
> **关联**：[`02-prod-env-reload.md`](./02-prod-env-reload.md) §0（重建 api 丢 HF 缓存后须预热 bge-m3）  
> **下游 task**：[`../tasks/active/task_rag_embed_api_backend.md`](../tasks/active/task_rag_embed_api_backend.md)（迁移查询路径到 SiliconFlow `ApiEmbedder`）

---

## 1. 现象

- LC Evidence / Chat 检索路径上，**retrieve 偶发到分钟级**。
- 同进程连续第二次请求往往恢复到秒级 → 符合「进程内首次加载」特征，而非每次召回 SQL 都慢。
- 个人服 2C4G：重建 `api` 容器后未预热，首次请求还可能叠 **下载 ~2.2GB**（`IncompleteRead` / 前端 120s 超时），见 `02-prod-env-reload.md`。

---

## 2. 根因（对照代码 · 2026-08-17）

旁路与 Chat 查询路径均**硬编码**本地嵌入：

| 入口 | 路径 | 行为 |
|---|---|---|
| LC Evidence | `app/ops/lc_evidence_chain/retrieve.py` · `_get_embedder()` | 固定 `SentenceTransformerEmbedder`（bge-m3，懒加载 ~2.3GB） |
| Chat RAG | `app/ops/chat/rag_nodes.py` · `_get_embedder()` | 同上 |

`app/ops/rag/embedder.py` 已有 `ApiEmbedder`（SiliconFlow OpenAI 兼容 `/embeddings`），但**查询路径未接线**；精排已于同日前后切 SiliconFlow HTTP（`RAG_RERANK_BACKEND=siliconflow`）。

冷启动触发常见场景：

1. 进程 / worker **首次** embed  
2. `docker compose … up --force-recreate api` **丢掉容器内 HF 缓存**（现网未挂 `HF_HOME` volume）  
3. 多 worker 各自冷加载一次  

精排 HTTP（超时约 12s）**单独撑不满分钟级**；分钟级主因是 **本地 bge-m3 加载/下载**。

---

## 3. 与「加机器」的关系（结论备忘）

| 目标 | 是否必须加配 |
|---|---|
| 消灭用户路径上的冷启动 | **否**。可选：查询改 ApiEmbedder、启动预热、Ready 探针、HF volume、独立 embed 服务 |
| 坚持同进程常驻本地模型且多 worker | **可能需要**更大内存，避免 OOM |

个人小机：优先 **API 嵌入**（与精排同供应商）→ 见下游 task。  
企业富裕机器且坚持自助部署本地模型：见 **§6**（把冷启动关在发布期，而不是靠「CPU 更快」）。

---

## 4. 运维临时缓解（不改码 · 个人服现状）

重建 `api` 后、对用户开放前：

```bash
# 见 02-prod-env-reload.md §0
docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  exec -T api python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('BAAI/bge-m3'); print('bge-m3 loaded ok')"
```

确认：`HF_ENDPOINT` / 镜像站透传；日志是否出现 `loading embedding model BAAI/bge-m3`。

---

## 5. 明确非本记录范围

- 本文件**不**改 `ops-desk-api` 代码（实现走下游 task）  
- 不在本文件里执行升配 / 挂 volume（可另开 infra task；§6 仅方案备忘）  
- 不改灌库模型维度（仍须 `BAAI/bge-m3` @1024，与库内 fingerprint 一致）  
- Langfuse `t-` observation 404、token UI 抽检：观测问题，见 api hardening 关账说明，**非**本冷启动记录

---

## 6. 企业自助部署方案（以后回顾 · 富裕机器 + 本地模型）

> **前提**：机器内存/磁盘完全够常驻 bge-m3（约 +1～2GB+），且组织选择 **自托管嵌入**（不上 SiliconFlow 查询路径）。  
> **目标**：用户请求打到的进程里，模型**已经加载完**；冷启动只发生在部署流水线，不发生在首个用户。

### 6.1 原则

1. **加载在启动期，不在首个业务请求**  
2. **模型随 worker 常驻内存**，直到进程退出  
3. **新副本先预热再进流量**（Ready ≠ Alive）  
4. **禁止闲时缩到 0**（若 SLA 要求随时可用）

### 6.2 应用内启动预热（FastAPI 最直接）

- 在 **lifespan / startup** 中调用一次 `embed(["warmup"])`（若本地还有 CrossEncoder，一并 warmup）  
- 日志出现 `loading embedding model …` **成功之后**再对外 ready  
- 多 worker（gunicorn / uvicorn `workers=N`）：**每个 worker 各预热一次**（fork 后各自加载）

### 6.3 健康检查分层

| 探针 | 含义 | 未通过时 |
|---|---|---|
| liveness | 进程还活着 | 可重启 |
| **readiness** | 模型已加载、可服务 | **不要**进负载均衡 |

K8s / Nginx upstream / Compose 健康检查：只把 **Ready** 实例加进流量。新 Pod：启动 → 加载模型 → Ready → 才收请求。

### 6.4 副本与发布

- HPA / 副本数：`minReplicas ≥ 1`（按 SLA 可 ≥ N）  
- **不要**用「缩到 0 再冷启」的 serverless 形态承载本地大模型  
- 滚动发布：先起新副本并预热 → Ready → 再摘旧副本（控制 `maxUnavailable`）  
- 可选：构建期烘进镜像 + `HF_HUB_OFFLINE=1`，避免运行时下权重；或挂持久 **`HF_HOME` volume**，避免 recreate 丢缓存

### 6.5 独立 Embedding 服务（企业更干净）

```text
API / Chat  →  Embedding Service（常驻、已加载 bge-m3）
            →  Rerank（可远程或另一常驻服务）
            →  Qdrant / PG
```

- API 水平扩缩 **不必**每个实例扛 2.3GB  
- Embedding 池单独扩、单独预热、单独监控  
- 与「查询走 ApiEmbedder / 精排走 SiliconFlow」同一解耦思路；富裕机上 Embedding Service 用大内存机常驻即可

### 6.6 事件对照（用户会不会踩冷启动）

| 事件 | 用户是否冷启动 |
|---|---|
| 正常运行中的请求 | 否（已在内存） |
| 新部署 / 新 Pod（Ready 门禁正确） | 否 |
| 单副本 OOM / 崩溃重启 | 可能；靠多副本 + Ready 挡住该实例 |
| 全量缩到 0 再扩 | **会**；企业 SLA 下应避免 |

### 6.7 企业自助检查清单

- [ ] lifespan **强制 warmup**，失败则进程退出（半开服务不上线）  
- [ ] readiness 依赖 warmup 成功  
- [ ] `minReplicas ≥ 1`，禁止闲时缩零（若要求随时可用）  
- [ ] 滚动发布：新实例 Ready 后再切流  
- [ ] 监控：模型加载耗时、RSS、首包延迟、Ready 前是否误进流量  
- [ ]（可选）Embedding 独立部署；或镜像烘模 / `HF_HOME` volume  

### 6.8 与个人服路径的分工（回顾用）

| 场景 | 推荐 |
|---|---|
| 个人 / 2C4G / 要稳 | **查询改 SiliconFlow ApiEmbedder**（下游 task）；精排已 HTTP |
| 企业富裕 + 必须本地离线 | §6.2～6.7 自助部署；加配解决的是「能否常驻」，不是「CPU 让冷启动消失」 |
| 企业富裕 + 可接受托管查询 | 仍可用 ApiEmbedder；本地 ST 仅留给 ingest / 离线灌库 |

---

## 修订

| 日期 | 说明 |
|---|---|
| 2026-08-17 | 首记：retrieve 分钟级 ↔ 本地 bge-m3 冷启动；指向 ApiEmbedder 迁移 task |
| 2026-08-17 | 补 §6 企业自助部署方案（预热 / Ready / 副本 / 独立 embed 服务 / 检查清单） |
