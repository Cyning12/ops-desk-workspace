# Invoke：30 · workspace-specwave-init-3-0-0

| 字段 | 值 |
|------|-----|
| hat_id | `30` |
| task_slug | `workspace-specwave-init-3-0-0` |
| task_paths | `docs/tasks/active/task_workspace_specwave_init_3_0_0.md` |
| related_review | `docs/harness/reviews/task_workspace_specwave_init_3_0_0_audit_R1_20260918.md` |
| git_branch | `task/workspace-specwave-3-0-0` |

## 执行清单

1. 钉 `spec-wave@3.0.0` + `npm install`  
2. `init --preset harness-only --tools cursor,claude,agents --yes`  
3. `sync prompts` / IDE 块；**删 hooks 若生成**  
4. 最小 `docs/_tech_graph/00_main.graph.yaml` + `scripts/graph-compile.sh`  
5. 策略三文 + AGENTS 纠偏  
6. `check` / `verify --task` / graph-compile；FEEDBACK  

## GATE_VERIFY

三闸 approved → 开工。
