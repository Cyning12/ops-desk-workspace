# RAG 知识检索契约 v1(R-P0 · 已定稿)

> **用途**:Ops 仓内 RAG 的开工契约。六问已人审定稿(2026-08-08),为 R-1 向量表 / R-2 入库管线的输入真值。
> **提交**:`human-node: rag-contract — <一句话>`。
> **roadmap**:`05-plan/04-agent-completion-roadmap_v1_zh.md` §P1-RAG。
> **旧仓实证指针**:`Projects/ai-ink-brain-api-python`(下文简称 Ink)。
> **实现落点**:`ops-desk-api/app/ops/rag/`(契约未定稿前不写实现代码)。

## 1. 范围与边界

- 形态:LangGraph **检索节点**汇入现有 chat graph;不做旁路脚本、不改码
- 语料(v1):Ops DB 已 sync 的 Issue/PR(英文为主,含少量中文如 #2676)+ 本仓 docs(中文:05-plan / contracts / runbook)
- 禁止:写业务表、调用 GitHub API、把未入库内容当证据
- 主路径:`用户问 → 混合召回(语义 + 关键词)→ RRF 融合 → LLM 评级闸 → 引用约束生成 / 拒答`
- 与 `chat-tool-context-v1.md` 的分工:**工具节点查「这一条 issue」(按 #n 精确取);检索节点答「哪条 issue/文档相关」(模糊语义找)**

---

## Q1 · chunk 策略与向量文本构成



### 1a. 粒度与切分规则

**【决策 · 2026-08-08 人确认】** 结构感知切分,禁止固定长度硬切。三规则按优先级:

1. **切分边界看结构**:`##`/`###` 标题 > 段落 > 句子。Issue/PR 按章切(实证:#2720 天然 `### What issue / ### Root cause` 章节结构);docs 按 Markdown 章节切
2. **原子单元不切开**:代码块(``` fence)、md 表格。表格超上限时按行切,**每片重复表头**(断表行失去列语义,embed 出垃圾向量)
3. **图片不进向量,改锚点**(见 1c)

> **决策**:Issue/PR/docs 均按结构切分(规则 1–3);chunk 上限 **800 tokens**(2026-08-08 人定);超限处理:按规则 1 递归降一级边界。评论 v1 不入库。



### 1b. 向量文本构成(被 embedding 的到底是什么)

沿用 Ink 前缀注入法(`api/rag_shared.py` → `strip_doc_context_prefix`):语义信号以文本前缀注入 content 再 embed,展示时剥离:

```text
[Document Context]
Title: <issue 标题 / doc 标题>
Type: <issue|pr|doc>
Ref: <repo>#<number>            -- 如 MoonshotAI/kimi-code#2720
Module: <module_tag>            -- 有才写
---
Content: <切分后的正文(含 [IMAGE#n] 锚点)>
```

**分工原则**:用户会念出来的(标题/编号/类型)进前缀——query 里会出现这些词;只用于过滤和展示的留 metadata 或活表。两边都放 = 浪费 token + 稀释向量。

### 1c. 图片策略(位置锚点,非抽走)

 入库时图片语法改写为**位置锚点**留在正文,URL 有序存入 metadata:

```markdown
<!-- 原文 --><img width="431" alt="Image" src="https://user-attachments/.../4e60..."/>
<!-- 入库 content -->[IMAGE#1]
<!-- alt 有意义(非 "Image"/空)时 -->[IMAGE#1: <alt文本>]
```

```json
"images": [{"anchor": "[IMAGE#1]", "url": "https://user-attachments/.../4e60...", "alt": "Image"}]
```

- 现在:锚点是干净文本标记(顺带清洗 `<img>` HTML 噪声);有意义的 alt 进向量文本
- 未来多模态:按锚点取 URL → VLM 生成描述 → **原位替换**锚点重 embed,位置语义完整(若只存 url 列表,位置丢失,多模态升级无法重建图文对应)
- **known limitation**:v1 不理解图片内容(实证:#2688 截图为 `<img>` HTML、#2676 图片+中文标题);被问「图片怎么办」答边界即可

---



## Q2 · metadata schema

metadata **不进向量**,管过滤与引用卡片。Ink 实证:`supabase/sql/init.sql`(`metadata jsonb` + 表达式索引)+ `api/rag_shared.py` → `build_sources_payload`。

**核心原则**:chunk 行只存「身份 + 不可变快照」;**易变字段(state/labels)不拷进 chunk**——它们是必然过期的快照,且变更不该触发重嵌(正文没变)。查询时从 `ops_issues` 活表 **join 取**(sync 管线保证新鲜度,一条管线管到底)。


| 字段            | 来源                                  | 用途                   | 纳入?(2026-08-08 人填) |
| ------------- | ----------------------------------- | -------------------- | ------------------ |
| `source_type` | issue / pr / doc                    | 过滤 + 引用 kind         | Y,Required         |
| `source_id`   | issue number / pr number / doc path | 引用定位 + golden 断言锚    | Y,Required         |
| `state`       | open / closed                       | 过滤(查询时 join 活表)      | N                  |
| `labels`      | issue labels                        | 过滤 / 展示(查询时 join 活表) | N                  |
| `module_tag`  | ops_issues.module_tag               | 过滤 + 前缀注入            | Y,Optional         |
| `updated_at`  | DB 时间                               | 增量重嵌水位参考             | Y,Required         |
| `chunk_index` | 切分序号                                | 排序 / 引用 / upsert 键   | Y,Required         |
| `html_url`    | GitHub 链接                           | 引用卡片跳转               | Y,Optional         |


补充(【决策 · 2026-08-08 人确认】):

- `source_id` = issue 的 **number**(如 2720),不是 GitHub node ID:number 是用户语言、golden 断言锚、可拼 URL。**坑:issue/PR 共享 number 序列**,逻辑主键必须是组合键 `(repo, source_type, source_id, chunk_index)`
- 新增 `repo` 字段(多仓未来 · 组合键之一);新增 `images jsonb`(见 1c);`content_hash = sha1(title + 正文)` 作重嵌水位——hash 变才重切重嵌,改 label 不动
- 需表达式索引的过滤字段:`(metadata->>'source_type')` + 组合键唯一索引;向量列 HNSW(cosine)

---



## Q3 · embedding 选型(选定即锁 vector(N))

约束:语料英文为主 + 用户中文提问 → **必须多语言模型**。Ink 实证:BGE-M3 / 百炼 text-embedding-v3 @1024(`init.sql` 头注释:维度变更须重建表 + 全量重灌)。


| 候选                     | 维度   | 成本        | 备注           |
| ---------------------- | ---- | --------- | ------------ |
| bge-m3                 | 1024 | 可本地/开源自部署 | Ink 已用;中英混合强 |
| multilingual-e5-large  | 1024 | 开源自部署     | 跨语言检索老牌      |
| text-embedding-3-small | 1536 | API 按量    | 省运维,英文强中文够   |
| text-embedding-3-large | 3072 | API 较贵    | 性能余量最大       |


> **决策(2026-08-08 人填)**:沿用 **bge-m3(1024)**,此次**自部署**,离线 chunk,本机和生产均部署。
>
> **风险注记(讨论产物)**:生产 Lighthouse 2C4G 常驻 bge-m3 = +1~2GB 内存,与 FastAPI/PG/Nginx 共存有 OOM 风险。实现要求:**懒加载 + 空闲超时卸载**(无查询 N 分钟释放模型进程);灌库批处理可在 Mac 跑完写生产库。
>
> **环境事实**:pgvector 扩展已预埋(docker-compose `pgvector/pgvector:pg15`);生产库装没装,上线前 `SELECT extname FROM pg_extension WHERE extname='vector'` 验证。

---



## Q4 · 引用与拒答契约(枚举评级闸 · 本页最重要)

**【决策 · 2026-08-08 人确认】** 不用打分阈值,改 **LLM 评级枚举闸**(CRAG 式:融合后加 grader 节点逐条评级,按最高等级决定答/拒)。

### 4a. 评级枚举(四档 · 判死定义)


| 枚举           | 中文   | 判死定义                        | 闸行为                 |
| ------------ | ---- | --------------------------- | ------------------- |
| `irrelevant` | 毫不相关 | 主题不搭                        | **拒答**              |
| `weak`       | 少量相关 | 有关键词重叠但**无可用证据**(提了词,没实质内容) | **拒答**              |
| `relevant`   | 相关   | 含可用证据,但只覆盖问题一部分             | 回答 + 引用 + 注明「仅部分证据」 |
| `exact`      | 精确命中 | 直接回答所问                      | 回答 + 引用             |


> 枚举级数说明(讨论产物):初稿五档(毫不/少量/部分/大量/绝对)收为四档——「大量 vs 绝对」边界模糊,LLM 两次评级可能落相邻档,闸行为不可复现、golden 评测抖动。四档每档可写判死定义,评级一致性优先于粒度。若坚持五档,须在评测中加人工抽查评级稳定性。



### 4b. grader 机制


| 项    | 规则                                                                                           |
| ---- | -------------------------------------------------------------------------------------------- |
| 评级执行 | grader 节点(LangGraph 内):top-5 chunk **批量一次调用**,便宜模型,结构化输出 `{chunk_id, relevance, reason(一行)}` |
| 闸判定  | 最高评级 ∈ {irrelevant, weak} → 拒答;relevant → 答 + 「仅部分证据」注明;exact → 答                            |
| 分数处置 | RRF 分数**不进闸、保留在日志**——评级异常时的调试依据(观测 SPEC `evidence_refs`)                                     |
| 成本   | 每 query +1 次 LLM 调用(批量);用便宜模型                                                                |




### 4c. 引用与拒答


| 项    | 规则                                                                                                                               |
| ---- | -------------------------------------------------------------------------------------------------------------------------------- |
| 拒答话术 | 未查询到相关内容，无法针对此问题进行回答                                                                                                             |
| 引用格式 | 每条答案附 sources:`{source_type, source_id, title, snippet(≤400 字 · 剥前缀), url, relevance(枚举)}`;state/labels 展示时 join 活表;**用户面不展示分数** |
| 融合   | RRF(Ink `hybrid_fusion.RRF_K`),语义:关键词 **1:1 起跑**-确认                                                                              |




### 4d. 评测配套

- golden 断言改为**评级断言**:G01 期望「2720 chunk 评 relevant 或 exact」;负样本期望「最高 ≤ weak → 必须拒答」
- 评级稳定性抽查:同输入评 3 次的一致率,写入评测报告(小样本老实标 confidence,对齐观测 SPEC)

---



## Q5 · 金样场景(golden scenario)

> **术语**:golden scenario = **金样场景**——「人先认证过标准答案的评测用例」。系统跑完拿它逐条打分,不凭感觉。PLAN §5 的「金样对话」同义。每条金样三要素:**问题(query)· 应命中文档(expect_hit)· 断言(assert)**。



### 首批金样 G01–G05(2026-08-08 人写 · 锚定 [kimi-code#2720](https://github.com/MoonshotAI/kimi-code/issues/2720))

```yaml
- id: G01
  query: "Kimi Code 自动压缩被取消并报错 This operation was aborted 是什么原因?"
  expect_hit: { source_type: issue, source_id: "2720" }
  assert: { recall_at: 5, min_relevance: relevant, citation_in_hits: true }
  expect_relevance: exact           # 根因/现象正文直接覆盖
  note: "真实用户遇到压缩取消错误时,需要快速定位原因和解决方案"

- id: G02
  query: "compaction_trigger_ratio 设置多少可以避免自动压缩被取消的问题?"
  expect_hit: { source_type: issue, source_id: "2720" }
  assert: { recall_at: 5, min_relevance: relevant, citation_in_hits: true }
  expect_relevance: relevant        # issue 给了 blockRatio 行为(0.85),没给「安全值」→ 只算部分覆盖
  note: "用户调整配置后遇到问题,需要知道安全值"

- id: G03
  query: "为什么 Kimi Code 手动压缩成功但自动压缩总是失败?"
  expect_hit: { source_type: issue, source_id: "2720" }
  assert: { recall_at: 5, min_relevance: relevant, citation_in_hits: true }
  expect_relevance: exact           # 「Manual /compact on the exact same context always succeeds」正文直答
  note: "用户对比手动和自动压缩行为差异时的典型疑问"

- id: G04
  query: "Kimi Code 的 historySafeToCompact 函数是做什么的?"
  expect_hit: { source_type: issue, source_id: "2720" }
  assert: { recall_at: 5, min_relevance: relevant, citation_in_hits: true }
  expect_relevance: relevant        # 函数名在标题,正文讲 fullCompactionService 机制 → 部分覆盖
  note: "开发者或高级用户想了解压缩机制的内部实现"

- id: G05
  query: "Kimi Code 自动压缩每次浪费多少 token?"
  expect_hit: { source_type: issue, source_id: "2720" }
  assert: { recall_at: 5, min_relevance: relevant, citation_in_hits: true }
  expect_relevance: exact           # 「~160K cached input tokens per attempt」正文有数
  note: "用户关注成本/配额消耗时的量化问题"
```

字段约定:`source_id` 一律**字符串**(与 chunk 表 `source_id text` 对齐;doc 类金样的值是路径);`expect_relevance` 是人对「这题 issue 能答到什么程度」的预判,用于校准 grader——系统评级低于它即 fail。

### 评审注记(2026-08-08)

- **本批性质 = 单文档多角度深挖**:五条都打 2720,能验「召回 + 评级 + 引用」链路,**测不出语料区分度**(从全库几千条里认不认得出 2720 之外的正确答案)
- **四象限缺口待补**(G06+ · 人写):EN→EN 基线 / ZH→ZH(实证 #2676 中文 issue)/ **负样本拒答**(问一个语料里不存在的事,期望最高评级 ≤ weak → 拒答)——负样本是枚举闸存在意义的直接证据,优先级最高
- G02/G04 的 `expect_relevance` 定为 `relevant` 是故意的:它们检验 grader 会不会**夸大**证据强度——把「部分覆盖」吹成「精确命中」是 RAG 最经典的吹牛模式



### 评测结果样例(格式示意 · 非真实数据)

```yaml
run: eval-rag-20260808-r1
embed: bge-m3@1024(selfhost) · grader: <便宜模型> · corpus: ops_knowledge_chunks(N=<灌库后填>)
results:
  - id: G01
    top5: ["2720#c0", "2688#c0", "2720#c1", "2650#c0", "doc:05-plan/04#c2"]   # source_id#chunk_index
    recall_at5: pass                 # 2720 ∈ top5
    best_relevance: exact            # grader 最高评级 ≥ expect_relevance → pass
    citation_in_hits: pass
    verdict: pass
  - id: G02
    top5: ["2720#c1", ...]
    recall_at5: pass
    best_relevance: relevant         # 与 expect_relevance 持平 → pass;若系统报 exact → fail(夸大)
    verdict: pass
summary:
  pass: "5/5"
  measurement_source: observed       # 观测 SPEC 三字段(已签 2026-08-07)
  confidence: low                    # 样本 5 条,老实标
  comparability: not_comparable      # 首跑无基线;二跑起与 r1 比(同语料同模型 → comparable)
```

**已知难点(正是选 2720 的理由)**:无 labels、标题是长英文技术句——纯关键词路几乎必败,正好证明语义路 + query 扩展的必要性。金样要挑「能暴露系统边界」的。

---



## Q6 · 跨语言策略(先后手)


| 策略                                | 成本             | 证据                                                                      | 定位                                                               |
| --------------------------------- | -------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **query 侧扩展**(中文问 → 扩英文候选 → 关键词路) | 低(一份 glossary) | Ink 已验证:`api/rag_recall_tools.py` → `keyword_query_text_with_i18n_meta` | **先手**。确认                                                        |
| 入库加 `content_zh_summary` 摘要列      | 高(全量摘要 + 字段)   | 无                                                                       | **后手**:首轮 golden 评测,跨语言子集 recall@5 < **70**% 才启用(2026-08-08 人确认) |


---



## 验收(契约页自身)

- [x] 六问全部定稿,无【人填】/【待人确认】残留
- [x] Q3 已定(bge-m3@1024 自部署):向量表 DDL 可一次写出(R-1 输入)
- [ ] **G01 可执行——验证未过(2026-08-08 实测)**:本地库 pgvector 扩展 ✅;但 `ops_issues` 共 599 条、**最大 issue 号 = 2041 < 2720**(sync 水位旧,#2720 未入库)。**前置动作:刷新 sync 把 #2720 拉进库(生产库同验)**,再灌库跑金样
- [x] 与 `chat-tool-context-v1.md` 边界已写明(§1:工具节点查「这一条 issue」,检索节点答「哪条相关」)



## 修订


| 日期         | 说明                                                                                                                                                      |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-08-08 | 骨架(AI 搭)· 待人填六问                                                                                                                                         |
| 2026-08-08 | v3 重建:人回填 Q2(勾选表)/ Q3(bge-m3 自部署 · 附内存风险注记)+ 讨论结论合并(chunk 三规则 · 图片锚点 · 组合键 · G01@2720);**Q4 改枚举评级闸**(四档判死定义 · grader 批量评级 · 分数降级为日志)· 编辑器旧缓冲覆盖过一轮,以此版为准 |
| 2026-08-08 | Q1a 上限定 800;Q6 先后手人确认;Q5 人写首批金样 G01–G05(锚 2720)+ 术语说明 + expect_relevance 校准字段 + 评测结果样例格式;四象限缺口(EN→EN / ZH→ZH / 负样本)记 G06+ 待补                            |
| 2026-08-08 | **定稿**:拒答话术人填 · 全标记转决策 · §1 补检索/工具节点分工句;验收实测发现 sync 水位 2041 < 2720(G01 前置动作 = 刷新 sync)· `human-node:` 提交 |


