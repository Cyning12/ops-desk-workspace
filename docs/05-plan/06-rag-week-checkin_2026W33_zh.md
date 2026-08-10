# RAG 实战周打卡（2026-08-10 ~ 08-14 · 目标：周五上线）

| 项 | 内容 |
|----|------|
| **状态** | `active` |
| **契约** | [`../contracts/rag-knowledge-contract-v1.md`](../contracts/rag-knowledge-contract-v1.md) |
| **导读** | [`05-rag-pipeline-walkthrough_v1_zh.md`](./05-rag-pipeline-walkthrough_v1_zh.md) |

## 用法约定

- 复选框随手勾；计划变更直接改条目并留 `> 【注】` 说明原因
- 问答摘要：`Q:` 疑问一句话 / `A:` 结论一句话（细节链到对应文档，不复制大段）
- 知识点：当天新接触、值得记住的概念清单
- 面试亮点：可直接拿去讲的一句话素材
- **窗口分工**：统筹窗口管勾选与计划对齐；内容窗口填问答/知识点/亮点

## 总览

| 日 | 主题 | 人节点 | 状态 |
|----|------|--------|------|
| 一 8/10 | R-2 全量灌库 + LI 对照实验 + Langfuse 接入 | #2720 chunk 验收 | ✅ |
| 二 8/11 | R-3 接线（检索触发路由 + SSE 帧 + **观测埋点**） | 审 retrieve/grader + 拍 4 决策点 | ⬜ |
| 三 8/12 | R-4 金样评测 | 写 G06+（负样本优先）· 判读报告 | ⬜ |
| 四 8/13 | 生产部署 + 灌库同验 | 拍板生产 embedder 形态 · 执行部署 | ⬜ |
| 五 8/14 | 上线 + Demo 证据表 | 证据表 + 3 分钟口述 | ⬜ |

---

## 周一 8/10 · R-2 灌库

### 计划

- [x] dry-run 计数对账
- [x] #2720 单条试跑 + chunk 验收（契约 Q1a/1d 逐条核）
- [x] 全量灌库（2748 单元 / 8574 chunks）
- [x] E7 空正文规则增补 + 补灌 9 单元
- [x] R-2/R-3 代码与契约提交（`9e3c6de` / `88e385a` / `b40b50a`）

### 完成记录

- 全量灌库：2748 单元 / 8574 chunks（issue 2758 + pr 5662 + doc 144 + E7 补 9 单元），fingerprint 戳 `BAAI/bge-m3` 全覆盖
- #2720 验收过契约全项：章节边界 ✓ fence 原子 ✓ E2 合并 ✓ content ≤800 tokens（真 tokenizer 复核 max 672）✓
- E7（空正文标题块）/ E9（嵌套 fence 已知限制）规则增补；CommonMark 严格版参考实现落码未调用
- **LI 对照实验**（`experiments/rag_compare/`）：微型块 / fence / 检索成色三维度实证，结论回填 README
- 修生产 bug ×2：`plainto_tsquery` 误写、SQLAlchemy `::` cast 绑定失灵（改 CAST 写法）
- **Langfuse 云接入**（`Ops-chat-agent` 项目）：CallbackHandler 图 span + answer_llm generation（model/usage 全字段），官方基线自审通过；provider 流加 `include_usage` 捕获 token
- G01 检索实测 PASS：中文 query 在 8,574 块全语料中召回 2720（sem#1）

### 问答摘要

Q: 水位为什么不做 chunk 级差量？
A: chunk_index 会漂移、无稳定身份；水位管「哪些文档重做」，整组替换管「不留旧残渣」。

Q: LangChain/LlamaIndex 默认无法满足吗？
A: 框架默认覆盖 ~70%（结构切分/hash 增量/RRF 都有）；契约定制 30%（原子切分/锚点/枚举闸）无默认，扩展点照写，净省约零。

Q: LI 版检索为什么没出 docs 内容？
A: 实验索引只装了单篇（内存隔离），不是检索能力问题；BM25 缺失是另一独立差异（默认单语义路）。

Q: 为什么自建检索出了契约文档？
A: 自引用——G01 原题写在契约里被逐字命中；评测时排除含金样原文文档（评测卫生）。

Q: uv sync 和 pip install 的区别？
A: 本仓双轨：pyproject+uv.lock 是真值（CI/本地），requirements.txt 是 Dockerfile 副本；加依赖唯一入口 `uv add`。

Q: HF_HUB_OFFLINE 配在哪？
A: 环境变量，非配置文件；镜像/官方源混用曾致双 revision 快照重下 2.3GB。

Q: Langfuse 自建还是云？
A: 云免费版。自建栈 6 服务（ClickHouse/MinIO/Redis…）2C4G 生产放不下；观测的学习价值在埋点设计不在托管。

### 知识点

- RRF 融合：`Σ1/(60+rank)`，排名无量纲可比、K 平滑防单路碾压（双路都中者上浮）
- 内容指纹增量：sha1(title+body) 单元级水位 + 整组替换；跨文档省钱、文档内不省
- pgvector：cosine 距离 + HNSW 索引；向量写入 `CAST(:vec AS vector)`
- PG 全文：`to_tsvector`（文档侧）vs `plainto_tsquery`（查询侧，`@@` 右侧必须 tsquery）；'simple' 配置对中文分词残废 → Q6 query 扩展存在的理由
- SQLAlchemy/psycopg 坑族：`:param::jsonb` 绑定失灵 → `CAST()`；驱动发 unknown 类型 → 显式 cast；psql 能过 ≠ 驱动能过
- HF 模型缓存：双 revision 快照陷阱；`HF_HUB_OFFLINE=1` 或本地快照路径直读
- Langfuse 观测模型：trace/observation/generation 三级 + session 分组；LangGraph 用官方 CallbackHandler；自研 provider 的 LLM 调用须手动包 generation（`start_as_current_generation`）；usage 靠 `stream_options.include_usage`
- uv 双轨维护：`uv add` 唯一入口，`uv sync` 对齐，requirements 镜像给 Dockerfile

### 面试亮点

- 「为什么不用 LangChain/LlamaIndex」有对照实验数据：LI 默认微型块未合并 → G01 top-5 全是浅水标题块、真答案块落榜；自建在 8,574 块语料 sem#1 命中
- 语料实测驱动规则：881 issue 统计（103 img HTML / 110 视频附件 / 655 fence / 最大块 4,019 字符）→ E1–E9 规则
- 评测卫生意识：发现金样原文混入语料的自引用污染并提出排除口径
- 失败修复集可讲：pooler prepared statement、alembic 孤儿 revision（→「碰 DB 先 commit」纪律）、tsquery 误写
- 观测闭环：Langfuse 官方基线自审（model/usage/层级/类型逐项核），trace 链接可展示

---

## 周二 8/11 · R-3 接线

### 计划

- [ ] 审 retrieve.py / grader.py 接口
- [ ] 拍板 4 点：触发路由（建议 general/overview 走检索）· grader 失败倒向（建议 fail-closed）· grader 模型（deepseek-v4-flash）· snippet 600
- [ ] graph 接线：retrieve → grade → gate 节点 + SSE `tool_result`（tool=retrieve）帧
- [ ] **观测埋点**（新增 · 承接 Langfuse 接入）：
  - [ ] retrieve 节点 → retriever 观测（metadata：双路命中/排名/RRF 分数，契约 4b）
  - [ ] grade 节点 → generation 观测（grader 模型 usage/评级输出）
  - [ ] 闸判定 → metadata（action / best_relevance）
  - [ ] sources 引用集合入 answer 输出
- [ ] 复跑 smoke 出完整 RAG trace → langfuse-cli 自审 → 链接记入本节

**坑关注点（R-3）**：

- SQL 必须在真实驱动路径下验证（tsquery 坑族：psql 能过 ≠ psycopg 能过；`CAST()` 优于 `::`）
- 补真 tokenizer 集成测试：断言**不变量**（content ≤800 / fence 成对 / 前缀+content <8192），**不断言块数**；假计数器中文边界写进测试头注释
- 闸 fail-closed 落地时，日志必须区分「闸故障」与「真空命中」（否则拒答率指标失真）
- retrieve 启动校验 `embedding_model` 戳（防混库当场报错）

### 完成记录 / 问答摘要 / 知识点 / 面试亮点

> 待填

---

## 周三 8/12 · R-4 金样评测

### 计划

- [ ] eval runner（AI 起草：scenario → 断言 → 报告，对齐观测 SPEC 三字段）
- [ ] G06+ 金样人写（负样本拒答优先级最高）
- [ ] 首跑评测 + 判读 + 修复

**坑关注点（R-4）**：

- **自引用污染**：断言前过滤含金样原文的文档（实测契约#13 双路命中登顶）
- 小样本老实标 `confidence: low`；首跑 `comparability: not_comparable`（观测 SPEC 纪律）
- grader 稳定性抽查：同输入评 3 次一致率入报告
- 跨语言子集 recall@5 < 70% → 触发 Q6 先手（glossary query 扩展）

> 待填

---

## 周四 8/13 · 生产部署

### 计划

- [ ] Dockerfile：构建期烘 bge-m3 + `HF_HUB_OFFLINE=1`（AI 起草）
- [ ] 生产内存实测（2C4G · 契约 Q3 风险注记）
- [ ] 拍板：生产 embedder 自部署 vs API 兜底（降级预案已备）
- [ ] 生产库灌库 + 同验（契约验收栏 checkbox 在此勾掉）

**坑关注点（生产部署）**：

- **先 `alembic current` 再 upgrade**（孤儿 revision 教训；migration 未 commit 不碰 DB）
- 生产 pgvector 扩展存在性验证（`SELECT extname FROM pg_extension WHERE extname='vector'`）
- 2C4G 内存实测：bge-m3 常驻 +1~2GB 与 FastAPI/PG/Nginx 共存；OOM 即切 ApiEmbedder（一行构造）
- 镜像构建期烘模型 + `HF_HUB_OFFLINE=1`（双 revision 快照教训）；镜像 +2.3GB

> 待填

---

## 周五 8/14 · 上线

### 计划

- [ ] 上线验收（生产候选增强口径）
- [ ] Demo 证据表（版本/输入/结果/错误）
- [ ] 3 分钟口述自检（检索链路 + 枚举闸 + 评测闭环）

**坑关注点（上线）**：

- 口径纪律：「生产候选增强」≠「全能力已生产」；证据表四要素齐全才算数
- 负样本现场问一遍：拒答话术必须是契约原文「未查询到相关内容，无法针对此问题进行回答」
- 抽查新 trace：RAG 段（retrieve/grade/gate metadata）在 Langfuse 里齐全才算观测闭环

> 待填

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-08-10 | 骨架（统筹窗口建）· 周一计划勾掉；内容填充交专门窗口 |
