# 01 · 编排底座与执行模型

> 裁定议题：#23 议题2（编排底座）、议题4（执行模型），含架构侧端侧支撑。
> 三方一致；architect 在 R2 收回"MCP 优先"，见 02 文档。

## 1. 编排底座裁定：LangGraph 作执行引擎 + 自研薄 harness 作运行时

**裁定：分层。LangGraph 降级为单次 Run 的图执行器；之上在 ops-desk-api 内自研一个薄 harness 层，概念裁剪为 4 个——Run / Goal / Schedule / Skill。不引入 DSH 本体，也不在 LangGraph 里继续裸写运行时语义。**

### 理由（architect 立场，platform 附议）

- LangGraph 擅长"一次执行的图编排 + checkpointer"，天然不具备 subagent 树、goal 续跑、schedule 投递、skill 挂载这类**跨会话运行时语义**。在图框架里硬塞这些等于塞一个操作系统。
- **引入 DSH 本体是错的**：DSH 是 TypeScript 独立运行时，ops-desk-api 是 Python；跨语言耦合 + 双运行时维护会把 1 人团队拖死（platform）。
- 正确姿势是**机制移植而非代码复用**：subagent 树→LangGraph subgraph、goal→后台任务、skill→Markdown 加载器。抄 DSH 的语义定义不抄实现——负责人同时是 DSH 维护者，这是本项目独有优势；但要有纪律地"按需裁剪"，警惕把 DSH 当需求清单。
- 模型仅 API、无推理侧兜底，所有复杂度都由 1 人（AI Coding）维护，概念数必须最小：**4 概念 × 每个一张 PG 表**，AI Coding 可完全消化。

### 概念引入时机（architect R2 裁定）

| 概念 | 最早引入 | 说明 |
|---|---|---|
| Run | P0'/P1 | 一次任务执行：持久化、可回放 |
| Goal | P1 | 跨轮目标态；多轮 = 同一 Goal 下多个 Run 的链 |
| Schedule | P3 | 异步任务的触发器，与 approval 同批，提前无用 |
| Skill | P2b | 与 MCP 同批；载体 = workspace 仓 skills/ 目录 + 启动加载器 |

subagent 树（多 Agent 编排）推迟到 P4。

## 2. 执行模型裁定：异步为体，SSE 为用

**裁定：一切执行皆异步持久化 Run（PG 落库 + LangGraph PG checkpointer）。SSE 不是执行模型，而是"对某个 run_id 事件流的可断线重连订阅通道"。同步会话与后台任务由此统一，不存在取舍。**

- Chat 秒回 = 提交 run + 立即订阅事件流（体感与 v1 同步 SSE 一致）。
- 后台任务 = 提交 run + 不订阅（或稍后回放）。
- v1 同步 SSE 把执行生命周期绑死在 HTTP 连接上（断网/切后台/iOS 退屏 = 执行丢失），Agent 时代单次执行数分钟到数小时，此路必废。

### 队列与进程拓扑

- **不引入 Redis/Celery**：PG LISTEN/NOTIFY + 独立 worker 进程（docker-compose 多一个 service），足以支撑单机 Lighthouse。
- FastAPI 进程与 worker 进程**自 v1.1 起分进程**（同仓不同 service），边界早定。
- platform 建议的 Dramatiq/arq + PG broker 为可选增强，非必须。

### 事件协议（P0' 必须做对，后补极痛）

- `run_events` 表 append-only，`seq` 单调递增。
- SSE 订阅支持 `Last-Event-ID` 断线重连续传。
- iOS 端 SSE 后台不可用：v1 只做进入 app 拉取，APNs 留接口不实现。

## 3. P0' 地基（新增，v1 收尾时做）

**裁定（product 有条件接受，条件已满足）：把 v1 的 chat 历史存储直接建模为 runs/run_events，而不是朴素对话表。**

接受条件（product）：仅限数据层决策，v1 前端与 API 行为不变；判定标准——删掉 P0' 后 v1 可正常上线、P1 只需改后端不需数据迁移。

工作清单（architect，≈2~3 个 AI Coding 任务单）：

| 项 | 量级 | 内容 |
|---|---|---|
| 表结构 | ≈0.5 天 | `runs(id, session_id, status, created_at)` + `run_events(id, run_id, seq, kind, payload, created_at)`；v1 单轮 Chat = 恰好 1 个 run，事件 kind 仅 `token`/`thought`/`final` 三种。比原"对话+思考两张表"反而更简 |
| 事件序号协议 | ≈0.5 天 | seq 单调递增 + Last-Event-ID 重连续传 |
| PG checkpointer | ≈1 天 | 官方 `langgraph-checkpoint-postgres`，接入 + 验证断点恢复；P0' 只落表，P1 才启用 interrupt/恢复语义 |

依据：三项全部落在 v1 已确认的"保存完整对话+思考过程"决策的实现路径内，是把存储 schema 一次性设计对，**不是新增功能**。现在按朴素 chat 表落，P1 迁移脚本 + 双写期成本远超这 2 天。

### 数据冗余纪律（platform）

- **消息/事件表为准，checkpointer 只存 LangGraph 内部状态**，避免双写两套真相。

## 4. 阶段技术依赖图

```
P0' 地基: runs/run_events 表 + PG checkpointer + 事件序号协议
  └─ P1 会话深化（Run+Goal）：多轮 = 同一 Goal 下多个 Run 的链
       └─ P2a 工具：私有 FC + ToolRegistry（工具注册在 harness 层，不在图内）
            ├─ P2b 生态：MCP client 适配器 + 最小 skill 加载器
            └─ P3 任务化：Schedule/Approval 两张新表 + 写工具 + 事件回放
                 └─ P4 通用化：领域=工具包配置；多 Agent=Run 树
```
