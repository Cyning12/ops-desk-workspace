# 10 · P2a 冒烟验证与验收记录（T4）

> **日期**：2026-11-16 · **执行**：exec-p2a-t4（30 帽）· **授权**：issue #23 m03064 夜间窗口 + 08 终稿 §7 T4 行
> **验证假设**：「Agent 读面板数据出结论」（08 §6 验收双件制：CI 结构断言 + 四样例人工冒烟一次跑完）

## 一、三级裁定

**成立（4/4 全过）**。

- (a)-(f) 四样例逐项全过；(a) 走设计 §6 明示的替代证据路径（Langfuse 真云不可证 → SSE 帧序列 + DB 持久化 run events）。
- 无选错 capability · 无 mock_* 误选 · 无 plan fallback · 无数据错 → 失败处置（description 修订 / mock 收窄 / 退回 T1/T2）均不启动。
- **不触发 08 §3 FC 重估**：plan-JSON 选择失败 0/4（触发线为 ≥1/4 且可归因表达力）。

## 二、冒烟设置

- 端点现实：POST `/api/ops/lg-rag/stream`（mode=supervisor）——设计写 /api/ops/chat/stream 已 410 下线（api 仓 router.py:56 迁移指针）【偏差 1】
- LLM：真 .env siliconflow DeepSeek-V4-Flash；服务 blank 三键（LG_RAG_SUPERVISOR_PLAN_ON_FAIL=/LG_RAG_DELEGATION_TOKEN_MODE=/OPS_STRATEGY_EXTRA_CANDIDATE_CAPABILITY_IDS=，防 PLAN_ON_FAIL=single_rag 掩盖 plan fallback · 承 T1 偏差六先例）
- seed（tenant ops-desk-pilot · 人工构造 · dev 库）：repo cyning12/ops-desk-api · issues #101 open[bug]auth / #102 open[bug,performance]reports / #103 closed[enhancement] / #104 open[ci] · PRs #201 open+CI failure / #202 open+success / #203 merged · sync_run success · scan_snapshot{open_issues:3} · graph 4 模块 3 边 · module_matrix{reports:[auth],ci:[auth],integrations:[reports]}
- 面板对照：GET /api/ops/overview|issues|pulls|graph 同题 REST 对照（无浏览器/GUI · 设计明示允许替代 UI 截图）【偏差 3】

## 三、四样例证据与 (a)-(f) 判定

| 样例 | plan 选择（预期） | 数字对照 (b) | answer 要点 | 判定 |
|---|---|---|---|---|
| S1「最近 issue 吞吐怎么样？」66.6s | get_overview args{} ✓ | count=1/30d · as_of=2026-11-15T18:43:37Z 与面板逐键一致 | 显式引用数据截止时间（c ✓）+ 归纳「吞吐极低 · 若异常下滑建议排查」（e ✓） | 全过 |
| S2「open 的 PR 里哪些 CI 挂了？」61.1s | query_pull_requests{state:open, ci_status:failure} ✓ | 仅 #201 与面板一致 | 列举 #201 number+title+CI 状态 + 建议查日志（e ✓） | 全过 |
| S3「模块 reports 依赖哪些模块？」44.6s | graph_snapshot{view:full, module:reports} ✓（观察项：实发双参 · 设计预期单参） | module_matrix reports:[auth] 与面板一致 | 引用 module_matrix 归纳「reports 依赖 auth」（e ✓） | 全过 |
| S4「现在有哪些 open 的 bug？」74.7s | query_issues{state:open, label:bug} ✓ | #101/#102 两枚 · labels/module_tag/updated_at 逐键一致 | 归纳 2 枚 bug 的模块分布（e ✓） | 全过 |

- (a) tool_exec 命中预期 capability：**4/4 命中**（证据：SSE supervisor plan 帧 + subtask.progress 帧 + DB ops_lg_rag_run_events 持久化记录，四 run_id 逐一核对 tool+args）【Langfuse 云面终证不可达 · 偏差 2】
- (d) 无幻觉 id 致 plan fallback：PLAN_ON_FAIL blank（fail-closed 默认）下四样例均一次 http200 返回工具结果 ✓
- (f) 未误选 mock_*：四样例 plan 均为预期面板 capability ✓

## 四、CI 结构断言（双件制之另一件）

tests/test_capability_supervisor_smoke_assertions.py（16 例 · 零 app/ 改动 · PR #406）：
- supervisor allowlist 恰好九枚钉死（utc_now_iso / mock_get_issue_status / mock_get_deploy_info / get_issue_by_number / get_pr_by_number / query_issues / query_pull_requests / get_overview / graph_snapshot）
- 四设计样例→预期 capability 对照钉死 · 预期集 ∩ mock_* = ∅（(f) 结构面）
- 九枚逐枚 plan-JSON 可选中保留（表达力覆盖全 supervisor 面）· catalog 九枚可见
- capability 电池十一件 166 passed 0 failed（五键 blank）· 分支全量对拍：失败集与 base 96ccf902 恒等（16 枚 .env 污染既有红 · CI 无 .env 为终裁）

## 五、偏差清单

1. 端点现实 /api/ops/lg-rag/stream mode=supervisor（设计写 /api/ops/chat/stream 已 410 下线）。
2. Langfuse 真云 (a) 终证不可达：读 API 认证通（v2 observations），但项目最新 observation 停留 2026-10-29(prod)/10-27(dev)，本日冒烟窗口 0 条落店；uvicorn 日志 tracing=on keys=yes 零错误，有 WARNING「No active span in current context」（span metadata 跳过）→ 以设计 §6 (a) 明示替代路径（SSE 帧 + DB run events）落证。**后续建议**：另波排查 Langfuse ingest 链路（v3→v4 迁移日 2026-11-16 恰逢 · 疑似实例侧）。
3. 无浏览器/GUI：(b) 以面板 REST 四端点同题 JSON 对照替代 UI 截图；product N3 用户视角截图以 SSE 帧序列+面板 JSON 对照替。
4. ci_status 词面：设计样例写 failing，仓内 GitHub 惯例 failure（manifest description 在案）→ seed 用 failure，S2 LLM 自发命中。
5. S3 实发 view=full+module=reports 双参（设计预期 view=modules 或 module=X 单参）· schema 放行且结果正确 · 观察项。
6. 冒烟服务 blank 三键 · 承 T1 偏差六先例。
7. seed 人工构造（非 GitHub 真同步）· 冒烟设计本意。
8. test_wave_gate_registry 脏树期红（closed entry banned tests/ 在途守卫）· 承 T2 先例 · 提交后复绿实证。

## 六、结论与后续

- 总假设「Agent 读面板数据出结论」**成立**：supervisor 面九枚 capability 对四类面板问题可选中、数据与面板同源同数、答案带 as_of/归纳判断、零幻觉零 fallback。
- §3 FC 重估：**不触发**（0/4 失败 · 远低触发线）。
- P2b 前置：T3 回灌②③（mock 翻译层自证 · annotations 合成正确性）按 09-mapping §5 属 P2b 面，本波不承载，登记在案。
- 全量执行长日志：/tmp/opsdesk-rfc/p2a-t4-exec.md（帧证据/判定表/Langfuse 核查原始记录）。
