# 03 · 安全、人工闸与审计

> 裁定议题：#23 议题6（安全与闸）。platform 提案，三方一致。

## 裁定：工具级三档权限 + 单一 approval 闸 + 全量审计表，三件套一次到位

**不做 RBAC 大体系；权限标注在工具上。**

### 1. 权限模型 = 工具级三档标注

写在 ToolRegistry（见 02 文档）里，零额外系统：

| 档 | 行为 | 例子 |
|---|---|---|
| `read` | 自动执行 | issues/PRs/graph 查询 |
| `write` | 需人工闸（approval） | 文件写、Artifact 生成 |
| `admin` | 人工闸 + 二次确认；iOS 端降级仅展示 | 删数据、改配置、对外发送 |

- v1 仅预置邀请账号、无注册，**不做多角色 RBAC**——1 个真实用户做 RBAC 是过度设计。
- 产品原则（product）：写能力默认全闸、只读工具默认放行；**闸的 UI 优先级高于工具生态丰富度**——先保证 1 个写操作 + 完整审批流，再谈扩展。

### 2. 人工闸 = 单一审批端点（LangGraph 原生）

- LangGraph `interrupt()` 在 write/admin 工具调用前挂起；SSE 推 `approval_required` 事件到 Web，前端弹确认卡；恢复用 `Command(resume=...)`。几乎零自研，与已决策的"轻量版人工闸"一致。
- **approval 必须建模为独立 REST 资源**（architect 硬约束），而非 run 的状态字段——否则 iOS 审批、超时自动拒绝、审计都要返工。
- 闸成为编排图一等节点后，P3 的执行轨迹回放顺带免费获得。
- **时机纪律（platform）**：写能力的真实风险面在 P2/P3 才打开，但闸的骨架必须在 P1 前就和 ToolRegistry 一起建——事后补闸 = 给每个工具重做拦截，成本翻几倍。P2a 依赖配额优先给 interrupt 审批链。
- 断线安全：审批状态由 checkpointer 持久化；前端重连后恢复 pending 审批卡。

### 3. 审计 = 一张 append-only 表

```
audit_log(ts, session_id, tool, args_json,
          decision[auto/approved/rejected], result_hash, latency)
```

- 所有工具调用（含只读）全量记录；PG 单表 + 分区，不上 ELK。
- L2 记忆确认（propose_note 的 approved/rejected）也落同一审计表，decision 来源从工具闸换成记忆闸。
- 审计查询界面 v1 不做，直接 SQL。
- 保留策略：90 天分区 + 冷数据导出腾讯云 COS。

### 4. 端侧安全切面

- iOS：admin 级操作仅展示不可执行；审批是 iOS 的核心价值场景（见 00 文档）。
