# Invoke · 40 棒复测 · 联调 C6 修复后复测（stage-w-e2e-join-acceptance）

| 字段 | 值 |
|------|-----|
| **棒** | 复测执行棒（issue #311 回接条款 · 验收收尾回执） |
| **时间** | 2026-11-04 10:44–10:49 Asia/Shanghai（02:44–02:49 UTC） |
| **task** | api `task_api_w_hitl_tenant_fix`（active · 四闸 approved · HG-W-TENANT-DESIGN auth311 签） |
| **修复合入** | PR [#313](https://github.com/Cyning12/ops-desk-api/pull/313)（api · merge `7800b2b` · 2026-11-04 02:19 UTC · 「HITL resume 链租户快照还原 + delegation 单据租户戳 + 消费守卫扩列」） |
| **环境** | 本地双栈（api `uvicorn :8000` + PG/Qdrant 容器）· 双租户 fixture（A=`ops-desk-pilot` / B=`ops-desk-pilot-b`）· api master @ `7800b2b` · **不触生产** |
| **缺陷锚** | N-R2-1（resume 链零租户引用 · B 单被 A 上下文消费 · 回执 `d6bd262904544232` 错标 `ops-desk-pilot`）+ F3（delegation 类单据 `tenant_id=''` 真空）+ 消费守卫真空（`nodes.py:499-504` 仅 capability_write 类查租户） |

> **A6 合规声明**：本次复测 decide（批准）为授权窗口下的会话操作（复测性质 · 与 invoke_20261103 终验声明同轨）；无脚本化绕过审批语义。旧错标回执 `d6bd262904544232` 为历史数据，仅作对照读取，不回填。

---

## §1 主链（B 租户 · SSE 路径）—— C6 口径逐条达成 ✅

| # | 步骤 | 实测 | 判定 |
|---|------|------|------|
| 1 | B 身份发起写（supervisor 图 · `POST /api/ops/lg-rag/stream`） | run `c2224431d5f149ac84deb3c47d7a255b` → 拦单 `hitl_6cb7bec8a4db48058fec` | ✅ |
| 2 | **打戳**（F3 修复实证） | 单据 `tenant_id='ops-desk-pilot-b'`——delegation 类新单不再真空 | ✅ |
| 3 | B decide approved | 200 · `decision_note=retest311-B-approve-sse`（02:44:48 UTC） | ✅ |
| 4 | **A 身份 resume B 单**（手动入口守卫实证 · HG-W-TENANT-DESIGN ①） | **403** `tenant_scope_denied：该申请属于租户 ops-desk-pilot-b，与当前会话租户 ops-desk-pilot 不一致` | ✅ |
| 5 | B 身份 resume 本租户单 | 200 · `resume.status=accepted` · replay persisted | ✅ |
| 6 | 消费日志租户（N-R2-1 修复实证） | `capability_write_approval_consumed {…"approval_id":"hitl_6cb7bec8a4db48058fec","tenant_id":"ops-desk-pilot-b"…}`（02:45:13 UTC · api 日志）——对照旧错标 `d6bd262904544232`（tenant=`ops-desk-pilot`）不再复现 | ✅ |
| 7 | 回执租户 | 回执 `f14068d3b77c40f7` · `tenant_id='ops-desk-pilot-b'` · ok=t · write_confirmed=t | ✅ |
| 8 | 守卫扩列（消费级 · 裁决②） | B 消费在「还原上下文=单据租户」下通过（正样本**不误拒**）；跨租户入口已被步骤 4 的 403 拦截 | ✅ |

## §2 负样本

- **历史空租户单 fail-closed**（裁决③）：`hitl_b28a21f4982e43b0983a`（`tenant_id=''` 42 行历史 delegation 类之一）resume → **409**「申请行 tenant_id 为空 —— 无法还原租户上下文，拒绝恢复（历史空租户单据不回填；如需恢复请走单独授权的数据修复）」——`_resume_row_tenant` fail-closed 实证，从严不回填落实。

## §3 A 租户正样本（零变化回归）

- run `f068634363844e738d0c65885c29ce06` → 拦单 `hitl_c730997675354088b53d`（`tenant_id='ops-desk-pilot'`）→ decide 200 / resume 200 → 回执 `e8c64c784a00479e`（`tenant_id='ops-desk-pilot'` · ok=t · write_confirmed=t）。
- 判读：PR #313 对 A 租户主链**零行为变化**——打戳正确、消费正常、守卫不误伤。

## §4 测试面佐证

- `pytest tests/test_hitl_resume_tenant_fix.py` → **8 passed**（修复任务自带红→绿用例）。
- hitl 回归 6 文件 161 用例仅 1 个本地失败：`test_ta4_consumption_hit_does_not_waive_gateway_or_policy`——系本地 `.env` 的 `OPS_CAPABILITY_ALLOW_WRITE=1` 经 `app.config` load_dotenv 渗透 `os.environ` 所致（非代码回归 · CI 无 `.env`）；以 `OPS_CAPABILITY_ALLOW_WRITE=0` 复跑同文件 → **48 passed** 坐实。

## §5 附带观察（如实记录 · 非 PR #313 引入 · 不在本 task 处置）

| # | 现象 | 定位 | 建议去向 |
|---|------|------|----------|
| O1 | **sync `POST /api/ops/lg-rag/invoke` 不落 run 事件帧** → hitl decide 归属反查（`router.py:240-243 _run_owner_of` → `event_store.run_owner`）返回 None → decide 404「申请不存在」；拦单落库正常但永远 pending，resume 无从谈起。invoke 面实测拦单 `hitl_503224fd719a42c8b0fa`（run `8b4f3caf…`）因此滞留 pending | api `app/ops/hitl/router.py` 归属反查依赖事件帧；sync invoke 路径无帧 | invoke 面 HITL 可用性缺口，建议另行立项（与 #311 修复无因果：SSE/web UI 路径不受影响） |

## 结论

- **C6 复测口径全部达成**：B 租户发起写→拦单打戳→B approve+resume→消费日志/回执 tenant=`ops-desk-pilot-b`→守卫真空不复现；跨租户 403、空租户 409、A 正样本零变化三向实证齐。
- N-R2-1 / F3 / 消费守卫真空三缺陷均修复实证，从严口径（历史 '' 不回填）按裁决③执行。
- 遗留观察 O1（invoke 面 decide 404）登记备查，建议维护者决定是否立项。
