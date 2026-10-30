# 跨仓接口契约

本目录存放 Ops Desk 四仓库之间的对接契约。

## 契约列表

| 契约 | 文件 | 说明 | 消费方 |
|---|---|---|---|
| Auth | `auth-v1.md` | 登录、Session、登出 | web、ios、api |
| Data | `data-v1.md` | Overview/Issues/PRs/Graph/Models | web、ios、api |
| Chat SSE | `chat-stream-v1.md` | SSE 流式对话 | web、ios、api |
| Admin Sync | `admin-sync-v1.md` | GHA sync 数据接入 | api、GHA workflow |
| GitHub main Ruleset | `github-main-ruleset-v1.json` | 导入 Rulesets：main 仅允许 PR（需 Pro/Team） | 四仓 Settings → Rules |
| Tenant readonly（草稿） | `api-v1-tenant-readonly-context-draft.md` | 阶段 T 只读多租户请求上下文 · **未 freeze** | web、api（ios 后置） |

另：CI workflow 触发约束（`pull_request` + `push` → `main`）见 `docs/04-infrastructure/01-environment-setup.md` §10.3，不在本目录契约内。

## 使用方式

- **后端实现前**：先确认契约已在 workspace 定稿并通过 `HG-AUDIT-R1`。
- **前端/iOS 实现时**：直接引用本目录下的契约文件，按字段和事件类型消费。
- **后端实现后**：如有微调，同步更新契约文档，并在 workspace task 中记录变更。

## 变更流程

1. 在 workspace 修改契约文档。
2. 更新 `docs/_tech_graph/` 中的对应节点。
3. 重新进入相关子仓 task，按新契约实现。
