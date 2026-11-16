# 12 · P2b MCP 验证报告（T5b 真社区 server 冒烟 + 环境开启 runbook + P2c 评估）

> 2026-11-16 · exec-p2b-t5b（issue Cyning12/ops-desk-workspace#23 夜间授权）
> 真值配套：设计 [11-p2b-mcp-skill-design.md](11-p2b-mcp-skill-design.md) §8 T5b 行 / §9 验收；实现台账 ops-desk-api `docs/harness/invokes/by-task/p2b-t5b-mcp-smoke-wrapup/invoke_20261116_30_impl.md`（PR #416）；长日志本地 `/tmp/opsdesk-rfc/p2b-t5b-exec.md`。

## 1. 冒烟对象与环境

| 项 | 值 |
|---|---|
| 真社区 server | `@modelcontextprotocol/server-everything` v2.3.0（npx stdio · cwd=/tmp） |
| 协议钉版 | 2025-06-18（协商结果一致 ✓） |
| 负例 server | everything-mismatch（expected_server.name 故意错配 → 证拒连） |
| 服务面 | uvicorn 127.0.0.1:8001 · `OPS_CAPABILITY_MCP_ENABLED=true` · `OPS_STRATEGY_EXTRA_CANDIDATE_CAPABILITY_IDS=mcp__everything__echo,mcp__everything__get_sum,mcp__everything__get_env` |
| LLM | dev 配置 supervisor 模式 · Langfuse tracing on（exporter 403 见 §6） |

## 2. 冒烟判据核对（11 §9.1 三层之「真社区 server R6」+ R7 会话判据）

| 判据 | 结果 | 证据 |
|---|---|---|
| 建连握手 + expected_server 断言 | ✅ | 日志 `mcp server=everything connected protocol=2025-06-18 tools=16`；负例 everything-mismatch `identity_mismatch` 拒连 + span `mcp.connect` |
| tools/list → 翻译注册 | ✅ | 16 工具 → 12 注册 / 3 拒载（readOnlyHint=false 与配置 side_effect=read 冲突 · M1 fail-closed）/ 1 排除（exclude_tools）；命名 `mcp__everything__*` |
| catalog 投影 | ✅ | GET admin/catalog items 22 含 12 条 mcp（kind=mcp · se=read · risk=low · tags=["mcp","everything"]）；不含 args_schema（SPEC 纪律 #4） |
| 用户会话 ≥3 命中 | ✅ | ① mcp__everything__echo → `"Echo: p2b-t5b 真社区server冒烟"` ② mcp__everything__get_sum {a:17,b:25} → `"The sum of 17 and 25 is 42."`（数字类型正确）③ mcp__everything__get_env → 真子进程 env（INIT_CWD=/private/tmp=配置 cwd）；三枚 critic 全 pass |
| 用户会话 ≥2 不命中 + P2a 四样例不误选 | ✅ | 四样例复跑全选 builtin（get_overview / query_pull_requests / graph_snapshot / query_issues），**零误选 mcp.*** |
| 七层闸链 + span + receipt | ✅ | 每次命中 delegation token_verified（{capability_id, subtask_id}）；gateway span 载荷 {capability_id, kind=mcp, ok, tenant_id, risk_level=low, side_effect=read, policy=allowed, subtask_id}；translator span {registered:12, rejected:3, excluded:1} |
| args_schema V1-V13 + 边界 fail-visible | ✅ | 直调闸链错参 → 稳定码 `args_schema_invalid`（不 500、不裸异常）；tool_use_error 复核=已 fail-visible → **CLOSED**（无需 P2c 候选） |
| 优雅关停 | ✅ | SIGTERM → 日志 `mcp server=everything 摘除 12/12 条目` + Application shutdown complete |

## 3. 三级裁定（11 §9.3）

**裁定 = 成立（MCP 向）**：真社区 server 互操作零失败 → R6 触发闸未命中 → **R-A1 重议不启动，裁定 A（薄 transport 自研零新外部依赖）维持**，[04-roadmap.md](04-roadmap.md):50 已按此回写；09 文 G12-G14 关闭注记同波落地。

## 4. 环境开启 runbook（env 配置 → 冒烟复现）

```bash
# 1. 配置（样例 /tmp/opsdesk-rfc/p2b-t5b/mcp_servers.yaml）
#    servers: [{key: everything, transport: stdio, command: npx,
#      args: [-y, @modelcontextprotocol/server-everything], cwd: /tmp,
#      protocol_version: "2025-06-18",
#      expected_server: {name: "mcp-servers/everything"},
#      default_side_effect: read,
#      exclude_tools: [trigger-long-running-operation, trigger-sampling-request]}]

# 2. 起服（ops-desk-api 仓）
OPS_CAPABILITY_MCP_ENABLED=true \
OPS_CAPABILITY_MCP_SERVERS_CONFIG=/path/mcp_servers.yaml \
OPS_STRATEGY_EXTRA_CANDIDATE_CAPABILITY_IDS=mcp__everything__echo,mcp__everything__get_sum,mcp__everything__get_env \
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8001

# 3. 观测
#    日志：mcp server=everything connected protocol=2025-06-18 tools=16
#    catalog：GET /api/ops/admin/capability/catalog（Bearer OPS_ADMIN_SYNC_TOKEN）
#    会话：POST /api/ops/lg-rag/stream {query, mode: supervisor}（SSE）
# 4. 注意：supervisor 候选集默认仅 9 枚 builtin；mcp 条目须经
#    OPS_STRATEGY_EXTRA_CANDIDATE_CAPABILITY_IDS 注入（T3 偏差 L1 口径）
```

## 5. P2c 评估建议

1. **planner 选定率弱面**：泛化中文问法（不显式点名 capability）时 planner 退化 rag 直答、不选工具（hit-echo 首跑未命中，显式命名后 3/3 命中）。建议 P2c 立项：planner prompt 工具感知硬化（候选集描述注入/few-shot）+ 选定率回归测试基线。
2. **tool shadowing 残余**：catalog 节级引导语依赖模型遵守，恶意 server 可跨工具叙事投毒（09 文已登记）。建议 P2c 评估：工具描述二次蒸馏（Host 侧重写 when_to_use 已部分覆盖）/双模型校验/高风险 server 沙箱配额。
3. **观测面缺口**：Langfuse OTLP exporter 403（dev 密钥失效）致真实会话 span 未上送——建议 P2c 补 tracing 健康检查告警 + mcp.connect/identity_mismatch 负路径 span 的看板化。
4. **server 向立项**：G12 文本镜像策略、G14 mock 退役同批决策、显式 reload 挂接（R-G2 条件化尾巴）随 server 向翻译器单独立项，不进 P2c 本批。

## 6. 遗留与关账

- Langfuse 403 = 环境面（密钥失效），非代码缺陷；dev 可接受，prod 部署前须换发。
- api 仓本波纯文档（PR #416）：task 档 + R1 审查文（GO）+ invoke 10/30 + HG-GRAPH-MODULES 签收行（capability/lg_rag 模块双行零改动）。
- workspace 本波：04-roadmap:50 裁定回写 · 05-discussion-log R7 追加 T5b 闭环段 · 09 G12-G14 关闭注记 · 本文新建 · README 索引补 11/12 文。
