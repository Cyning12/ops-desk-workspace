# task_workspace_specwave_init_3_0_0 审查（R1 · 20-task-audit）

> **审查对象**：`docs/tasks/active/task_workspace_specwave_init_3_0_0.md`  
> **日期**：2026-09-18 · **分支**：`task/workspace-specwave-3-0-0`  
> **对照**：api/web 均已钉 `spec-wave@3.0.0`；ios 除外（OpenSpec）

---

## 结论

本审查 **PASS**：范围覆盖 greenfield 钉版、`init --preset harness-only`、prompts/IDE、最小总图与 graph-compile、活文档纠偏，以及 **hooks 不入库** 硬条款；明确 **不做统一分发**、不改子仓。failure_paths 覆盖 init 误伤 S2、hooks、compile 无图。验收可机验。维护者已确认钉版与范围，00 可签闸开工。

实质说明：本仓为文档/编排仓，preset 用 harness-only 正确；与 api fullstack 预设差异属预期。内容零阻塞。

---

## 核对

| 项 | 结果 |
|----|------|
| 目标钉 `3.0.0`（与 api/web 齐） | ✓ 维护者确认 api 已升 |
| greenfield init · S2 不覆盖 | ✓ 范围 A-3 · F-2 |
| hooks 不入库 | ✓ 范围 B-8 · F-4 |
| 废弃统一分发 | ✓ 非范围 + wiki_delta |
| 最小总图进范围 | ✓ C-10 · F-5 |
| ios / 子仓不动 | ✓ 非范围 |

## 签闸建议

HG-TASK-DRAFT / HG-AUDIT-R1 / HG-GRAPH-MODULES → **approved**。

---

## 00 签收（2026-09-18）

维护者：「api 也已经更新至 3.0.0，其他没有问题，统筹此升级 task」。本审查文与 task **一并签收有效**。
