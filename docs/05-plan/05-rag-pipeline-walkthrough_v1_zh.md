# RAG 管线 · 框架对照与代码导读（v1）

| 项 | 内容 |
|----|------|
| **状态** | `active` |
| **日期** | 2026-08-10 |
| **用途** | 面试备查 + 代码导读；回答「为什么不用 LangChain/LlamaIndex」 |
| **代码锚点** | `ops-desk-api/app/ops/rag/`（7 模块 854 行）+ `scripts/rag_ingest.py`（88 行） |
| **契约** | [`../contracts/rag-knowledge-contract-v1.md`](../contracts/rag-knowledge-contract-v1.md) |

---

## 1. 能力对照：框架共有 vs 契约特有

### 1a. 共有能力（框架默认覆盖，≈70%）

| 能力 | LangChain | LlamaIndex | 我们 |
|------|-----------|------------|------|
| Markdown 标题切分 | `MarkdownHeaderTextSplitter` | `MarkdownNodeParser` | `chunker.split_sections` |
| 超长递归降级 | `RecursiveCharacterTextSplitter` | `SentenceSplitter` | `chunker._to_units`（段落→句子） |
| bge-m3 嵌入封装 | `HuggingFaceEmbeddings` | `HuggingFaceEmbedding` | `embedder.SentenceTransformerEmbedder` |
| pgvector 存储 | `PGVector` | `PGVectorStore` | 自建表 + raw SQL |
| 内容指纹增量 + 清理 | `index()` + `RecordManager` | `refresh_ref_docs()` + `IngestionCache` | `ingest` 水位 + 整组替换 |
| RRF 混合融合 | `EnsembleRetriever` | `QueryFusionRetriever` | `retrieve.rrf_fuse` |
| top-k 余弦检索 / metadata 过滤 | 有 | 有 | `retrieve` 两条 SQL |

### 1b. 特有能力（契约定制，框架无默认，≈30%）

| # | 能力 | 契约锚点 | 代码落点 |
|---|------|----------|----------|
| U1 | fence/表格**原子不拆**；表格超限按行切、每片重复表头 | Q1a 规则 2 | `chunker._to_units` / `_split_table` |
| U2 | 图片/视频**位置锚点**（`[IMAGE#n]` 留正文、URL 有序入 metadata、alt 有意义才进文本、多模态原位替换升级路径） | §1c + E3 | `clean._anchor` / `_clean_segment_in_fence` |
| U3 | HTML 清洗（img/details/注释），**fence 感知**不洗代码 | E3 | `clean._fence_segments` |
| U4 | 前缀注入 + 展示剥离（用户会念的进前缀，过滤展示留 metadata） | §1b | `prefix.build/strip` |
| U5 | E1 超大原子单元裁决 + 8192 保险丝截断；E2 小块合并；E7 空正文标题块 | §1d | `chunker._pack` / `_merge_small` / `truncate_middle`；`ingest` E7 分支 |
| U6 | **枚举评级闸**：四档判死定义 + grader 批量评级 + 纯函数闸 + 三分支行为（拒答/部分证据/全答） | Q4 | `grader.decide` / `grade_chunks` |
| U7 | golden 断言锚 `source_id#chunk_index` + 组合键表结构 | Q2/Q5 | R-1 DDL + `RetrievedChunk.anchor` |
| U8 | `embedding_model` fingerprint 戳防混库 | Q3 + Ink 教训 | `ingest` metadata |
| U9 | token 计数用同源 tokenizer（非字符近似），可注入 fake 测试 | E5 | `tokenizer` |

---

## 2. 若用框架，特有能力怎么补

每条都有扩展点——但补完就等于把这套逻辑搬进框架的对象模型里重写一遍：

| 特有项 | LangChain 补法 | LlamaIndex 补法 | 代价 |
|--------|----------------|-----------------|------|
| U1 原子切分 | 自定义 `TextSplitter` 子类 | 自定义 `NodeParser` | 我们的 chunker 逻辑照写，只是换个基类 |
| U2/U3 锚点+清洗 | 自定义 `DocumentTransformer` | 自定义 `TransformComponent` | clean.py 照写 |
| U4 前缀 | 入库前拼 `page_content`，展示自写 strip | 同 | 简单，但仍手写 |
| U5 边界规则 | 散进自定义 splitter | 同 | 同 U1 |
| U6 枚举闸 | 检索链里插 grading 步骤（CRAG 示例链） | `NodePostprocessor` 钩子 | 闸逻辑照写，多包一层框架抽象 |
| U7 断言锚 | Document metadata 自定义字段 | node metadata | 可行，但表结构不再自控 |
| U8 指纹戳 | metadata 字段 | 同 | 可行 |

**结论**：框架省掉的是 1a 的胶水（约 200 行），但 1b 的每一条都要以框架扩展点重写，且测试要穿透框架抽象（splitter 的输入输出是 Document 对象、异步语义、版本漂移）。净省工作量接近零，换来黑盒依赖。

> **实测验证（2026-08-10）**：`ops-desk-api/experiments/rag_compare/` 同源同题对照——LI 默认切出 4 个微型块未合并，G01 检索 top-5 全是浅水标题块、真正的 Root cause 块落榜；自建管线在 8,574 块语料上把 2720 召回到 sem#1。「E2 合并 + 前缀注入」的价值有对照证据了。

---

## 3. 面试叙事点

**「为什么不用 LangChain」的标准答法**（忌说「框架太重」，要讲算账）：

1. 先承认覆盖度：「框架默认能给到 70%——结构切分、hash 增量、RRF 都有现成的，我都评估过」
2. 再讲那 30%：「但契约里有 9 条定制规则（原子切分、锚点、枚举闸…），每一条都得写成框架的自定义扩展点，工作量不变，还引入黑盒」
3. 落到价值：「自写让每一环可单测（chunker 8 条测试不碰模型不连库）、可对着契约逐条追溯」

**数据驱动设计的故事**：切分规则不是拍脑袋——先对 881 条 issue 做语料实测（103 条含 `<img>` HTML、110 条视频附件、655 个代码块、最大单块 4,019 字符），再定 E1–E7 规则。「先看数据分布，再定规则」是这题的加分叙述。

**工程真实性（失败与修复）**：

- Supabase pooler × asyncpg prepared statement 冲突 → `statement_cache_size=0`
- alembic 孤儿 revision（应用后未 commit 丢文件）→ 删表回拨 + 人审重建 + 「碰 DB 前先 commit」纪律
- 全量对账发现 9 个空正文单元零 chunk → E7 规则增补
- SQLAlchemy `text()` 里 `:param::jsonb` 绑定失灵 → `CAST()` 写法

**分层话语里的位置**：检索节点汇入 LangGraph = Graph 层；水位增量 + golden 回归 = Loop 层（做→验→改）；契约/闸/人节点 = 外环 Harness 纪律。

---

## 4. 代码导读（R-2 管线 815 行 + R-3 238 行）

### 4.1 数据流总图

```text
rag_ingest.py（CLI 薄壳：参数/引擎/装配）
  └─ ingest.py（核心编排）
       ├─ load_issue_units / load_pull_units  SQL → SourceUnit
       ├─ load_doc_units                      文件系统 → SourceUnit
       ├─ _existing_hashes                    存量指纹对比（水位）
       ├─ clean.py      HTML 清洗 + 媒体锚点
       ├─ chunker.py    结构切分（tokenizer.py 数 token）
       ├─ prefix.py     前缀注入
       ├─ embedder.py   向量化（ST 自部署 / API 兜底）
       └─ 整组替换 + 墓碑对账

查询侧（R-3）：retrieve.py 混合召回 → grader.py 枚举闸
```

### 4.2 clean.py（119 行）— HTML 清洗 + 锚点化

| 部分 | 解读 |
|------|------|
| 顶部正则区 | 每类噪声一个编译好的正则：fence 行、HTML 注释、details/summary、img/video 标签、md 图片、裸视频 URL、src/alt 属性抽取 |
| `_MEANINGLESS_ALTS` | §1c：alt 为 "Image"/空 等无信息值不进向量文本 |
| `_fence_segments` | **fence 感知分段器**：逐行扫描，遇 ``` 切换段属性；未闭合 fence 容错为「整段按 fence 处理」（宁可不洗也不错洗代码）。清洗只作用于非 fence 段 |
| `_anchor` | 生成 `[IMAGE#n]`/`[VIDEO#n]` 锚点：纯锚点存 media 列表（metadata），带 alt 的装饰锚点进正文（语义信号） |
| `_clean_segment_in_fence` | 非 fence 段的清洗流水线：注释→summary 伪标题→details 解包→img 标签→video 标签→md 图片→裸视频 URL。**顺序有讲究**：先标签后裸链，防止标签里的 URL 被裸链规则二次命中 |
| `clean_markdown` | 入口：分段→逐段清洗→拼装，返回 `CleanResult(text, media)` |

### 4.3 chunker.py（205 行）— 结构切分核心

| 函数 | 解读 |
|------|------|
| `parse_blocks` | 行级解析成四类 Block：fence（吞到闭合行）/ 表格（连续 `\|...\|` 行）/ 标题 / 段落 |
| `split_sections` | 按标题分组，标题与其后续内容同 section——规则 1 的第一级边界 |
| `_to_units` | 规范化为原子单元：超限表格→`_split_table`（按行切+重复表头）；超限段落→`_split_sentences`（句级贪心）；fence/标题永不拆（E1） |
| `_pack` | 贪心装箱：能放就放，超限原子单元冲出当前包、单独成 chunk |
| `_merge_small` | E2：<100 tokens 的小块并入后邻，末尾小块并入前一个 |
| `chunk_markdown` | 入口：section ≤800 直接成块，否则降级打包；最后 E2 收尾 |
| `truncate_middle` | E1 保险丝：超 8192 截中段保头尾（实测最大 ~2k，打不到，纯防御） |

### 4.4 prefix.py（46 行）

`build_prefix`（四行：Title/Type/Ref/Module 有才写）· `embed_text`（前缀+content 拼装）· `strip_doc_context_prefix`（正则剥到首个 `---\nContent: `，展示用）。§1b 的分工：用户会念的词进前缀参与向量化，过滤展示字段留 metadata。

### 4.5 tokenizer.py（43 行）

`TokenCounter` 协议（可注入）· `BgeM3TokenCounter`（懒加载，只载 tokenizer 不载模型权重）· `FuncTokenCounter`（测试 fake——8 条单测不下载模型的关键）。E5：数 token 与向量化是两个阶段。

### 4.6 embedder.py（98 行）

`Embedder` 协议（`name` + `embed`）· `SentenceTransformerEmbedder`（首选：懒加载 2.3GB 权重，`normalize_embeddings=True` 归一化）· `ApiEmbedder`（兜底：SiliconFlow OpenAI 兼容，指数退避重试，响应按 `index` 排序保序）。`name` 作 fingerprint 戳写入 metadata（U8）。

### 4.7 ingest.py（254 行）— 编排核心

| 部分 | 解读 |
|------|------|
| `SourceUnit` | 统一中间表示：三种来源归一，管线主体不关心数据来自 SQL 还是文件 |
| 三个 loader | issue/PR 走 ORM join 查库；doc 走 `rglob("*.md")`，`source_id=根目录名/相对路径`，标题取首个 `# ` 行 |
| `_hash` | `sha1(title+正文)`——内容指纹（水位），切分前计算，同单元所有 chunk 共享 |
| `_existing_hashes` | 查存量单元→指纹映射（GROUP BY 单元三元组） |
| `ingest` 主流程 | ① 三组差量：changed（指纹变/新）/ unchanged（跳过）/ stale（源消失）② changed 逐单元：清洗→切分→前缀→8192 断言→收集待嵌 ③ 批量 embed + 维度=1024 断言（防混库即停）④ 整组替换：单元级 DELETE+INSERT，逐单元 commit（崩溃可续）⑤ stale 整组删除（墓碑对账） |
| E7 分支 | 空正文单元 → 仅标题 chunk（全量实测 9/2748） |
| `CAST(:x AS jsonb)` | 教训：SQLAlchemy `text()` 里 `:param::jsonb` 绑定失灵 |

### 4.8 retrieve.py（112 行）— R-3 混合召回

两条 SQL：语义路 `embedding <=> :qvec`（cosine，走 HNSW）/ 关键词路 `fts_tokens @@ plainto_tsvector('simple')` + `ts_rank` 排序。`rrf_fuse`：`score = Σ 1/(60+rank)`，两路等权（契约 4c）。`RetrievedChunk.anchor` 直接产出 golden 断言格式（U7）。分数只进日志不进闸。

### 4.9 grader.py（126 行）— R-3 枚举闸

`Relevance` 四档枚举 + `_RANK` 排序表 · `_GRADER_SYSTEM` 判死定义 prompt · `decide` 纯函数闸（最高评级定三分支行为，空评级→拒答）· `parse_grades` 容错解析（非 JSON/未知枚举/越界 id 丢弃，宁缺毋滥）· `grade_chunks` top-5 批量一次调用（每 query +1 次便宜模型调用，契约 4b）。

## 5. 阶段总结（2026-08-10 · 人总结 + AI 补全）

> 第一性原理：**RAG 搭建第一步不是研究技术，是先看数据类型。**

### 5.1 语料决定选型

**语言构成 → embedding 模型**：

| 语料 | 候选 | 备注 |
|------|------|------|
| 纯英文 | text-embedding-3-small/large · voyage-3 · bge-large-en-v1.5 · e5-large-en | 英文强，中文弱或无 |
| 中英混合 | **bge-m3**（选定）· multilingual-e5-large · text-embedding-v3/v4（百炼）· Qwen3-Embedding（0.6B/4B/8B）· jina-embeddings-v3 | e5 系强制 `query:`/`passage:` 前缀 |

选型纪律：① 维度选定即锁表（`vector(N)` 变更 = 重建 + 全量重灌）；② 最终裁决靠自家金样 recall@k，不靠公开榜单。

**语料复杂度 → chunk 规则**：纯文本（小说/纯文档）用固定块/滑窗/段落即可；本语料是 md（表格/图片/代码/引用混合），代码块必须保原子性（方法级甚至程序级完整）。规则由语料实测驱动（881 issue 统计：103 img HTML / 110 视频 / 655 fence / 最大单块 4,019 字符 → E1–E9）。

### 5.2 框架黑盒环节 ↔ 自建代码对照

| 环节 | 框架黑盒 | 自建 |
|------|----------|------|
| 标题树解析 | `MarkdownNodeParser` 内部标题栈 | `chunker.parse_blocks` / `split_sections` |
| 尺寸切分 | `SentenceSplitter`（分隔符优先级/句子正则/合并逻辑不可见；默认 tiktoken 计数，与被嵌模型不同源） | `_to_units` / `_pack` + bge-m3 tokenizer（E5） |
| 嵌入封装 | `HuggingFaceEmbedding`（batch/设备/归一化默认值） | `embedder.py`（显式归一化 · 懒加载） |
| 存储/查询 SQL | `PGVectorStore` 表结构与查询不可控 | R-1 自建 DDL + `retrieve.py` 明 SQL |
| 增量 | `RecordManager` / `refresh_ref_docs` hash 语义 | 水位 + 整组替换 + 墓碑对账 |
| 检索分数 | distance→score 变换不透明 | 显式 cosine + ts_rank + RRF |

结论：定制规则占比高时，框架扩展点投入 ≈ 自建（AI 辅助下尤甚），且框架留有黑盒环节。
### 5.3 Metadata 设计亮点

- **身份 + 不可变快照入 chunk；易变字段（state/labels）查询时 join 活表**——不拷必过期的快照，一条 sync 管线管到底
- **组合键 `(repo, source_type, source_id, chunk_index)`**：issue/PR 共享 number 序列，单 number 必撞
- **fingerprint 戳**（`embedding_model`）：不是召回过滤器，是**防混库校验锚**——换模型必须全量重嵌（维度变还须重建表），戳让「忘了重嵌」当场报错而非静默腐烂（Ink rag_embedding_guard 实证；v1 已写戳，校验待补）
- **分工原则**：用户会念的（标题/编号）进前缀参与向量；过滤展示字段留 metadata——两边都放 = 浪费 token + 稀释向量
- `chunk_index` 兼任 golden 断言锚；`content_hash` 兼任重嵌水位；`images` 数组兼任多模态升级接口

### 5.4 多模态升级路径（原位替换 · 可行性已论证）

文本 chunk 的锚点（`[IMAGE#n]`）保位置、metadata 存 URL → VLM 生成描述 → **原位替换锚点重嵌**：位置语义完整、单向量空间、无需改表。适配性：本语料 103 条带图 issue 多为报错/UI 截图，OCR 级描述转化率即高。边界：高密度图（架构图）描述有损，终极路径是 ColPali 类视觉向量（独立列 + 检索期融合，v3 再议）——锚点设计不挡这条路。

### 5.5 增量工程三件套（ingest.py）

1. **水位**：`content_hash = sha1(title + 正文)`，切分前算，同单元全 chunk 共享
2. **整组替换**：指纹变 → 单元级 DELETE + 重切重嵌 INSERT，逐单元 commit（崩溃可续）
3. **墓碑对账**：源消失（文件删/issue 移除）的单元，chunk 整组 DELETE

水位省的是**跨文档**的钱（未变单元零嵌入成本）；文档内不做 chunk 级差量（chunk_index 会漂移，无稳定身份）。

### 5.6 评测体系

**检索技术全景**：稠密语义（bge-m3 ✓）· 稀疏关键词（ts_rank 版，替代 BM25 角色 ✓）· RRF 融合（✓）· 精排 cross-encoder（备选未上）· **枚举评级闸（差异化 ✓）**。

**金样断言**：recall@k（锚 `source_id#chunk_index`）· grader 评级 vs 人预判 `expect_relevance` · 引用 ∈ 命中集 · 负样本拒答正确率 · 评级稳定性（同输入评 3 次一致率）。

**评测卫生——自引用污染**：金样 query 原文混入被测语料 → 指标虚高。污染源不是「docs 不该入库」，是「金样原文不该在被测语料里」。可观察信号：top 命中含 query 原文、双路命中、RRF 分数异常领先（实测：契约#13 以约第二名两倍分数登顶）。对策：评测断言前过滤含金样原文的文档。

**坑：测试计数器分层**——单测用假计数器（确定性锁算法规则，秒级零模型）；真 tokenizer 的验收断言**不变量**（≤800 / fence 成对 / 8192 余量）不断言块数；假计数器对中文夹具失效（无空格按 1 词算），中文尺寸断言必须走真 tokenizer 集成测试。

### 5.7 跨语言策略（Q6 先后手）

已实现：**底座**（bge-m3 多语言嵌入，中文问英文语料语义路实测可中）。
未实现：**先手** query 侧扩展（glossary：压缩→compaction…，落点 `retrieve.py` 关键词路之前；启动时机看 R-4 跨语言子集 recall@5）；**后手** `content_zh_summary` 列（recall <70% 才启用）。

### 5.8 评级闸的两层演进（不是替代关系）

```text
在线枚举闸（grader · 便宜模型 · 请求路径内）   ← 第一线，实时挡垃圾，判死定义可复现
        ↕ 被校准
离线 LLM judge（大模型 · 异步抽评生产 trace）   ← 校准器，评估答案质量/引用忠实度
```

grader 本身就是 LLM-as-judge 的一种（CRAG 式）；「升级」的正确形态是**加离线 judge 层**（Langfuse evaluator 按 observation 名锚定 `answer_llm`），其评分与在线评级对照，分歧案例回喂金样库。反向警告：大模型 judge 不进在线路径（延迟/成本直接打在用户体感上）；判死定义的可复现性 > 判断的聪明度。

### 5.9 考点地图（人未列到的重点/难点）

1. 枚举闸：四档判死、五收四的决策（评级一致性 > 粒度）、分数不进闸的纪律、fail-closed
2. 混合召回必要性证明：语义漏字面（函数名/issue 号）、关键词中文哑火——两方向失败均有实测
3. 一词三义分工：工具节点查「这一条」（#n 精确）vs 检索节点答「哪条相关」（模糊语义）——路由裁决的基础
4. 生产工程账：2C4G 内存（懒加载/空闲卸载/API 兜底）、HF 离线部署、驱动层坑族（CAST / unknown 类型 / psql≠驱动）
5. 观测闭环：埋点设计（retriever/generation/闸 metadata）+ 官方基线自审

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-08-10 | 首版：能力对照 + 框架补法 + 面试叙事 + 全模块导读 |
| 2026-08-10 | §5 阶段总结（人总结 + AI 补全）：选型/黑盒对照/metadata/多模态/增量/评测/跨语言/闸演进/考点地图 |
