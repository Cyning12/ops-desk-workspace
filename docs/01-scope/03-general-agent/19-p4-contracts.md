# P4 契约文档 — domain-pack-v1（领域配置化） · run-tree-v1（多 Agent Run 树）

> **状态**：v1 终稿（P4-T1 落盘） · 2026-11-18
> **设计真源**：[18-p4-generalization-design.md](18-p4-generalization-design.md)（R1-R25 全关闭 · §14 Q1-Q7 明判 · 全部裁定以 18 文为准）；勘察真源 /tmp/opsdesk-rfc/inv-p4.md
> **本文定位**：P4 后续任务单 T2-T9（api/web 两仓 · 双泳道）实施的**共同契约面**。词表、DDL、端点字段、env 语义、失败路径以本文为准；本文与 18 文冲突处 → 18 文优先（18 文修订需走 R 轮重开）。
> **体例**：承 [15-p3-contracts.md](15-p3-contracts.md) 端点/词表/失败路径体例 + 18 文裁定措辞；每节附 SQL / 配置 / 端点示例。
> **红线**：SSE 零新帧 · cursor "{run_id}:{seq}" 零改动 · freeze 契约零修订 · ops 默认域零 diff · 总闸 off 态 SSE 帧面+行为面零 diff · 零新外部依赖 · 跨租户 404。

---

## §0 词表总表

| 词表 | 取值 | 说明 |
|---|---|---|
| **domain id** | `[a-z0-9_]+`（**无点号**） | 域标识；与 template id 词表（loader.py:20 `_ID_RE` 允许点号）**各自独立 · 禁止互拼**（§1.2 · R5） |
| **domain 保留字** | `allow_tags_any`/`allow_write_tags_any` 现存值 ∪ {`mcp`} | domain 值撞保留字 → manifest 拒载/显式告警（§2.3 · R6） |
| `OPS_DOMAIN` | domain id 词表 · 默认 `ops` | 部署级单值；非法值回退 `ops` + `logger.warning`（§5.1） |
| `OPS_RUN_TREE_ENABLED` | `off`（默认）/ `on` | Run 树总闸；非法值回退 `off` + warning（§12 · 三件套） |
| `OPS_RUN_TREE_MAX_CHILDREN` | int · 默认 `8` | 每父 run 子 run 总数上限（§8.4） |
| `runs.depth` | `0`（根 run）/ `1`（子 run） | 深度硬上限 1，结构性无环（§7.3） |
| `runs.status`（六词表 · **不动**） | `running`/`waiting_approval`/`done`/`error`/`disconnected`/`resumed` | 子 run 复用同一状态机；**不加新词表值** |
| `event_type` 白名单（8 值 · **不动**） | `run.start`/`answer`/`subtask.progress`/`node.progress`/`hitl.waiting`/`done`/`error`/`hitl.resumed` | 子 run 帧序全部落在既有词表内（§11.1） |
| cursor 形状（**不动**） | `"{run_id}:{seq}"` | sse_replay.py:12-14；树回放 = 投影拿树关系 + 逐 run 既有端点回放（§11.3） |

---

# 第一部分 · domain-pack-v1（领域配置化契约）

## §1 域 id 词表与词表纪律

### 1.1 域 id 词表

域 id = 小写字母/数字/下划线：`^[a-z0-9_]+$`，**不含点号**。非法形态处处拒入（manifest 加载期 ManifestError · env 解析期回退 ops + warning · prompt 加载路径不进），与 capability tag 形态校验同源。

### 1.2 词表独立 · 禁止互拼（R5 · platform N1）

- **domain 词表与 template id 词表各自独立**：template id 允许点号（`lg_rag.supervisor.system`），domain 不允许。
- **禁止互拼**：domain 只拼**目录名**（`assets/<domain>/`），**不得拼进 template_id**（禁 `lg_rag.supervisor.system.oa` 形态）；template_id 不感知 domain。
- 理由：防后续把 domain 拼进模板 id 的回流——那会污染白名单维度并引起 11 处调用点 churn。

### 1.3 domain 保留字（R6 · platform N2）

domain 值**不得**与以下任一撞名（撞名即注入 tag 意外命中安全豁免面）：

1. `CapabilityFilter.allow_tags_any` / `allow_write_tags_any` 词表中的任何现存值（baseline.py:35 `DOMAIN_ALLOW_TAGS={"oa","mcp"}` 是豁免 kinds 裁剪的消费点）；
2. 字面量 `"mcp"`（同时是 MCP 翻译条目首 tag，mcp/translator.py:372）。

**裁定**：domain=mcp → **拒载 / 显式告警**（T3 单测钉死）。注意：`oa` 在 DOMAIN_ALLOW_TAGS 中是**合法域值**（oa.readonly.v1.yaml 的正式域），豁免面语义不变——本条防的是新域撞名豁免词表，不溯及既有 oa。

### 1.4 配置示例

```bash
# 部署级域选择（进程单值 · 默认 ops）
OPS_DOMAIN=oa
```

---

## §2 manifest domain 键消费语义（→ tags 注入）

### 2.1 消费规则

加载器 `_parse_and_validate`（manifest.py:450-479 现状只校验结构、**不读不拒** domain 键——本契约消除该「第三状态」）：

| 情形 | 行为 |
|---|---|
| 顶层 `domain` 键存在且合法 | 将 domain 值**注入该 manifest 全部 capability 的 tags 集合**（与显式声明 tags 取**并集去重**） |
| `domain` 键缺失 | 不注入（builtin.v1.yaml **零 diff**） |
| `domain` 非法形态（非字符串/词表外） | `ManifestError` **拒载**（加载期强校验先例 manifest.py:444-447） |
| `domain` 撞保留字（§1.3） | **拒载 / 显式告警**（R6） |

消费语义锚 = types.py:160-162 既有共识「域天然落在 tags 上」：`CapabilityFilter` 的 `tags_any`/`allow_tags_any`/`allow_write_tags_any` **判序不动**；oa 域能力经 `allow_tags_any={"oa"}` 逐批放行的用法自此有了 manifest 侧真源。**被否已钉**：否 schema 拒绝 domain 键 · 否 Domain 注册表实体 · 否 domain 进 CapabilityFilter 判序字段。

### 2.2 tags 冲突处置 + oa 手写 tags 防双写漂移约定（R10 · platform N7）

- **冲突处置 = 并集去重**：manifest 手写 tags 与 domain 注入 tag 取并集，无优先级、无覆盖——tags 是集合语义。
- **oa 防双写漂移约定**：oa 三能力现状已手写 `tags:[oa,...]`（oa.readonly.v1.yaml:29/96/157）。T3 注入实现后，**验收钉死**：「注入并集去重后 tags 集合 = 现状手写面**逐值一致**」——即 domain 键对 oa 是便利（防新增能力忘写 tag）而非改变现状语义；**禁止**出现「手写 tags 删了 oa、靠注入补齐」与「手写保留、注入叠加」两种写法并存导致的漂移。约定：**oa manifest 手写 tags 保留不动**，domain 注入作为兜底；任何一侧语义变更必须双侧同步并过验收对拍。

### 2.3 MCP 翻译条目 domain 真源 = server 配置侧（R6 · platform N3）

- MCP 翻译条目的域归属**唯一真源 = 其所属 manifest（server 配置侧）的 domain 键**；T3 注入覆盖 mcp 块条目。
- **远端 server 无 domain 声明可信面**——MCP 协议无域语义，远端自述不可信。
- **翻译层（mcp/translator.py）禁加任何域逻辑**，本契约注明防后续回流。

### 2.4 manifest 示例

```yaml
# app/ops/capability/manifests/oa.readonly.v1.yaml
version: 1
domain: oa                      # 顶层 domain 键：注入全部 capability tags 并集
capabilities:
  - id: oa.doc.search
    kind: http
    tags: [oa, readonly]        # 手写 tags 保留（§2.2）；注入后 = {oa, readonly} 并集
    # ... 其余字段不动
```

---

## §3 prompt 域机制契约（目录回退 · 白名单保留 · contextvar 注入）

### 3.1 目录回退规则

`load_asset(template_id, domain=None)`（loader.py:52 改造）：

1. `domain` 非空时**先读** `assets/<domain>/<template_id>.md`；
2. 文件**不存在** → 回退根目录 `assets/<template_id>.md`；
3. 缓存键 = `(template_id, domain)`；
4. **覆盖以模板为单位、缺省回退**——不允许半份文件合并等任何第二形态（防资产矩阵失控 R-P4-1）；
5. **坏文件不静默**：域路径文件存在但形态非法（front-matter 缺字段/空 body/version 非法）→ `PromptAssetError` 显式炸点名路径（loader :3-6 既有纪律，**域路径不豁免**——缺文件才回退，坏文件显式炸）；
6. **域集合运行时发现在 `assets/` 子目录，不硬编码**——加一个域 = 加一个子目录，零代码零注册动作。

### 3.2 白名单保留清单（11 模板 id · 编译期白名单不动）

templates.py:11-26 的 11 个模板 id 仍是编译期白名单（安全面：loader 只认白名单 id + 文件名正则，不变）；`TEMPLATES` 保持构建 ops 默认面（import 期行为零 diff），新增 `get_template_for_domain(template_id, domain)` 薄封装。

| 模板 id | 域耦合性（oa 领域包处置 · §2.4 18 文） |
|---|---|
| `lg_rag.supervisor.system` | 域耦合 → oa 覆盖 |
| `lg_rag.direct.system` | 域耦合 → oa 覆盖 |
| `lg_rag.aggregator.system` | 域耦合 → oa 覆盖 |
| `lg_rag.router.system` | 域耦合 → oa 覆盖 |
| `lg_rag.rewrite.system` | 域耦合 → oa 覆盖 |
| `lg_rag.intent.system` | 域耦合 → oa 覆盖（intent 词表 oa 化） |
| `memory.extract.system` | 域耦合 → oa 覆盖（记忆 key 目录 oa 化） |
| `session.summary.system` | 域中立 → **刻意不覆盖**（走根目录回退） |
| `lg_rag.query_rewrite.system` | 域中立 → **刻意不覆盖** |
| `lg_rag.extract.system` | 域中立 → **刻意不覆盖** |
| `lg_rag.supervisor.suffix` | 域中立 → **刻意不覆盖** |

> 4 份中立模板刻意不覆盖，使「混合解析」成为回退机制的端到端实证（S1 checklist ①）。

### 3.3 contextvar 注入面

- 新增 `app/ops/prompts/domain_context.py`（仿 tenant_context.py:11-26 先例）：`current_domain()` contextvar，**默认 `"ops"`**。
- 注入位：OPS_DOMAIN env 在 **run 启动处**（start_run_worker 设置，与 set_current_tenant 同位 run_worker.py:117-120）注入。
- **调用点零 churn**：全部 11 处调用点（nodes.py:196/2703/2740 · lg_rag/nodes.py:85/216 · intent.py:19 · memory/extract.py:107）**不改签名**——render 内部读 contextvar 取域。
- 漏设无害化：默认 ops 与现状同值 ⇒ 非 run 通路调用读到错误域的风险结构性消解（R-P4-2）。

### 3.4 默认 ops 零 diff 声明

**`assets/ops/` 目录不建**——ops 域解析恒走根目录回退，加载结果与现状**逐字节一致**。零 diff 由「回退顺序 + 不建 ops 目录」**双保险**构成；T2 验收 = 全量 11 模板 body 在 OPS_DOMAIN on/off 双跑下逐字节对拍一致。

### 3.5 目录结构示例

```
app/ops/prompts/assets/
├── lg_rag.supervisor.system.md      # 根目录 = ops 默认面（逐字节不变）
├── memory.extract.system.md
├── ...（其余 9 份根目录模板不动）
└── oa/                              # 加一个域 = 加一个子目录，零代码
    ├── lg_rag.supervisor.system.md  # 7 份 oa 覆盖
    ├── lg_rag.direct.system.md
    ├── lg_rag.aggregator.system.md
    ├── lg_rag.router.system.md
    ├── lg_rag.rewrite.system.md
    ├── lg_rag.intent.system.md
    └── memory.extract.system.md
    # 4 份域中立模板刻意不在此目录 → 回退根目录
```

---

## §4 RAG 域配置面（collection env · glossary 文件回退 · ingest 不泛化）

### 4.1 collection env 回退矩阵（**fail-closed** · R3/LB3）

`qdrant_collection(domain)`（backend.py:39-40 改造）：

| 域 | 回退链 | 缺省行为 |
|---|---|---|
| **ops（含缺省域）** | `QDRANT_COLLECTION_OPS` → `QDRANT_COLLECTION` 全局值 → `ops_knowledge` | 三级回退 · **零 diff** |
| **domain≠ops** | `QDRANT_COLLECTION_<DOMAIN_UPPER>` 单级 | **env 缺省 ⇒ fail-closed：该域本地 RAG 显式禁用**——rag 子任务报「**本域未配置检索**」· **不回落全局/ops_knowledge** |

**理由（钉死）**：初稿三级回退意味着 oa 部署忘配 per-domain env 时 rag 子任务**静默检索 ops 语料**喂进 oa 答案——非「空跑」，是**跨域向量泄漏**（ops 语料含发布面/回滚面内部细节进 oa 上下文，R-P4-7）；prompt 词表收紧不能充当数据隔离闸。纯 env 约定，零新配置文件。

### 4.2 glossary 按域文件回退

- `glossary.<domain>.yaml` 文件回退（glossary.py:18 单路径 → 按域解析）：**存在则读域文件，否则读 `glossary.yaml`**；加载改按域缓存。
- **oa glossary 本波不随包交付**（oa 三能力全 http kind 远端只读，不消费本地 RAG = 死配置，违「不预搭」纪律）；glossary 回退机制由 ops 夹具单测覆盖。

### 4.3 source_type 词表 + ingest 不泛化声明

- `source_type` 词表 `issue|pr|doc` 与 `load_issue_units`/`load_pull_units` 直读 OpsIssue/OpsPullRequest 表（ingest.py:43/58-89）**本波不泛化**——绑死 ops 语料模型。
- oa 验证域**不消费本地 RAG**（三能力 oa.doc.search/oa.org.whois/oa.todo.mine 全 http kind 远端只读）。
- **触发式后续登记**：出现第二个需要本地语料 ingest 的域时再泛化。

### 4.4 配置示例

```bash
# ops 部署（现状 · 零 diff）
QDRANT_COLLECTION=ops_knowledge          # 或更优先 QDRANT_COLLECTION_OPS

# oa 部署：必须显式配置，否则该域 RAG 显式禁用（fail-closed）
OPS_DOMAIN=oa
QDRANT_COLLECTION_OA=oa_knowledge        # 缺省 → rag 子任务报「本域未配置检索」
```

---

## §5 域=部署级 · tenant 正交 · 记忆面与共库约束

### 5.1 域=部署级（OPS_DOMAIN · 不挂 tenant）

- domain 是**部署级配置**（OPS_DOMAIN env，**进程单值**，承 QDRANT_COLLECTION 全局单值先例 backend.py:28-40）。
- **不挂 tenant**：tenant_context.py:11-26 维持纯租户谓词，不加域维度。**一次部署 = 一个域 + 多租户**；跨租户隔离规则（F1-F6）在域内不变。
- 理由：域改变的是语料/prompt/能力集语义——与部署的外部系统绑定（OA_BASE 本身就是部署 env），与「哪个租户在问」正交。**被否**：per-tenant domain（无消费者 · 把部署语义错配进数据模型）。

### 5.2 多域部署不得共库（R4 · platform LB4 · 部署面硬约束）

- **事实**：记忆落库键 = tenant+user，**无 domain 维**（memory/extract.py FactCandidate 现状）。
- **风险**：「一次部署=一个域」不蕴含「一域一库」——双部署共库时，oa 部署写入的 facts（oa key 目录产物）在同库 ops 部署召回侧**无任何域过滤命中** = 跨域污染面（R-P4-11）。
- **契约约束**：**多域部署不得共库**——域=部署级 ⇒ 一次部署天然单库单域，**零 DDL**；本节为显式文档声明，防未来误配。
- **触发式后续**：共库真实需求出现 ⇒ memory 加 domain 列 + 召回过滤（18 §9 登记，本波非范围）。

### 5.3 skill/goal 部署级定位声明（R11 · platform 盲点1）

- `format_skill_catalog`（skill_registry/registry.py:37）注入的 `skills/` 目录与 goal 注入（continuity.py:507-535 + goals/inject.py:18-22）是**部署级资产**——**不进 `assets/<domain>/` 域回退机制**。
- **oa 部署自管其 skills 目录**；禁止把 skill 目录塞进域回退（防后续误配，本节为契约面声明）。

### 5.4 部署示例（docker-compose 片段）

```yaml
# 两域 = 两独立部署 + 两独立库（§5.2 硬约束）
services:
  api-ops:                        # 现状部署 · 零 diff
    environment:
      # OPS_DOMAIN 缺省 = ops
      DATABASE_URL: postgres://.../opsdesk
  api-oa-demo:                    # dev 演示部署（不进 prod 默认面 · 18 §11.2）
    environment:
      OPS_DOMAIN: oa
      OPS_CAPABILITY_EXTRA_MANIFESTS: /app/manifests/oa.readonly.v1.yaml
      DATABASE_URL: postgres://.../opsdesk_oa   # 独立库，不得与 ops 共库
```

---

## §6 domain-pack 失败路径汇总

| 失败 | 行为 |
|---|---|
| OPS_DOMAIN 非法值（词表外/含路径符） | 回退 `ops` + `logger.warning`（**不进加载路径**，防 env 注入路径穿越） |
| manifest domain 键非法形态 | `ManifestError` 拒载（加载期强校验） |
| manifest domain 值撞保留字（§1.3） | **拒载 / 显式告警**（T3 单测钉死 domain=mcp） |
| 域 prompt 文件存在但形态非法 | `PromptAssetError` 显式炸点名路径（**域路径不豁免**：缺文件才回退，坏文件不静默） |
| domain≠ops 且 `QDRANT_COLLECTION_<DOMAIN>` 缺省 | **fail-closed**：本地 RAG 显式禁用 · rag 子任务报「本域未配置检索」· 不回落（R3） |
| `QDRANT_COLLECTION_<DOMAIN>` 设了但集合不存在 | RAG 检索既有降级链（grader/语义路兜底）不动；env 配置属部署面，不新增校验面 |
| 多域部署共库（误配 · §5.2） | 契约禁止+本节显式声明；共库即跨域召回污染面（R-P4-11）；触发式后续=memory 加 domain 列 |

---

# 第二部分 · run-tree-v1（多 Agent Run 树契约）

## §7 数据模型契约：runs 三列 + uq 委派 claim

### 7.1 唯一新 DDL（runs 表加三列 · 遵守「新 DDL 含 tenant_id」——runs 已有 tenant_id 满足）

| 列 | 型 | 说明 |
|---|---|---|
| `parent_run_id` | String(64) null | 父 run；**不加 FK**（承 run_events 顺序容错先例 models.py:285-288 注释） |
| `subtask_id` | String(64) null | 父图内子任务 id（委派 claim 的业务键一半） |
| `depth` | Integer not null default 0 | `0`=根 run，`1`=子 run；**深度硬上限 1**（§7.3） |

### 7.2 SQL 示例（alembic 迁移 · 可逆）

```sql
ALTER TABLE ops_lg_rag_runs
  ADD COLUMN parent_run_id VARCHAR(64) NULL,
  ADD COLUMN subtask_id    VARCHAR(64) NULL,
  ADD COLUMN depth         INTEGER NOT NULL DEFAULT 0;

-- 委派 claim 键：部分唯一索引 =「建行即认领」
CREATE UNIQUE INDEX uq_ops_lg_rag_runs_parent_subtask
  ON ops_lg_rag_runs (parent_run_id, subtask_id)
  WHERE parent_run_id IS NOT NULL;

-- 投影反查索引
CREATE INDEX idx_ops_lg_rag_runs_parent
  ON ops_lg_rag_runs (parent_run_id);
```

`create_run`（run_store.py:52-75）扩 `parent_run_id`/`subtask_id`/`depth` 三个**可选** kw 参数——缺省调用零 diff。

### 7.3 委派 claim 语义（建行即认领 · ON CONFLICT）

- **claim = 建行**：`INSERT ... ON CONFLICT DO NOTHING`（复用 OpsScheduleFire 范式 models.py:750-785；PG 同事务撞 uq abort 教训已在 14 R10 记录——须新写 ON CONFLICT 路径，create_run 现状 check-then-insert 不复用）。
- **撞 uq = 「该子任务已委派过」** → SELECT 取回已有 child run_id 复用，**零重复建行**（防 replan/resume/checkpoint 重放重复建行；图节点重执行是 LangGraph 常态）。
- **并发正确性（R9/N6 复核结论）**：ON CONFLICT DO NOTHING 并发双 INSERT 正确（败者阻塞至胜者提交后 SELECT 取回）；`subtask_id` 签发 `f"{run_id}:{seq}"` 且 locked 前缀序列**不回退不复用**（nodes.py:876-928）⇒ replan 不撞号，uq 撞键仅发生在「同一子任务重入」的语义正确场景。
- **深度断言**：claim 建行时校验父 run `depth = 0`，否则拒建 + `logger.exception`（防御性断言，正常路径不可达——子 run 跑非 supervisor 委派管线，结构性无环，不靠运行时检测）。
- **被否已钉**：否新 delegations 台账表（建行即认领单真源）· 否 root_run_id 冗余列（depth≤1 时 root≡parent）· 否深度参数化 · 否运行时环检测。

### 7.4 claim SQL 示例

```sql
-- 委派 claim（同一事务内）：
INSERT INTO ops_lg_rag_runs
  (run_id, tenant_id, user_id, thread_id, status, parent_run_id, subtask_id, depth, created_at)
VALUES
  (:child_run_id, :tenant_id, :user_id, :thread_id, 'running', :parent_run_id, :subtask_id, 1, now())
ON CONFLICT (parent_run_id, subtask_id) WHERE parent_run_id IS NOT NULL
DO NOTHING;
-- 未插入（已委派过）→ 取回复用：
SELECT run_id FROM ops_lg_rag_runs
WHERE parent_run_id = :parent_run_id AND subtask_id = :subtask_id;
```

---

## §8 触发语义 · 归属继承 · 预算

### 8.1 触发（闸开时 tool_exec 委派提升为子 run · plan-JSON 零新 type）

- 总闸 `OPS_RUN_TREE_ENABLED=on` 时：`route_next_subtask`（nodes.py:1837-1873）对 **type=tool 的 inflight 子任务**不再发 `Send(tool_exec)`，改走「委派 claim（§7.3）→ 启动 `start_delegate_run_worker` 子 run worker → 图内节点轮询子 run 终态 join」。
- **rag/extract 子任务留在图内不动**（无外溢副作用、无独立回放/审计诉求）。
- **plan-JSON 不加新 type**：提升面由「子任务 type=tool + 闸开」机械决定，`SUBTASK_TYPES` 词表（nodes.py:94）不动，supervisor prompt 零改动。
- 子 run 帧序 = `run.start`（payload 带子任务 query 摘要）→（`hitl.waiting`，若能力要求审批）→ `answer` → `done`（或 `error`）——**全部既有帧类型，零新帧**；runs.status 六词表不动。

### 8.2 归属继承（assert_run_owned 兼容声明 · R7/N4 测试矩阵要求）

- 子 run **继承**父 run 的 `tenant_id`/`user_id`/`thread_id`——claim 建行时**从父行取值，不从请求上下文取**（承 14 §1.8「请求上下文外创建须显式传身份」纪律）。
- **兼容声明**：runs 列表/events/replay 的既有 `thread_owner`/`assert_run_owned` 校验（runs_router.py:67-74）对子 run **天然通过**（同 user 同 thread），**零改动**；跨用户/跨租户访问子 run → 404（不泄露存在性）。
- **N4 测试矩阵要求（R7）**：`run_owner` = 反查事件表首行 `user_id`（event_store.py:100-117 · hitl/router.py:405-439 恢复段同靠此链——查不到归属→不落盘→前端永远停「等待授权」）。故契约钉死：**子 run 首帧 `run.start` 落盘 `user_id = 父 user_id`** 是 decide/resume/replay 全链成立前提；T7 验收矩阵必含「子 run 首帧落盘 user_id → run_owner 反查成立 → decide/resume/replay 全链实证」。
- **被否**：子 run 独立归属（无消费者且打破审计链）· 父 run 代理审批（审批面双写=状态分叉）。

### 8.3 join 与断线恢复（轮询终态 + DB claim 重入）

父图提升分支的等待节点**轮询子 run 终态**（SELECT status，间隔 1s，承 runs.status 状态机 TERMINAL_STATUSES），超时/失败预算复用既有子任务闸（is_supervisor_budget_exhausted · MAX_SUBTASKS=4 不动）；子 run 达终态后从其事件表读 answer/done payload 进 subtask_join 既有通路。断线矩阵（18 §3.5）：父崩 → claim 重入撞 uq 取回零重复建行；子崩 → orphan 扫描对子 run 天然生效零改造；claim 已建 worker 未起 → 孤儿补偿两段式 + 父侧失败预算收口（残余窗口登记 R-P4-4）。

### 8.4 预算防爆炸（三层）

1. 深度 1 硬上限（§7.3 结构性）；
2. **每父 run 子 run 总数上限 `OPS_RUN_TREE_MAX_CHILDREN` 默认 8**（claim 前 `COUNT(parent_run_id)` 校验，超限 = 该子任务按失败进 observe 通路 + 审计日志——覆盖 replan 多轮累计）；
3. 单轮扇出 = 既有 `MAX_SUBTASKS=4` 不动。

**配额归因**：子 run 的 usage/span key 继承父 run user_id/tenant_id（`start_delegate_run_worker` 显式传入）；**配额记桶键 = 父（根）run_id**——子 run 配额计入父 run 预算桶（与图内 Send 记桶语义逐值一致 · 防 1 父+8 子约 9× 分裂 · §9）。

---

## §9 委派令牌与身份映射（R2/LB2 · 契约钉死五行表）

### 9.1 签发面裁定

- **委派令牌由子 run 执行体在每次执行尝试时自发签发**（issuance 策略闸 nodes.py:677-702 已是可提取单元 · 随执行体一并复用），**TTL 自尝试起算**——HITL 长等后 decide 重跑即重签发，「批准后 REJECT_EXPIRED 必败」形态**消解**（§13 落行 · R13）。
- **签发审批（`delegation_issue_hitl_required`）仍在父侧 dispatch 前完成**——子侧重签发只解决墙钟，**不绕审批**。
- **父签发的令牌仅作授权凭证、不直接复用**于子 run 验签（verify_token 校验 subject 四元组含 run_id/subtask_id · delegation.py:567-574 · 直接复用必撞 REJECT_SUBJECT_MISMATCH）。
- 令牌**格式**复用成立；**签发主体/时序**按本条修订（Q3 补注）。
- **nonce**：每次执行尝试新 token 新 nonce，重跑不复用旧 nonce（一次性 delegation.py:557-579 与重跑的交互进 T7 用例）；nonce 维持进程内 `_NonceRegistry` **不外置**（子 run 与父同进程执行验签 · 外置登记为多副本化债）。

### 9.2 身份映射表（契约钉死五行）

| 面 | 取值 |
|---|---|
| 事件/状态行 `run_id` | **子 run_id** |
| token binding `run_id` / `subtask_id` | **子 run_id / 子任务 id**（claim 先于签发——建行即得 child_run_id，次序天然满足） |
| cap_ctx 预算键（配额记桶） | **父（根）run_id**——子 run 配额计入父 run 预算桶（§8.4 · 防约 9× 分裂） |
| HITL 单据 `run_id` | **子 run_id**（「打开子 run 视图审批」decide/_run_owner_of 链成立前提 · R7） |
| `_approval_consumed` 匹配键 | 与 HITL 单据对齐：**（子 run_id, subtask_id, capability_id）**（nodes.py:497-533） |

---

## §10 子 run HITL 恢复契约（R1/LB1 ·「退出-重跑-消费闸放行」三段）

**既有 resume 通路对子 run 恒不成立**：resume_hitl_run 是图 checkpoint 耦合（hitl/resume.py:311 → aget_state 探针 → Command(resume=...)），子 run 是从 tool_exec 提取的**非图执行体**，无 LangGraph checkpoint。裁定 = **三段机制，全程复用既有 HITL 端点/审批卡，零新端点零新帧**：

1. **退出**：子 run 执行体遇写类能力且审批未消费 → 落 `hitl.waiting` 帧 + `status=waiting_approval` 后**退出 worker**（不占 `_workers` 槽 · HITL TTL 既有语义兜底）；
2. **重跑**：用户经**既有 decide/resume 端点**（按子 run_id）批准 → resume 通路按 run 行 `depth` 分流：`depth=1` → **重启 `start_delegate_run_worker` 重跑该子任务执行体**；
3. **消费闸放行**：重跑至同一能力调用点，`_approval_consumed(run_id, subtask_id, capability_id)` 命中放行（nodes.py:497-533 既有消费点 · **fail-closed**）。

**重跑幂等成立**：全部副作用闸（idempotency/circuit/budget/HITL）在 capability_ainvoke 之前，重跑只重放无副作用的闸链前段；**重复 decide / 重复 resume 不重复执行能力**（消费闸一次性）。T7 实证两条钉死：「approve 后子 run 重跑放行至 done」·「重复 decide/重复 resume 不重复执行能力」。

**端点示例（全部既有端点 · 零新增）**：

```bash
# 1. 查看子 run 待审批（runs 投影 · §11.4）
curl 'https://<host>/api/ops/lg-rag/threads/t-001/runs' \
  -H 'Cookie: ops_session=<session>'
# → 列表项含 depth=1、status=waiting_approval 的子 run

# 2. 按子 run_id 起续看流（hitl.waiting 帧渲染既有 HitlApprovalCard）
curl -N 'https://<host>/api/ops/lg-rag/runs/<child_run_id>/stream' \
  -H 'Cookie: ops_session=<session>'

# 3. 既有 HITL decide（批准）→ resume 按 depth 分流 → 重启 delegate worker 重跑放行
curl -X POST 'https://<host>/api/ops/hitl/<child_run_id>/decide' \
  -H 'Content-Type: application/json' \
  -H 'Cookie: ops_session=<session>' \
  -d '{"approval_id": "<approval_id>", "decision": "approve"}'
```

---

## §11 SSE 帧面 · cursor · REST 投影契约

### 11.1 帧面零新增

- **帧类型零新增**（web 7 种 useLgRagSse.ts:28 / iOS 11 种 LgRagFrame.swift:60-72 词表均不动）。
- `run.start` payload 加**可选** `parent_run_id` 字段——纯可加字段（web/iOS 对未知键天然忽略，且老客户端**根本收不到子 run 的流**，见 §11.2）。

### 11.2 流边界钉死（帧永远 per-run 流）

- 客户端订阅父 run（stream/replay 按父 run_id）收到的帧序列与今天**逐字节一致**（父图仍发自己的 subtask.progress，子任务维度进度语义不变）。
- **子 run 的帧只出现在按子 run_id 订阅的流里**；老客户端没有任何通路被动收到子 run 帧。老客户端行为钉死为「看到的世界与 P3 完全一致」（契约 freeze 零修订）。
- **被否**：树形合并流 / 跨 run 统一 cursor（无消费者 · 破 cursor 成本收益倒挂 · 登记后续候选）。

### 11.3 cursor 不动

`"{run_id}:{seq}"`（sse_replay.py:12-14）**零改动**。树形回放 = ① REST runs 列表投影拿树关系 → ② 对任意 run_id 用**既有** replay/续看端点逐 run 回放。每 run 一条流，cursor 语义恒为单 run 内 seq。

### 11.4 REST 投影加性变更（不开 children 端点）

`GET /api/ops/lg-rag/threads/{thread_id}/runs` 列表项新增两字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `parent_run_id` | string · null | 父 run_id；`null` = 根 run |
| `depth` | int | `0`/`1` |

- **加性变更契约豁免**：消费方须容忍未知键（承 R-P4-8 兼容惯例）；旧 web 版本忽略未知键零影响。
- **不开 `/runs/{id}/children` 端点**：列表平铺 + parent_run_id 已够客户端 O(n) 组树，children 端点是同信息的第二投影面（被否）。
- 闸 off 部署收到含 parent_run_id 的投影（数据残留）→ 纯数据字段，消费方忽略；REST 面不加过滤（投影幂等）。

**投影示例**：

```bash
curl 'https://<host>/api/ops/lg-rag/threads/t-001/runs' \
  -H 'Cookie: ops_session=<session>'
```

```json
{
  "ok": true,
  "data": {
    "runs": [
      { "run_id": "r-parent", "status": "done", "depth": 0, "parent_run_id": null, "query_summary": "巡检三台主机..." },
      { "run_id": "r-child-1", "status": "done", "depth": 1, "parent_run_id": "r-parent", "query_summary": "巡检 host-a 磁盘与内存" },
      { "run_id": "r-child-2", "status": "waiting_approval", "depth": 1, "parent_run_id": "r-parent", "query_summary": "巡检 host-b 磁盘与内存" }
    ]
  }
}
```

### 11.5 「off 态零 diff」精确措辞（R12 · 契约钉死）

**「off 态零 diff」= SSE 帧面 + 行为面零 diff；REST 投影新增 parent_run_id/depth 字段为加性变更（契约豁免 · 消费方须容忍未知键）**。投影字段是无条件常加字段，不属于「零 diff」语义面。验收 = 闸 off 部署全量测试（含 TestClient 帧面/行为面）零 diff。

### 11.6 iOS 兼容性三断言（本波 iOS 零任务单 · 登记）

1. **零新帧类型** → LgRagFrame.swift 词表不触达；
2. runs 列表为 REST 投影可加字段 → 旧版 iOS 若消费该端点忽略未知键（当前 iOS 无 runs 列表面消费——P3 R23 登记口径维持）；
3. 子 run 流只有按子 run_id 订阅才出现，iOS 无此通路。

登记项：iOS 树形任务面板 + 子 run 审批面 = 后续候选（与 P3 R23 合并跟踪；触发条件 = web 面 S2/S3 验收通过后产品评审立项）。

---

## §12 总闸环境契约（OPS_RUN_TREE_ENABLED 三件套 · 承 auto_resume / 14 §1.7 先例）

| 项 | 约定 |
|---|---|
| 词表 | `off`（**默认**）/ `on` |
| 非法值 | 回退 `off` + `logger.warning` |
| off 态行为 | SSE 帧面+行为面**零 diff**（§11.5）；route_next_subtask 走既有 Send 路径逐字节不变 |
| on 态行为 | type=tool inflight 子任务提升为子 run（§8.1） |

```bash
# 默认（零 diff · 现状）
# OPS_RUN_TREE_ENABLED 缺省 = off

# 闸开部署
OPS_RUN_TREE_ENABLED=on
OPS_RUN_TREE_MAX_CHILDREN=8     # 缺省 8
```

---

## §13 Run 树失败路径汇总（含令牌过期行 · R13）

| 失败 | 行为 |
|---|---|
| 委派 claim 撞 uq（replan/resume/checkpoint 重入） | SELECT 取回已有 child run_id 复用，**零重复建行**（§7.3） |
| 子 run 超 `MAX_CHILDREN` 上限 | 该子任务按失败进 observe/critic 既有通路 + 审计日志 |
| 父轮询期间子 run 达 error/disconnected | 按失败子任务进 subtask_join → observe 既有收口（预算尽→end 等 critic 规则不动） |
| claim 建行成功但子 worker 启动异常 | `logger.exception` + 子 run 留 running 无进展 → 孤儿补偿既有机制兜终帧 + 父侧预算收口（残余窗口登记 R-P4-4） |
| 父进程崩于子 run 在飞 | 子 run 独立跑完；父恢复后 route_next_subtask 重执行 → **DB claim 撞 uq 取回已有 child run_id** → 继续轮询 |
| 子 run 遇 hitl.required 且审批未消费（R1） | 落 hitl.waiting 帧 + status=waiting_approval 后**退出 worker**（不占 `_workers` 槽 · HITL TTL 既有语义兜底） |
| decide 后子 run 重跑至能力调用点（R1） | `_approval_consumed(子 run_id, subtask_id, capability_id)` 命中放行（fail-closed）；未命中（重复 decide/重复 resume）→ **不重复执行能力**（消费闸一次性） |
| 子 run HITL 超时（approval_expired） | 既有 409 语义；父轮询见终态 error 按失败收口（TTL 语义不动） |
| **子 run 令牌墙钟过期（HITL 长等 >600s · R13）** | **形态消解（R2）**：令牌由子侧**每次执行尝试自发签发 · TTL 自尝试起算** · decide 后重跑即重签发——「批准后 REJECT_EXPIRED 必败」路径**不存在**；签发审批（delegation_issue_hitl_required）仍在父侧 dispatch 前完成，不绕审批 |
| 闸 off 部署收到含 parent_run_id 的投影（数据残留） | 纯数据字段，消费方忽略；REST 面不加过滤（投影幂等 · 加性变更豁免） |

---

## §14 契约面非范围与触发式后续登记

**非范围（本波契约冻结点 · 18 §9 对齐）**：

- RunWorker 全面 DB 租约 / _SCAN_TASK 多副本改造 / nonce·熔断·预算外置（14 §6.2-6.3 登记债原样顺延；claim 只解决委派建行幂等）；
- rag/extract 子任务 run 化 · plan-JSON 新 type · supervisor prompt 机制改动；
- 多深度树（depth>1）· root_run_id 冗余列 · 运行时环检测；
- **树形合并流 / 跨 run 统一 cursor / SSE 任何新帧 / 契约 freeze 任何修订**；
- oa RAG ingest / source_type 词表泛化 / oa glossary 交付（无消费者）· domains.yaml 领域注册文件（任何形态）；
- per-tenant domain（域=部署级钉死）· domain 进 CapabilityFilter 判序字段（tags 已够载）；
- **memory 加 domain 列+召回过滤**（触发式后续：多域共库真实需求出现时 · §5.2）· **skill 目录域化**（skills/ 与 goal 注入=部署级资产不进域回退 · §5.3）；
- 聚合态计算（父卡只显示自身 status）· children 端点 · iOS 全部面（登记后续候选，合并 P3 R23 跟踪）；
- MCP/skill 面机制改动（MCP 条目 domain 真源=server 配置侧仅契约注明 · §2.3）。

**触发式后续登记汇总**：

| 项 | 触发条件 |
|---|---|
| memory 加 domain 列 + 召回过滤 | 多域共库真实需求出现（§5.2 · R4） |
| ingest / source_type 泛化 | 第二个需要本地语料 ingest 的域出现（§4.3） |
| 树形合并流 / 跨 run 统一 cursor | 跨 run 时间线合并视图的真实产品需求（§11.2） |
| iOS 树形面板 + 子 run 审批面 | web 面 S2/S3 验收通过后产品评审立项（§11.6） |
| 多深度树 | S2 一层证据不足的真实需求驱动（18 §3.3） |
