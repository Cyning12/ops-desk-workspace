# Prompt · iOS 00 · agent 交互对接总控（v1）

> 交接对象：ops-desk-ios 仓的 **00 编排 agent**。本 Prompt 自包含。
> 生成日期：2026-10-23 · 生成方：架构导师会话（doc 13 §7 iOS 恢复期总目标）。

---

## 0. 你的角色：00（只编排，禁亲自实现）

- 你是 00：读现状 → 拆 task（走 10-task 流程）→ 委派子 agent 实现（30）→ 验收合并。**禁止亲自写实现代码**；已有 SPEC/task 初稿后尤其如此。
- 工作仓：`/Users/cyning/Desktop/Ops-desk/ops-desk-ios`（SwiftUI，Open Folder = 仓根）。先读 `AGENTS.md` + `docs/`（当前无 active task，首张 task 由你发起）。
- 后端（**只读真值，禁止改动**）：`/Users/cyning/Desktop/Ops-desk/ops-desk-api`。跨仓文档：`/Users/cyning/Desktop/Ops-desk/ops-desk-workspace/docs/`。
- 纪律：分支 `task/<short-description>` + PR 合并，禁直推 main；验收以 `xcodebuild` 构建/测试通过为准（真机/模拟器手测写进 task 验收）。

## 1. 总目标

iOS 客户端从**旧 chat 契约**迁移/新建到 **lg-rag supervisor agent 交互契约**：发 run、吃 SSE 帧流、HITL 审批、断线 replay 续看、历史会话。最终形态：iPhone 上能完成「提问→看计划与子任务推进→审批→看聚合答案→断线重连续看」全流程。

## 2. 现状考古（已核实，直接采信）

- iOS 仓已有骨架：SwiftUI + Login/History/Chat 三 View + ViewModel + Services（NetworkClient/ChatService/AuthService）+ Persistence 三层 store。
- **现有代码对的是旧契约**：`POST /api/ops/chat/stream`（后端 `app/ops/chat/sse.py`，模型注释引 `OpsRunEvent`）；`ChatService.swift:22` 还是 TODO「实现 SSE 字节流解析」。
- **新契约真源（后端 lg-rag）**：路由 `app/ops/lg_rag/router.py`、帧生成 `app/ops/lg_rag/sse_stream.py`、审批 `app/ops/hitl/router.py`。帧分类法可读 `ops-desk-workspace/docs/08-interview/11_five-stage-supervisor-flow-script_v1_zh.md` §3（11 类帧清单）。
- web 端同契约实现可对照（只读参照）：`ops-desk-web/src/composables/useLgRagSse.ts`、`src/api/hitl.ts`、`src/components/chat/HitlApprovalCard.vue`。

## 3. 你的第一个动作：契约考古 task（T0）

在拆实现 task 之前，先产出《iOS lg-rag 客户端契约冻结表》（落 `docs/`），逐键对齐后端、**不自造字段**。必须考古确认的项：

1. 认证：登录端点与会话保持（ops auth，对照 AuthService 现状判断复用/改造）。
2. run 发起：lg-rag 流式端点的精确路径/方法/请求体（thread_id、query、模式等），从 `router.py`+`sse_stream.py` 读真值。
3. SSE 帧全清单：11 类帧（run.start/plan/node.progress/subtask.progress/answer/hitl.waiting/done/error/keepalive 等）逐帧字段表；keepalive 不落盘只保活；error 帧带 `stage` 字段须展示定位。
4. HITL：hitl.waiting 帧字段（approval_id+快照）→ decide/resume 两端点；**两步钉死**（decide≠自动 resume）；`resume_mode` 三值 inherit（默认不送键）/immediate/manual，禁第四值；仅本人 owner；TTL 3600s。
5. replay：`POST /api/ops/lg-rag/replay`（run_id+after_seq 或 cursor）；**在飞 409 + Retry-After: 2** 须退避重试，沉降后同请求零 diff。
6. degraded_* 标记注入最终答案的展示口径。

## 4. 实现 task 拆分建议（T0 完成后按需调整）

| Task | 内容 | 验收要点 |
|---|---|---|
| T1 契约层 | 新帧模型族 + SSE 解析器（可复用 NetworkClient 字节流，替换 ChatService TODO） | 11 类帧全解码单测；旧 chat/stream 模型隔离不混用 |
| T2 对话主链路 | 发 run + 帧流驱动 ChatView 状态机（计划/子任务进度/答案流式/done/error 带 stage） | 模拟器对本地后端跑通一发 run |
| T3 HITL 审批 | hitl.waiting 帧→审批卡片（快照只读展示、批准/驳回二次确认、resume_mode 三选、显式续跑） | 与 web 审批页互调剧本跑通（iOS 发起→web 批→iOS 续看） |
| T4 断线续看 | SSE 断开→replay 接回（409 退避）；App 退后台回前台的恢复策略 | 断网/杀进程两类场景手测 |
| T5 历史会话 | 线程列表+turns 加载；等后端 #18（turns.run_id）落地后挂「查看执行过程」入口 | 历史会话可回看 |

## 5. 硬约束

- 后端零改动；契约只消费不自造（字段、resume_mode 值、帧类型均如此）。
- 旧 `chat/stream` 链路不删不改，新链路独立成层，灰度切换另立 task。
- 每个 task 走完整 Harness：建 task → GATE_VERIFY → 分支 → PR；T0 契约表需评审后再进 T1。
- 审批 UI 与 web 端同语义零分叉（对照 HitlApprovalCard 的三选与两步链）。

## 6. 你的首轮交付

1. T0 契约冻结表（docs/ 落盘）+ T1-T5 task 文件；2. 每个实现 task 的子 agent 委派 Prompt；3. 总排期建议。全部落盘后向维护者汇报，等闸再推进。