# Invoke · 10 帽 · C8 证据归档（stage-w-e2e-join-acceptance）

| 字段 | 值 |
|------|-----|
| **帽** | `10`（task/文档 · C8 证据归档棒 · 纯文档轨零业务码） |
| **时间** | 2026-11-02（实测窗口 09:00–16:00 · Asia/Shanghai · 时间戳正文用本地时，DB 原文 UTC+00 已换算标注） |
| **task** | `docs/tasks/active/task_stage_w_e2e_join_acceptance.md`（三闸 approved · 过程轨） |
| **环境** | 本地双栈：api `uvicorn :8000` + web `vite :5173` + PG/Qdrant 容器（`ops-desk-api-db-1` / `ops-desk-api-qdrant-1`）· Fixture 轨双租户（`ops-desk-pilot` / `ops-desk-pilot-b`）· **不触生产**（HG-E2E-ENV 口径） |
| **截图资产** | api 仓 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/screenshots/`（8 张 · 见 §C7） |

> **A6 合规声明（前置）**：本联调全部 decide 均为维护者真人手操（/hitl 页或 Chat 浮层），无脚本 / 无 auto-approve；resume 不属于 decide，其中一次由 00 铸会话 curl 补位（UI 无入口 · 见 §6），A6 红线未违。

---

## §1 · C1–C7 逐项结论与证据锚

### C1 · 环境就绪 ✅

- api：`uv run uvicorn app.main:app --reload --port 8000`（首启 job `bash-386d57e8d5204ca0`；TTL 实验重启 `bash-f05870bcbc914fe6`；恢复默认 `bash-983b0b662ace4bde`）· `/health` 200 · `/docs` 200
- web：`npx -y pnpm@10.32.1 dev`（job `bash-9138cf67b5ee4865`；仓 `devEngines` 钉 pnpm@10.32.1 与 corepack 11.28.5 冲突，故 npx 钉版启动）· **`http://localhost:5173`**（vite 绑 IPv6，`127.0.0.1` 不通）· 代理 `/api → 127.0.0.1:8000` 已验证（`/hitl/pending` 未登录 401）
- 依赖容器：PG `:5432` / Qdrant `:6333` healthy · `QDRANT_URL` 默认 `http://127.0.0.1:6333`（api `app/ops/rag/backend.py:36`）
- env 口径记录：`OPS_HITL_AUTO_RESUME` **未设 → 默认 manual（显式续跑链）** ✅ 与 task 预期一致；`OPS_HITL_PERSISTENCE=db`（`.env:53`）；策略 env 追加 `testing.write.echo` 生效（日志 `strategy 候选 env 追加集生效：count=1 ids=['testing.write.echo']`）

### C2 · 发起 echo 写 → 拦单挂起 ✅

- 真人从 web Chat 发「写入"面试加油"的文件」→ run `f9453b7f1c9a4dc79aa469773931e7c6` · thread `fa4a46ca72024db9a92cb8d2b9b0a030`
- 拦单落库：`hitl_ef414f4a2b464bd69bbb`（2026-11-02 09:22:00 本地 · `blocked_by=delegation_issue_hitl_required` · `tenant_id=''` · reason「委派签发需人工审批（capability testing.write.echo 非只读（side_effect=write））」）
- **审批前零写执行**：run events 止于 seq14 `done/waiting_approval`（`ops_lg_rag_run_events`）
- 注意：实跑拦单来自**既有 delegation 签发闸**（api `app/ops/lg_rag/multi/nodes.py:553` `_delegation_issue_block_reason`），**非**阶段 W 新 W0 写执行闸（`nodes.py:1875` 附近未触发）——见发现 F3

### C3 · approve 全链 ✅

- 真人 decide：/hitl 页 approve **09:24:27**（`decision_by=admin` · manual 模式 · 页面严格两步）
- resume：页面无已决单续跑入口（F1）→ **00 补位 curl** `POST /api/ops/hitl/requests/hitl_ef414f4a2b464bd69bbb/resume`（09:43:04 · 详见 §6）
- 事件链（`ops_lg_rag_run_events` seq15→25）：`hitl.resumed`（approved=[`:2`] · decided_by=admin）→ `delegation_approval_consumed`（ttl 余 2465s）→ `delegation token_issued dt-1-96f286f90bf6` → **`capability_write_approval_consumed`**（`approval_id=hitl_ef414f4a2b464bd69bbb` · `tenant_id=ops-desk-pilot`）→ `token_verified` → echo 执行（seq19 · 语义 mock `written:false` 测试专用）→ `answer(final)`（seq23）→ `done status=resumed`（seq25 · latency 103s）
- 回执：`ops_capability_receipts` **`98d28309f55f4f58`**（`write_confirmed=t` · `tenant_id=ops-desk-pilot` · 2026-11-02 01:43:21Z）

### C4 · reject 路径 ✅

- run `03d500d21bd74eb7936ed032a5ca7f8d` · thread `bb00d5278aa7442aaa4c48669e1009e6`
- 真人驳回（Chat 浮层 · **09:47:59** admin）→ 浮层**链式 decide+resume**（`stores/chat.ts:1300` · 85ms 后自动 resume，见 F6）→ 日志「HITL 未获批准（驳回或无授权），收工」→ 驳回答复落帧（seq9 answer 明示「这步没做、因为没批」）
- **写未执行**：`ops_capability_receipts` 该 run 零行
- 三单全 rejected：`hitl_c84b69d633db4de9bc5c`（09:47:59）· `hitl_4392b09f12d2401190f9`（孤儿单 · 10:07:29 · F9）· `hitl_50e1f310da7640d4862b`（重规划新单 · 10:07:45 · F7）
- 第二驳回曾误点旧卡（c84b 已 rejected）→ decide **409 幂等拒绝**（防重放实证 · F2）

### C5 · 审计链核对 ✅（span 级受限如实标注）

- 正链可串（同一 `approval_id=hitl_ef414f4a2b464bd69bbb`）：审批决策（decide 日志 `HITL 浏览器决策 … decision=approved by=admin`）→ resume（`hitl.resumed` 载荷含 `decided_by=admin`）→ 消费（`capability_write_approval_consumed {"approval_id":"hitl_ef414f4a2b464bd69bbb", …}`）→ 写执行回执 `98d28309f55f4f58`
- 反链：run `03d500d2` 三驳回零回执（fail-closed 铁证）
- **限制**：span `approval_id` 观测依赖 langfuse 导出，本地 OTLP 持续 403/timeout（`jp.cloud.langfuse.com`）→ **span 级审计本环境不可验**（F5）；以上以本地日志 + DB 回执为据
- 幂等表 `ops_capability_idempotency` 当日零行（echo mock 不走幂等键 · 非缺陷）

### C6 · 跨租户负样本 ✅（实测完成 · 结果超预期：两处缺口坐实）

- B 租户（右上角下拉 `ops-desk-pilot-b`）发「写入'跨租户测试'的文件」→ run `cc56b23119a64d3e81e88b97c2bd668a`（同 thread bb00d527 · **thread 不绑租户** 实测）→ 拦单 `hitl_b4c35664bc10412fa561`（10:13:10 · `tenant_id=''` F3 复现）
- **B 身份真人** approve（10:17:22）+ 页面显式续跑（10:17:24）
- 实测结果：**写执行了，但租户上下文错**——消费日志 `capability_write_approval_consumed {"tenant_id":"ops-desk-pilot"}`（应 `-b`）· 回执 **`d6bd262904544232`** `tenant_id=ops-desk-pilot`（错标 · 02:17:27Z）
- **N-R2-1 坐实**（20-R2 观察点 → 缺陷）：resume 链（api `app/ops/hitl/resume.py`）零 tenant 引用；`app/ops/tenant_context.py:24-26` `current_tenant_or_default()` 回落 `TENANT_A` → B 单被 A 上下文消费且回执错标
- **守卫真空坐实**：delegation 类单据 `tenant_id=''` 且消费守卫仅对 `capability_write` 类生效（`nodes.py:499-504` 注释「委派类单据不进入本守卫」）→ task C6 原断言「写不执行 · 拦单维持」在该路径**无法触发**（非步骤错，码面缺口）
- decide 返 200 属 owner-only 闸预期（api `app/ops/hitl/router.py:213-216` · store 无 tenant 谓词 `store.py:171,184`）——证据如实区分：**owner-404（`hitl-browser-decide-v1`）≠ F4 机制**
- run 终态：answer seq15（10:20:35）· done seq17 ✅
- **未执行子项（如实挂账）**：F4 资源命中面 404（对 B 租户资源 id 只读/写请求）与 F1=C 头/session 不一致 403 **未抽测** → 见 §A4 挂账

### C7 · TC9 承接 ✅（过期态除外 · 如实标注）

- 链路「批准 → 显式续跑 → 回到会话查看」已随 C3 全链跑通（截图 `c7-resumed.jpg`）
- 四态截图（api 仓 `docs/harness/invokes/by-task/stage-w-e2e-join-acceptance/screenshots/`）：
  - **列表态**：`tc9-list-approved.jpg`
  - **空态**：`tc9-empty.jpg`（pending 清零后「无待审批」· admin 视角）
  - **403 态**：`tc9-403-page.jpg` + `tc9-403-network.jpg` + `tc9-403-response-body.jpg`（viewer40 会话 · 响应体 `"Maintainer role required"`）
  - **过期态**：**不可达**（F12 · 详见 §5）
- 闸表截图：`gate-table.jpg`（联调 task 人工闸表三闸 approved）
- 过程补充：`c6-final-answer.jpg`（C6 B 租户最终答复）
- 语义对照表：§4

---

## §2 · 发现清单 F1–F12 + N-R2-1 + 守卫真空

| # | 现象 | 码面定位 | 严重度 | 去向 |
|---|------|----------|--------|------|
| F1 | 已决单无续跑入口：/hitl 只列 pending，decide 后行仅存组件本地态，整页刷新即丢；Chat 浮层渲染 `hitl.waiting` 历史帧快照仍示「待审批」 | web `src/views/HitlApprovalView.vue:61-85`（刷新合并保留本地已决行） | ux | web fix task |
| F2 | 浮层重复点「批准」→ decide 409 ×2（09:38/09:39） | api `router.py` decide 幂等（`store.adecide` 只受理 pending） | by-design（防重放实证，非缺陷） | 记录即可 |
| F3 | delegation 类单据 `tenant_id=''`（建单路径不打租户戳）且消费守卫仅对 `capability_write` 类生效（委派类跳过） | api `nodes.py:~2221`（`term.get("tenant_id")`）· `nodes.py:499-504` 注释 | **gap** | api fix task（可与 N-R2-1 合并设计） |
| F4 | 20-R2 观察点 N-R2-1 探针 | — | superseded | 已被 N-R2-1 独立条目取代（坐实） |
| F5 | SiliconFlow 网络抖动（embed/LLM 超时 · circuit open · supervisor 输出非法 `{"subtasks":[]}` 降级单 rag）· langfuse OTLP 403/timeout | 环境 | noise | C5 span 审计不可验的根因；记录 |
| F6 | 两入口 decide 行为不一致：Chat 浮层卡片 decide 成功自动链调 resume vs /hitl 页严格两步显式续跑 | web `src/stores/chat.ts:1300`（`decideHitl` 链式两调用）vs `HitlApprovalView.vue` | ux | web/freeze 评议（统一或文档明示） |
| F7 | 驳回/过期后 supervisor 重规划重新尝试同一写能力 → 新拦单（c84b 驳回→50e1 · 297b 过期→b28a）· fail-closed 未破但审批轰炸 | api supervisor 重规划无「已驳回/已过期」约束 | **defect** | api fix task |
| F8 | replay 409 写窗被 web 当原始英文错误弹窗「Resume is writing new events; retry after it settles.」 | api `router.py:512`（Retry-After 设计语义）· web 错误呈现层 | ux | web fix task（中性提示+沉降自动重试） |
| F9 | 孤儿单 `hitl_4392b09f`：resume 瞬间（09:47:59.545）为刚被驳回的 `:1` 又建 pending 单 | api `_persist_hitl` 去重只按 `status=pending` 拉取，已 rejected 不在 already 集 | **defect** | api fix task（去重纳入已决态） |
| F10 | 陈旧可点卡片：聊天底部卡片聚合历史 `hitl.waiting` 帧，列出已驳回旧单（c84b+50e1）仍示「待审批」可点 | web Chat 浮层渲染逻辑 | ux | web fix task（与 F1 合并） |
| F11 | 手动 resume 链零 TTL 闸：过期批准（实验 178s > 90s TTL）仍可解锁重跑；自动扫描路径有 TTL 闸（不对称） | api `router.py:520 resume_request` → `:473 _preflight_decided_resume`（全文无 ttl/过期引用）vs `store.py:116-117 aclaim_approved_for_resume` | **defect** | api fix task |
| F12 | api hitl 面无「过期」出口 → web FP-5「审批已过期」态不可达 | api `store.py:22 STATUS_EXPIRED` 无人赋值 · decide/resume 无过期分支 · freeze `task_hitl_browser_decide` 无 TTL 条 | **gap（契约）** | **维护者定夺**：api 补 TTL 分支 or freeze/web 摘态（见 §5） |
| N-R2-1 | resume 链租户上下文丢失：B 租户单批准续跑后消费以默认租户 A 执行且回执错标 `ops-desk-pilot` | api `app/ops/hitl/resume.py` 零 tenant 引用 · `app/ops/tenant_context.py:24-26` 回落 `TENANT_A` | **defect（高优先 · 审计失真）** | api fix task |
| 守卫真空 | C6 消费链 fail-closed 在 delegation 路径无法触发（F3+N-R2-1 叠加） | 同 F3 / N-R2-1 | **gap** | 并入上述 fix task 设计 |

> failure_paths 对照：`resume 出现第二条恢复路径`——**未触发**（resume 单路径 `router._execute_decided_resume` 全程唯一）；`echo 写在审批前已执行`——**未触发**（三驳回零回执）；`本仓误改子仓代码`——**未触发**（A7 机断见 §A7）。

---

## §3 · 闸态证据

- task 人工闸表三闸 **approved**（`docs/tasks/active/task_stage_w_e2e_join_acceptance.md:42-44`）：HG-TASK-DRAFT（2026-10-30 维护者签收 · 00 代录）· HG-AUDIT-R1（20-R1/R2 闭环后维护者授权 00 代录）· HG-E2E-ENV（本地 · Fixture · 不触生产 · 同上授权锚）
- 闸表截图：api 仓 `…/screenshots/gate-table.jpg`
- 审查文：`docs/harness/reviews/task_stage_w_e2e_join_acceptance_audit_R1_20261030.md` · `…_R2_20261030.md`

## §4 · 语义对照表（api freeze/码面语义 vs web 渲染语义 vs 实测行为）

| 维度 | api freeze / 码面语义 | web 渲染语义 | 实测行为 |
|------|------------------------|--------------|----------|
| `hitl.waiting` 帧 | 时点快照（requests 当时态） | Chat 浮层当实时卡片渲染 | decide 后仍示「待审批」（F1/F10） |
| decide | 置已决 · manual 默认不自动 resume · 重复 409 · owner 不明 404 | 浮层：成功自动链调 resume；页面：严格两步显式续跑 | 两入口不一致（F6） |
| resume 409 在飞 | 「该申请的恢复正在执行中」 | FP-H4 分流「恢复进行中」 | 符合（未实测到） |
| replay 409 写窗 | 「Resume is writing new events; retry after it settles.」（Retry-After 语义） | 原始英文错误弹窗 | F8（用户误判为失败） |
| replay | 纯重放 · 零驱动 | 「续看 / 续看推进」按钮 | 用户误以为能推进 run（实测确认） |
| 列表四态 | pending 空集→空态；403→权限红条；过期→**无 api 出口** | `hitl-empty` / `hitl-error-forbidden` / FP-5 mapping | 空/403 实拍 ✅；过期不可达（F12） |
| TTL | 批准不过期 · 执行权过期（消费闸 T1 + 自动扫描 aclaim） | 行级「审批已过期，请刷新列表」mapping | api 无出口（F12）· 手动 resume 无闸（F11）· 消费闸兜底有效（零回执实证） |
| tenant 上下文 | run 入口/HTTP 头设置（`run_worker.py:120` · `router.py:398`） | 右上角租户下拉 | resume 链丢失（N-R2-1 坐实） |
| thread 归属 | 无租户谓词 | 会话列表按用户 | thread 不绑租户（B 租户续用 A thread 实测）→ 评议项 |

## §5 · 过期态「不可达」如实标注（F12 · 维护者定夺项）

- **实验设计**：api 以 `OPS_HITL_APPROVAL_CONSUMPTION_TTL_SECONDS=90` 重启；单据 `hitl_297ba1959e0845138600`（run `68838581bbe640d3ba33baf771968275`）10:29:46 建单 → 10:36:36 批准（+410s）→ 10:39:34 续跑（批准后 +178s > 90s）
- **实测结果**：decide 不因超龄拦截（`store.adecide` 零 TTL 检查 · 设计语义「批准不过期，执行权过期」）；手动 resume 受理（无 TTL 闸 · F11）；**消费闸拒消费**（零回执 ✅ fail-closed 兜底有效）→ 系统静默重规划开新单 `hitl_b28a21f4982e43b0983a`（F7 再现 · 已驳回清场 10:47:11）
- **结论**：api 全链无任何「过期」错误出口（`STATUS_EXPIRED` 定义于 `store.py:22` 但无人赋值）→ web FP-5「审批已过期」行级提示**悬空不可达**，TC9 过期态截图无法诚实复现
- **维护者定夺**（二选一或组合）：
  - (a) api 补过期出口：`adecide`/`resume_request` 对超 TTL pending/approved 返 410 或错误文案（推荐与 F11 同修）
  - (b) freeze/web 修订：摘除或改写 FP-5 过期态（freeze `hitl-browser-decide-v1` 变更走契约闸）

## §6 · 00 补位 resume 记录（A6 合规证据）

| 环节 | 执行者 | 方式 | 时间（本地） |
|------|--------|------|--------------|
| decide ×7（全部） | **维护者真人**（admin） | /hitl 页 或 Chat 浮层 | 09:24:27 / 09:47:59 / 10:07:29 / 10:07:45 / 10:17:22 / 10:36:36 / 10:47:11 |
| resume · C3（ef414f） | 00（补位） | 铸 admin 会话 + curl `POST …/resume`（UI 无入口 · F1） | 09:43:04 |
| resume · C4（c84b） | 浮层自动链调（F6） | decide 成功后 web 链式调用 | 09:47:59 |
| resume · C6（b4c356） | **维护者真人** | /hitl 页显式续跑 | 10:17:24 |
| resume · TTL 实验（297b） | **维护者真人** | /hitl 页显式续跑 | 10:39:34 |

- **A6 判定**：decide 全真人 ✅；resume 非 decide（execution continuation），00 补位不构成脚本化审批 ✅；`auto_resume` 未触发（`OPS_HITL_AUTO_RESUME` 未设 · 补偿扫描四条件不全）
- 会话铸造记录（本地联调用 · 均已备案）：admin 会话（C3 补位 · token 对存 `/tmp/e2e_resume_token.txt`）· viewer40 会话（403 态 · 12h · `/tmp/e2e_viewer_token.txt`）

## §7 · 后续 fix task 建议清单（仅清单 · 不起草正文）

1. **api · N-R2-1（高优先）**：resume 链租户上下文恢复——`resume.py` 从 run/thread 还原 tenant 并 `set_current_tenant`；回执错标修复（回执 tenant 应取单据/运行上下文真值）
2. **api · F3**：delegation 类单据 tenant 戳（`_persist_hitl` 路径补 `current_tenant_or_default()`）+ 消费守卫纳入委派类（或显式文档化豁免理由）
3. **api · F7**：supervisor 重规划注入「该能力已被驳回/批准已过期」约束或终止重试（防审批轰炸环）
4. **api · F9**：`_persist_hitl` 建单去重纳入 rejected/expired 态（同 run+subtask 幂等键）
5. **api · F11**：手动 resume 补 TTL 闸（对齐 `aclaim_approved_for_resume` · 与 F12(a) 合并设计）
6. **web · F1/F10**：已决单续跑入口 + Chat 浮层卡片与 `/hitl/pending` 对账
7. **web · F6**：两入口 decide 行为统一（或文档明示差异）
8. **web · F8**：replay 409 写窗中性提示 + 沉降后自动重试
9. **freeze/api · F12**：过期态出口定夺（§5）

## §8 · 遗留与后续

- **A4 挂账**：F4 资源命中面 404 / F1=C 头-session 403 未抽测（§C6）→ 待维护者补测或定夺降级
- **A5 挂账**：过期态截图缺（F12 不可达）→ 待维护者定夺是否以 §5 记录替代
- **40 自检棒未跑**：`required_invoke_hats=10,00,40`；本棒为 10 归档，40 证据自检与验收勾选核对按 orchestration 链待派
- **CLOSE 归维护者**：本棒不动 task status 字段、不做 done/ 归档
- wiki_delta（CLOSE 时）：`docs/05-plan/05_post_h_stage_brief_v1_zh.md` 阶段 W 行补「双轨联调验收已 CLOSE · 证据锚」

---

### 修订

| 日期 | 说明 |
|------|------|
| 2026-11-02 | 10 帽 C8 棒：C1–C7 证据归档（7 单 2 回执全实证）· F1–F12 + N-R2-1 + 守卫真空清单 · 语义对照表 · 过期态不可达标注 · A6 合规声明 · fix task 建议清单 ×9 |
