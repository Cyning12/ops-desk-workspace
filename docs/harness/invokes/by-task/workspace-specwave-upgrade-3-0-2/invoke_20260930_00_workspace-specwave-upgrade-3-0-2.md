# Invoke：00 · workspace-specwave-upgrade-3-0-2（统筹签收 + 派工）

| 字段 | 值 |
|------|-----|
| hat | 00 |
| task_slug | `workspace-specwave-upgrade-3-0-2` |
| related_review | `docs/harness/reviews/task_workspace_specwave_upgrade_3_0_2_audit_R1_20260930.md` |
| git_branch | `task/workspace-specwave-3-0-2` |
| started_at | 2026-09-30 |

## 00 裁定

> 「更新specwave到最新版本」（web + workspace；api 另波）  
> 「签收当前task，后续过程文档授权00签收，完成后PR 通过CI后merge，最后CLOSE」

| 项 | 结论 |
|----|------|
| 目标钉 | `spec-wave@3.0.2`（自 3.0.0） |
| hooks 物化 | **不入库**（删 `.cursor/hooks.json` + `.claude/settings.json`；本仓原无后者） |
| schema v2 | 不强制 |
| 范围 | 本仓 + ops-desk-web；**api 不在本波** |

### 闸复签

| human_gate_id | status | 依据 |
|---------------|--------|------|
| HG-GRAPH-MODULES | approved | R1 A-2 补行 · graph_delta=none 实体不适用 · 依仓内惯例登记 |
| HG-TASK-DRAFT | approved | 00 本窗授权 |
| HG-AUDIT-R1 | approved | R1 PASS-with-conditions（内容零阻塞）· 00 授权签收 |

### P-1 闸序倒置留痕（诚实口径）

30 先于 20-R1 执行完毕、`verify --task` 曾 BLOCKED(exit 2) 属实（task 已自陈）。R1 **不追认**既成实现；00 依二次授权签收并承担判认：本波为过程轨 patch 热修（依赖钉版 + 文档字面 + 图谱戳），未触碰子仓与业务代码。该倒置不得成为先例。

### R1 非阻塞发现闭合（A-1 ~ A-6）

| ID | 处置 |
|----|------|
| A-1 `AGENTS.md` 钉字面漂移（**中**） | 闭合：:113 业务节 + :155 仓内定制块 → 3.0.2 |
| A-2 `HG-GRAPH-MODULES` 行缺失 | 闭合：补行 approved（前提纠正：本仓确实定义/引用该闸） |
| A-3 缺思考轮节 W4 warn | 已声明合法豁免轨 |
| A-4 D5 依赖 CI 步骤名 `Graph compile test` | 闭合：`test_strategy_note` 写明依赖 |
| A-5 关账面（related_pr / PR·CI） | 闭合：invoke 落盘 + PR 后回填 `related_pr` |
| A-6 F-3 用语精度 | 闭合：改「hooks 物化（入库前）」；补 F-6 / F-7 |

## 派工板

| 序 | 帽 | 工作包 | 状态 |
|----|----|--------|------|
| 1 | 30 | 钉版/upgrade/字面/host update（无 hooks）/验收/FEEDBACK | done |
| 2 | 20 | R1 审查文 | done |
| 3 | 00 | 闸复签 + A-1~A-6 闭合 + invoke 落盘 | **本窗** |
| 4 | 00 | push + PR | **本窗** |
| 5 | 00 | CI 绿 → merge | **本窗**（授权「通过CI后merge」） |
| 6 | 00 | CLOSE（归档 active→done + done/README 索引 + KPI） | merge 后 |

> **WIP 保护**：本仓 `main` 携带既有未提交文档 WIP（`docs/05-plan/` · `07-design/` · `08-interview/` · `contracts/` · `tmp/` 等）。本窗**禁用 `git add -A`**，仅按路径白名单暂存；R1 §D 已独立复核 WIP 未被触碰。
