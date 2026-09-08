# 生产：改 `.env` 如何真正生效

> **日期**：2026-08-17  
> **给谁**：SSH 上改 Flag / Key / 模型名之后，发现 `printenv` 还是旧值。  
> **对照 compose**：`deploy/docker-compose.prod.yml`（现网拷贝在 `/opt/ops-desk/deploy/`）  
> **对照 env**：服务器 `/opt/ops-desk/.env`（GHA **不会**下发这份文件）

---

## 0. 先做这一条（精排开关这次没生效）

你现在的状态：

| 位置 | `RAG_RERANK_ENABLED` |
|---|---|
| `/opt/ops-desk/.env` | `false`（已改） |
| `api` 容器 `printenv` | `true`（**进程仍用旧值**） |

**不要** `docker compose restart`。**不要** `systemctl restart docker`。**不要** `docker compose down`。

在生产机执行：

```bash
cd /opt/ops-desk/deploy

docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  up -d --no-deps api

docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  exec -T api printenv RAG_RERANK_ENABLED
# 期望：false
```

`--no-deps`：只动 `api`，不动 `db` / `qdrant`。  
`--build`：**不要加**（只改 env 不需要重建镜像）。

若 `up -d` 后 `printenv` 仍是 `true`，再强制重建同一服务：

```bash
docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  up -d --no-deps --force-recreate api
```

重建 `api` 会丢掉容器可写层里的 HuggingFace 缓存（现网未挂 `HF_HOME` volume）。关精排后仍要加载嵌入模型 `BAAI/bge-m3`，**必须先预热再点前端**，否则第一次 LC Evidence 会在下载 ~2.2GB 时被 Nginx/浏览器 120s 掐掉：

> **问题记录（2026-08-17）**：查询路径硬编码本地 ST → retrieve 可到分钟级。只记不改码见 [`04-rag-embed-cold-start_note_20260817.md`](./04-rag-embed-cold-start_note_20260817.md)；迁移到 SiliconFlow `ApiEmbedder` 见 [`../tasks/active/task_rag_embed_api_backend.md`](../tasks/active/task_rag_embed_api_backend.md)。

```bash
docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  exec -T api python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('BAAI/bge-m3'); print('bge-m3 loaded ok')"
```

---

## 1. 为什么改了 `.env` 没生效

应用**读的是容器环境变量**，不是宿主机文件。

```text
/opt/ops-desk/.env
        │
        │  只在「compose up」时被读入，用来展开 yaml 里的 ${VAR}
        ▼
docker-compose.prod.yml
  api.environment:
    RAG_RERANK_ENABLED: ${RAG_RERANK_ENABLED:-true}
        │
        │  展开结果写进容器配置（创建/重建时钉死）
        ▼
api 容器 printenv     ← 进程 os.getenv 只看这里
```

因此会出现：**文件已是 `false`，容器仍是 `true`。**

代码侧（`app/ops/rag/reranker.py`）只认容器值为 `true` / `1` / `yes` 才开精排。空字符串或 `false` = 关。

---

## 2. 命令对照（只记这一张表）

在 `/opt/ops-desk/deploy`，一律带：

`-f docker-compose.prod.yml --env-file /opt/ops-desk/.env`

| 你做了什么 | 该用的命令 | 会不会读新 `.env` | 副作用 |
|---|---|---|---|
| 只改 `/opt/ops-desk/.env` 里已透传的键 | `up -d --no-deps api` | **会**（compose 发现配置变了会重建 `api`） | `api` 短暂重启；HF 缓存丢；启动时跑 `alembic upgrade head` |
| 上条之后 `printenv` 仍旧 | `up -d --no-deps --force-recreate api` | **会**（强制重建） | 同上，更确定 |
| 改了代码 / Dockerfile | GHA 或 `up -d --build api` | 会（顺带用当时 `.env`） | 重建镜像，更慢；HF 缓存同样丢 |
| `docker compose restart api` | — | **不会** | 旧环境变量原样重启；HF 缓存保留 |
| `docker restart <容器ID>` | — | **不会** | 同上 |
| `systemctl restart docker` | — | **不会**（也没必要） | 整机容器全抖，过当 |
| `docker compose down` | — | 会停 **db / qdrant / api** | 网站挂；**禁止**为改 env 使用 |
| 只 `vim .env` 然后等 | — | **不会** | 进程继续用旧值 |

**口诀**：改 env → `up -d --no-deps <服务>` → `exec printenv` 核对。`restart` 只重启进程，不重新展开 `.env`。

---

## 3. 标准流程（以后每次改生产 env）

### 3.1 改文件

```bash
sudo vim /opt/ops-desk/.env    # 或你惯用的编辑器
grep '^RAG_RERANK_ENABLED' /opt/ops-desk/.env
```

键必须出现在 `docker-compose.prod.yml` 的 `api.environment:` 里（见 §4）。只写 `.env`、compose 没引用 → 容器永远看不到。

### 3.2 重载对应服务

只改 api 用到的键（几乎都是这种情况）：

```bash
cd /opt/ops-desk/deploy
docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  up -d --no-deps api
```

改 `db` 的 `POSTGRES_PASSWORD` 等：那是另一件事（库密码与 volume 里已有角色可能不一致），不要当普通 Flag 处理。

### 3.3 以容器为准核对

`printenv` 一次写多个名字时：**未设置的变量不会打空行，会直接跳过**。所以本次你看到两行（`true` + `HF_ENDPOINT`），中间的 `RAG_RERANK_MODEL` 其实是**未设置**（走代码默认 `BAAI/bge-reranker-v2-m3`），不是丢了。

建议一次一个，或包进 python：

```bash
docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  exec -T api printenv RAG_RERANK_ENABLED

docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  exec -T api python -c "import os; print(repr(os.getenv('RAG_RERANK_ENABLED')))"
```

文件与容器必须一致，才算生效。

### 3.4 运行时旁证（按 Flag 选）

关本地精排后，再问一发 LC Evidence，日志**不应**再出现：

```text
loading reranker
rerank failed; fallback to coarse
```

查法：

```bash
docker compose -f docker-compose.prod.yml --env-file /opt/ops-desk/.env \
  logs --since 10m api | grep -E 'loading reranker|rerank failed|CrossEncoder' || true
```

---

## 4. 只改 `.env` 不够：compose 必须透传

生产 `api` **没有** `env_file: /opt/ops-desk/.env`。Compose 只会把 yaml 里写明的键灌进容器。

现网已透传的例子：`RAG_RERANK_ENABLED`、`HF_ENDPOINT`、`RAG_VECTOR_BACKEND`、`SILICONFLOW_API_KEY` 等。见 `deploy/docker-compose.prod.yml` 的 `api.environment`。

| 现象 | 原因 | 做法 |
|---|---|---|
| `.env` 有键，`printenv` 无此键 | yaml **没有**这一行 | 改 **workspace** 的 `deploy/docker-compose.prod.yml`，scp 到现网后再 `up` |
| `.env` 没有键，`printenv` 却有值 | yaml 写了 `${VAR:-默认}` | 要么在 `.env` 显式写，要么改 compose 默认 |
| 仓里 compose 已加键，现网 `printenv` 仍无 | 现网 yaml 还是旧拷贝 | scp 后再 `up -d --no-deps api`；**合 PR / GHA 不会自动 scp compose** |

GHA `deploy-api.yml` 只 rsync **api 源码**并 `up -d --build api`。它会用**当时**的 `/opt/ops-desk/.env` 展开现网那份 compose，但：

- **不会**把你本机 `.env` 推上去；
- **不会**更新 `/opt/ops-desk/deploy/docker-compose.prod.yml`（除非你另 scp）。

---

## 5. `${VAR:-默认}` 陷阱

现网：

```yaml
RAG_RERANK_ENABLED: ${RAG_RERANK_ENABLED:-true}
```

含义：`.env` **没写**或写成空 → 容器得到 `true`。  
SPEC 曾锁生产默认关精排，但现网 compose 默认是 **开**。所以关精排必须在 `.env` **显式** `RAG_RERANK_ENABLED=false`，并且 **重建 api**。

同类：`RAG_VECTOR_BACKEND:-pgvector`、`HF_HUB_OFFLINE:-0`。  
切流 / 关精排 / 换镜像站，都不要假设「没写 = 我想要的默认」。

---

## 6. 重建 `api` 的副作用（按需承担）

| 项 | `restart` | `up -d --no-deps api` / `--force-recreate` |
|---|---|---|
| 读新 `.env` | 否 | 是 |
| `db` / `qdrant` volume | 不动 | 不动（有 `--no-deps`） |
| 网站 | 几乎不停 | `api` 大约几十秒 unhealthy，Nginx 可能 502 |
| HuggingFace 缓存（容器内 `/root/.cache/huggingface`） | **保留** | **丢失**（未挂 named volume） |
| 启动命令 | 不重跑 alembic | 会跑 `alembic upgrade head`（一般幂等） |

现网 2C4G：丢掉 HF 缓存后，第一次加载 `bge-m3` 若走 `huggingface.co` 会失败；须已透传 `HF_ENDPOINT=https://hf-mirror.com`，并按 §0 预热。

以后若不想每次 recreate 都重新拉权重：给 `api` 挂 named volume 到 `HF_HOME`（另开改 compose 的窗口，不在本文展开）。

---

## 7. 常见 Flag 速查

| 目的 | `.env` | 重载 | 核对 |
|---|---|---|---|
| 关本地精排 | `RAG_RERANK_ENABLED=false` | `up -d --no-deps api` | `printenv RAG_RERANK_ENABLED` → `false` |
| 开精排（本地 CE，2C4G 易 OOM） | `true` | 同上 | 日志出现 `loading reranker` 或失败回退 |
| 切读 Qdrant / PG | `RAG_VECTOR_BACKEND=qdrant` 或 `pgvector` | 同上 | `printenv RAG_VECTOR_BACKEND` |
| HuggingFace 镜像站 | `HF_ENDPOINT=https://hf-mirror.com` | 同上；**compose 必须有该键** | `printenv HF_ENDPOINT` |
| LLM / SiliconFlow key | 改对应 `*_API_KEY` | 同上 | **不要**把 key 打进聊天或日志；只确认 `printenv` 非空 |
| 鉴权 HMAC | `OPS_DESK_SECRET`（丢失见 [`03-ops-desk-secret-incident.md`](./03-ops-desk-secret-incident.md)） | 同上；**禁止**只 `restart` | 只确认 `printenv` 非空；轮换后须重发邀请码 |

---

## 8. 本机开发 vs 生产

| | 本机 `ops-desk-api` | 生产 |
|---|---|---|
| env 文件 | 仓根 `.env` | `/opt/ops-desk/.env` |
| compose | 仓内 `docker-compose.yml`（多半只起 db/qdrant） | `/opt/ops-desk/deploy/docker-compose.prod.yml` |
| api 进程 | 常是宿主机 `uvicorn --reload`，**直接读仓根 `.env`**，改完重启进程即可 | **只**读容器环境，必须 `compose up` |
| 改 Flag 后 | 重启 uvicorn 通常够 | 按本文 §3 |

不要拿本机「改 `.env` 即生效」去套生产。

---

## 9. 自检清单（改完再离开 SSH）

- [ ] `grep` 宿主机 `.env` 已是目标值
- [ ] 该键在现网 `docker-compose.prod.yml` 的 `api.environment` 里
- [ ] 已 `up -d --no-deps api`（必要时 `--force-recreate`）
- [ ] `exec printenv` 与文件一致
- [ ] 若重建了 `api`：已预热 `bge-m3` 或接受第一次请求变慢
- [ ] 未对 `db`/`qdrant` 使用 `down` / `--force-recreate`

---

## 10. 日志对照：哪句是内存不足（哪句不是）

| 日志 | 是不是内存不够 | 实际含义 |
|---|---|---|
| `Cannot copy out of meta tensor; no data!`（常跟 `CrossEncoder(...).to(device)`） | **是** | 2C4G 上 **bge-m3 已占 RAM**，再加载本地精排 `bge-reranker-v2-m3` 失败。会打 `rerank failed; fallback to coarse` |
| `Killed` / 容器 exit **137** / `dmesg` 里 `Out of memory` | **是** | Linux OOM killer |
| `urllib3.exceptions.IncompleteRead: IncompleteRead(45609510 bytes read, 2225462342 more expected)` | **不是** | HTTP **下载被截断**。已读 ~43.5 MiB，还缺 ~2.07 GiB（合计约 **2.2 GB** = `bge-m3` 权重）。镜像站/链路中断，或前端 120s 先断开 |
| `Context error: No active span in current context` | **不是** | Langfuse 没有父 span，**可忽略**，与召回/精排无关 |
| `loading reranker model` | 否（过程句） | 正在加载**本地** CE；`RAG_RERANK_ENABLED=false` 时不应再出现 |

`IncompleteRead` 里的两个数字：**已读字节 + 还期望字节 ≈ 文件总长**。约 2.2 GB 是嵌模型下载，不是「内存还差 2.2 GB」。

---

## 11. 事故记录（2026-08-17 · 关精排 recreate 后前端仍红）

**已确认开关生效**：`printenv` → `'false'`；`logs \| grep loading reranker\|rerank failed\|CrossEncoder` 无命中。精排**已关**。

**前端仍失败（重试 3 次成功 1 次）**：`up -d --no-deps api` 重建容器，HF 缓存丢失，请求路径仍要加载 **嵌入** `BAAI/bge-m3`（与精排开关无关）。下载未完成即 `IncompleteRead` / 120s 超时；某次下完或命中半成品缓存后成功。

**API 精排上生产时对照**：切 `RAG_RERANK_ENABLED=true` + `RAG_RERANK_BACKEND=siliconflow` 后，不应再出现 `loading reranker` / `meta tensor`。若前端再红，先查是不是又 recreate 丢了 **bge-m3** 缓存（`IncompleteRead`），而不是 SiliconFlow 精排。上线前仍先预热 bge-m3。

---

## 修订

| 日期 | 说明 |
|---|---|
| 2026-08-17 | 首稿。起因：`.env` 已 `RAG_RERANK_ENABLED=false`，容器 `printenv` 仍为 `true`（`restart` 不够） |
| 2026-08-17 | 现网已 `printenv='false'`；补日志对照：`IncompleteRead`≠OOM；recreate 丢 HF 缓存导致前端仍红 |
| 2026-08-17 | 手改 `.env` 丢掉 `OPS_DESK_SECRET` → GHA compose 插值失败；查询/轮换/重发邀请见 `03-ops-desk-secret-incident.md` |
