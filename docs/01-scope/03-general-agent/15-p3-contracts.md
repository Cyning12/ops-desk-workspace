# P3 契约文档 — Schedule REST · create_schedule capability · runs/events 只读 · fires 台账 · admin memory · device_tokens 草案 · 总闸环境

> **状态**：v1 终稿（P3-T1 落盘） · 2026-11-16
> **设计真源**：[14-p3-schedule-taskcard-design.md](14-p3-schedule-taskcard-design.md)（R1-R23 全关闭 · 全部裁定以 14 文为准）
> **本文定位**：P3 后续任务单 T2/T2b/T3/T4/T5/T8 各仓实施的**共同契约面**。端点 schema、字段词表、错误文案、闸链纪律以本文为准；本文与 14 文冲突处 → 14 文优先（14 文修订需走 R 轮重开）。
> **体例**：承 `docs/contracts/` 既有契约档（chat-stream-v1.md / admin-sync-v1.md）端点体例 + 14 文裁定措辞；每个端点附 curl 示例。
> **红线**：SSE 零新帧 · freeze 契约零修订 · 全部新 DDL 含 `tenant_id` · 跨租户 404。

---

## §0 词表总表（四值词表 · 状态投影 · 事件白名单）

| 词表 | 取值 | 说明 |
|---|---|---|
| `schedule_kind` | `once_at` / `interval` / `daily_at` | 三种排期模式；词表外 → 422 |
| `schedule.status` | `active` / `paused` / `cancelled` | `active↔paused` 人工 PATCH 互转；`cancelled` 终态不可逆 |
| `catchup_policy` | `fire_once` | 停机期间错过点火恢复后只补一次；词表留 `skip` 位 v1 不实现 |
| `fires.status` | `claimed` / `fired` / `skipped` / `failed` | 状态机见 §4.1 |
| `runs.status`（六词表） | `running` / `waiting_approval` / `done` / `error` / `disconnected` / `resumed` | 卡片态投影见 §3.1 |
| `facts.status` | `active` / `superseded` / `revoked` / `expired` | 既有 models.py CHECK |
| `facts.kind` | `fact` / `preference` | 既有 CHECK |
| `episodes.status` / `episodes.outcome` | `active` / `revoked` · `success` / `failure` / `partial` | 既有 CHECK |
| `event_type` 白名单（8 值） | `run.start` / `answer` / `subtask.progress` / `node.progress` / `hitl.waiting` / `done` / `error` / `hitl.resumed` | = freeze 客户端词表（核实结论见 §3.3） |

**runs.status → 卡片视觉态映射**（三端一致 · T4 web 投影依此）：

| status | 卡片态 | Element Plus type | 行为 |
|---|---|---|---|
| `running` | 进行中 | primary + 转圈 | — |
| `waiting_approval` | 待审批 | warning | 点击锚定滚动至 hitl 审批卡 |
| `done` | 已完成 | success | 可回放 |
| `error` | 失败 | danger | — |
| `disconnected` | 中断 | info | 可续看 |
| `resumed` | 已恢复 | success（浅） | 可回放 |

---

## §1 Schedule REST 契约（api T2）

### 1.1 端点总表

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/ops/schedules` | CurrentUser | 创建定时任务 |
| GET | `/api/ops/schedules?thread_id=` | CurrentUser | 当前用户 schedule 列表（可按 thread 过滤） |
| GET | `/api/ops/schedules/{schedule_id}` | CurrentUser | 单条详情（含最近 10 条 fires） |
| PATCH | `/api/ops/schedules/{schedule_id}` | CurrentUser | 暂停/恢复/取消 + 改排期（重算 `next_fire_at`） |

统一响应壳承既有约定：`{"ok": true, "data": ...}`；错误 `{"detail": "..."}`。

### 1.2 schedule 响应对象（数据模型投影）

| 字段 | 类型 | 说明 |
|---|---|---|
| `schedule_id` | uuid | 主键 |
| `tenant_id` | string(64) | 租户（路由谓词，不暴露他租） |
| `user_id` | uuid | 创建者（归属谓词） |
| `thread_id` | string(255) | 归属对话窗（无 FK · fire 时不存在则自建） |
| `name` | string(120) | 任务名 |
| `instruction` | text | 执行指令（写入前单行化：折叠换行为空格） |
| `schedule_kind` | enum | `once_at` / `interval` / `daily_at` |
| `run_at` | timestamptz · null | once_at 专用 |
| `interval_seconds` | int · null | interval 专用 · **≥300** |
| `time_of_day` | string(5) · null | daily_at 专用 · `"HH:MM"` |
| `timezone` | string(64) | IANA 时区 · 默认 `Asia/Shanghai`（v1 不随 DST 校准，边界注释钉明） |
| `next_fire_at` | timestamptz | 下次点火时刻（索引 `idx_ops_schedules_next_fire(status, next_fire_at)`） |
| `catchup_policy` | enum | v1 仅 `fire_once` |
| `status` | enum | `active` / `paused` / `cancelled` |
| `fire_count` | int | 已点火次数 |
| `max_fires` | int · null | 上限；空 = 不限；`once_at` 等价 `max_fires=1` |
| `last_fired_at` | timestamptz · null | 最近点火 |
| `created_at` / `updated_at` | timestamptz | — |
| `humanized_display` | string | 人类化频率文案（见 §1.8） |

### 1.3 POST /api/ops/schedules — 创建

**请求体**（`additionalProperties: false`）：

| 字段 | 类型 | 必填 | 校验 |
|---|---|---|---|
| `thread_id` | string(255) | 是 | 归属校验见 §1.7 |
| `name` | string(1..120) | 是 | — |
| `instruction` | string | 是 | 单行化 |
| `schedule_kind` | enum | 是 | 词表外 → 422 |
| `run_at` | timestamptz | once_at 必填 | 须未来时刻 |
| `interval_seconds` | int | interval 必填 | ≥300 → 否则 422 |
| `time_of_day` | string(5) | daily_at 必填 | `HH:MM` 24h |
| `timezone` | string(64) | 否 | IANA；默认 `Asia/Shanghai` |
| `max_fires` | int ≥1 | 否 | 空 = 不限 |

**创建语义**：创建即按 kind 计算 `next_fire_at`（once_at→`run_at`；interval→`now+interval_seconds`；daily_at→时区内下一个 `time_of_day` 时刻）· `status=active` · `fire_count=0`。双上限校验（§1.8）通过才落库。

**响应 201**：`{"ok": true, "data": {"schedule": {…§1.2 全字段…}}}`

```bash
curl -X POST https://<host>/api/ops/schedules \
  -H 'Content-Type: application/json' \
  -H 'Cookie: ops_session=<session>' \
  -d '{
    "thread_id": "t-ops-001",
    "name": "每日晨检",
    "instruction": "汇总昨日错误日志并给出处置建议",
    "schedule_kind": "daily_at",
    "time_of_day": "08:30",
    "timezone": "Asia/Shanghai"
  }'
```

### 1.4 GET /api/ops/schedules — 列表

- 谓词：`tenant_id == user.tenant_id AND user_id == user.id`（仅本人）。
- query：`thread_id`（可选过滤）；`status`（可选 · 词表校验）。
- v1 不分页（per-user 上限 20 天然有界 · product 盲点5）。

**响应 200**：`{"ok": true, "data": {"schedules": […]}}`

```bash
curl 'https://<host>/api/ops/schedules?thread_id=t-ops-001' \
  -H 'Cookie: ops_session=<session>'
```

### 1.5 GET /api/ops/schedules/{schedule_id} — 单条详情

- 跨 tenant / 跨 user / 不存在 → **404**（不泄露存在性）。
- 响应附 `recent_fires`：该 schedule 最近 10 条 fires（`id` / `planned_fire_at` / `run_id` / `status` / `fired_at` 倒序）。

**响应 200**：`{"ok": true, "data": {"schedule": {…}, "recent_fires": […]}}`

```bash
curl 'https://<host>/api/ops/schedules/9b2e…' \
  -H 'Cookie: ops_session=<session>'
```

### 1.6 PATCH /api/ops/schedules/{schedule_id} — 状态机 + 改排期

**请求体**（全部可选 · 至少一项）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `status` | `active` / `paused` / `cancelled` | `active↔paused` 互转；`cancelled` 终态不可逆（已 cancelled 再 PATCH → 422） |
| `name` / `instruction` | string | 同 POST 校验 |
| `run_at` / `interval_seconds` / `time_of_day` / `timezone` / `max_fires` | 同 POST | 任一排期字段变更 → **重算 `next_fire_at`**（重算守卫 N5） |

**响应 200**：`{"ok": true, "data": {"schedule": {…更新后全字段…}}}`

```bash
curl -X PATCH 'https://<host>/api/ops/schedules/9b2e…' \
  -H 'Content-Type: application/json' \
  -H 'Cookie: ops_session=<session>' \
  -d '{"status": "paused"}'
```

### 1.7 归属校验语义（R6）

1. **schedule 本体**：所有端点谓词 `tenant_id == 当前租户 AND user_id == 当前用户`；不满足 → 404（跨 tenant/跨 user/不存在同码，不泄露存在性）。
2. **thread 归属**：创建 / PATCH 时若 `thread_id` 对应 thread **存在**，须 `thread_owner == creator`，否则 **422 零写**；thread **不存在则允许**（fire 时由 worker 自建）。
3. **worker 点火前复核**：fire 时 thread 已存在且 owner 易主（非 schedule.user_id）→ 不建 run，`fires.status=failed` + 审计留痕。

失败路径对照（14 §11）：词表外值 → 422 · 跨 tenant → 404 · 非 thread_owner → 422（零写）。

### 1.8 双上限与人类化错误文案词表（R4 · product 盲点5 · R20）

**配额**：per-user `status=active` ≤ **20** 枚；per-tenant 全量 ≤ **200** 枚。`interval_seconds` ≥ **300**（once_at / daily_at 无下限）。

**422 错误文案词表**（`detail` 字段逐字使用 · 前端不做二次包装）：

| 场景 | detail 文案 |
|---|---|
| per-user 超限 | `本会话定时任务已达上限（20 个），请先暂停或取消不用的任务` |
| per-tenant 超限 | `本租户定时任务已达上限（200 个），请联系管理员暂停或取消不用的任务` |
| interval < 300 | `定时任务间隔不能小于 300 秒（5 分钟）` |
| 词表外 kind | `非法的 schedule_kind（允许值：once_at / interval / daily_at）` |
| 词表外 status | `非法的 status（允许值：active / paused / cancelled）` |
| 非 thread_owner | `该对话不属于当前用户，无法创建定时任务` |
| 已 cancelled 再改 | `已取消的定时任务不可修改` |

**人类化频率文案**（`humanized_display` 字段 · 卡片/列表展示用）：

| kind | 模板 | 示例 |
|---|---|---|
| `once_at` | `将于 {YYYY-MM-DD HH:mm}（{时区中文名}）执行一次` | `将于 2026-11-20 09:00（北京时间）执行一次` |
| `interval` | `每 {N} 分钟`（≥60 分钟显示 `每 {N} 小时`） | `每 30 分钟` |
| `daily_at` | `每天 {HH:MM}（{时区中文名}）` | `每天 08:30（北京时间）` |

时区中文名映射 v1 仅收 `Asia/Shanghai→北京时间`；其余 IANA 时区回退展示原名。

---

## §2 create_schedule capability 契约（api T2b）

### 2.1 manifest 条目草案（新文件 `app/ops/capability/manifests/ops.schedule.v1.yaml`）

```yaml
version: 1
capabilities:
  - id: ops.schedule.create
    kind: local_fn
    description: 创建定时任务（schedule），到点自动在指定对话窗发起一轮 ops run
    when_to_use: 用户要求"每天/每小时/定时/稍后自动执行"某运维查询或操作时
    when_not_to_use: 一次性立即执行的请求（直接用既有 ops.* 工具）；用户未明确同意未来自动执行
    tags: [schedule, write]
    risk_level: medium          # 闸面由 W1 HITL 承担；不触发 deny_high_risk（该层永不豁免）
    side_effect: write
    enabled: true
    tenant_scoped: true
    hitl:
      required: true            # W1 确认卡 · 见 §2.3
      snapshot_fields: [thread_id, name, instruction, schedule_kind, run_at, interval_seconds, time_of_day, timezone, max_fires]
    idempotency_key: "{{request_id}}"   # V1 幂等键 · 承既有闸链
    args_schema:
      type: object
      properties:
        thread_id:        { type: string, maxLength: 255 }
        name:             { type: string, minLength: 1, maxLength: 120 }
        instruction:      { type: string, minLength: 1 }
        schedule_kind:    { type: string, enum: [once_at, interval, daily_at] }
        run_at:           { type: string, format: date-time }
        interval_seconds: { type: integer, minimum: 300 }
        time_of_day:      { type: string, pattern: "^([01]\d|2[0-3]):[0-5]\d$" }
        timezone:         { type: string, maxLength: 64, default: "Asia/Shanghai" }
        max_fires:        { type: integer, minimum: 1 }
      required: [thread_id, name, instruction, schedule_kind]
      additionalProperties: false
    output_fields: [schedule_id, next_fire_at, status, humanized_display]
    output_schema:
      type: object
      properties:
        schedule_id:       { type: string, format: uuid }
        next_fire_at:      { type: string, format: date-time }
        status:            { type: string, enum: [active] }
        humanized_display: { type: string }
      required: [schedule_id, next_fire_at, status]
      additionalProperties: false
    reversible: true              # 可逆路径 = PATCH status=cancelled
    execution_type: instant
    max_reversal_latency: 0
    requires_stop_support: false
    adapter:
      local_fn: app.ops.schedule.service.create_schedule_from_capability
```

### 2.2 加载与放行纪律（承既有写类 manifest 先例）

1. **不进默认加载面**：部署侧经 `OPS_CAPABILITY_EXTRA_MANIFESTS` 显式加载 `ops.schedule.v1.yaml`。
2. **deny_write 放行**：`OPS_CAPABILITY_ALLOW_WRITE_TAGS=schedule`（逗号分隔 tag 词表 · 只豁免 deny_write 一层）。
3. **deny_high_risk 永不豁免**：本条 `risk_level=medium`，不触发该层；不得为其开启 `OPS_CAPABILITY_ALLOW_HIGH_RISK`。
4. 既有闸链全保留：registry → policy（baseline 词表）→ 参数 schema 校验 → V1 幂等键 → HITL → 执行。

### 2.3 HITL W1 确认卡

- 复用既有 `HitlApprovalCard`（web 零改动 · freeze 帧 `hitl.waiting` 不变）。
- 卡面标题钉死：**「创建定时任务 = 承诺未来 LLM 花费」**。
- 卡面正文投影 `snapshot_fields`：任务名 / `humanized_display` 频率文案 / instruction 摘要 / 目标 thread。
- 用户点「拒绝」→ capability 返回 `hitl_rejected`，零写。

### 2.4 HITL 通过后执行语义

1. 执行体**直调 T2 schedule store**（与 §1 REST 同一套归属校验 + 双上限 + 词表校验，不复制逻辑）。
2. 幂等：`idempotency_key={{request_id}}` 经 DbIdempotencyStore（§7.3 装配后）防重；同键重放返回首执收据。
3. 成功 → 返回 §2.1 `output_fields`；配额/校验失败 → 抛 §1.8 同款 422 文案（Agent 把 detail 原文转述给用户，不改写）。
4. 创建后的点火由 T3 worker 产生 fires（§4）；capability 本身不直接发 run。

---

## §3 runs / events 只读端点契约（api T4 · 任务卡片数据源）

### 3.1 GET /api/ops/lg-rag/threads/{thread_id}/runs — 单 thread run 列表

- **鉴权**：CurrentUser；`thread_owner == 当前用户`，否则 **404**（跨用户/未知同码 · 不泄露存在性）。admin 越权读面 v1 不开。
- **分页**：keyset（`created_at desc, run_id`）· `limit` 默认 20 · **上限 50/页**（R-P3-8）超限 422 · `cursor` max_length=512。
- **响应投影字段**（任务卡片所需清单）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `run_id` | string(64) | 主键 |
| `thread_id` | string(255) | — |
| `status` | enum | 六词表（§0）；卡片态映射三端依 §0 表 |
| `created_at` / `finished_at` | timestamptz · null | — |
| `query_summary` | string | 用户 query / schedule instruction 摘要，截 **80** 字符（TITLE_MAX_CHARS=80） |
| `schedule_attribution` | object · null | 定时归因徽标：`{schedule_id, name, fire_id}`；**由 fires.run_id IN 批量反查**（防 N+1）；无归因（手动发起）→ null |

**响应 200**：

```json
{
  "ok": true,
  "data": {
    "runs": [
      {
        "run_id": "run-…",
        "thread_id": "t-ops-001",
        "status": "waiting_approval",
        "created_at": "2026-11-16T08:30:00+08:00",
        "finished_at": null,
        "query_summary": "[定时任务 · 每日晨检] 汇总昨日错误日志并给出处置建议",
        "schedule_attribution": { "schedule_id": "9b2e…", "name": "每日晨检", "fire_id": "f-…" }
      }
    ],
    "next_cursor": "eyJ…"
  }
}
```

```bash
curl 'https://<host>/api/ops/lg-rag/threads/t-ops-001/runs?limit=20' \
  -H 'Cookie: ops_session=<session>'
```

### 3.2 GET /api/ops/lg-rag/runs/{run_id}/events — run 事件帧（轨迹回放数据源）

- **鉴权**：CurrentUser；`assert_run_owned(run_id, user_id)` 前置（承 event_store.py:361 语义），跨用户/未知 → **404**。
- **event_type 白名单过滤**：仅返回 §0 白名单 8 值；白名单外（防御性 · 理论不落盘）直接滤除，不报错——前置防泄。
- **截断**：单次最多返回 **500 帧**；超出 → `truncated: true` + `next_after_seq`（客户端按 seq 续拉）。
- query：`after_seq`（可选 · 增量拉取起点）。
- payload 结构承 freeze 契约（ops-desk-ios `docs/lg-rag-contract-freeze_v1_zh.md` §3），本文不重复定义；本文只钉白名单与分页。

**响应 200**：

```json
{
  "ok": true,
  "data": {
    "run_id": "run-…",
    "events": [
      { "seq": 1, "event_type": "run.start", "payload": {}, "created_at": "…" },
      { "seq": 2, "event_type": "answer", "payload": { "delta": "…" }, "created_at": "…" }
    ],
    "truncated": false,
    "next_after_seq": null
  }
}
```

```bash
curl 'https://<host>/api/ops/lg-rag/runs/run-…/events?after_seq=0' \
  -H 'Cookie: ops_session=<session>'
```

### 3.3 核实结论登记（R5 · 落库词表 = freeze 客户端词表）

已枚举 api 仓全部落库 emit 点核实：现落库 `event_type` 词表恰 = freeze 客户端词表 8 值（`run.start` / `answer`（含 token delta `{delta}` 帧与整段终帧）/ `subtask.progress` / `node.progress` / `hitl.waiting` / `done` / `error` / `hitl.resumed`）；`keepalive` 为 SSE 注释行不落盘；`progress_stream.py` docstring 钉死「禁止新增 event_type」。**结论：无需逐 payload 脱敏；§3.2 白名单过滤为前置防泄层，而非词表差异修补。** run_store.py:29 docstring 出现的 token/thought 字样仅历史示例，非现词表。

---

## §4 fires 台账语义（api T2 建表 · T3 worker 写入）

### 4.1 ops_schedule_fires 表结构与状态机

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | uuid pk | fire 行主键（fire_id） |
| `schedule_id` | uuid | 无 FK（schedule 删除不级联 · 台账保留） |
| `tenant_id` | string(64) | 冗余租户谓词 |
| `planned_fire_at` | timestamptz | 计划点火时刻 |
| `run_id` | string(64) · null · **加索引** | 写回才算 fired；索引供 `run_ids IN` 批量反查（§3.1 归因 · 防 N+1） |
| `status` | enum | `claimed` / `fired` / `skipped` / `failed` |
| `fired_at` | timestamptz · null | 实际点火时刻 |

幂等键：部分唯一索引 `uq_ops_schedule_fires_planned(schedule_id, planned_fire_at)`。

**状态机**：

```
claimed ──run 创建成功·写回 run_id──► fired
claimed ──thread 外来/校验失败──────► failed   （审计留痕）
claimed ──schedule 已 paused/cancelled 或已达 max_fires──► skipped
```

### 4.2 写入纪律

1. worker tick 扫描 `status=active AND next_fire_at <= now`（走 `idx_ops_schedules_next_fire`）。
2. **INSERT fires (schedule_id, planned_fire_at, status=claimed) ON CONFLICT (schedule_id, planned_fire_at) DO NOTHING**；影响行 = 0 → 该计划时刻已被占，跳过（天然幂等 · 多实例安全）。
3. 占位成功 → 创建 lg-rag run；**run 创建成功并 UPDATE fires SET run_id=…, status='fired', fired_at=now() 才算 fired**。
4. run 创建失败 → `status='failed'` + 审计。

### 4.3 启动补链（R10）

lifespan 首轮对 `status='claimed' AND run_id IS NULL` 且超时的 fires 行**按台账重放触发**（承 auto_resume `scan_orphan` 模式）：补建 run 并写回，或标记 failed。补链只信台账，不信内存态。

### 4.4 归因真源声明（R12 · SP2）

> **「[定时任务 · {name}]」query 前缀文本仅展示用途，非归因依据、非鉴权依据。唯一定时归因真源 = fires 台账三元组（schedule_id, fire_id, run_id）。** worker 每次点火写审计日志含该三元组；§3.1 的 `schedule_attribution` 投影由 `fires.run_id` 反查得出，与 query 文本无关。任何凭前缀文本做权限/归因判断的实现视为契约违背。

---

## §5 admin memory 端点契约（api T5）

### 5.1 admin 面 = 跨租户运维面（R7 钉死）

> **/api/ops/admin/* 是跨租户运维面**：鉴权 = `AdminSyncAuth`（机器 Bearer `OPS_ADMIN_SYNC_TOKEN` **或** maintainer cookie）；`OpsUser.role` 的 `maintainer` 是**全局角色，无租户绑定**。`tenant_id` / `user_id` 一律**显式传入**而非会话推导。Bearer 优先（token 空则 Bearer 路径禁用 · 带 Bearer 一律 401 · `secrets.compare_digest` · token 禁入日志）；cookie 用户非 maintainer → 403「Maintainer role required」。审计 `logger.info` 记动作（tenant/user/key/affected）**不记内容**。`/admin/memory` 页 = maintainer 可达，**不是租户管理员面**。与 F4 原则的关系按「运维面例外」登记：见 [03-security-audit.md](03-security-audit.md) §4 第 6 条（purge 同缺口 SP3 登记 · 本波不收紧）。

### 5.2 GET /api/ops/admin/memory/facts — facts 分页浏览

- query：`tenant_id`（必填）· `user_id`（可选）· `status`（默认 `active` · 词表校验）· `kind`（可选）· `limit`（默认 50 · 上限 200 · T1 钉值：admin 浏览面密度高于用户面）· `cursor`（keyset · max_length=512）。
- 投影字段：`id` / `tenant_id` / `user_id` / `key` / `value` / `kind` / `source_run_id` / `source_turn` / `status` / `expires_at` / `created_at` / `updated_at`（**不含 `embedding`**）。

**响应 200**：`{"ok": true, "data": {"facts": […], "next_cursor": "…" | null}}`

```bash
curl 'https://<host>/api/ops/admin/memory/facts?tenant_id=acme&status=active&limit=50' \
  -H 'Authorization: Bearer <OPS_ADMIN_SYNC_TOKEN>'
```

### 5.3 POST /api/ops/admin/memory/facts/{key}/revoke — 撤销（幂等）

- **复用 `service.py:168 revoke_by_key` 语义**：`UPDATE facts SET status='revoked' WHERE tenant_id/user_id/key AND status='active'`（只动 active 行 ⇒ 天然幂等）。
- 路径携带 `key`；body 显式传 `{"tenant_id": "…", "user_id": "…"}`（user_id 可选 · 缺省对该 tenant 下所有用户同 key 生效——慎用 · 14 §4 承 revoke_by_key 签名）。
- **幂等响应**：已撤销 / 无匹配 → **200 `{"ok": true, "data": {"affected": 0}}`**（不报错）；成功 → 200 `affected: N`。审计 `logger.info` 记 key/tenant/affected。

```bash
curl -X POST 'https://<host>/api/ops/admin/memory/facts/deploy.window/revoke' \
  -H 'Authorization: Bearer <OPS_ADMIN_SYNC_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{"tenant_id": "acme", "user_id": "7c1e…"}'
```

### 5.4 GET /api/ops/admin/memory/episodes — episodes 只读浏览

- query：`tenant_id`（必填）· `run_id` / `status` / `outcome`（可选 · 词表校验）· `limit` / `cursor`（同 §5.2）。
- 投影字段：`id` / `tenant_id` / `run_id` / `task_domain` / `context_fingerprint` / `plan_summary` / `tool_sequence` / `outcome` / `failure_class` / `status` / `created_at`。
- **只读**：单条 revoke 不做（N2）。

```bash
curl 'https://<host>/api/ops/admin/memory/episodes?tenant_id=acme&outcome=failure' \
  -H 'Authorization: Bearer <OPS_ADMIN_SYNC_TOKEN>'
```

---

## §6 APNs device_tokens 契约草案（R3 · 纯文档 · 实施顺移）

> **顺移声明**：本节为草案，**本波（P3 T1-T11）不实施**。实施顺移至 Swift 推送代码落地波；届时**表 DDL + 端点 + 发送管线一个 PR 收口**。本波不做：APNs provider 配置 / 证书管理 / Swift 端代码 / 发送 worker。

### 6.1 ops_device_tokens 表结构草案

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | uuid pk | — |
| `tenant_id` | string(64) not null | 租户谓词 |
| `user_id` | uuid FK → ops_users | 设备归属用户 |
| `platform` | string(16) | CHECK IN (`'ios'`)（v1 仅 iOS · 词表留扩展位） |
| `token_hash` | string(128) not null | APNs device token 的哈希（**不存原始 token**） |
| `created_at` | timestamptz | — |
| `last_seen_at` | timestamptz | 最近 register/心跳 |

约束：`uq_ops_device_tokens(tenant_id, token_hash)`（同租户同设备幂等）；索引 `(user_id)`。

### 6.2 端点草案

| 方法 | 路径 | 鉴权 | 语义 |
|---|---|---|---|
| POST | `/api/ops/devices/register` | CurrentUser + tenant 谓词 | body `{platform, token}` → 服务端哈希后 **upsert by (tenant_id, token_hash)**，刷新 `last_seen_at`；幂等 200/201 |
| POST | `/api/ops/devices/unregister` | CurrentUser + tenant 谓词 | body `{token}` → 按 `(tenant_id, token_hash, user_id)` 删除；不存在 → **200 幂等** |

```bash
curl -X POST 'https://<host>/api/ops/devices/register' \
  -H 'Cookie: ops_session=<session>' \
  -H 'Content-Type: application/json' \
  -d '{"platform": "ios", "token": "<apns-device-token>"}'
```

---

## §7 总闸与环境契约

### 7.1 OPS_SCHEDULE_ENABLED（R8 · 承 auto_resume 三件套）

| 项 | 裁定 |
|---|---|
| 取值 | `off`（**默认**）/ `on`；解析 `strip().lower()` |
| 非法值 | 回退 `off` + `logger.warning` |
| 语义 | `on` 才创建 worker task；`off` = 默认关零创建 · off 态 TestClient 行为零 diff |
| 边界 | **总闸只管 worker 创建，不闸 REST 面**（off 时 CRUD 照常，schedule 落库不点火） |

### 7.2 OPS_SCHEDULE_TICK_SECONDS

默认 **30** 秒；非法值回退 30 + `logger.warning`。

### 7.3 OPS_CAPABILITY_PERSISTENCE 默认 null → db（R9 · 部署面说明）

> **代码默认已翻转：未设/空串 null → db（DbIdempotencyStore 现役转正，persistence.py:39 · P3-T6 已落地 · 承 14 终稿 §6.4/R9）。** 刻意不做自动探测数据库可用性；显式 `null` 仍保留为回退口（不防重+告警 · **不能上生产**）；装配是部署动作，生产部署清单须显式 `OPS_CAPABILITY_PERSISTENCE=db`。。

| 取值 | 装配 | 语义 |
|---|---|---|
| `db` | DbIdempotencyStore + DbReceiptSink | 生产唯一合法（V1 幂等键 DB 防重） |
| `memory` | 进程内 | 多实例防重无效 · 仅本地开发 |
| 未设 / `null` | 不防重 + 告警 | **不能上生产** |
| 未知值 | `logger.error` 按不防重处理 | 部署笔误不留静默 |

R9 四条件（14 §6.4 · 已由 P3-T6 落地）：persistence.py docstring 改写「装配是部署动作」· env 四分回归矩阵测试（db / memory / null / 未设）· fail-closed + 显式 null 两回归 · 风险登记 R-P3-10（热路径 DB 写 + 可用性耦合）。

### 7.4 capability 放行环境（§2.2 汇总）

| env | 值 | 作用 |
|---|---|---|
| `OPS_CAPABILITY_EXTRA_MANIFESTS` | 含 `ops.schedule.v1.yaml` 路径 | 显式加载写类 manifest |
| `OPS_CAPABILITY_ALLOW_WRITE_TAGS` | `schedule` | 豁免 deny_write 一层（tag 匹配） |

### 7.5 部署 env 汇总表

| env | 默认 | 生产要求 | 所属 |
|---|---|---|---|
| `OPS_SCHEDULE_ENABLED` | `off` | 功能上线时 `on` | T3 worker |
| `OPS_SCHEDULE_TICK_SECONDS` | `30` | 按需 | T3 worker |
| `OPS_CAPABILITY_PERSISTENCE` | **`db`（T6 翻转）** | **`db`** | T2b capability |
| `OPS_CAPABILITY_EXTRA_MANIFESTS` | 空 | 含 schedule manifest | T2b |
| `OPS_CAPABILITY_ALLOW_WRITE_TAGS` | 空 | `schedule` | T2b |
| `OPS_ADMIN_SYNC_TOKEN` | 空（Bearer 禁用） | 运维面按需 | T5 admin |

---

## §8 附：03-security-audit.md §4 增补记录

本次 T1 同步在 [03-security-audit.md](03-security-audit.md) §4 尾部增补第 6 条「运维面例外」：登记 admin 面跨租户性质（AdminSyncAuth = 机器 Bearer 或 maintainer cookie · maintainer 全局角色无租户绑定）与既有 purge 同缺口（SP3 · 本波不收紧）。增补全文以 03 文为准。

---

## 版本记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1 | 2026-11-16 | T1 落盘：§1 Schedule REST · §2 create_schedule capability · §3 runs/events 只读（含 R5 核实结论）· §4 fires 台账 · §5 admin memory · §6 device_tokens 草案 · §7 总闸环境 · §8 03 增补记录 |
