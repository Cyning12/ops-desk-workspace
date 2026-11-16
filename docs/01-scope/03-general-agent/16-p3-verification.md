# 16 · P3 验证假设「给目标、等交付」验收记录（P3-T11 · 2026-11-17 凌晨 · exec-p3-t11）

> **验收对象**：14 §7 验证假设——用户给目标、agent 定时交付，三样例一次跑完。
> **设计真源**：14 §7（判据/三级裁定/失败处置）· 契约 15。
> **执行环境**：api 仓终态 master 396f7fed（起点 600dd6cd + 波内小修 PR #433）· 本地 PG opsdesk（alembic head 含 20261116_ops_schedules 双表）· uvicorn :8017（OPS_SCHEDULE_ENABLED=on · tick=5s · schedule/write 双 manifest · GOAL_INJECT_ENABLED=true）· seed 承 P2a-T4 先例（直写 PG 铸 maintainer 邀请码 → 登录 p3t11 / tenant=ops-desk-pilot）· 真 SiliconFlow · 服务用后已杀。
> **长日志**：/tmp/opsdesk-rfc/p3-t11-exec.md。

## 三级裁定：**部分成立**（工程判据全过 · S1①②③ web 数据面验收过 · 缺口限枚举内 (b)(d)(e)）

- 工程判据：S1/S2/S3 全部判据实测通过（逐条证据见下表一）。
- S1 ④ goal_injected span 因 Langfuse OTLP 403（R-P3-6 密钥债未换）不可录——按 14 §7 允许的「录制替代+降级标注」处理：以 ops_goals DB 行（goal_id=6b408f2c status=active）替代，如实降级标注。
- 枚举内缺口（14 §7 清单）：
  - **(b) 徽标可见性缺陷（新实例 · 清单内登记）**：worker-fired run 不实体化 ops_lg_rag_threads 行 → runs 端点对该 thread 404「Thread not found」→ **用户不在场时任务卡片面不可见**。现场消化（向 thread 发一条消息后实体化，徽标/归因随即正确）但实现缺陷成立，待修（建议立 issue）。
  - **(d) 用户不在场+run error 无感知面**：本波既定已知缺口（R18/S-e），S1 fired run 内 planner 试图再建 schedule 被步预算拦下等异常无任何感知面，实证该缺口存在。
  - **(e) 移动端审批/交付缺位**：T10 iOS 人签未落地，S2 按 Q5 既定降级改判 web 单端，如实登记。
- 无清单外新缺口 → 不触发升级复议；未触发「大缺陷降级」失败处置。S1 暴露的 user_id 缺陷判定波内可修（小修），已走 fix 分支+PR #433 合入（见下）。

## 表一 · 验证假设三样例逐判据

### S1 定时交付全链 —— **过**

| 环节 | 证据 |
|---|---|
| 对话化创建 | thread=p3t11-s1-20261117 · query 嘱 args 必须 JSON object → run 626f50bf → hitl.waiting（hitl_f6c591ac/38610720/3a9e83ff · blocked_by=delegation_issue_hitl_required）→ web 批准×3（resume_mode=immediate auto_triggered）→ hitl.resumed → 00:57:17 token_verified → ops_schedules 落行 **f95589cc-958b-4a3d-81dc-3f7f805c3af0「晨间巡检」active interval=300s**。委派 enforce 模式下 planner 三次 replan 三次出卡才落笔（体验偏差登记 · 非判据） |
| 到点 fire | fires 台账 id=298a7ee6 status=fired planned=01:02:17 run_id=d73acca9 非空 ✓ · fire_count=1 · next_fire_at 推进 01:07:17 ✓ |
| ① 消息流 | GET /api/ops/chat/threads/{tid}/history → user turn「[定时任务 · 晨间巡检] 汇总昨日 issue 变更并给出风险点」+ Agent answer（answer_truncated=false）✓ |
| ② 任务卡片数据面 | GET runs 端点 → fired run status=done 带 schedule_attribution={schedule_id:f95589cc, name:晨间巡检, fire_id:298a7ee6}；对话 run attribution=null ✓ |
| ③ 回放 | GET events 端点 → 374 帧 run.start→node.progress→answer×368→done 完整时间线 ✓ |
| ④ goal chip | ops_goals 行 active ✓；goal_injected=1 span 降级（langfuse 403 · R-P3-6 · DB 行替代+标注）✓ |
| 终态 | run d73acca9 status=done ✓ · 未落库多余 schedule（sanity 核实）✓ |

### S2 定时 HITL 链 —— **过**（web 单端 · iOS 缺位按 Q5 登记）

| 环节 | 证据 |
|---|---|
| 定时触发含写类 capability | schedule f85824ea「定时审计便签」interval=300s → 首 fire 00:22:45（fire ae93bc9b → run ea3a800a）· run.start query 前缀「[定时任务 · 定时审计便签]」· planner 产出 ops.write.run_note 子任务（args=JSON object）|
| HITL 卡出现 | seq5 hitl.waiting（hitl_e9fbecbf · blocked_by=delegation_issue_hitl_required）✓ |
| web 批准 → 执行完成 | decide approved（resume_mode=immediate · auto_triggered=true）→ seq7 hitl.resumed → seq11 subtask.progress done → **ops_capability_notes 落行 aaa65af6**（idempotency_key=req_audit_note_p3t11s2）→ run 达终态 status=resumed ✓ |
| 徽标 | 两个 fired run 各带 schedule_attribution；对话 run null ✓ |
| iOS 缺位 | T10 人签未落地 → Q5 降级 web 单端 · 如实登记（非掩饰口径）|

### S3 停跨时点补跑幂等 —— **过**

| 环节 | 证据 |
|---|---|
| 停服跨 ≥2 时点 | schedule 937fd11c「停机补跑验证」interval=300s catchup=fire_once · 01:09:22 停服 → 01:16:14 重启，错过 **01:10:03 与 01:15:03 两个时点** ✓ |
| 重启 30s 内补跑 | 01:16:15.954（重启后 2s · worker tick）fire 85e97365 → run 09cfd79b ✓ |
| 仅补一次 + uq 幂等 | 补跑后 fires 行恰增 1 条（planned=01:10:03；01:15:03 不建行=fire_once）；此后 tick 每 5s 持续，**同 planned_fire_at 零重复行**（uq_ops_schedule_fires_planned 实证）✓ |
| next_fire_at 推进未来 | 01:21:15 > 重启时刻 ✓ |
| fires.run_id 非空且 run 终态 | run 09cfd79b status=done ✓（441 帧回放可拉）|
| 附带实证 | 首次停机窗（01:05:12–01:08:40 · 错过 1 点）补跑同样仅 1 行；S1 schedule 停机期间的错过点亦按 fire_once 各补 1 次 |

## 表二 · 治理放量结果汇总（引用 T5/T6/T7 三单终报 · lead 会话留存）

| 单 | 合并 | 结果 | 偏差 |
|---|---|---|---|
| **T5 admin memory 端点** | feat #422 squash 0ab54c7b · CLOSE #423 e83537a9 | 三端点 app/ops/admin/memory.py：GET /facts（keyset 分页 50/200 · 十二字段投影无 embedding）· POST /facts/{key}/revoke（幂等 200 affected=0/N · 审计不记 value）· GET /episodes 只读。AdminSyncAuth 跨租户运维面（viewer 403）。**23 用例真 PG 绿** | 无 |
| **T6 幂等转正** | feat #428 squash d2785471 · CLOSE #429 ac968901 | persistence.py:39 未设/空串 null→db 现役转正（显式 null 回退保留）。R9 四条件全落（docstring 部署动作声明 · env 四分回归矩阵 · fail-closed 回归 · 风险登记 R-P3-10）。**42 用例真 PG 绿** | D1：契约 15 §7.3 与 14 终稿矛盾照 14 落地，15 文已和解（workspace b85ae90）|
| **T7 summaries 放量** | feat #430 squash 8569fa0e · CLOSE #431 600dd6cd | 纯 env 放量零代码。对拍 40 轮：off −82.6% → on **−51.1%/−51.3%（≥50% 达标）**。缓存复核二跑零 LLM 调用逐字节一致。降级实证：chunk 超时维持占位不缓存。抽检实体全保留 | 限制：L1 无 per-tenant · L2 压缩率随轮长漂移快照不承诺复现；master flake test_tc_b1_replay_after_disconnect_includes_tail 已立 issue #432 |

## 波内失败处置记录

- **S1 创建链暴露实现缺陷（波内可修 · 已修）**：ops.schedule.create 对话化创建 HITL 批准后必败 PermissionError('user_scope_missing')。根因两层：① LgRagState 无 user_id 字段+graph.py payload 不携带（9b07fe37）；② resume 后 route_next_subtask Send 载荷=_worker_state 手工子集不含 user_id → 委派签发侧/验签侧 subject_mismatch（d3b5f45 · 照 run_id 先例）。合 **PR #433**（CI 4 绿）squash 合入 master **396f7fed**；修复后全链实证闭环（token_verified → schedule 落库）。
- 未触发「大缺陷登记+降级裁定」路径。

## 偏差清单

1. **(b) 实例**：worker-fired run 不实体化 ops_lg_rag_threads 行 → runs 端点 404 → 用户不在场时任务卡片不可见（待修 · 建议立 issue）。
2. **(e) iOS 审批缺位**：Q5 既定降级 web 单端（T10 未落地）。
3. **S1④ span 降级**：Langfuse OTLP 403（R-P3-6 密钥债未换）→ goal_injected=1 不可录 · DB goal 行替代+标注。
4. **委派 enforce 模式创建体验**：同一 capability 三次 replan 三次 HITL 才落笔（:4/:5/:6）· 非判据 · 体验登记。
5. **resume 报错文案误标**：decide auto resume 已消费 interrupt 后手动重试 resume 报「无 interrupt 元数据/旧格式 checkpoint」（app/ops/hitl/resume.py:240-252）——对已恢复场景误标。
6. **planner 字面量**：S2 子任务 args run_id='current_run_id' 字面量（非真 run_id）· LLM 质量偏差 · 便签落库不受影响。
7. **fired run 内越界企图**：S1 fired run planner 试图再调 ops.schedule.create 被步预算拦下（未落库多余行）· LLM 行为非链路缺陷。
8. **操作偏差**：S3 REST 创建响应包络=data.schedule 解析误判致重复建一张（72b65fc0 · 已 paused）。
9. **master flake**（T7 附带登记）：test_tc_b1_replay_after_disconnect_includes_tail · issue #432 跟踪。
