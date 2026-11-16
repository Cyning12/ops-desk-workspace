# P2b Skill 机制验证报告（T5a 冒烟 · issue #23）

> 日期：2026-11-16（夜间自动）｜执行：exec-p2b-t5a ｜范围：11-p2b-mcp-skill-design.md §8 T5a 行 + §9.2 skill 判据
> 结论速览：**假设成立（夜间小样本）**——原样 catalog 差 1 命中，两轮 when_to_use 措辞调优后全判据达阈；api 代码零改动。

## 1. 验证假设与判据

假设：skill 指引（panel-data-guide）进入 supervisor catalog 后，跨模型选择质量达阈。

判据（设计 §9.2）：
- 命中 ≥3/3：plan 帧声明 `skill_ref=panel-data-guide` + 注入生效 + 回答呈现 skill 行为（置信度/判读口径/数据不足明说）。
- 不命中 ≥2/2：无关 query 零 `skill_ref` 声明。
- P2a 四样例复跑：工具命中参数正确且不误选 skill。
- off/on 对照会话：off 零注入零 skill 话术；on 更贴域话术。
- 三级裁定（§9.3）：工程红=不成立；工程全绿但会话缺口=部分成立。

## 2. 环境与方法

- api master 尖 `bfbb855c`；dev 库 `opsdesk`（P2a seed 完好：issues #101-104 / PRs #201 failure #202 success #203 merged / graph 4 模块）。
- env blank 三键（`LG_RAG_SUPERVISOR_PLAN_ON_FAIL=` / `LG_RAG_DELEGATION_TOKEN_MODE=` / `OPS_STRATEGY_EXTRA_CANDIDATE_CAPABILITY_IDS=`）；skill 闸显式控制：OFF=`OPS_SKILL_LOADER_ENABLED=`（空），ON=`=1`。catalog 上限默认 4000 字符未动。
- 驱动：fire-and-harvest——SSE 抓 `run.start` 拿 run_id 后断开，服务端续跑，事后从 `ops_lg_rag_run_events` 收 plan 帧/答案/done（夜间 LLM 延迟 200s+，curl 长连接不可行）。
- 样例：H1 CI 健康度+建议（"先看下项目近期 CI 健康度，再给我一些改进建议"）/ H2 解读面板读数带置信度 / H3 指标判读顺序；N1 数学（37×58）/ N2 闲聊；S1-S4 = P2a 回归四样例（吞吐/CI 挂 PR/reports 依赖/open bug）。

## 3. 判定矩阵（三轮迭代）

| 轮次 | catalog 措辞 | H1 | H2 | H3 | N1 | N2 | S1-S4 | 判定 |
|---|---|---|---|---|---|---|---|---|
| 0 原样 | 「解读面板指标（错误率/延迟/队列深度等）的子任务」 | ✗ 未声明 | ✓ | ✓ | ✓ 零声明 | ✓ 零声明 | 4/4 工具对+零声明 | 命中 2/3，**差 1 不达阈** |
| 1 正向扩写 | +「或基于面板读数做健康度评估、异常判读、改进建议」 | ✓ | ✓ | ✓ | （沿用轮 0） | （沿用轮 0） | **S1 误触发**（tool 子任务声明 skill_ref） | 命中 3/3 但回归失败 |
| 2 +负向条款 | 轮 1 +「；只取数不解读的纯查询/统计子任务不声明」 | ✓ | ✓ | ✓ | ✓ 零声明 | ✓ 零声明 | 4/4 工具对+零声明 | **全判据达阈** |

迭代 2 明细：H1c rag 子任务声明（input 原文「…评估当前项目的运行健康度，并基于面板数据解读指南提供针对性的改进建议」）；H2c rag 声明；H3c 双 rag 子任务均声明（解读型 query 内可接受）；S1c `get_overview` / S2c `query_pull_requests` / S3c `graph_snapshot` / S4c `query_issues` 全部工具命中且零声明；N1d（数学，复跑）/ N2c（闲聊）零声明。

## 4. 注入与行为证据

- 工程面：CI 六项注入证据前置已绿；本会话 in-process 复核 `format_skill_catalog` 出「## 可用技能（摘要）」节且渲染后 supervisor system prompt 含 panel-data-guide；OFF 态 supervisor schema 无 `skill_ref` 键（条件化生效）；ON 态服务日志全程零「skill_ref 未知」告警（未知 ref 会落 warning + 零注入，无告警即 `get_skill` 命中且 `wrap_slot("skill_content")` 已追加）。
- 行为面（回答层）：
  - H2/H2b/H2c 均输出「**置信度：中**」并展开依据与限制（缺历史基线、RAG 未命中阈值标准），H2 还准确引用指南覆盖范围（「仅涵盖错误率/P95/队列深度判读口径」）——rag 工人读到了注入全文。
  - H2/H1b 「如实反馈检索失败，不补充外部假设口径」——命中 skill「数据不足时明确说明，不推测填补」。
  - H3 建议段复现 skill 判读步骤：先对齐时间窗 → 入口→服务→依赖分层 → 单指标异动看配置变更/多指标联动看共享依赖。
- off/on 对照：OFF Q1（同 H1 原文）plan 无 `skill_ref` 键、答案为泛 CI 建议无置信度口径；ON 迭代 2 H1c 声明 + 注入 + 「改进路径严格围绕面板读数展开」。对照成立：**有 skill 的回答更贴域话术**。

## 5. 三级裁定

**成立（夜间小样本）**。
- 装配链（catalog → plan 声明 → wrap_slot 注入 → 工人行为）端到端验证通过；api 代码零改动。
- 选择质量经两轮 §9.2 允许的措辞调优后达阈（命中 3/3 · 不命中 2/2 · 回归 4/4）。
- 残余风险：①每 query 单样本，夜间 LLM 方差大（N1 首轮即触发 supervisor 空 plan fail-closed，复跑正常——与 skill 面无关的域外 query 行为噪声）；②选择信号对 catalog 单行措辞高度敏感（轮 0 差 1、轮 1 误触发、轮 2 才双边过），后续新增 skill 时须复跑本冒烟。

## 6. 调优落点（已随本报告落仓）

`skills/panel-data-guide/SKILL.md` `when_to_use` 最终措辞：

> supervisor 拆解出需要解读面板指标（错误率/延迟/队列深度等），或基于面板读数做项目健康度评估、异常判读、改进建议的子任务时声明 skill_ref=panel-data-guide；只取数不解读的纯查询/统计子任务不声明

## 7. 附带观测性发现（非本冒烟判据，建议后续 task）

1. **plan 帧 800 字符截断**：`node.progress` supervisor 帧的 `subtasks` 在 >800 字符时以字符串形式截断落库（H1b/H2b/H3c 实测恰 800 字符截断），事后审计/回放须正则兜底；不影响执行（执行走内存态）。
2. **域外 query 空 plan fail-closed**：数学 query 首轮 supervisor 输出 `{"subtasks": []}` 被判非法停图（`LG_RAG_SUPERVISOR_PLAN_ON_FAIL` blank 时 fail-closed），复跑正常——域外小 query 的 supervisor 稳定性可观察。

## 8. 附录

- run ids——OFF 基线：`852c22e5b2b9439b82e660791833c3ba`；轮 0：H1 `83f28c28…` H2 `08f29779…` H3 `3b1c320b…` N1 `a7f2bf97…` N2 `c0f52cb8…` S1 `5eff78c8…` S2 `e50f0b96…` S3 `4e47b843…` S4 `d7ef781b…`；轮 1：H1b `581e45d1…` H2b `3fded749…` H3b `038b2b7d…` S1b `65c52f6b…`；轮 2：H1c `9b781f3d…` H2c `18b0c0f0…` H3c `589dbed1…` S1c `5917e134…` S2c `87d2b77b…` S3c `fa9f359c…` S4c `ad755ac5…` N1c `b2bf5410…`（fail-closed）N1d `19ae689b…` N2c `3b5a7362…`。
- 原始证据：`/tmp/opsdesk-rfc/t5a_on_*.harvest.json`（plan/skill_refs/tools/answer/done）+ `/tmp/opsdesk-rfc/p2b-t5a-exec.md`（执行日志）+ `/tmp/opsdesk-rfc/SKILL.md.iter0.bak`（原样备份）。
