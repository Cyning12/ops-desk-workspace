# Task：workspace 默认分支归一到 main

> **状态**：in_progress（HG-PUSH-CONFIRM 已批准：维护者 2026-07-28「进行收尾…棒 C」）  
> **类型**：Git / GitHub 仓库卫生  
> **关联**：00 统筹 `docs/05-plan/03-post-go-live-hygiene-orchestration.md` 棒 C

---

## Harness 元信息

| 字段 | 值 |
|---|---|
| **task_slug** | `normalize-default-branch` |
| **git_branch** | `task/epic-backlog-and-roadmap`（现有）→ 收尾后以 `main` 为默认 |
| **graph_change_layer** | `none` |
| **review_hat** | `20` |
| **thinking_profile** | `shortest` |
| **invoke_retention_profile** | `minimal` |
| **required_invoke_hats** | `30` |
| **test_strategy** | `recommended` |
| **test_strategy_note** | `git ls-remote` / `gh repo view` 断言 defaultBranchRef=main |
| **code_quality_bar** | `not_applicable` |
| **orchestration** | 00 统筹棒 C；**高风险 Git 操作**；00 代签内容闸，**push/改 default 须人确认** |

### 人工闸

| human_gate_id | status | blocks_hats | 说明 |
|---|---|---|---|
| **HG-GRAPH-MODULES** | approved | **30** | 00 代签：无业务图谱；仅 Git 引用 |
| HG-TASK-DRAFT | approved | 22-R1 | 维护者 2026-07-28：先收尾 |
| **HG-AUDIT-R1** | approved | **30** | 00 代签内容；**HG-PUSH-CONFIRM** 另见下 |
| **HG-PUSH-CONFIRM** | approved | **30** | 维护者 2026-07-28 明示执行棒 C（允许 push + 改 GitHub default） |

---

## 背景与目标

远程仅有 `task/epic-backlog-and-roadmap`，且为仓库 default；本地该分支 **ahead 8**（含 prod deploy / Epic 文档更新）；本地 `main` 落后且未推远程。

**完成态（顺序）**：

1. [x] 维护者将 **HG-PUSH-CONFIRM** → approved（本会话口头即可，执行者回填表）
2. [ ] `git push -u origin task/epic-backlog-and-roadmap`（推送 ahead 8；禁止 `--force`）
3. [ ] 以该 tip 创建/更新远程 `main`：`git branch main <tip> && git push -u origin main`（若 remote 无 main）
4. [ ] `gh repo edit --default-branch main`
5. [ ] 本地 checkout `main` 跟踪 origin；确认 `origin/HEAD` → main
6. [ ] 删除远程 `task/epic-backlog-and-roadmap`（default 已切后）；删本地同名分支（可选）
7. [ ] 将本统筹文档与本 task 提交到 `main`（若尚未包含）

**不做**：`--force` / 改写已推送历史；删其他仓分支；部署动作

---

## 失败路径

| 触发 | 行为 | 可重试 |
|---|---|---|
| HG-PUSH-CONFIRM 仍 pending | **拒推送**；仅报告计划 | 否（等人） |
| default 未切换就删任务分支 | **禁止**；先 `gh repo edit` | 是 |
| push 被拒 | 记录错误；不 force | 人判 |

---

## 验收标准

- [ ] `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` → `main`
- [ ] `git ls-remote --heads origin` 含 `main`；任务分支已删或仅本地留档
- [ ] 本地当前分支 `main` 与 `origin/main` 对齐（允许文档卫生 commit）
