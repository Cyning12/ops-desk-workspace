# 02 · 工具、技能与记忆

> 裁定议题：#23 议题3（工具生态）、议题5（记忆与上下文）。
> C1（MCP 时机）三方裁定进 P2b；C2（skill 加载器时机）2:1，组织人按多数裁定进 P2b。

## 1. 工具生态裁定

**裁定：内部工具一律走私有 Function Calling；MCP 仅作 client 消费第三方 server，适配器进 P2b；不做 MCP server。**

### 理由（platform 立场，architect R2 收回"MCP 优先"后一致）

- v1~P2 阶段工具消费者只有自己的 Agent，自建 MCP server 是纯增协议层与维护面。
- 模型仅 API（SiliconFlow/百炼），FC 兼容性参差；私有协议可自控 schema 复杂度并做降级（不支持 FC 的模型退化为 ReAct 文本解析），MCP 帮不上这个忙。
- 1 人团队：MCP 的进程管理/传输/重连是一整套生命周期代码；私有协议 = 一个 Python 装饰器。**每阶段只引一个新外部依赖，P2a 的依赖配额留给 LangGraph interrupt 审批链。**
- GitHub 数据经已有 kimi-code sync 入库，P2a 读数走私有只读工具即可，不依赖 GitHub MCP。

### 硬约束（architect R2）

**ToolRegistry 的工具描述 schema 从第一天起与 MCP Tool Schema 字段级对齐**（`name` / `description` / `inputSchema`），使 P2b 的 MCP 适配器（`langchain-mcp-adapters`）只是"远端工具 → 注册表条目"的翻译器，零返工。

### ToolRegistry 最小实现（P2a 内）

- 位置：ops-desk-api；装饰器注册 + JSON Schema 导出 + **权限标注字段**（见 03 文档）。
- P2a 工具 = 硬编码注册的几个 Python 函数（3~5 个只读工具：issues/PRs/graph/overview 查询），不需要 skills/ 目录（product）。
- LangGraph 节点不直接感知任何外部协议，换取未来换协议的自由。
- **冒烟测试**：P1 就用一个测试集钉死 SiliconFlow/百炼各模型的 tool_call 输出稳定性，别等 P2 才发现兼容性坑（platform）。

## 2. Skill 裁定

**裁定（组织人按多数）：最小 skill 加载器与 Skill 体系一并进 P2b，与 MCP 同批；P2a 不做。**

- 少数意见（platform）：P2a 含约 50 行的最小加载器（扫 `ops-desk-workspace/skills/*.md`、解析 frontmatter、按描述注入 system prompt），理由是避免提示词硬编码在 api 仓。——记录在案；P2a 期间提示词以 api 仓配置文件形式过渡，P2b 迁入 skills/ 目录。
- 多数意见（architect + product）：P2a 工具就是硬编码注册函数，加载器无真实消费者；先有写操作的真实需求，再建生态。
- P2b 口径："文件即技能、启动加载、重启生效"；版本管理/依赖/远端分发/热更新等高级特性**再往后**。
- 载体与分发：Markdown（YAML frontmatter + 指令正文）放 `ops-desk-workspace/skills/`，Git 分发——版本控制、review、回滚免费获得，不建"技能市场"。与 DSH skill 机制同构，符合 workspace 总调度仓定位。

## 3. 记忆模型裁定：三层，L2 禁止自动写

**裁定（platform 提案，architect/product 附议）：**

| 层 | 载体 | 内容 | 读写方 |
|---|---|---|---|
| L1 会话记忆 | PG（runs/run_events，见 01 文档） | 当前会话全量消息 + 思考过程 | Agent 读写；checkpointer 只存内部状态 |
| L2 工作记忆（跨会话） | PG `agent_notes` 表 | 用户确认"记住"的事实、任务结论摘要 | Agent 只读自动；**写入必须人工确认** |
| L3 知识库 | PG + pgvector（现有底座） | ops 文档、issue/PR 快照、技术图谱 | 离线 ETL 写入；Agent 只读 RAG |

### 关键纪律

- **禁止"Agent 自动总结写长期记忆"**——业界记忆系统最大的脏数据来源；1 人团队无力做记忆清洗管线。
- L2 写入交互（platform R2 设计）：Agent 调 `propose_note(content)`（read 级，自动执行）→ 落 `proposed` 行 → SSE 推 `note_proposal` 事件 → 前端渲染确认卡（复用 approval 卡片组件）→ 确认进检索集 / 驳回留审计。检索只查 `confirmed`。零新机制：复用 approval 端点与审计表。
- 产品补充（product）：**已确认的 L2 记忆必须可浏览、可单条删除**，放审批/设置界面，不做独立页面。价值：记忆对用户透明可控，避免"Agent 背着我记了什么"的信任损耗。
- 上下文窗口管理借鉴 billion-context 折叠思路但**不引入它**：P1 先"滑动窗口 + issue 上下文重注入"，折叠摘要放 P3。

### agent_notes 表（platform R2，单表双态）

```sql
agent_notes(id, session_id, content, source_msg_id,
            status TEXT CHECK(status IN ('proposed','confirmed','rejected')),
            created_at, confirmed_at)
```

### 容量纪律

- PG 单库承载 sessions + run_events + 向量，Lighthouse 配置有限：run_events 是 append-only 大表，P1 就要定归档/压缩策略；pgvector 索引用 IVFFlat + 定期 vacuum，知识库先只做 ops 域，不做通用文档库。
