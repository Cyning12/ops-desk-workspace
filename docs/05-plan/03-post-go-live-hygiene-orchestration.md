# 00 统筹：上线后收尾卫生（2026-07-28）

> **角色**：00 统筹下发  
> **触发**：维护者指示「先收尾」；分支盘点后 api/ios 已净，web 陈旧远程已删；余下文档归档 + workspace 默认分支归一  
> **状态**：issued（三棒 30 Prompt 已下发，待执行）

---

## 现状快照

| 仓 | 默认分支现状 | 脏工作区 / 债务 |
|---|---|---|
| ops-desk-api | `master` ≡ origin | `task_api_tech_graph_ci` 已 completed 且工作区已移到 `done/`，**未提交** |
| ops-desk-web | `main` ≡ origin（已删合并远程） | `active/` 残留多份 **completed** task + kickoff Prompt；`web-obs-nav-label-en` 已 MERGED 仍标 ready-for-merge |
| ops-desk-ios | `master` | 无分支债务；本波不派工 |
| ops-desk-workspace | 远程 **仅** `task/epic-backlog-and-roadmap`（且为 default）；本地 **ahead 8**；本地有孤立 `main` | 须归一到 `main` |

---

## 派工表（按序）

| # | 仓 | task_slug | 分支 | 阻塞下一棒？ | 说明 |
|---|---|---|---|---|---|
| **A** | api | `post-merge-hygiene` | `task/post-merge-hygiene` | 否 | 归档 commit + PR；禁止在 `master` 直推 |
| **B** | web | `archive-completed-tasks` | `task/archive-completed-tasks` | 否 | active→done；可与 A 并行 |
| **C** | workspace | `normalize-default-branch` | 在现有 `task/epic-backlog-and-roadmap` 上收尾，再切 `main` | **建议 A/B 不依赖，但 C 须维护者确认 push** | push 8 commit → 建/推 `main` → GitHub default → 删任务分支 |

**并行**：A ∥ B；**C 单独**（涉及默认分支与未推送历史，00 要求人确认后再跑 push）。

---

## 非本波（明确不做）

- Epic 8.6 备份、Chat 增强、Epic 7 测试债、iOS 骨架  
- 业务 Python / Vue 功能改码  
- 强制回灌 cyning-harness / P3b 扩面  

---

## 验收（统筹级）

- [ ] api：`active/` 无已完成 tech-graph task；归档已合入 `master`
- [ ] web：`active/` 仅保留未完成项或空；completed 均在 `done/`
- [ ] workspace：GitHub default = `main`；远程无长期任务分支作 HEAD；本地与 origin/main 对齐
- [ ] 四仓 `git branch -r` 无已合并陈旧 task 分支（本波已清 web；再扫一轮）

---

## 下一棒

维护者在各仓 Open Folder 后粘贴对应 **Harness 30 Prompt**（见各仓 `docs/tasks/active/PROMPT_*.md` 或会话下发正文）。

| 修订 | 说明 |
|---|---|
| 2026-07-28 | 00 初版下发 |
