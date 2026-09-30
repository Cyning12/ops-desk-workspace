# Invoke：30 · workspace-specwave-upgrade-3-0-2

| 字段 | 值 |
|------|-----|
| hat | 30 |
| task_slug | `workspace-specwave-upgrade-3-0-2` |
| related_review | `docs/harness/reviews/task_workspace_specwave_upgrade_3_0_2_audit_R1_20260930.md` |
| git_branch | `task/workspace-specwave-3-0-2` |
| started_at | 2026-09-30 |

## GATE_VERIFY

| human_gate_id | status | evidence |
|---------------|--------|----------|
| HG-GRAPH-MODULES | approved | task 表 · graph_delta=none（R1 A-2 补行） |
| HG-TASK-DRAFT | approved | task 表 · 00「更新specwave到最新版本」 |
| HG-AUDIT-R1 | approved | R1 PASS-with-conditions · 00 二次授权签收 |

结论：**30 开工前置齐备**（本波 30 实为先行执行 · 闸序倒置已由 00 留痕判认 · 见 00 invoke P-1 节）

## 30 落地面（实际执行）

| 项 | 结果 |
|----|------|
| 钉版 | `package.json` + `package-lock.json` → `spec-wave@3.0.2` |
| upgrade | `3.0.0 → 3.0.2` · manifest `from_version=3.0.0` |
| host update | PASS · `kit_semver=3.0.2` · 新增 `table_source.kind=builtin` |
| hooks | **不入库**：删 `.cursor/hooks.json` + `.claude/settings.json`（从未入库） |
| sync prompts | 11 skip · 1 conflict · 手合 `TASK_TEMPLATE.md` 1 hunk（与包内逐字节一致） |
| pins 钉面 | `.github/workflows/harness.yml:20` → `spec-wave@3.0.2`（`pins check --consumer` 1/1） |
| 钉版字面 | `scripts/graph-compile.sh` · `docs/01-scope/01-harness-tech-graph-strategy.md` · `AGENTS.md`（R1 A-1 补漏） |
| 验收 | `check` / `verify --task` / `pins check --consumer` 1/1 / graph-compile（零产物 diff） |
| FEEDBACK | `docs/spec/doc-health/feedback/2026-09-30_3.0.2_workspace_upgrade.md` |

**子仓改动：零**；**`main` 遗留 WIP：未触碰**（R1 §D 复核确认）。
