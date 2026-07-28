# Invoke 30 · normalize-default-branch

| 字段 | 值 |
|---|---|
| **hat** | 30 |
| **日期** | 2026-07-28 |
| **task** | `docs/tasks/active/task_normalize_default_branch.md` |
| **触发** | 维护者「进行收尾…棒 C」→ HG-PUSH-CONFIRM approved |

## 计划（强制顺序）

1. 入库统筹 / task / R1 / Prompt / 本 invoke
2. `git push` 任务分支（禁止 force）
3. tip → `origin/main`
4. `gh repo edit --default-branch main`
5. 确认后再删远程 `task/epic-backlog-and-roadmap`
6. 本地切 `main` 跟踪 origin

## 结果

| 步骤 | 结果 |
|---|---|
| push 任务分支 | `ee9ee38..098b5e4` → `origin/task/epic-backlog-and-roadmap` |
| tip → main | 新建 `origin/main` @ `098b5e4` |
| default-branch | `main` |
| 删远程任务分支 | 已删 |
| origin/HEAD | `refs/remotes/origin/main` |
| ls-remote | 仅 `refs/heads/main` |
| 本地 | 在 `main`，与 `origin/main` 对齐 |

**结论**：棒 C 验收通过。
