# 04 · 演进路线图与 MVP 切分

> 裁定议题：#23 第 3 节候选路径的修订版。product 主导切分，architect 提供依赖关系，platform 提供依赖配额纪律。

## 最终序列

```
P0' 地基 → MVP-1（P1）→ MVP-2（P2a）→ MVP-3（P3）→ P2b 生态 → P4 通用化
```

P2b 插在 MVP-3 之后的原因（product）：先有写操作的真实需求，再决定生态建设。

## 各阶段定义

### P0' · 地基（v1 收尾，≈2~3 个任务单）

- 内容：runs/run_events 表建模、事件序号协议（seq + Last-Event-ID）、PG checkpointer 接入（只落表）。
- 验收：删掉它 v1 可正常上线；P1 只需改后端、零数据迁移。
- 详见 01-architecture.md 第 3 节。

### MVP-1（P1 · 会话深化）

- 内容：多轮会话状态机（同一 Goal 下多个 Run 的链）、ReAct 循环骨架、思考过程持久化、滑动窗口 + issue 上下文重注入。
- harness 概念：Run + Goal 进代码；UI 只见"任务"。
- 依赖配额（platform）：本阶段唯一新外部依赖配额留给 LangGraph interrupt 审批链骨架。
- **验证假设**：多轮 + 会话记忆是否已能当日常运维助手用。
- 附带：SiliconFlow/百炼 tool_call 稳定性冒烟测试集（为 P2a 铺路）。

### MVP-2（P2a · 工具动手·只读）

- 内容：私有 FC + ToolRegistry（schema 与 MCP 字段级对齐）+ 3~5 个只读工具（面板四视图改造：issues/PRs/graph/overview 查询）挂进 ReAct 循环。
- 安全：工具级三档权限标注随 ToolRegistry 一并落地（闸骨架，read 档自动放行）。
- **验证假设**：「Agent 读面板数据出结论」是否成立——这是定位裁定（00 文档）的技术验证点。
- 不做：MCP、skills/ 目录、写工具。

### MVP-3（P3 · 任务化执行）

- 内容：Schedule/Approval 两张新表 + 首批 write 级工具 + 后台异步执行（PG LISTEN/NOTIFY + worker）+ 对话窗内任务卡片/审批卡片/轨迹回放 + L2 记忆提议-确认交互 + 上下文折叠摘要。
- **验证假设**：「给目标、等交付」的心智是否成立。
- 端侧：Web 嵌入看板组件；iOS 上"移动人工闸"（手动拉取待审批，APNs 留接口）。

### P2b · 生态（MVP-3 之后）

- MCP client 适配器（langchain-mcp-adapters，远端工具 → ToolRegistry 条目翻译器）。
- 最小 skill 加载器（workspace 仓 skills/ 目录、启动加载、重启生效）；skill 高级特性继续后置。
- P2a 过渡期的 api 仓提示词配置迁入 skills/。

### P4 · 通用化（愿景，非承诺）

- 领域配置化（数据源/工具/提示词解耦）、多 Agent（Run 树 / LangGraph subgraph）、面板降级完成态。
- 纪律（product）：在 ops 域内做到 P3 闭环之前，领域配置化没有第二领域检验，做了也是空抽象——**P4 不设排期**。

## 阶段纪律汇总

1. 每阶段最多引入一个新外部依赖（platform）。
2. 不预搭未来形态的 UI 空壳（product）。
3. P0' 的存储 schema 一次设计对，拒绝迁移期双写（architect）。
4. P4 之前的所有抽象必须服务于 ops 域真实闭环（三方）。
