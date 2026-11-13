# OpsDesk 通用 Agent 演进 · 文档套

> 来源：Issue [#23](https://github.com/Cyning12/ops-desk-workspace/issues/23) 方向讨论。
> 产生方式：多轮专家讨论（Agent 架构师 / 产品负责人 / 平台与安全工程师三角立场，两轮：R1 立场陈述 → 组织人整合冲突点 → R2 交叉质询裁定），由讨论组织人整合成文。
> 日期：2026-11-13。状态：**讨论结论稿，待负责人拍板后转为正式决策**。

## 文档索引

| 文档 | 内容 |
|---|---|
| [00-positioning.md](00-positioning.md) | 定位裁定：Agent 为核心、面板降级为工具视图；端侧形态；概念可见性映射 |
| [01-architecture.md](01-architecture.md) | 编排底座（LangGraph + 薄 harness 4 概念）与执行模型（Run/Event 持久化 + SSE 订阅） |
| [02-tools-skills-memory.md](02-tools-skills-memory.md) | ToolRegistry 与权限标注、FC/MCP/Skill 时机、三层记忆模型 |
| [03-security-audit.md](03-security-audit.md) | 人工闸（interrupt + approval 资源）、审计表、保留策略 |
| [04-roadmap.md](04-roadmap.md) | P0' → MVP-1/2/3 → P2b → P4 路线图、各阶段验收标准与依赖 |
| [05-discussion-log.md](05-discussion-log.md) | 两轮讨论立场全录与 5 个冲突点的裁定表（可追溯） |

## 一页结论

1. **定位**：Agent 为核心，运维四面板降级为 Agent 的只读工具与可视化产物，不做"两个模式"。
2. **底座**：不嵌入 DSH；LangGraph 保留为单次 Run 执行引擎，其上自研薄 harness（Run/Goal/Schedule/Skill 四概念，机制裁剪移植自 DSH）。
3. **执行**：一切执行皆异步持久化 Run；SSE 只是 run 事件流的可断线重连订阅通道；PG LISTEN/NOTIFY + 独立 worker，不引 Redis。
4. **工具**：私有 Function Calling 优先；ToolRegistry 的 schema 与 MCP Tool Schema 字段级对齐，MCP client 适配器与最小 skill 加载器同批进 P2b。
5. **记忆**：三层（L1 会话 / L2 工作记忆提议+人工确认 / L3 pgvector 只读 RAG）；禁止 Agent 自动写长期记忆。
6. **安全**：工具级三档权限（read/write/admin）+ LangGraph interrupt 单一审批闸 + append-only audit_log；闸骨架 P1 前必须就位。
7. **路线**：P0'（v1 收尾把 chat 存储直接建模为 runs/run_events）→ MVP-1 多轮 → MVP-2 只读工具进 ReAct → MVP-3 异步任务+审批 → P2b 生态 → P4 通用化。
