# 17 · P2c planner 验证报告（T2 选定率真 LLM 冒烟 · T1 硬化验收）

> 2026-11-17 夜 · exec-p2c-t2（issue Cyning12/ops-desk-workspace#23 夜间授权 · task slug p2c-t2-selection-rate-smoke）
> 冒烟对象：api master 尖 `cfe76b23`（P2c-T1 硬化已合：`app/ops/lg_rag/multi/nodes.py` `_TOOL_AWARENESS_GUIDANCE` 引导语+few-shot 注入 · 装配点 `_build_catalog_block`）
> 需求真源：[12-p2b-verification.md](12-p2b-verification.md) §5-1（hit-echo 首跑未命中弱面）· [13-p2b-skill-verification.md](13-p2b-skill-verification.md) §7-2（域外负例 fail-closed 须保住）
> 长日志：`/tmp/opsdesk-rfc/p2c-t2-exec.md` · harvest：`/tmp/opsdesk-rfc/p2c-t2/*.harvest.json`（承 t5a_on_*.harvest.json 格式）

## 1. 三级裁定

**成立**——选定率组 5/5 行为正确（≥4/5 线 · 其中 2 条首跑 fail-closed、复跑承 13 §7-2 先例后命中）· 回归组 4/4 零劣化 · 域外负例正确（纯 rag 不选工具）· skill 回归 1/1 命中。

## 2. 环境

| 项 | 值 |
|---|---|
| 服务 A（选定率+回归组） | uvicorn 127.0.0.1:8000 · 真 .env SiliconFlow · blank 两键（LG_RAG_SUPERVISOR_PLAN_ON_FAIL= / LG_RAG_DELEGATION_TOKEN_MODE= · 承 P2a-T4 先例）· OPS_CHAT_TRACER=（关 langfuse · 偏差 2）· MCP 开（server-everything · /tmp/opsdesk-rfc/p2c-t2/mcp_servers.yaml · 建连 12 注册/3 拒载/1 排除）· EXTRA_CANDIDATE=mcp__everything__echo,get_sum,get_env |
| 服务 B（skill 回归组） | uvicorn 127.0.0.1:8001 · OPS_SKILL_LOADER_ENABLED=1 · 三键 blank（承 T5a 迭代 2 环境）· MCP 关 |
| 数据 | dev 库 opsdesk · P2a-T4 seed 完好（issues #101-104 / PRs #201 failure #202 success #203 merged / graph 4 模块）· 新邀请码 p2c-t2-smoke-invite-20261117（maintainer · dev 一次性留存） |
| 驱动 | **串行** fire→等 done→harvest（/tmp/opsdesk-rfc/p2c-t2/serial_drive.py）· 并发驱动触发熔断事故见 §5 F3 |

## 3. 选定率组（5 条 · 泛化中文问法不点名 capability · 逐条 planner 实际选择）

| # | 问法 | 首跑 | 复跑 | 判定 |
|---|---|---|---|---|
| ① sel1 | 现在几点了 | **fail-closed**（supervisor first plan failed · 非 LLM 错误） | **tool=utc_now_iso {}** ✓ | 正确（复跑命中 · 承 13 §7-2 先例） |
| ② sel2 | 帮我看看服务器现在负载怎么样 | **纯 rag**（1 rag 子任务 · 如实答「知识库无负载数据」并给出 uptime/top/监控平台建议） | — | 正确（目录无服务器负载能力 · 符合兜底从句「仅当目录中没有工具能覆盖该问题时才纯 rag」） |
| ③ sel3 | 今天有哪些待审批的申请 | **fail-closed**（同 ①） | **tool=query_issues {state:open}** | tool 选定 ✓ 但语义拉伸登记（目录无审批能力 · 映射到最近 issue 台账 · 见 §5 F2） |
| ④ sel4 | 请用 echo 工具回显这句话：p2c-t2 选定率冒烟（12 §5-1 原泛化问法） | **tool=mcp__everything__echo {message:"p2c-t2 选定率冒烟"}** 首跑命中 ✓ | — | 正确 · **弱面改善实证** |
| ⑤ sel5 | 1+1 等于几（域外负例） | **纯 rag**（答 2 · 零工具声明） | — | 负例正确 ✓ |

**计数：5/5 ≥ 4/5 线。**

## 4. 回归组（10 文原文四句 · 期望不劣化）

| # | 问法 | plan 实际选择 | 与 10 文预期 | 判定 |
|---|---|---|---|---|
| reg1 | 最近 issue 吞吐怎么样？ | get_overview {} | get_overview ✓ | 不劣化 |
| reg2 | open 的 PR 里哪些 CI 挂了？ | query_pull_requests {state:open, ci_status:failure} | 逐键一致 ✓ | 不劣化 |
| reg3 | 模块 reports 依赖哪些模块？ | graph_snapshot {view:full, module:reports} | 一致（含 10 文已登记双参观察项） ✓ | 不劣化 |
| reg4 | 现在有哪些 open 的 bug？ | query_issues {label:bug, state:open} | 一致 ✓ | 不劣化 |

**4/4 零劣化**（硬化未误伤既有命中 · 答案均带数据引用与归纳）。

## 5. skill 回归组（13 文 H1 复跑）与新发现

skill-h1「先看下项目近期 CI 健康度，再给我一些改进建议」→ plan 3 子任务（get_overview {} · query_pull_requests {page:1,page_size:10} · rag t3 **skill_ref=panel-data-guide 声明**）· 答案带置信度口径与面板读数归因。**1/1 命中**（环境允许已跑）。

新发现登记：
- **F1 plan-JSON 稳定性噪声扩展**：fail-closed 首跑不再限于域外 query（13 §7-2 仅登记域外数学题）——①③ 域内问法首跑 `SupervisorPlanError('supervisor first plan failed (no locked prefix)')`、复跑即过；与 T1 硬化无因果（解析面零改 · 回归组 4/4 同环境全一次过）→ 建议后续波登记 supervisor plan-JSON 重试/稳定性观察项。
- **F2 过度选择边界**：③「待审批的申请」被映射 query_issues{state:open}（语义拉伸）——硬化后 planner 选定倾向增强，边界 query 出现近似工具强行匹配；与 ② 正确 rag 兜底对照，登记为引导语措辞后续观察项（本波不判失败：判据仅要求负例不选工具 · ③非负例）。
- **F3 冒烟方法论**：承 T5a 并发驱动（sem=3 × 9 路）于 21:14 触发 SiliconFlow 熔断（circuit_open 60s）全灭——单发 curl 两模型均 200 排除 key/模型失效，定为并发突发限流；夜间冒烟一律改**串行驱动**（首轮 9 个 run_id 作废 · error 帧非证据）。
- **F4 langfuse OTLP 403 持续**（承 12 §6 dev 密钥失效 · 环境面）；本波 OPS_CHAT_TRACER= 关闭以降噪（偏差 2）。

## 6. 与 12 §5-1 原弱面对照改善量

| 对照点 | 12 §5-1 原状（T5b · 硬化前） | 本波（T1 硬化后） | 改善 |
|---|---|---|---|
| hit-echo 泛化问法 | 首跑 planner 退化 rag 直答未选工具 · 须显式命名 capability id 才稳定选中 | **同型问法首跑命中 tool**（mcp__everything__echo · args 正确） | 首跑命中 0→1 |
| 泛化时间问法 | （当时未测） | 复跑命中 utc_now_iso | 新增实证 |
| 域外负例 | 空 plan fail-closed（13 §7-2） | 纯 rag 直答（不选工具）——引导语兜底从句生效，行为更平滑 | 不劣化且更优 |

## 7. 偏差清单

1. ④ hit-echo 复测 message 文本改为「p2c-t2 选定率冒烟」（原文为 p2b-t5b 字样 · 同型问法保留）。
2. 双服务 OPS_CHAT_TRACER= 关闭 langfuse（OTLP 403 已知环境面 · 承 12 §6 · 不影响判据证据链——证据走 SSE+DB run events 承 10 文 (a) 替代路径先例）。
3. MCP yaml 裁掉 everything-mismatch 负例 server（本波不验 expected_server 拒连 · 12 文已证）。
4. 驱动改串行（并发熔断事故 F3）；skill 组独立服务 B 复现 T5a 迭代 2 环境。
5. seed 人工构造承 P2a-T4（非真同步 · 冒烟设计本意）；邀请码/seed 保留说明见 §2。

## 8. 证据索引

- run ids——sel1 f1690f27（fail-closed）· sel1b 4ddc98e3（utc_now_iso）· sel2 6cacd6db · sel3 df52397c（fail-closed）· sel3b a93aeac4（query_issues）· sel4 0ce86efd（mcp echo）· sel5 a0b5d6cc · reg1 ac5fb21e · reg2 69139fc4 · reg3 3d33a315 · reg4 81f29b1b · skill-h1 2cbd049f
- harvest：/tmp/opsdesk-rfc/p2c-t2/{sel1-time,sel1b-time,sel2-load,sel3-approval,sel3b-approval,sel4-hitecho,sel5-math,reg1-throughput,reg2-prci,reg3-deps,reg4-openbug,skill-h1}.harvest.json
- 服务日志：/tmp/opsdesk-rfc/p2c-t2/server-a2.log（A）· server-b2.log（B）· server-a.log（首轮熔断事故现场）
