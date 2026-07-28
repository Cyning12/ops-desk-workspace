# Harness 30 Prompt · normalize-default-branch（workspace）

> 用法：Open Folder = `ops-desk-workspace` 根；**须维护者先批准 push**；再粘贴复制区。

---

`````text
你是 Harness 30（含 40 自检）。Open Folder = ops-desk-workspace 仓根。

读：
- docs/tasks/active/task_normalize_default_branch.md
- docs/harness/reviews/task_normalize_default_branch_audit_R1_20260728.md
- docs/05-plan/03-post-go-live-hygiene-orchestration.md（棒 C）

纪律：
1. 若 task 表 HG-PUSH-CONFIRM 仍为 pending：输出计划后 STOP，不 push、不改 default、不删分支。
2. 维护者批准后：回填 HG-PUSH-CONFIRM=approved，再执行。
3. 顺序强制：push 现有任务分支（ahead 8，禁止 force）→ 推/建 origin/main → gh repo edit --default-branch main → 确认 → 再删远程任务分支。
4. 将本 task、R1、统筹文档若未入库则提交到 main。
5. 不部署、不改 api/web/ios。

完成后：贴 gh defaultBranchRef 与 ls-remote 结果。
`````
