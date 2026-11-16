# P3 设计终稿 — 任务化执行（Schedule · 任务卡片 · 轨迹回放 · L2 记忆产品化 · 多副本前置）

> 状态：v1 终稿（三方评审合并版 · lead 整合）· 2026-11-16
> 基线：ops-desk-api master（P1 T1-T4 已交付 · P2a/P2b 终稿见 08/11）· 全部 file:line 引自实地勘察
> 上游：/tmp/opsdesk-rfc/inv-p3.md（勘察报告）；04-roadmap.md §P3(:53-58)+§阶段纪律(:65-70)；01-architecture.md v2 §2-§3；02-tools-skills-memory.md v2 §4；03-security-audit.md v2 §4；07-p1-goal-design.md；11-p2b-mcp-skill-design.md
> 体例：承 11-p2b-mcp-skill-design.md
> 评审记录：architect 初稿 /tmp/opsdesk-rfc/p3-design-architect.md（345 行 · D-A~D-I · T1-T11 · §14 Q1-Q6）→ product 条件 GO（B1-B3+S-a~S-g+盲点5）/tmp/opsdesk-rfc/p3-review-product.md → platform 条件 GO（B1-B7+N1-N6+SP1-SP3，评审意见经 lead 逐条裁定转述）→ 本稿 R1-R23 全部关闭 · §14 Q1-Q6 明判落盘

---

## 0. 一页结论

P3 以**零新外部依赖、SSE 零新帧、契约 freeze 零修订**落地任务化执行：Schedule 走「DB 表 + lifespan 进程内 interval loop + DB 原子抢占」三件套（承 auto_resume.py:275-297 先例，否 APScheduler/croniter/Redis），**总闸 OPS_SCHEDULE_ENABLED 默认 off**（R8），fires 台账走 {claimed, fired, skipped, failed} 状态机、**run_id 写回才算 fired**（R10）；创建入口 = **agent 对话化 create_schedule 写类 capability**（既有闸链 + W1 HITL 确认「创建定时任务=承诺未来 LLM 花费」· 走既有 HitlApprovalCard · web 零改动，R1）；任务卡片 = ops_lg_rag_runs 的 UI 投影（**零新表**），web 对话窗内嵌任务面板（el-collapse 区含「定时任务」子区 + el-drawer/el-timeline 回放，R2），状态面经 REST + 既有帧族增量，**不新增 SSE 帧**（iOS LgRagFrame.swift:87 未知帧抛错是硬约束）；只读端点全部 per-user 归属校验（404），events 响应白名单过滤 event_type 至 freeze 词表（R5）；L2 记忆产品化补 admin 浏览/撤销端点（AdminSyncAuth 复用，**admin 面钉死=跨租户运维面**，R7），propose→confirm 本波不做；session_summaries 仅开 env 放量+对拍验收；多副本前置 = 幂等转正 DB（OPS_CAPABILITY_PERSISTENCE 默认 null→db，附四条件 R9）+ 其余五项进程内状态**维持单副本声明**；APNs 留接口**降级为 T1 契约文档草案**（ops_device_tokens 表结构+register/unregister+token_hash 约定，实施顺移 Swift 推送波，R3）；验证假设「给目标、等交付」以 S1-S3 三条验收样例三级裁定收口（**web 为主验证端**，移动闭环以下波推送为前提，R21）；iOS hitl 审批本波解签落地（人签不落则 S2 改判 web 单端，如实登记）。新 DDL 两张表全部含 tenant_id（红线 F1-F6）。

**叙事定位钉死（R19）**：admin memory 端点/页面与 summaries 放量是**治理/成本面**，不进「等交付」验证叙事——T11 验收报告分两表（验证假设裁定 / 治理放量结果），防「交付物清单很长」掩盖「心智验证只系于 S1-S3」。

### 0.1 评审修订记录（R1–R23，全关闭）

| # | 修订 | 来源 |
|---|------|------|
| R1 | **Schedule 创建入口补闭环**：新增写类 capability `create_schedule`（既有 capability 闸链 + W1 HITL 确认——创建定时任务=承诺未来 LLM 花费 · 走既有 HitlApprovalCard · web 零改动 · 幂等键满足 V1）→ 新任务单 **T2b**（api）；S1 创建主体=agent 对话化创建 | product B1（lead 采纳方案 a） |
| R2 | T8 任务面板加「定时任务」子区（同 el-collapse 面板零新路由 · GET /schedules?thread_id= 渲染 active/paused · 行内 pause/resume/cancel + ElMessageBox 双确认）；跨会话全局管理页登记后续 | product B2 |
| R3 | ops_device_tokens 降级为 **T1 契约文档草案章节**（表结构+register/unregister+token_hash 存储约定，纯文档）；实施顺移至 Swift 推送代码落地波（表+端点+发送管线一个 PR 收口）；T6 只剩幂等转正；§13 红线措辞同步修正 | product B3 |
| R4 | 滥用防堵双上限：**per-user 20 枚 + per-tenant 200 枚** active schedule；interval_seconds 下限 60→**≥300s**（once_at/daily_at 无下限）；T3 验收含**预算归因验证**（schedule 触发的 run 预算 key=creator 身份 · start_run_worker 请求上下文外创建须显式传 · 防整体绕过预算） | platform LB1 |
| R5 | 只读端点归属校验：GET threads/{id}/runs → thread_owner==当前用户否则 404；GET runs/{id}/events → assert_run_owned 前置否则 404；admin 越权面 v1 不开；events 响应**白名单过滤 event_type 至 freeze 词表**（防未来内部帧外泄 · 现落库词表=freeze 客户端词表、无需脱敏的核实结论写入 T1） | platform LB2 |
| R6 | schedule 归属校验：创建/PATCH 校验 thread_owner==creator（thread 不存在允许、fire 时自建）；worker fire 前复核归属，外来 thread → fires.status=failed+台账留痕 | platform LB3 |
| R7 | T1 契约钉死 **admin 面=跨租户运维面**（AdminSyncAuth=机器 Bearer 或 maintainer cookie · OpsUser.role 全局无租户绑定）——与 F4 关系按「运维面例外」写进 03-security-audit §4（SP3 一并裁定：现有 purge 同缺口一并登记，不本波收紧）；T5 复用 service.py:168 revoke_by_key（幂等带审计）；revoke 已撤销→**200 affected=0**（否 409）；文档明示 /admin/memory 页=maintainer 可达非租户管理员 | platform LB4+SP3 |
| R8 | **OPS_SCHEDULE_ENABLED 默认 off**（env ∈ {off（默认）,on} · 非法回退 off · on 才创建 task · 逐字承 auto_resume 三件套 + TestClient 零 diff 纪律 + 行为由部署决策激活）；T3 验收格残留「默认 on?」清除 | platform LB5 |
| R9 | 幂等转正附四条件：① persistence.py docstring 改写（装配是部署动作非代码默认值 · 刻意不做自动探测）；② 部署 env 四分回归矩阵（显式 db/memory/null/未设）；③ fail-closed+显式 null 回退两回归；④ 风险登记补热路径 DB 写+可用性耦合 | platform LB6 |
| R10 | fires 状态机 **{claimed, fired, skipped, failed}** · **run_id 写回才算 fired** · lifespan 启动首轮对 status=claimed AND run_id IS NULL 超时行补链（承 scan_orphan 思路）；INSERT 用 **ON CONFLICT DO NOTHING**（PG 同事务撞 uq 会 abort）；S3 判据加「fires.run_id 非空且 run 达终态」 | platform LB7（方案①） |
| R11 | fire 前 user 存在校验：创建者已删（悬空）→ fires.status=failed + schedule 自动 paused | platform SP1 |
| R12 | 「[定时任务]」前缀**非归因/鉴权依据** · 唯一归因真源=fires 台账 → 进 T1 契约；worker 审计日志（schedule_id/fire_id/run_id 三元组）进 T3 验收 | platform SP2 |
| R13 | platform N1-N6 全采纳：N1 SKIP LOCKED 先例锚改 hitl/store.py:261-277（测试 test_hitl_auto_resume.py:481 test_db_claim_skip_locked_only_one_succeeds）；N2 episodes 不做单条撤销（status CHECK 已有+revoke_by_run 已存在+召回双层过滤已够）；N3 device_token 存 hash（uq(tenant_id,token_hash)，随 R3 进契约草案）；N4 fires.run_id 加索引+按 run_ids IN 批量反查防 N+1；N5 PATCH 重算守卫（重算值>now 或行锁，登记低概率）；N6 RunEventBus _history 内存债被 schedule 放大登记 | platform N1-N6 |
| R14 | 三级裁定判据可操作化：S1 ①-④ checklist 逐项过/不过；「部分成立」枚举闭合清单，清单外缺口一律升级复议 | product S-a |
| R15 | 面板「待审批」卡片点击=**锚定滚动到消息流对应 hitl 卡**（不另开审批面）进 T8 验收 | product S-b |
| R16 | 折叠区标题计数徽标「任务 · 2 进行中」（el-collapse-item title 插槽） | product S-c |
| R17 | S2 钉具体写类 capability=**ops.write.run_note**（仓内实际唯一真实业务写 · manifests/ops.write.v1.yaml:27 · tenant_scoped · hitl.required） | product S-d |
| R18 | 用户不在场+run error 无感知面=登记「部分成立」已知缺口（非新问题） | product S-e |
| R19 | §0 钉明 admin memory/summaries=治理/成本面不进「等交付」验证叙事；T11 报告分两表 | product S-f |
| R20 | daily_at 文案人类化「每天 08:30（北京时间）」（创建文案/契约注释）；第 21 枚创建 422 人类化错误文案进 T1 契约 | product S-g+盲点5 |
| R21 | §8 加「P3 验证以 web 为主验证端 · 移动端『等交付』闭环以下波推送管线为前提」诚实声明 | product 盲点2 |
| R22 | 任务切分分「证伪主线/并行治理线」双泳道（关键路径 T1→T2→T2b→T3→T4→T8→T11 · 砍单序 T9→T7→T5） | product 盲点3 |
| R23 | iOS 任务卡片/回放=后续候选登记（双端能力差不作漏项） | product 盲点4 |

### 0.2 裁定总表（D-A ~ D-I）

| # | 开放点 | 裁定 |
|---|--------|------|
| D-A | Schedule 体系 | **进程内 interval loop + DB 原子抢占**（否 APScheduler/croniter/Redis）；ops_schedules + ops_schedule_fires 双表；schedule_kind ∈ {once_at, interval, daily_at}（否 cron 表达式）；触发=目标 thread 落 user turn 创建新 run；补跑=fire_once 幂等；**fires 状态机 claimed→fired（run_id 写回）**（R10）；**总闸默认 off**（R8）；**双上限 20/200 + interval ≥300s**（R4）；创建入口=create_schedule capability 对话化（R1） |
| D-B | 任务卡片 | **run 的 UI 投影零新表**；web 对话窗内嵌任务面板（否第四槽/侧栏/独立路由）含**定时任务子区**（R2）与计数徽标（R16）；runs.status 六词表映射视觉态；**SSE 零新帧**；归属校验 thread_owner 否则 404（R5） |
| D-C | 轨迹回放 | el-drawer + el-timeline（同库新引件零新依赖）；数据源=新只读 REST 端点 GET /lg-rag/runs/{run_id}/events（否复用 replay SSE）；**assert_run_owned 404 + event_type 白名单过滤**（R5）；与断连续看边界=静态查阅 vs live 订阅 |
| D-D | L2 记忆产品化 | admin/memory 补 GET facts 分页浏览 + POST revoke + episodes 只读列表；**admin 面=跨租户运维面**（R7）；revoke 复用 revoke_by_key、已撤销 200 affected=0；**propose→confirm 本波不做**（登记 P3 后续候选）；三开关维持默认关，放量=读→写→向量召回三步灰度 |
| D-E | session_summaries 启用 | 仅 env 放量（off→pilot tenant→全开）；接受窗口折叠+chunk_hash 缓存语义（否增量滚动摘要）；验收=token 对拍 + 对照会话 + 缓存命中率；治理面叙事（R19） |
| D-F | 多副本前置 | **不引入现役 Redis**；幂等转正 DB（默认 null→db，附 R9 四条件）；熔断/双预算/nonce/_SCAN_TASK/RunEventBus 维持进程内+登记单副本声明（_history 内存债放大登记 R13-N6）；Schedule worker 自带 DB 抢占 |
| D-G | 验证假设 | S1 定时交付全链（创建主体=agent 对话化）/ S2 定时 HITL 链（钉 ops.write.run_note）/ S3 停跨时点补跑幂等（判据含 run_id 非空+run 终态）；三级裁定承 11 §9.3 并可操作化（R14）；**web 为主验证端**（R21） |
| D-H | iOS | hitl 审批本波解签实施（HG-AUDIT-R1 人签前置，独立任务单不阻塞主线；人签不落→S2 改 web 单端如实登记）；APNs 留接口=**T1 契约文档草案**（实施顺移 Swift 推送波，R3）；iOS 任务卡片/回放=后续候选（R23）；契约 freeze 零修订 |
| D-I | 任务切分 | **双泳道**：证伪主线 T1→T2→T2b→T3→T4→T8→T11 · 并行治理线 T5/T6/T7/T9 · 独立人签波次 T10；砍单序 T9→T7→T5（R22） |

---

## 1. D-A · Schedule 体系

### 1.1 触发器形态裁定：进程内 interval loop（否 APScheduler）

**裁定**：lifespan 周期任务 + 模块级句柄幂等复用 + shutdown cancel——逐字承 auto_resume.py:275-297（start_compensation_scanner/stop_compensation_scanner）与 main.py:92/:110 挂接先例。tick 默认 30s（env OPS_SCHEDULE_TICK_SECONDS，非法回退 30）。**每 tick 一轮 DB 原子抢占**（见 §1.4），单副本即正确，多副本天然安全。**worker 创建受总闸 OPS_SCHEDULE_ENABLED 控制（默认 off，见 §1.7）**。

**理由**：
1. **阶段纪律**（04-roadmap:67「每阶段最多一个新外部依赖」）：APScheduler 是一枚新外部依赖（且拖 tzlocal 级联）；本阶段依赖名额留给**零**——Schedule 用 asyncio stdlib 即可，croniter 也被否（见 §1.2）。
2. **先例已跑通**：auto_resume 的「lifespan 启停 + 模块级 _SCAN_TASK + 异常吞掉下周期重试 + shutdown cancel 等收尾」五件套是仓内唯一周期任务纪律，同源复制零发明。
3. **量级错配**：APScheduler 的 job store/触发器插件体系对「扫一张 DB 表」是纯负担；30s tick 对「每天 8:30 巡检」类需求精度足够（±30s）。

**被否替代**：APScheduler（新依赖+形态过重）；croniter 只作解析库（仍是新依赖且 cron 语义 v1 不需要，见 §1.2）；Celery/RQ（队列基建，跨阶段红线）；PG LISTEN/NOTIFY 独立 worker 进程（01 v2 §3 已降级为多副本扩展项）。

### 1.2 表结构（唯一新 DDL · 全部含 tenant_id）

**ops_schedules**：

| 列 | 型 | 说明 |
|---|---|---|
| schedule_id | UUID pk | |
| tenant_id | String(64) not null | 红线 F1-F6；跨租户 404 |
| user_id | UUID FK ops_users | 创建者（REST 面=CurrentUser；agent 对话化创建=会话用户，R1）；**预算归因真源**（R4） |
| thread_id | String(255) not null | 投递目标会话（不加 FK，承 run_events 顺序容错先例；创建时校验 thread_owner==creator，thread 不存在允许、fire 时自建，R6） |
| name | String(120) | 展示名 |
| instruction | Text | 到点投递的用户消息全文（单行化纪律同 goal objective，承 07 §2.3） |
| schedule_kind | String(16) | **{once_at, interval, daily_at}** 三值词表 |
| run_at | timestamptz null | once_at 专用 |
| interval_seconds | int null | interval 专用（**≥300s 校验**，R4；once_at/daily_at 无下限） |
| time_of_day | String(5) null | daily_at 专用 "HH:MM" |
| timezone | String(64) null | daily_at 专用，IANA 名（默认 Asia/Shanghai）；**v1 不随 DST 自动校准的边界在配置注释钉明**；创建文案人类化「每天 08:30（北京时间）」（R20） |
| next_fire_at | timestamptz not null | 索引 idx_ops_schedules_next_fire (status, next_fire_at) |
| catchup_policy | String(16) | **仅 fire_once**（词表留 skip 位不实现，见 §1.5 被否） |
| status | String(16) | **{active, paused, cancelled}**；active↔paused 人工 PATCH，cancelled 终态不可逆（承 goal 状态机纪律 07 §1）；**fire 前复核发现创建者悬空时 worker 自动置 paused**（R11） |
| fire_count / max_fires | int / int null | max_fires 空=不限；once_at 等价 max_fires=1 |
| last_fired_at | timestamptz null | |
| created_at / updated_at | timestamptz | |

**ops_schedule_fires**（触发台账 = 幂等键 + 审计面 + **唯一归因真源**，R12）：

| 列 | 型 | 说明 |
|---|---|---|
| id | UUID pk | |
| schedule_id | UUID not null（无 FK，承孤儿容忍先例） | |
| tenant_id | String(64) not null | |
| planned_fire_at | timestamptz not null | **uq_ops_schedule_fires_planned (schedule_id, planned_fire_at) 部分唯一 = 幂等键** |
| run_id | String(64) null | 触发的 run（关联 ops_lg_rag_runs）；**run_id 写回才算 fired**（R10）；**加索引**，任务面板按 run_ids IN 批量反查防 N+1（R13-N4） |
| status | String(16) | **{claimed, fired, skipped, failed}**（R10：INSERT 先占 claimed → run 创建成功写回 run_id 才算 fired） |
| fired_at | timestamptz | |

**词表取舍**：schedule_kind 三值覆盖「一次提醒 / 每 N 分钟巡检 / 每天 HH:MM 晨会材料」三类 ops 真实场景；daily_at 用「当日 HH:MM 下次发生时刻」纯算术（zoneinfo stdlib，~30 行），**不引 cron 表达式**——croniter 占依赖名额、五个字段的表达力 v1 无消费者、rrule 日历语义留 P4 再议。

### 1.3 触发语义：到点做什么

**裁定**：到点 = 向目标 thread 落一条 role=user 的 turn（content = instruction，带 schedule 归因前缀标记「[定时任务 · {name}]」供人识别），随后走 /lg-rag/stream 同源的**内部 run 创建通路**（run_store.create_run + start_run_worker，router.py:454-487 同函数直调，不经 HTTP 自调用），产出 answer 帧自然出现在该对话窗消息流。

**归因纪律（R12 · SP2）**：「[定时任务 · {name}]」前缀**仅供人识别，非归因/鉴权依据**——唯一归因真源 = ops_schedule_fires 台账（schedule_id/fire_id/run_id 三元组）；worker 触发时写审计日志（logger.info 三元组，进 T3 验收）；任何下游（卡片徽标/预算归因/审计）一律查 fires 反查，不得解析消息文本前缀。此条进 T1 契约钉死。

**理由**：「等交付」心智的交付物必须出现在对话上下文里——用户打开会话看到「定时任务触发的提问 + Agent 的回答」，这是 roadmap §P3 验证假设的直接证据面。落 user turn 是诚实归因（persist_thread_turns 先例，sse_stream.py:506），与 goal 注入的「不落盘横幅」纪律不冲突——goal 是上下文，schedule 触发是**真实的用户级输入事件**。

**与 goal 关系**：schedule **不绑定 goal_id**（v1 不加列）。到点 run 的装配走既有管线，该 thread 若有 active goal 则 goal 注入（07 §2）自然生效——「每天推进目标」由「thread 上有 goal + schedule 定时发问」两机制正交组合而成，不需要第三机制。被否：schedule.goal_id 显式绑定（P1 最小化裁定 07 §3「不加 runs.goal_id」同源理由——一个 alembic 的事，等真实需求驱动）；「向既有 run 注入消息」（run 是一次图执行，无中途注入语义，架构红线）。

### 1.4 DB 原子抢占（「DB 租约 worker」的落实面）

每 tick：
```
UPDATE ops_schedules SET next_fire_at = <按 kind 重算的下一未来时刻>, last_fired_at=now, fire_count=fire_count+1
WHERE schedule_id IN (SELECT schedule_id FROM ops_schedules
  WHERE status='active' AND next_fire_at <= now ORDER BY next_fire_at LIMIT <batch> FOR UPDATE SKIP LOCKED)
RETURNING *;
```
- **推进 next_fire_at 与触发台账插入同事务**：先 INSERT ops_schedule_fires（status=claimed）——**用 ON CONFLICT DO NOTHING**（R10：PG 中同事务撞 uq 会 abort 整个事务，吞错跳过写法不可用；DO NOTHING 返回空即「已被别的副本/上一 tick 抢过」），再落 user turn + create_run + start_run_worker，**run 创建成功后写回 fires.run_id + status=fired**（run_id 写回才算 fired）。
- 仓内首个 FOR UPDATE SKIP LOCKED 先例锚 = **hitl/store.py:261-277 _CLAIM_APPROVED_FOR_RESUME**（并发双认领仅一成功；确定性测试 test_hitl_auto_resume.py:481 test_db_claim_skip_locked_only_one_succeeds）——Schedule 抢占同模式复制（R13-N1）；租约判定交给 DB 时钟与行锁，承 DbIdempotencyStore（idempotency.py:320）「租约判定交给 DB」模式，零新机制。
- 单 tick 处理上限 batch=50（防雪崩）；触发失败的 fire 行 status=failed + logger.exception（admin/memory.py:35-45 不静默先例）。

### 1.5 错过补跑（catchup）与启动补链

**裁定：fire_once**。worker 每 tick（含 lifespan 启动后首轮立即执行，承 auto_resume :275 首轮即扫先例）对 next_fire_at < now 的 active 行各补跑一次，随后把 next_fire_at 推进到严格未来。**停机跨 10 个 interval 只补一次**——幂等键 (schedule_id, planned_fire_at) 保证重启/多副本不重复。

**启动补链（R10）**：lifespan 启动首轮对 **status=claimed AND run_id IS NULL 且超时的 fires 行**做补偿扫描——claimed 是「抢占已记、run 未建」的中间态，进程在两次写之间崩溃会留下孤儿 claimed 行；补链动作 = 按台账重放触发（落 user turn + 建 run + 写回 run_id），思路承 run_worker.py:198-258 scan_orphan 孤儿补偿先例。

**被否**：skip（巡检漏跑无人知，违「等交付」心智）；fire_all 全量追补（停机一夜补 96 次巡检=消息流洪水+LLM 预算爆炸）。

### 1.6 冻结/暂停与 REST 面

- POST /api/ops/schedules（创建）· GET /api/ops/schedules?thread_id=（列表）· PATCH /api/ops/schedules/{id}（status: active↔paused·cancelled 单向；instruction/name/排期可改，改排期重算 next_fire_at）· GET 单条（含最近 fires 10 条）。
- 鉴权 CurrentUser + tenant 谓词（router.py:376 _resolve_request_tenant 先例）；跨 tenant 404（F4）。
- **归属校验（R6 · LB3）**：创建/PATCH 校验 **thread_owner==creator**（thread 不存在允许、fire 时自建）；worker fire 前复核归属，发现 thread 已易主（外来 thread）→ fires.status=failed + 台账留痕，不投递。
- **配额上限（R4 · LB1）**：每用户 active schedule ≤ **20 枚** + 每租户 ≤ **200 枚**双上限；超限 422 且**人类化错误文案**（如「定时任务已达上限（20 个），请先暂停或取消其他任务」——文案进 T1 契约词表，R20/盲点5）。
- **PATCH 重算守卫（R13-N5）**：改排期重算 next_fire_at 须保证重算值 > now（否则取行锁串行化）——重算瞬间 tick 并发抢旧值的低概率竞态登记风险（§9 R-P3-11）。
- 暂停=行在 worker 不抢（status 谓词）；进程重启零丢失（DB 行）；cancelled 终态不可逆（换排期=新建，承 goal O 系列纪律）。

### 1.7 总闸 OPS_SCHEDULE_ENABLED：默认 off（R8 · LB5）

**裁定**：env ∈ {**off（默认）**, on}；非法值回退 off 并 logger.warning；**on 才创建 worker task**——逐字承 auto_resume 三件套（env 解析 + 默认关零创建 + TestClient 零 diff 纪律：off 态 lifespan 行为逐字节不变）；**行为由部署决策激活**（设计不替部署默认开启）。T3 验收含 off 态 TestClient 零 diff 回归。

### 1.8 预算归因（R4 · LB1）

schedule 触发的 run 在**请求上下文外**创建，start_run_worker 须**显式传入 creator 身份**（user_id/tenant_id 取自 schedule 行，不得缺省/继承 worker 进程身份）——LLM 预算（llm/budget.py:85）与 usage 归因的 key = creator 身份，防「schedule 触发整体绕过预算」。T3 验收含预算归因验证：schedule 触发的 run 其 usage/span 行 user_id==creator。

---

## 2. D-B · 任务卡片

### 2.1 信息模型：run 的 UI 投影，零新表

**裁定**：任务卡片不是新实体。卡片数据 = ops_lg_rag_runs 行（run_id/status/created_at/finished_at）+ 该 run 首帧 run.start 的 query 摘要（截 80，承 history.py:24 TITLE_MAX_CHARS）+ schedule 归因（**fires.run_id 反查**，按 run_ids IN 批量反查防 N+1，R13-N4；定时任务卡片带「定时」徽标——归因只认台账不认消息前缀，R12）。**唯一新增是只读端点**：GET /api/ops/lg-rag/threads/{thread_id}/runs（分页，含上述投影字段）——history_router.py:95/:122 现有两端点只覆盖 threads 列表与 turns 历史，无 per-thread runs 面（勘察 §一.3）。**归属校验（R5 · LB2）**：thread_owner==当前用户否则 404；admin 越权读面 v1 不开。

**被否**：新任务表（run 已是一等表，双源=漂移）；复用 ops_runs 旧表（随旧 chat 410 下线，01 v2 §3 C-3 清理对象）。

### 2.2 呈现形态：对话窗内嵌任务面板（否第四槽/侧栏/独立路由）

**裁定**：ChatView.vue 内新增 el-collapse-item「任务」（承 :298-329「编排进度/子任务过程」折叠区先例），列本 thread runs 卡片流；每卡片 = el-tag 状态 + query 摘要 + 相对时间 + （定时徽标）+ 点击开回放 drawer（§3）。组件新立 src/components/chat/TaskCard.vue，**同构 HitlApprovalCard 的「内嵌卡片 + props message/run + store action + ElMessageBox 二次确认」模式**（勘察 §二.4 实证该模式已跑通）。

**定时任务子区（R2 · PB2）**：同一 el-collapse 面板内加「定时任务」子区（零新路由）：消费 GET /api/ops/schedules?thread_id= 渲染当前会话 active/paused 列表（name + schedule_kind 人类化文案「每天 08:30（北京时间）」R20 + next_fire_at 相对时间），行内 pause/resume/cancel 按钮走既有 PATCH + **ElMessageBox 双确认**（HitlApprovalCard 模式复用）。纯 REST 消费，零新端点零新帧。**跨会话全局管理页本波不做**（登记后续）——会话内列表已足够支撑 S1。

**计数徽标（R16 · S-c）**：折叠区标题插槽带计数/状态徽标「任务 · 2 进行中」——S1 真实场景是「次日打开对话窗」，running 中的 schedule 触发在折叠态下须非零信号（el-collapse-item title 插槽零成本）。

**被否**：
- **ChatMessage 第四槽**（chat.ts:155-160 thinking/subtasks/hitl 之后加 task 槽）：run 与 message 非 1:1——schedule 触发的 run 有自己的 user turn 但续看/历史 run 无对应消息对象；卡片挂消息会把「任务列表」语义切碎进消息流。
- **独立侧栏**：ChatView 已有历史 tab（:462-464）+审批浮层（:429）多重挂载，侧栏挤压主聊区；且 iOS 无侧栏形态，双端分叉。
- **独立路由 /tasks**：违「交付出现在对话里」的验证假设——用户不该离开对话窗去别处看交付。

### 2.3 生命周期状态映射

runs.status 词表（run_store.py:20 · models.py 注释）→ 卡片视觉态（element-plus tag type，零新词表）：

| runs.status | 卡片态 | 交互 |
|---|---|---|
| running | 进行中（primary + 转圈） | 点击=跳既有「续看」（replay live-tail，ChatView.vue:258） |
| waiting_approval | 待审批（warning） | 点击=**锚定滚动到消息流对应 hitl 卡**（R15 · S-b：run.start 帧可定位消息，复用消息流内联 HitlApprovalCard 审批链路，**不另开审批面**——三面入口保留但操作唯一，防状态分叉；进 T8 验收） |
| done | 已完成（success） | 点击=轨迹回放 drawer |
| error | 失败（danger） | 回放 + done payload error 摘要 |
| disconnected | 中断（info） | 「续看」入口（断连续看既有语义） |
| resumed | 已恢复（success 浅） | 回放 |

### 2.4 SSE 新帧裁定：零新帧（契约 freeze 零修订）

**裁定**：不新增任何 SSE 帧类型。任务卡片状态面 = ①进入会话/手动刷新经 REST GET runs 列表全量拉；②live 期间复用既有帧族增量——web store 已在 processFrame 分流 run.start/done（chat.ts:387-412），run.start → 本地插入 running 卡片，done → 按 payload.status 更新卡片终态，hitl.waiting → waiting_approval。**三端契约 freeze（docs/lg-rag-contract-freeze_v1_zh.md）零修订**。

**理由（硬约束）**：iOS LgRagFrame.swift:87 对未知 event_type 上抛 unknownEventType 错误（非静默忽略）——任何新帧 = LgRagEvent 封闭 enum 扩展 + payload 模型 + 契约 freeze 修订 + ios/web/api 三端同步波次。而卡片状态变化频率 = run 生命周期级（分钟级），REST + 既有帧完全够载。**被否**：task.card 新帧（成本是全 freeze 修订波次，收益为零——同信息既有帧已携带）；复用 thought 帧族塞卡片数据（污染 freeze 词表语义，01 v2 §P0' 接受条件红线）。

---

## 3. D-C · 轨迹回放

**裁定**：web 回放视图 = el-drawer（右滑出）内嵌 el-timeline 渲染 run 事件序列——两组件均为 element-plus 已装未用件（勘察 §二.3），**同库新引件，零新依赖**。数据源 = **新只读 REST 端点 GET /api/ops/lg-rag/runs/{run_id}/events**（读 event_store.load_events_after :361 全量返回，上限 500 帧 + truncated 标志），渲染器把 event_type 词表映射为时间线节点（run.start=起点 / node.progress=节点步骤 / subtask.*=子任务 / answer=回答 / hitl.waiting=审批点 / done=终点 / error=失败），payload 折叠详情（el-collapse）。

**归属与白名单（R5 · LB2）**：端点前置 **assert_run_owned**（run 归属当前用户否则 404；admin 越权面 v1 不开）；响应**白名单过滤 event_type 至 freeze 词表**——防未来内部帧落库后经本端点外泄到客户端；**核实结论写入 T1**：现落库 event_type 词表 = freeze 客户端词表，无需逐 payload 脱敏，过滤是前置防泄而非现状脱敏。

**否复用 POST /lg-rag/replay（router.py:514）**：该端点是**流订阅**契约（cursor + follow live-tail + 在飞 409 Retry-After，sse_replay.py:13-58），语义是「断连续看」——el-timeline 是静态查阅，SSE 订阅形态错配；强行复用会把 409 退避/cursor 管理复杂度拖进一个纯查阅视图。**边界钉死**：续看=恢复 live（既有不动）；回放=已完成/历史 run 的只读静态查阅（新端点新视图）。iOS 侧本地 ChatRunEvent 全帧归档（勘察 §三.1）已具回放数据层，iOS 回放 UI 登记后续候选（R23，见 §8）。

---

## 4. D-D · L2 记忆产品化

### 4.1 admin 端点补全（现仅 purge :73）

| 端点 | 语义 |
|---|---|
| GET /api/ops/admin/memory/facts?tenant_id&user_id&status&kind&cursor | 分页浏览（keyset 分页承既有历史面先例；status/kind 过滤，默认 status=active） |
| POST /api/ops/admin/memory/facts/{fact_id}/revoke | 撤销：status→revoked（ops_memory_facts 状态机 active\|superseded\|revoked\|expired 已有该值，不物理删——02 §4「不物理删」裁定落地）；**复用 service.py:168 revoke_by_key**（幂等带审计，R7）；**revoke 已撤销 → 200 affected=0**（幂等成功，否 409） |
| GET /api/ops/admin/memory/episodes?tenant_id&user_id&cursor | 只读浏览（run 级经验）；**episodes 单条 revoke 不做**（R13-N2：episode status CHECK 约束已有 + service.py:138 revoke_by_run 已存在 + 召回双层过滤已够，撤销语义弱） |

**admin 面=跨租户运维面钉死（R7 · LB4）**：AdminSyncAuth = 机器 Bearer 或 maintainer cookie，OpsUser.role 全局**无租户绑定**——admin 面语义是「跨租户运维」而非「租户管理员」，与 F4（跨租户 404）的关系按**「运维面例外」**写进 03-security-audit §4（T1 一并落实）。**SP3 一并裁定**：现有 purge 端点同属此缺口（跨租户运维面无租户边界），一并登记、**不本波收紧**。审计 logger.info 记动作不记内容（同 purge 先例）。web 侧新增 /admin/memory 管理页（浏览+撤销双确认 ElMessageBox，承 HitlApprovalCard 模式），**文档明示该页=maintainer 可达、非租户管理员**——否则端点无消费面。

### 4.2 propose→confirm（02 §4 B 方案 agent_notes）：本波不做

**裁定：降级登记为 P3 后续候选**。理由：全链 = facts.status 词表加 proposed + 抽取管线改写 proposed + 审批卡片复用改造 + 契约评审（03 §2「新增事件走红线 3」）+ 三端确认 UI；而三开关默认全关、无真实记忆数据在库，propose 面建好即空转（违阶段纪律 2「不预搭未来形态的 UI 空壳」）。**触发条件钉死**：三开关放量后（§4.3）出现真实误抽取样本 → 再议 B 方案。

### 4.3 三开关放量策略

维持默认全关。放量三步（每步独立 runbook + 回退=关 env）：
1. MEMORY_FACTS_ENABLED（**读**面，continuity.py:144）pilot tenant 灰度 1 周——只注入既有 facts 进装配，无写；
2. MEMORY_FACTS_EXTRACT_ENABLED（**写**面，extract.py:63）pilot 灰度 1 周——admin 浏览/撤销面（§4.1）是此前置（02 §4「开启前必须可审」裁定）；
3. MEMORY_FACTS_VECTOR_RECALL_ENABLED（service.py:385）最后开。
**观测前置债**：Langfuse OTLP 403（.env dev 密钥失效，traces 止于 2026-10-29——勘察 §一.8）须维护者先换密钥，否则放量对拍证据只能走录制替代路径。

---

## 5. D-E · session_summaries 启用

**裁定**：本波只做「放量 + 验收对拍」，零代码改动（表 models.py:350、写 summary.py:218、读 continuity.py:367、降级 :387 全齐，SESSION_SUMMARY_ENABLED 默认关）。

- **语义接受**：骨架 = placeholder 窗口折叠 + chunk_hash 缓存（窗口外旧 turn 折叠为摘要，窗口内恒原文）——新鲜度由窗口边界天然保证，摘要只是「旧上下文的压缩视图」。**否增量滚动摘要**：第二套摘要机制=新失真源+新失效面，P3 不造。
- **放量节奏**：off → pilot tenant → 全开，runbook 含回退命令（承 P1-T5 体例）。
- **验收口径**：① token 预算对拍——同 thread 长会话（≥30 turn）on/off 双跑，装配 messages token 计数（ops_llm_usage/span 导出）给出压缩率报告（预期窗口外 turn 折叠后 token 降 ≥50%，判据进验收单）；②答案质量对照会话（承 11 §9.2 off/on 对照体例，人工抽检 3 条）；③chunk_hash 缓存命中率观测（窗口稳定时二次装配应命中缓存零 LLM 调用）；④thread_id 缺失告警降级路径（continuity.py:387）回归。
- **叙事定位（R19）**：本项与 §4 同属治理/成本面，T11 报告进「治理放量结果」表，不进「等交付」验证假设裁定表。

---

## 6. D-F · 多副本前置

### 6.1 总裁定：不引入现役 Redis（核实结论）

compose 全仓核实：api/docker-compose.yml（db/qdrant/api 三服务）与 workspace deploy/docker-compose.prod.yml **均无 Redis 服务**，仅 prod :100-104 留 OPS_CAPABILITY_CB_REDIS_URL env 注释位。阶段纪律「每阶段最多一个新外部依赖」+ 单机 Lighthouse 现状 → **Postgres 是唯一外置基板**；Redis 维持「留位不实现」（circuit_storage.py 注释先例）。

### 6.2 台账逐项裁定（勘察 §一.5）

| 进程内状态 | 位置 | 裁定 | 理由 |
|---|---|---|---|
| LLM 熔断 | llm/circuit.py:53 | **维持进程内 + 单副本声明** | 热路径，DB 化=每调用一次 DB 写不可接受；无 Redis；pybreaker 进程内语义与「单副本部署」声明自洽。登记 P4 债 |
| capability 熔断 | capability/circuit.py:150 | **维持默认进程内；文档钉「多副本必填 CB_REDIS_URL」** | FallbackStorage（circuit_storage.py:105）外置路径已存在——转正=多副本化时的配置动作非代码动作，本波不写码 |
| LLM 预算 | llm/budget.py:85 | **维持进程内**（schedule 触发的 run 预算 key=creator 身份，R4/§1.8） | :413 自承「非持久配额」；软限额重启归零语义可接受；DB 化热路径不可行。登记债 |
| capability 配额 | capability/budget.py:51 | **维持进程内** | 同上（:228 已自承边界） |
| 幂等 | idempotency.py:169/:320 | **★ 转正 DB：OPS_CAPABILITY_PERSISTENCE 默认 null→db（附 R9 四条件，见 §6.4）** | DbIdempotencyStore 已交付（:320），装配闸已存在（persistence.py:31-58）；多副本防重的核心件，转正=改默认值+回归，零新代码。03 §4 债项#4 的实际偿还 |
| nonce 防重放 | delegation.py:351 | **维持进程内 + 登记债** | :14-16 自述跨进程防重放 v2.0；nonce 仅 delegation 内部用，单副本无跨进程面 |
| HITL _SCAN_TASK | auto_resume.py | **维持现状 + 登记** | 多副本重复扫描=多副本化时问题；届时与 RunWorker 租约同批做（可用 §1.4 DB 抢占同模式改造，成本已知） |
| RunEventBus/_workers | run_worker.py:72 | **维持进程内**；**_history 内存债被 schedule 放大登记**（R13-N6：schedule 让 run 量随时间自动增长，_history 无界持有在长期运行进程内存占用上浮，登记 §9 R-P3-12） | 01 v2 §3 已裁定「DB 租约降级为多副本扩展项」，本稿不重开；事件已落 DB，孤儿补偿（:198-258）兜断连 |

### 6.3 DB 租约 worker 本波边界

**Schedule worker 本波做且自带 DB 原子抢占**（§1.4）——它不是「多副本扩展项」而是 Schedule 的正确性本体（重启补跑+防重都需要台账）。**RunWorker 的 DB 租约不做**（维持 01 v2 §3 降级裁定 + 孤儿补偿现状）。两者边界：Schedule worker 是「谁触发」，RunWorker 是「谁执行」；触发面 DB 化、执行面进程内，单副本下完全自洽，多副本化时执行面租约与 _SCAN_TASK 改造同批进 P4。

### 6.4 幂等转正四条件（R9 · LB6）

1. **persistence.py docstring 改写**：钉明「装配是部署动作、非代码默认值；刻意不做自动探测（不猜 DB 可用性来自动升级）」——默认 db 是配置面默认值变更，不是运行时自适应。
2. **部署 env 四分回归矩阵**：显式 db / 显式 memory / 显式 null / 未设（=新默认 db）四种部署形态全回归。
3. **fail-closed + 显式 null 回退两回归**：DB 不可用时 capability 调用 fail-closed（persistence 闸既有语义）回归；显式 OPS_CAPABILITY_PERSISTENCE=null 可完整回退旧行为回归。
4. **风险登记补两条**：幂等热路径新增 DB 写（每次 capability 调用）+ 可用性耦合（DB 故障 → capability 面 fail-closed）——见 §9 R-P3-10。

---

## 7. D-G · 验证假设「给目标、等交付」验收样例

**验证端声明（R21 · 盲点2）**：P3 验证以 **web 为主验证端**；移动端「等交付」闭环以下波推送管线为前提（无 APNs 发送管线 = 用户离开 App 后不会知道交付发生）——T11 报告照此措辞，移动端缺位如实登记为非「部分成立」掩饰口径。

**S1 · 定时交付全链（核心样例）**：用户在对话窗设定 goal「关注昨日 issue 风险」→ **对话化创建 schedule**（用户说「每天早上 8:30 汇总昨日 issue 变更并给出风险点」→ supervisor 调 create_schedule capability → **W1 HITL 确认卡**（HitlApprovalCard）approve → 创建落库，R1；daily_at 08:30，thread=当前会话）→ 到点（或测试用小 interval）自动触发 → 用户次日打开对话窗。**checklist（S-a · R14，逐项过/不过）**：①消息流出现「[定时任务 · 晨间巡检]」user turn + Agent answer；②任务面板卡片 running→done 状态迁移可见（折叠区计数徽标非零信号）；③点击卡片轨迹回放 drawer 呈现完整执行时间线；④goal chip 仍 active 且本轮装配带 goal 注入（span goal_injected=1——④依赖 R-P3-6 密钥债，密钥未换时允许走录制替代并降级标注）。
**S2 · 定时 HITL 链**：schedule instruction 触发写类 capability **ops.write.run_note**（R17 · S-d：仓内唯一真实业务写，manifests/ops.write.v1.yaml:27，hitl.required+幂等键齐备）→ run 挂 hitl.waiting → 卡片转「待审批」→ 用户在 web（+iOS，若 T10 已合）经锚定滚动的消息流 hitl 卡审批 approve → resumed→done 全链；审批不过期/执行权过期 TTL 语义（03 §0）回归不破。
**S3 · 错过补跑幂等**：api 容器停止跨过 ≥2 个 fire 时点 → 重启 → 30s 内**补跑且仅补一次**（ops_schedule_fires 台账行数=1，uq 幂等键实证）→ next_fire_at 推进到未来；**判据加（R10）：fires.run_id 非空且对应 run 达终态**——claimed 孤儿行不得残留（启动补链实证）。

**三级裁定（S-a · R14 可操作化，承 11 §9.3 体例）**：
- **成立** = 工程判据全过 + S1 ①②③ 人工验收过（④span 依赖 R-P3-6 密钥债，密钥未换时允许走录制替代并降级标注）。
- **部分成立** = 工程判据过但「等交付」心智体验有缺口——**枚举闭合清单**：(a) 面板折叠态下用户无引导找不到交付；(b) 定时徽标缺失/归因错误；(c) 回放 drawer 打开失败；(d) 用户不在场 + run error 无任何感知面（R18 · S-e，本波已知缺口：web 无通知机制，消息流留有 error turn 兜底）；(e) 移动端审批/交付缺位（人签不落时如实登记，R21/Q5）。**清单外缺口一律升级复议，不得裁「部分成立」**。
- **不成立** = 触发/幂等/交付链有红 → 失败分流 §11，触发设计复议。

**T11 报告分两表（R19 · S-f）**：表一=验证假设裁定（S1-S3 三级裁定）；表二=治理放量结果（admin memory 端点/页 + summaries 对拍）。

---

## 8. D-H · iOS

### 8.1 hitl 审批落地波次：本波解签实施

active task task_lg-rag-hitl-approval_v1.md 状态 pending（HG-TASK-DRAFT approved · **HG-AUDIT-R1 未签拒派 30**；依赖 T1 契约层 + T2 chat 主链路合并 master——勘察 §三.2）。**裁定：本波由 lead 推动维护者解签 HG-AUDIT-R1，解签后按既有 task 范围实施**（LgRagHitService decide/resume 两端点 · resume_mode 三值 inherit 编码 omit · 卡片六态与 web 零分叉 · replay.cursor 仅暂存）。iOS 任务单**独立于 api/web 主线排期**——人签不落不阻塞 P3 主线；若本波人签终不落，hitl 移动闸整体顺移至下波，**S2 样例 iOS 半改判 web 单端**（三级裁定如实登记「移动端审批缺位为已知债」，非「部分成立」的掩饰口径——Q5 明判）。

### 8.2 APNs「留接口」具体形态：T1 契约文档草案（R3 · PB3）

**裁定：留接口 = T1 契约文档内 device-tokens-v1 草案章节（纯文档）；DDL/端点实施顺移至 Swift 推送代码落地波**（届时表+端点+发送管线一个 PR 收口）。理由（product B3）：本波无 Swift 推送代码（勘察 §三.4：iOS 零 registerForRemoteNotifications）→ register 端点建好即零 caller 空转，违阶段纪律 2「不预搭未来形态的空壳」——与 §4.2 propose→confirm 后置同一把尺。
- **契约草案内容**：ops_device_tokens 表结构提案（id · tenant_id · user_id · platform ∈{ios} · **token_hash** · created_at · last_seen_at；**uq(tenant_id, token_hash)**——device_token 存 hash 不存明文，R13-N3）；POST /api/ops/devices/register（upsert by token_hash）· POST /api/ops/devices/unregister 端点形态；CurrentUser 鉴权 + tenant 谓词。
- **本波不做**：APNs provider HTTP/2 连接、证书/密钥运维、UNUserNotificationCenter/registerForRemoteNotifications Swift 代码、hitl.waiting→推送的发送 worker。触发时机：hitl 移动闸上线后出现「审批在飞人不在场」真实痛点 → 下波议发送管线（届时 APNs client 库计入该阶段依赖名额）。
- 协议面零改动：hitl.waiting 帧 payload 已含审批必要信息（freeze 内），未来推送负载直接映射该 payload，无需预留字段。

### 8.3 契约 freeze 修订波次安排

**零修订**（D-B §2.4 已判）。hitl 所需帧族 hitlWaiting/hitlResumed 已在 freeze 内（LgRagFrame.swift:68,71）；任务卡片/回放走 REST 不经流。本波三端无契约同步波次。**iOS 任务卡片/回放 UI = 后续候选登记**（R23 · 盲点4：web 有面板而 iOS 连 runs 列表端点的消费计划都无，属能力差不属漏项，验收时照此登记）。

---

## 9. 风险登记

| # | 风险 | 缓解 |
|---|------|------|
| R-P3-1 | interval loop 漂移：tick 内 fire 处理慢 → 后续 fire 延迟 | batch=50 上限 + fire 异步落 run（start_run_worker 不 await，router.py:487 先例）；tick 周期 env 可调 |
| R-P3-2 | daily_at 时区/DST 边界算错（zoneinfo 算术） | 单测覆盖 DST 切换日；配置注释钉明 v1 边界；文案人类化钉「北京时间」（R20） |
| R-P3-3 | schedule 触发 run 无用户在场，写类 capability 挂 hitl 无人审批 → run 滞留 waiting_approval | 卡片「待审批」态可见 + HITL TTL（approval_expired 409）既有语义兜底；S2 样例验收；用户不在场+error 无感知面登记已知缺口（R18） |
| R-P3-4 | 幂等转正 DB（persistence 默认 db）改变默认行为面：旧测试/部署假设 null | R9 四条件：docstring 改写 + env 四分回归矩阵 + fail-closed/显式 null 两回归 + 风险登记（R-P3-10）；.env.example 注释 + runbook |
| R-P3-5 | session_summaries 摘要质量差 → 长会话答案退化 | 对照会话验收（§5）；回退=关 env 即时 |
| R-P3-6 | Langfuse 密钥债未偿 → S1-S3 与放量对拍无 span 证据 | 列为 T7/T11 前置条件（维护者换密钥）；无密钥则证据走录制替代路径并如实标注（S1 ④ 降级条款） |
| R-P3-7 | HG-AUDIT-R1 人签不落 → iOS hitl 顺延 | §8.1 降级路径预置（S2 改 web 单端如实登记）；不阻塞主线 |
| R-P3-8 | runs 列表端点放大查询面（长 thread runs 多） | keyset 分页 + 上限 50/页；idx_ops_lg_rag_runs_thread 索引已在（20261114_lg_rag_runs.py:37-44）；归属 404 校验（R5） |
| R-P3-9 | schedule 被滥用作攻击面（创建高频 interval 打爆 LLM 预算） | **interval_seconds ≥300s 硬校验 + per-user 20 枚 + per-tenant 200 枚双上限（R4）** + 422 人类化文案（R20）+ **预算归因=creator 身份**（§1.8）+ LLM 预算既有软限额兜底 + create_schedule 走 W1 HITL（R1，创建动作本身有人工闸） |
| R-P3-10 | 幂等转正后：capability 热路径每次调用新增 DB 写；DB 故障 → capability 面 fail-closed 可用性耦合（R9④） | 风险如实登记；fail-closed 回归进 T6 验收；DB 为既有单点基板不新增耦合面 |
| R-P3-11 | PATCH 改排期重算 next_fire_at 与 tick 抢火的低概率竞态（R13-N5） | 重算守卫：重算值必须 > now，否则取行锁串行化；登记低概率 |
| R-P3-12 | RunEventBus _history 无界内存债被 schedule 放大的 run 量推高（R13-N6） | 登记债；多副本化/长运行治理时与 RunWorker 租约同批处理（P4） |
| R-P3-13 | schedule 创建者被删号 → 悬空 schedule 持续触发烧预算 | fire 前 user 存在校验（R11 · SP1）：悬空 → fires.status=failed + schedule 自动 paused |
| R-P3-14 | admin 跨租户运维面被误当租户管理员面（R7） | T1 契约钉死语义 + 03-security-audit §4「运维面例外」+ /admin/memory 页明示 maintainer 可达；purge 同缺口登记不本波收紧（SP3） |

---

## 10. D-I · 任务切分（契约先行 · 双泳道三仓错峰 · R22）

**双泳道**：**证伪主线**（验证假设关键路径）T1→T2→T2b→T3→T4→T8→T11；**并行治理线** T5/T6/T7/T9（任何一单滑期不阻塞 T11）；**独立人签波次** T10。**资源紧张时砍单序 = T9→T7→T5**（治理线按价值逆序砍；T6 幂等转正便宜且是多副本前置实际偿债，保留主线侧）。

| 单 | 仓 | 泳道 | Scope | 验收 | 依赖 |
|----|----|------|-------|------|------|
| **P3-T1** 契约文档 | workspace | 主线 | docs/contracts 新增 schedule-v1 / lg-rag-runs-read-v1 / admin-memory-v1 / **device-tokens-v1（草案章节：表结构+register/unregister+token_hash 约定，纯文档，R3/N3）**；词表（schedule_kind/status/catchup/fires.status 四值）+ runs 投影字段钉死；**422 人类化错误文案词表**（上限/非法词表，R20）；「[定时任务]前缀非归因依据 · fires 台账唯一真源」钉死（R12）；**admin 面=跨租户运维面钉死 + 03-security-audit §4 运维面例外（含 purge 同缺口登记，R7/SP3）**；「现落库 event_type=freeze 客户端词表无需脱敏」核实结论（R5）；04-roadmap §P3 回写占位 | 契约文档齐 + HG-AUDIT-R1 签收 | 无（**最先行**） |
| **P3-T2** Schedule DDL+REST | api | 主线 | ops_schedules + ops_schedule_fires 迁移（可逆；fires 状态机四值 + run_id 索引 R10/N4）；store；§1.6 四端点；单行化/词表/**双上限 20/200（R4）**/interval ≥300s 校验；**thread_owner==creator 校验（R6）**；PATCH 重算守卫（N5）；422 人类化文案（R20） | 单测全矩阵（非法词表 422 · 第 21 枚 422 文案 · 跨 tenant 404 · 并发创建幂等 · thread 归属 422/404 · PATCH 重算守卫）；迁移 upgrade/downgrade | T1 |
| **P3-T2b** create_schedule capability | api | 主线 | 新增写类 capability（R1）：既有闸链全过（V1 幂等键 · W1 HITL「创建定时任务=承诺未来 LLM 花费」· tenant_scoped）；执行体直调 T2 store 创建行；web 零改动（确认走既有 HitlApprovalCard） | 闸链单测（无幂等键拒载/HITL 必挂/tenant 谓词）；对话化创建冒烟（用户指令 → HitlApprovalCard approve → schedules 行落库 + 双上限生效） | T2 |
| **P3-T3** Schedule worker | api | 主线 | §1.1 interval loop + §1.4 DB 抢占（**ON CONFLICT DO NOTHING**）+ §1.5 补跑 + **启动补链（claimed AND run_id IS NULL 超时行）** + 触发通路（落 user turn + create_run + **start_run_worker 显式传 creator 身份**，§1.8）；lifespan 启停（auto_resume 同构）；**总闸 OPS_SCHEDULE_ENABLED 默认 off 三件套（§1.7）**；fire 前复核（归属 R6 + user 存在 R11）；审计日志三元组（R12） | S3 补跑幂等实证（**fires.run_id 非空且 run 达终态** · claimed 孤儿零残留）；ON CONFLICT 竞态测试（并发 tick 仅一胜）；**off 态 TestClient 零 diff**；**预算归因验证**（schedule 触发的 run usage/span user_id==creator）；悬空 user → failed+paused 实证；外来 thread → failed+留痕实证；审计日志三元组落盘 | T2 |
| **P3-T4** runs/events 只读端点 | api | 主线 | GET threads/{id}/runs（**thread_owner 404**，R5 · 投影+分页 · fires 按 run_ids IN 批量反查 N4）+ GET runs/{id}/events（**assert_run_owned 404** · ≤500+truncated · **event_type 白名单过滤至 freeze 词表**，R5） | 契约测试：分页边界/归属 404/超截断标志/**白名单过滤实证**（构造词表外 event_type 行验证不外泄） | T1（与 T2 并行） |
| **P3-T5** admin memory 端点 | api | 治理线 | §4.1 三端点（facts 浏览/revoke/episodes 只读）；AdminSyncAuth 复用；**revoke 复用 service.py:168 revoke_by_key · 已撤销 200 affected=0**（R7）；审计日志 | revoke 状态机单测（revoked 不可逆 · 重复 revoke 200 affected=0）；未授权 401/403 零写 | T1（并行） |
| **P3-T6** 幂等转正 | api | 治理线 | OPS_CAPABILITY_PERSISTENCE 默认 db + **R9 四条件**（persistence.py docstring 改写「部署动作非代码默认值 · 刻意不做自动探测」· env 四分回归矩阵 · fail-closed+显式 null 两回归 · §9 R-P3-10 登记）；**device_tokens 实施已顺移（R3）**，本单只剩幂等转正 | 默认面防重双调实证；env 四分矩阵回归；fail-closed + 显式 null 回退验证 | T1（并行） |
| **P3-T7** summaries 放量对拍 | api | 治理线 | §5 验收全量（token 对拍脚本+对照会话+缓存命中观测）；放量 runbook | 压缩率报告+3 条对照会话记录 | T1；**前置=Langfuse 密钥（R-P3-6）** |
| **P3-T8** web 任务面板+回放 | web | 主线 | §2.2 任务面板（**计数徽标** R16）+ **定时任务子区**（active/paused 渲染 + 行内 pause/resume/cancel + ElMessageBox 双确认，R2）+ TaskCard + §2.3 六态映射（**待审批点击=锚定滚动消息流 hitl 卡**，R15）+ §3 drawer/timeline；store 帧增量接线 | pnpm lint/test/build 绿；六态截图归档；回放渲染三 run 型（done/error/disconnected）；定时子区 pause/resume/cancel 双确认交互；锚定滚动验收 | T1+T4（+T2 schedules 端点） |
| **P3-T9** web admin memory 页 | web | 治理线 | /admin/memory 路由+浏览表格+revoke 双确认；**页面明示 maintainer 可达非租户管理员**（R7） | 页面验收+撤销后列表状态迁移（200 affected=0 幂等展示） | T1+T5（与 T8 并行） |
| **P3-T10** ios hitl 审批 | ios | 人签波次 | 既有 task_lg-rag-hitl-approval_v1.md 解签实施（范围不动） | 六态与 web 零分叉对照截图；xcodebuild 过 | **HG-AUDIT-R1 人签**+T1；独立波次 |
| **P3-T11** 验收样例+报告 | api+web | 主线 | S1-S3 执行 + 三级裁定（S-a 可操作化清单）+ 验证报告**分两表**（验证假设裁定 / 治理放量结果，R19）· 承 12/13 体例 | §7 判据全过+裁定落盘；移动端缺位如实登记（R21） | T2b+T3+T8 |

依赖图：主线 T1 → T2 → {T2b, T3} · T4（T1 后并行）→ T8(T4+T2) → T11(T2b+T3+T8)；治理线 T1 → {T5→T9, T6, T7} 并行面；T10 人签独立。每单 ≤1 PR，过闸体例同 P1/P2a/P2b（10 起草 → 20 审查 → HG-AUDIT-R1 → 30 实施）。

---

## 11. 失败路径

| 失败 | 行为 |
|------|------|
| schedules 表查询/写入异常（worker tick 内） | logger.exception + 下周期重试（auto_resume 同构，不炸 lifespan） |
| 单次 fire 触发失败（run 创建异常） | fires.status=failed + 台账留痕；next_fire_at 已推进不重打 |
| 进程崩溃留 claimed 孤儿行（run_id IS NULL） | lifespan 启动首轮补链（§1.5） |
| fire 前复核：thread 已易主（外来 thread） | fires.status=failed + 台账留痕，不投递（R6） |
| fire 前复核：创建者 user 已删（悬空） | fires.status=failed + schedule 自动 paused（R11） |
| schedule REST 词表外/跨 tenant/非 thread_owner | 422 / 404 / 422（零写） |
| interval <300s / 超双上限（user 20 · tenant 200） | 422 + 人类化错误文案（R4/R20） |
| PATCH 重算 next_fire_at ≤ now | 重算守卫拒绝或行锁串行化（N5） |
| OPS_SCHEDULE_ENABLED 非法值 | 回退 off + logger.warning（§1.7） |
| create_schedule 无幂等键/无 HITL 声明 | 加载期拒载+warn（V1 闸链既有语义，R1） |
| runs/events 端点 run 不存在/跨 tenant/非归属 | 404 |
| events 含词表外 event_type（未来内部帧） | 白名单过滤不外泄（R5） |
| revoke 已 revoked/superseded fact | **200 affected=0**（幂等成功，R7） |
| 幂等 DB store 不可用（DB 连接故障） | capability 调用 fail-closed（persistence 闸既有语义）+ span 告警（R-P3-10） |
| session summary 生成失败 | continuity.py:387 既有降级=不注入摘要，装配回退原文窗口 |

---

## 12. 非范围

- cron 表达式/rrule 日历语义、schedule 的 goal_id 显式绑定、向进行中 run 注入消息
- RunWorker DB 租约、_SCAN_TASK 多副本改造、熔断/预算/nonce 外置（全部登记 P4 债）
- Redis 现役引入（任何形态）
- **ops_device_tokens 实施**（DDL+register/unregister 端点+发送管线——本波仅 T1 契约草案，顺移 Swift 推送波，R3）；APNs 发送管线与 Swift 推送代码；iOS 轨迹回放 UI 与任务卡片面（R23 后续候选）
- **跨会话 schedule 全局管理页**（R2 登记后续）；admin 越权读面（v1 不开，R5）；episodes 单条撤销（N2）
- propose→confirm（02 §4 B 方案 agent_notes）；记忆配置面（env 直读维持）
- goal 新端点（创建走懒创建 · P1 面已够）；「等交付」推送通知（APNs 留接口=契约草案即全部）
- SSE 任何新帧；契约 freeze 任何修订；FC 重估；MCP/skill 面改动

---

## 13. 红线自检

| 红线 | 自检 |
|------|------|
| 不破 lg-rag-sse-v1 freeze | ✅ 零新帧（§2.4）；iOS unknownEventType 抛错面零触达；events 端点白名单过滤至 freeze 词表（R5） |
| 不破 tenant freeze F1-F6 | ✅ 两张新表全含 tenant_id；REST 面跨 tenant 404；只读端点 per-user 归属 404（R5）；schedule 创建/PATCH thread_owner==creator（R6）；worker 触发谓词带 tenant；**admin 面=跨租户运维面例外已钉死并写进 03 §4**（R7，非破例是语义明示） |
| 阶段纪律（≤1 新外部依赖） | ✅ **零新依赖**（asyncio/zoneinfo stdlib + element-plus 同库件） |
| 独立可回退 | ✅ Schedule 总闸默认 off（§1.7 · off 态 TestClient 零 diff）；幂等显式 null 回退（R9③）；summaries env 回退；web 面纯增量 |
| 不预搭 UI 空壳 | ✅ propose→confirm 后置（§4.2）；**ops_device_tokens 降级为契约草案、实施顺移**（R3——「建好即空转」形态已消除，自检措辞与裁定一致）；跨会话全局管理页不预建（R2） |
| 先盘点复用再规划新建 | ✅ 复用面：auto_resume 周期任务纪律 / hitl SKIP LOCKED 先例（hitl/store.py:261-277）/ DbIdempotencyStore / AdminSyncAuth / revoke_by_key（service.py:168）/ HitlApprovalCard 模式 / ops_lg_rag_runs 投影 / el-drawer+timeline 同库件 / 既有 capability 闸链+W1 HITL（create_schedule 零新闸面） |
| importlinter 零新边 | ✅ Schedule 落 app/ops/schedule/ 新模块挂 router，create_schedule 走既有 manifest 通路，无跨模块新边预期（T2/T2b 验证） |

---

## 14. 评审确认点明判（Q1-Q6 关闭登记）

| # | 点 | 明判 |
|---|----|------|
| Q1 | schedule_kind 三值 + daily_at 时区默认 | **裁可**（product）：三值覆盖 ops 三类真实场景；daily_at 默认 Asia/Shanghai + S-g 人类化文案「每天 08:30（北京时间）」（R20）；once_at 保留（「半小时后提醒我」是真实高频话术） |
| Q2 | 任务面板内嵌 ChatView 折叠区 | **裁可**（product）：内嵌折叠区——与「Agent 为核心、面板降级」定位一致；附 S-c 计数徽标（R16）+ PB2 定时任务子区并入同一面板（R2）两前提 |
| Q3 | 幂等默认转正 db 的行为面变更 | **接受默认转 db**（platform）· 附 LB6 四条件（R9：docstring 改写 + env 四分回归矩阵 + fail-closed/显式 null 两回归 + 风险登记） |
| Q4 | OPS_SCHEDULE_ENABLED 默认取值 | **默认 off**（platform LB5 · R8：非法回退 off · on 才创建 task · TestClient 零 diff · 行为由部署决策激活） |
| Q5 | iOS hitl 人签不落的降级路径 | **裁可**（product）：人签不落 → S2 改判 web 单端 + 如实登记「移动端审批缺位为已知债」，不阻塞主线，非「部分成立」掩饰口径 |
| Q6 | S1-S3 样例与三级裁定口径 | **有条件裁可**（product+platform）：条件 = S-a 判据可操作化（R14）+ S-d 钉具体写类 capability ops.write.run_note（R17）+ S1 创建主体按 PB1 回填（R1）——**三条件本稿已全部落实，Q6 关闭** |
