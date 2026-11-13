# OpsDesk 通用 Agent 演进 · 文档套

> 来源：Issue [#23](https://github.com/Cyning12/ops-desk-workspace/issues/23) 方向讨论。
> 产生方式：多轮专家讨论（Agent 架构师 / 产品负责人 / 平台与安全工程师三角立场，两轮：R1 立场陈述 → 组织人整合冲突点 → R2 交叉质询裁定），由讨论组织人整合成文。
> 日期：2026-11-13。状态：**v2 代码校验稿**——初稿经两轮讨论产出后，又经三路实地代码调研（ops-desk-api / ops-desk-web+ios / workspace-docs）逐条校验修正，证据见各文档及 05 附录；待负责人拍板后转为正式决策。
> 调研产物存档：`/tmp/opsdesk-rfc/inv-inv-api.md`、`inv-web.md`、`inv-inv-docs.md`（本地）。

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

1. **定位**：Agent 为核心，运维面板降级为 Agent 的只读工具与可视化产物，不做"两个模式"（降级是目标态，拆可验收步骤——现状四面板仍在主导航前五位）。
2. **底座**：不嵌入 DSH；LangGraph 已是现役执行引擎（supervisor 五阶段图），薄 harness 的真正新增概念主要是 Goal 与 Schedule。
3. **执行**："异步为体、SSE 为用"的内核已在现网（进程内 RunWorker + 事件表 + cursor replay）；缺口是多副本 DB 租约/独立 worker 进程化，非新建。
4. **工具**：ToolRegistry = 现役 Capability 体系（27 文件）；权限采用现有 side_effect 四档词表；MCP client 与最小 skill 加载器同批进 P2b；FC 主路径为开放裁定项。
5. **记忆**：三层维持；L2 已有双表 + 抽取管线（默认全关）——"禁止自动写"落实为"默认关 + 人工可审"；L3 实为 Qdrant 默认、pgvector 降级。
6. **安全**：HITL 审批全链已交付并 freeze（decide→resume 两步、TTL"批准不过期执行权过期"、四入口前端）；审计为分域多表 + 统一视图；新风险：未鉴权 demo WS 端点待下线。
7. **路线**：P0' 收敛与默认开启（checkpointer 默认开、旧 chat 遗产下线、run 实体化裁定）→ P1 在既有 supervisor 图上收敛 Goal → P2a 面板数据工具化 → P2b 生态 / P3 任务化 → P4 通用化（不设排期）。
