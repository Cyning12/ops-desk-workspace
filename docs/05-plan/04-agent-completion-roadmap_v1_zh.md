# 04 · Ops Desk Agent 完善路线（v1）

| 项 | 内容 |
|----|------|
| **状态** | `active` |
| **日期** | 2026-07-29 |
| **总册** | `/Users/cyning/Desktop/cyning-ai-program/PLAN_dual_track_v1_zh.md` |
| **分册** | `cyning-ai-program/tracks/TRACK_A_ops_desk_v1_zh.md` |
| **Open Folder** | 本仓统筹；实现分别在 `ops-desk-api` / `ops-desk-web` |

> **边界**：本文件只规划 **线 A（应用 Agent）**。完整 HE Runtime → 程序总册线 B2，**不**在本 API 仓实现 coding agent 外壳。  
> **研发模式（H6）**：关键节点人主导（契约 / 首测 / 停条件）；AI 辅助样板与扩展。真值：`cyning-ai-program/docs/DEV_MODE_guided_human_v1_zh.md`。

---

## 0. 人必过节点（本路线）

| 节点 | 建议由人先完成 |
|------|----------------|
| Tool 契约 | 每个新 Tool：名称、参数、权限、错误语义一页 |
| 首条 scenario | 人写第 1 条断言；其余可 AI 仿写 |
| LangGraph 停条件 | 人定「何时结束 / 何时拒答」 |
| Demo 口述 | 人走通并录音或讲稿自检 |

## 0.5 澄清（2026-07-29 · 已齐）

- 主投应用岗；Demo=**生产**；program **已 git init**  
- P0 勾选：见 `cyning-ai-program/docs/P0_TOOL_SELECTION_v1_zh.md`（Core T1+T3+T4+T8+T13）  
- **Ops 内 RAG（P1）**，不以 Ink 作主路径  
- harness-web 不进 P0；不补 Java（口述 WHY_NOT_JAVA）  
- 关键 commit 前缀 `human-node:`  

---

## 1. 目标

把 Ops Desk Chat 从「可对话的 LLM 应用」推进到 **可演示的企业研发助手**：  
**工具化 Graph 节点**（M1）+ 仿真可测 +（P1）Ops 内 RAG；过程保障继续用已嵌入的 cyning-harness。

**用语**：P0 不称「Tool Calling / bind_tools」。  
**Demo**：生产环境上的 **候选增强**（须证据）。  
**主路径**：Issue #n → T1 → T4（可依赖 T3）→ T13 引用。  
**闸**：只读已批 → `cyning-ai-program/docs/GATE_HG_OPS_AGENT_TOOLS_readonly_v1_zh.md`。

---

## 2. 阶段

### P0 · 可演示 Agent

| ID | 项 | 建议落点 | 验收 |
|----|-----|----------|------|
| A-P0-0 | 契约页（P0-Core 合订） | workspace `docs/` · `human-node:` | H6 |
| A-P0-1 | T1+T3+T4+T8+T13 | `ops-desk-api` 节点 | scenario 断言 |
| A-P0-1b | Stretch T2+T6 | 同上 | 尽量同窗 |
| A-P0-2 | scenario ≥5（含故障） | tests 或 `docs/eval/` | 可复跑 |
| A-P0-3 | **生产** Demo 脚本 | 05-plan 或 interview | 主路径 T1→T4 |

### P1 · 生产感

| ID | 项 | 验收 |
|----|-----|------|
| A-P1-1 | SSE 停止 · error · fallback | 生产笔记 + 演示 |
| A-P1-2 | **Ops 仓内 RAG**（非 Ink） | 检索增强可演示 |
| A-P1-3 | 观测字段手填模板 | 对齐 SPEC-evaluation-observation |

### P2 · 受控扩展

| ID | 项 | 闸 |
|----|-----|-----|
| A-P2-1 | 写操作 / 真 GitHub API | `HG-OPS-AGENT-TOOLS`（见 cyning-ai-program/AGENTS.md） |
| A-P2-2 | 与纪律闸联合 Demo（verify 挡错误开工） | 录屏即可，不改 harness 产品边界 |

---

## 3. 测评纪律

- **自建** scenario eval；**不**用 BMH 跑 Ops Chat  
- 详见：`cyning-ai-program/docs/EVAL_and_BMH_boundary_v1_zh.md`

---

## 4. 非目标

- 在 api 仓实现完整 coding agent / sandbox  
- 把 BMH 或 kimi-code Runtime 并入本仓依赖  
- 全量 SWE-bench  

---

## 5. 与既有计划关系

| 文档 | 关系 |
|------|------|
| `00-migration-roadmap.md` | 迁移/上线主线；本文件为 **上线后 Agent 能力** 增量 |
| `03-post-go-live-hygiene-orchestration.md` | 卫生/编排；本文件偏产品 Agent |
| `01-epic-task-backlog.md` | 开具体 task 时从此处拆条 |

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-07-29 | 首版 · 对齐 cyning-ai-program |
