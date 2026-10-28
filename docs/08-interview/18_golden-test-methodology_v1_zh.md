# 18 · Golden Test Set 方法论 v1（面试向 · 两仓实证整理）

> 用途：回答「Golden Test 集的设定标准是什么」——不只给定义，给**可迁移的方法论结论**，每条都挂着两个真实项目的实证。
> 素材：ops-desk-api（RAG 金样 r4 系列 / 记忆金样五轮校准 / 能力红线清单 R0-R15）+ ai-ink-brain（gate A/B/C 上下文选型金标 F1）。
> 日期：2026-10-28 · 二面备战用。

---

## §0 · 一页口径（60 秒速答版）

「Golden set 的设定标准，我总结成六条：
① **按行为类别分桶，不是随机抽样**——每类有独立判定口径和数量下限；
② **负样本是一等公民**——有独立指标和独立的失败分类；
③ **阈值先签收后跑数**——门槛写进 SPEC 锁死，不是跑完看数再定；
④ **小样本老实标**——n<50 必须同时报 n 和 Wilson 置信区间，不许只报百分比；
⑤ **红线不等于准确率**——红线是否决项，不能拿别处的高分来补；
⑥ **归因要分离**——未达标要分清是被测系统的错、还是金标本尊标错了。」

然后补一句实证钩子：「这六条不是我读的，是我用三轮项目交的学费——记忆金样第一轮 live 真跑，抓出来的第一个问题不是模型不行，是我们自己的时区 bug。」

---

## §1 · 六条方法论 × 实证对照

### ① 按行为类别分桶，不是随机抽样

| 实证 | 分桶 | 判定口径 |
|---|---|---|
| 记忆金样 evals/memory/golden_v1.yaml（50 条） | 四类：should_remember 应记 / should_not_remember 不应记 / supersede 冲突取代 / paraphrase 复述召回 | 每类独立判定：应记看写入、负样本看零写入、supersede 看「召回只见新值且旧值 superseded」、复述看向量 top1/top3 |
| RAG 金样 evals/golden/queries_v1.yaml（73 条） | 四象限：zh2en / zh2zh / en2en / negative | 三指标：recall@5 命中率 / min_relevance / citation_in_hits |

关键机制：**schema 校验强制数量下限**（应记≥12 / 负样本≥12 / supersede≥8 / 复述≥10，evals/memory/README.md）——防止「类别桶写着四类，实际一类只有两条」的统计假象。

### ② 负样本是一等公民

- 记忆负样本有**独立指标**：noise_write_rate ≤ 0.1（首轮 live 实测 0.3571，未过）；
- RAG 负样本有**独立指标**：拒答正确率（10/11，90.91%），且失败要分两类——**误答**（负样本未拒答，G63）vs **疑似误拒**（正样本被拒答，9 条 G-id 清单），后者供人工复核但**不改默认参数**（FP-3 纪律）；
- 负样本本身还要**覆盖两种形态**：闸可拒的（非法 key/易失前缀）和 prompt 级的（理想 LLM 不产出）——只测前者等于只测了过滤器，没测模型。

### ③ 阈值先签收后跑数

每份报告头部钉死同一句话（reports/memory_golden_eval_20260921.yaml 等）：

> 门槛来自 SPEC-memory-golden-eval §2 D5（**签收锁死**）；fake 模式为确定性管线自检，**不构成开开关依据**；裁决以 live 真跑报告为准。

三层含义：阈值是 SPEC 的一部分要先过人签；确定性自检（fake）和真跑裁决（live）严格分档；**先射箭后画靶在流程上不可能**。

### ④ 小样本老实标

r4 结案报告（reports/r4_final_live_20261019T032150Z.md）的写法：zh2en 跨语言 recall@5 = 19/26（73.08%）vs 门槛 ≥1/3 → MET，**但必须紧跟** n=26 · Wilson 95% CI=[0.54, 0.86] · confidence=low。模板原文：「小样本（n<50）结论置信有限，任何『已达标』表述必须同时引用 n 与 Wilson CI」。

观测三字段随报告透传：measurement_source=observed / confidence=low / comparability=not_comparable——**本地 compose 口径，不外推生产**。

### ⑤ 红线 ≠ 准确率（否决项哲学）

evals/agent/redlines/capability_v1.yaml 头部三句话是整个方法论的精华：

> 红线 ≠ 准确率。红线是**否决项**：任一条被突破，整体不通过，不能『用别处的高分补』。
> 每条红线要有**正向断言 + 反向对照**：该拦的拦住了 / 该放行的放行了。只做正向会得到**假通过**——『一律拒绝』天然满足『未授权访问被拒绝』。
> 清单里有、测试里没有 → fail；测试里有、清单里没有 → fail。这条对齐本身也是一条红线（R0）——否则清单会慢慢变成一张废纸。

每条红线带**依据栏**指回真实事故（H4 写操作闸 / V5 校验 / V7 死代码）——金样从事故里长出来，不是从想象里编出来。

### ⑥ 归因要分离

r4 模板 §4 未达成项表强制填「归因：检索 / 评级 / 金标 / 语料」——**金标本尊允许被质疑**。「疑似误拒」9 条的存在就是说：正样本被拒答不一定是系统错，可能是金标过期（issue 内容变了），要人工复核而不是急着调参。

---

## §2 · 最有故事性的实证：记忆金样五轮校准曲线

reports/ 目录里躺着一条完整的「评测驱动修复」曲线（同一个 50 条金样集，只动 prompt 版本）：

| 轮次 | 报告 | extraction_precision（≥0.9） | noise_write_rate（≤0.1） | 事件 |
|---|---|---|---|---|
| 首轮 live | memory_golden_eval_20260921.yaml | **0.2286** | 0.3571 | 12 条 TypeError: offset-naive vs offset-aware datetime——**金样第一功是抓实现 bug 不是测模型** |
| tz 修复后 | memory_golden_eval_20260921_post_tzfix.yaml | （修复验证） | — | 同一金样集复跑 |
| 校准 R1 | extract_calib_round_1.yaml | 0.88 | 0.1429 | paraphrase/supersede 已 1.0，抽取精度差一点 |
| … | round_2..5 | 逐轮收敛 | | 每轮只动一个变量（校准日志 evals/memory/extract_calib_log_20260922.md） |
| 定稿 v4 | memory_extract_calibrated_20260922.yaml | **0.96 ✅** | **0.0714 ✅** | all_thresholds_met: true |

面试金句：**「Golden set 的价值排序——先抓实现的 bug，再抓模型的短板，最后才轮到调参。我们的第一轮金样评测，0.22 的抽取精度里有 12 条根本不是模型的错。」**

---

## §3 · 旧项目（ai-ink-brain）的对应实践：gate A/B/C

路径：ai-ink-brain-api-python/docs/diary/jsonPKmermaid/reports/。场景：选「喂给 LLM 的代码上下文形态」——Mermaid 全文 vs JSON 图谱 vs 子图查询 vs 精选双轨。

四个方法论亮点（迁移价值高于结论本身）：

1. **freeze_id 冻结被测对象**：TECH_GRAPH_GATE_C_FREEZE_20260518_V1_0——评测可复现的前提是**被测对象版本钉死**，图谱变了金标就失效；
2. **NR-1 / NR-2 纪律**：历史臂不新跑（「勿复做主实验」）——防「重跑到过为止」的 p-hacking；
3. **复现命令进报告**：每份结论报告带完整 reproduce_commands（materialize→run→score→pytest 四步）；
4. **成本轴与质量轴并列**：子图查询臂 F1 不劣于全文臂的同时 token 只有 0.10×——评测不只看对错还看成本，这个双轴表（gold_f1_s1s2_s0_segments.md：entrypoints/impacts 两轴 P/R/F1 × 各臂 token 中位数）就是选型决策本身。

结论同样走人签：状态 accepted（待 HG-GATE-C-SIGNOFF）——**金样实验的结论也是要经过闸的**。

---

## §4 · 可迁移结论：「如果明天让你给 TokenOS 建 golden set」

八步（每步都能指回上面某条实证）：

1. **用例从真实事故和评审记录反推**，不从想象编（红线依据栏 = H4/V5/V7）；
2. **按行为类别分桶** + schema 强制每类数量下限；
3. **负样本独立指标 + 独立失败分类**（误答/误拒分开记）；
4. **阈值写进 SPEC 先签收**，fake 自检档与 live 裁决档分离；
5. **被测对象版本钉死**（freeze_id / commit / 语料 N 全进报告头）；
6. **小样本纪律**：n + Wilson CI + confidence 三件套，「已达标」表述必须带置信；
7. **未达标归因四选**：被测系统 / 评级器 / 金标 / 语料——金标可质疑；
8. **红线层独立于准确率层**：否决项 + 正反对照 + 清单↔实现对齐闸。

反模式清单（面试主动列，显方法论成熟度）：跑完再定阈值 / 只有正样本 / 平均数掩盖类别塌陷 / 重跑到过为止 / 金标不可质疑 / 红线被高分稀释。

---

## §5 · 反问收尾（把方法论变成对话）

「TokenOS 现在的评测是怎么做的？——我特别想知道两件事：你们的行为类别是怎么分的，以及**有没有红线层**——因为按我的经验，准确率先行的团队，往往在第一次线上事故之后才补红线。」

---

## 附 · 素材索引（真值位置）

| 素材 | 位置 |
|---|---|
| 记忆金样集 50 条四类 + 标注指南 | ops-desk-api/evals/memory/golden_v1.yaml + README.md |
| 五轮校准报告链 | ops-desk-api/reports/memory_golden_eval_20260921*.yaml · extract_calib_round_1..5.yaml · memory_extract_calibrated_20260922.yaml |
| RAG 金样 73 条四象限 + 结案模板 | ops-desk-api/evals/golden/queries_v1.yaml · reports/r4_final_TEMPLATE.md · r4_final_live_20261019T032150Z.md |
| 能力红线 R0-R15 | ops-desk-api/evals/agent/redlines/capability_v1.yaml（实现在 tests/eval/test_capability_redlines.py） |
| agent 金样四套件 | ops-desk-api/evals/agent/golden/{capability,supervisor,router,strategy_builder,e2e} |
| 旧项目 gate A/B/C | ai-ink-brain-api-python/docs/diary/jsonPKmermaid/reports/conclusion_gate_*.md + gold_f1_s1s2_s0_segments.{json,md} |

更新：v1 2026-10-28 初版（m01518 用户点单：整理两仓 golden test 方法论）。
