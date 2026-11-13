# 03 · 安全、人工闸与审计

> 裁定议题：#23 议题6（安全与闸）。
> **v2（2026-11-13）：经实地代码调研修正**——初稿把 HITL 闸当作 P1 待建骨架，代码现实是审批全链已交付并 freeze，本版以现状为基线。

## 0. 现状基线（已交付，调研证实）

**人工闸已全链落地**（api PR#303 / web 审批页合 main，2026-10-30 W CLOSE；freeze `hitl-browser-decide-v1`）：

- **挂起**：supervisor 图内 `interrupt()` → SSE `hitl.waiting` 事件（`sse_stream.py:148-173`）→ done{status:waiting_approval}。写类 capability 无新鲜 approved 单据一律挂起，fail-closed（`multi/nodes.py:319-322`，`capability_write_hitl_required`）。
- **审批资源独立**（初稿的 architect 硬约束已满足）：`OpsHitlRequest ops_hitl_requests`（models.py:479-517：status pending|approved|rejected|expired、run_id/thread_id/checkpoint_id/subtask_id/decision_by）；REST 面 GET pending / POST decide / POST resume 等（`app/ops/hitl/router.py`）。
- **恢复语义 = decide → resume 两步链式**（非初稿写的 `Command(resume=...)` 单步）：decide 带 `resume_mode` 三选（inherit/immediate/manual，白名单第四值 400）；resume 经 checkpointer 同源恢复，未开 PG saver 显式 503。
- **TTL 语义已冻结**：「批准不过期、执行权过期」——resume 遇超龄 approved → 409 `approval_expired` + 单据置 expired；旋钮 `OPS_HITL_APPROVAL_CONSUMPTION_TTL_SECONDS` 默认 3600s（`src/api/hitl.ts:19-35`）。初稿"超时自动拒绝"表述作废，以此为准。
- **前端四入口审批面已上线**：Chat 浮层卡（`HitlApprovalCard.vue`）+ 独立 `/hitl` 页（756 行，已决区 FIFO 20、visibilitychange 边沿刷新零轮询）+ 对账机制（服务端已处理而本端未感知时转只读，`isHitlRequestReconciled`）。

## 1. 权限模型裁定（修订）

**采用现役 side_effect 四档词表**（`none/read/write/irreversible`，`capability/types.py:23-24`）+ risk_level 独立维度；详见 02 文档 §2。不做多角色 RBAC（邀请制、viewer/maintainer 两角色已够，`contracts/auth-v1.md`）。

产品纪律维持：写能力默认全闸（现状已 fail-closed）；只读默认放行。

## 2. 人工闸裁定（修订为"验收与复用"）

- 闸骨架"必须先于写能力就位"的目标**已达成**，本节从建设项转为验收项：P0' 验收清单加入"HITL decide→resume 全链回归 + 默认开启 checkpointer"。
- 新增事件（如 L2 记忆的 `note_proposal`，若采纳 02 文档 B 方案）复用 approval 卡片组件与端点，走红线 3 契约评审，不另开机制。
- iOS：契约层已含 `hitlWaiting/hitlResumed` 帧（`LgRagFrame.swift:68,71`），active task `task_lg-rag-hitl-approval_v1.md` 已立项——"移动人工闸"依托 lg-rag 主链路落地，admin（irreversible）级操作 iOS 端仅展示。

## 3. 审计裁定（修订）

**裁定：分域审计表 + 统一查询视图，不另建单一 audit_log 表。**

现状（inv-api 调研）：无 audit_log 单表；等价物为分域多表——

| 表 | 覆盖 |
|---|---|
| `ops_capability_receipts`（models.py:378-410） | 写能力副作用回执，无论成败全量落（gateway.py:25） |
| `ops_capability_idempotency`（:413-441） | 幂等键 |
| `ops_hitl_requests`（:479-517） | 审批决策全量（含 decision_by/驳回） |
| `ops_llm_usage`（:651-688） | LLM 调用用量 |

- 后续工作：统一查询视图（SQL view 或管理端聚合页），并说明与 receipts 的去重关系；v1 查询仍直接 SQL。
- 保留策略：90 天分区 + 冷数据导出腾讯云 COS（维持初稿）。

## 4. 现存安全风险（调研新发现，列入 P0'/v1.1 清理清单）

1. **未鉴权 demo WebSocket 仍注册在路由**：`app/ops/chat/ws.py:1-15`（复用旧 chat 事件，文件头自述 "do not expose publicly"，但路由已注册 `app/ops/router.py:33`）——**裁定：下线或补鉴权，优先下线**。
2. **旧 chat 图代码残留**：`app/ops/chat/graph.py/service.py`（无 checkpointer 的 StateGraph）仍在仓内，随 P0' C-3 一并清理。
3. **已登记缺陷**：resume 链丢失（N-R2-1，`invoke_20261102_10_c8_evidence_archive.md:122`），P0' 跟进。
4. **进程内状态是已登记最大工程债**：熔断/配额/幂等/nonce 全内存、capability persistence 默认 null 不可上生产（`09_general_agent_architecture_direction_v0_zh.md:19`）——多副本化（P3+）的前置。
5. **iOS WebSocket 实验资产**（`IMWebSocketClient.swift` 323 行未接主链路）：裁定去留；若规划推送通道再议。

## 5. 可观测性（初稿遗漏，补记）

Langfuse tracing 已接入图执行（`graph.py:106-146` CallbackHandler + propagate_attributes）；错误 i18n 层与"零轮询"纪律为前端既有工程约束，新功能须遵守。
