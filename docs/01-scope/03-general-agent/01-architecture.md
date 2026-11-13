# 01 · 编排底座与执行模型

> 裁定议题：#23 议题2（编排底座）、议题4（执行模型）。
> **v2（2026-11-13）：经 inv-api / inv-web / inv-docs 三路实地代码调研修正**——初稿基于过时 v1 画像，本版以代码事实为准（证据均附文件路径）。

## 0. 代码现状基线（调研修正后的 As-Is）

以下能力**已在生产代码中存在**（生产 cynaya.cn，迁移主线已上线），不是待办：

| 能力 | 证据 |
|---|---|
| LangGraph 现役执行引擎（supervisor 五阶段多智能体图：strategy_builder→supervisor→Send 并行→observe ReAct 外环→aggregator→critic） | `app/ops/lg_rag/multi/graph.py:79-105`；`POST /lg-rag/stream` 默认 mode=supervisor（router.py:452-500） |
| PG checkpointer（`AsyncPostgresSaver`，env 闸 `LG_RAG_HTTP_CHECKPOINTER=postgres`，默认关） | `app/ops/lg_rag/checkpointer.py:46-54`、`router.py:12-13` |
| 事件持久化三表族 `OpsLgRagThread/Turn/RunEvent`（uq(run_id,seq)，事件帧 {run_id,seq,ts_ms,agent_role,event_type,payload,cursor}） | `app/db/models.py:291-343`；alembic `20260831_lg_rag_*` |
| 执行与 HTTP 解耦（进程内 RunWorker 单飞：断连只 cancel subscriber 不 cancel worker；孤儿补偿 300s） | `app/ops/lg_rag/run_worker.py:93-165,185-238`；`sse_subscribe.py:59-63` |
| 断线续看 replay（`POST /lg-rag/replay`，cursor 或 run_id+after_seq，follow=true live-tail，在飞 409） | `router.py:503-593` |
| HITL 审批全链（interrupt→`hitl.waiting`→decide→resume 两步链式；approval 独立 REST 资源） | `app/ops/hitl/router.py`；`app/ops/hitl/resume.py` |
| Capability 工具体系（27 文件：registry/gateway/policy/idempotency/receipts/circuit/budget/visibility…） | `app/ops/capability/` |
| 旧 chat SSE 已 410 下线 | `app/ops/chat/router.py:18-47` |

## 1. 编排底座裁定（维持方向，修正表述）

**裁定：LangGraph 保留为单次 Run 的图执行引擎（已是现状）；之上收敛出薄 harness 层，概念 = Run / Goal / Schedule / Skill。不引入 DSH 本体，机制裁剪移植。**

修正点：

- "薄 harness"不是从零新建——现役 capability 体系、RunWorker、HITL 已覆盖其中大部分；**真正新增的概念主要是 Goal（跨轮目标态）与 Schedule（定时投递，P3）**。Run 当前以"事件流即 run"存在（`OpsLgRagRunEvent.run_id` 为 String 非 FK，run 边界由事件流隐含）；**是否将 run 实体化为一等表是开放裁定项**（见 §3）。
- subagent 树（多 Agent 编排）推迟到 P4；现役 supervisor 图的 Send 并行子任务是其雏形。

## 2. 执行模型裁定（修订）

**裁定：维持"异步为体，SSE 为用"，但确认其内核已实现（进程内版）；后续工作是加固而非新建。**

- SSE 是"对 run_id 事件流的可断线重连订阅通道"——已由 `/lg-rag/replay` + cursor 实现。**沿用 cursor+replay 契约，不引入 Last-Event-ID**（初稿表述作废）；前端纪律为"手动续看、不自动 replay"（`useLgRagSse.ts:111-112`、`ChatView.vue:113-116`）。
- 断线恢复已有**三种语义**，文档与实现均须区分：replay 续看（只读回放）/ 继续回复（`continue_from_run_id` 发起新 run）/ HITL resume（审批恢复）。
- **独立 worker 进程 + PG LISTEN/NOTIFY 降级为多副本扩展项**（初稿把它列为既定架构，作废）。代码现实是进程内 `RunEventBus` + asyncio.Task 单飞，注释明确"MVP 进程内；多副本 DB 租约另立"（run_worker.py）。单机 Lighthouse 阶段维持进程内。
- 不引 Redis（现状一致：仅熔断共享存储留 `OPS_CAPABILITY_CB_REDIS_URL` 可选位，默认进程内）。

## 3. P0' 重定基线（修订）

初稿的 P0'（新建 runs/run_events、事件序号、接入 checkpointer）**大半已被现役 lg-rag 覆盖**。修订为 **P0' · 收敛与默认开启**：

| 项 | 内容 | 量级 |
|---|---|---|
| C-1 | 默认开启 `LG_RAG_HTTP_CHECKPOINTER=postgres` 并验收（它是 HITL resume 的前置，未开显式 503 `checkpointer_not_configured`，`resume.py:317`） | ≈0.5 天 |
| C-2 | **裁定 run 是否升为一等实体表**（现状无 runs 表；旧 `ops_runs` 随旧 chat 下线）。若做：与 `chat-stream-v1.md` §2、现役三表族裁定真源 | 需裁定 |
| C-3 | 下线旧 chat 遗产：`app/ops/chat/graph.py`/`service.py`/`ws.py`、旧表 `ops_runs`/`ops_run_events`（410 端点保留或移除一并定） | ≈1 天 |
| C-4 | 文档真值切换：表结构引用指向 alembic migrations（18 个），`ops_desk_ddl.sql` 标记为 v1 快照 | ≈0.5 天 |

**接受条件（替换初稿条件）：不破 `lg-rag-sse-v1` freeze 词表（updates/answer delta/subtask.progress/keepalive），不触发 tenant freeze 闸（F1–F6）；新增内部事件分类须给出现有词表的映射并走红线 3 契约评审。** 初稿的 `token/thought/final` 三值 kind 与 freeze 冲突，作废。

## 4. 贯穿约束：多租户（初稿完全遗漏）

- session.tenant_id 已是租户真源（`models.py:67-84`，默认 `ops-desk-pilot`）；capability visibility / HITL / memory 多表已带 tenant_id。
- **本文档套及后续所有新 DDL 必须含 `tenant_id`，跨租户访问 404（freeze F4）**；已有登记缺陷"resume 链丢失"（N-R2-1）随 P0' 跟进。

## 5. 阶段技术依赖图（修订）

```
P0' 收敛与默认开启（checkpointer 默认开 / 旧遗产下线 / run 实体化裁定）
  └─ P1 会话深化：在既有 supervisor 图上收敛多轮 Goal 语义（非新建 ReAct——图里已有）
       └─ P2a 工具：复用 capability registry，补 MCP schema 对齐 + FC 路径裁定
            ├─ P2b 生态：MCP client 适配器 + 最小 skill 加载器
            └─ P3 任务化：Schedule 表 + 任务卡片/轨迹回放 UI + L2 记忆产品化
                 └─ P4 通用化：领域=工具包配置；多 Agent=Run 树
```
