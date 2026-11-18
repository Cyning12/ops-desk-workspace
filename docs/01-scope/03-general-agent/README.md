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
| [05-discussion-log.md](05-discussion-log.md) | 四轮讨论立场全录、冲突点裁定表、R3 代码校验对照（可追溯） |
| [06-kickoff-readiness.md](06-kickoff-readiness.md) | **开工就绪包**：R4 终局裁定、P0' 任务卡（T1–T7）、开工检查表 |
| [07-p1-goal-design.md](07-p1-goal-design.md) | **P1 设计终稿**：Goal 状态机/装配层注入/唯一新 DDL/任务切分 T1–T5（R5 终裁） |
| [08-p2a-tools-design.md](08-p2a-tools-design.md) | **P2a 设计终稿**：面板四视图→四枚只读 capability（query_issues/query_pull_requests/get_overview/graph_snapshot）· 租户口径 · 验证假设四样例 · 任务切分 T1–T4（R6 终裁） |
| [09-p2a-capability-mcp-mapping.md](09-p2a-capability-mcp-mapping.md) | **P2a-T3 MCP 对齐评审**：CapabilitySpec 24 字段 ↔ MCP Tool 全对照 · 两处有损映射专行 · 差距 14 项三选一 · P2b 翻译器需求 7 条（字段族冻结 · 不回改 manifest） |
| [10-p2a-verification.md](10-p2a-verification.md) | **P2a 验收记录**：四样例真 LLM 冒烟 4/4 · 三级裁定成立 · 判据 (a)-(f) 逐条证据 |
| [11-p2b-mcp-skill-design.md](11-p2b-mcp-skill-design.md) | **P2b 设计终稿**：MCP client 桥接（零新依赖薄 transport · kind=mcp 翻译器 · 毒 description 三板斧）+ skill 加载器（DSH 裁剪移植 · skill_ref 按需装配）· 任务切分 T1–T5b（R7 终裁） |
| [12-p2b-verification.md](12-p2b-verification.md) | **P2b 验收记录**：T5b 真社区 server 冒烟 3 命中+4 不命中 · 三级裁定成立（R-A1 未触发）· env 开启 runbook · P2c 评估建议 |
| [13-p2b-skill-verification.md](13-p2b-skill-verification.md) | **P2b skill 验收记录**：T5a 选择质量冒烟——when_to_use 两轮调优后命中 3/3 · 不命中 2/2 · P2a 复跑 4/4 · 裁定成立（夜间小样本 · 新增 skill 须复跑） |
| [14-p3-schedule-taskcard-design.md](14-p3-schedule-taskcard-design.md) | **P3 设计终稿**：Schedule（进程内 loop+DB 抢占 · 总闸默认 off · fires claimed 状态机+启动补链 · 双上限 20/200+interval≥300s）· create_schedule 走 W1 HITL 对话化创建 · 任务卡片=run 投影（web 内嵌面板+定时子区）· 回放 REST（归属 404+白名单过滤）· L2 admin 浏览/撤销（跨租户运维面钉死）· 幂等转正 DB 附四条件 · 双泳道任务切分 T1–T11（R8 终裁） |
| [15-p3-contracts.md](15-p3-contracts.md) | **P3 契约文档**（T1）：Schedule REST 四端点 schema + 双上限/interval 人类化 422 文案词表 · create_schedule manifest 草案（W1 HITL「创建定时任务=承诺未来 LLM 花费」）· runs/events 只读（归属 404 · event_type 白名单=freeze 词表核实成立）· fires 台账状态机+「前缀非归因 · fires 台账唯一真源」声明 · admin memory 三端点（跨租户运维面钉死）· device_tokens 草案（顺移 Swift 推送波）· 总闸/幂等环境契约 |
| [16-p3-verification.md](16-p3-verification.md) | **P3 验收记录**（T11）：S1 定时交付全链 / S2 定时 HITL 链（web 单端）/ S3 停跨时点补跑幂等 三样例逐判据过 · 三级裁定**部分成立**（缺口限枚举内 (b)(d)(e)）· 波内小修 PR #433（图 state user_id）· 分两表（验证假设裁定 + T5/T6/T7 治理放量）· 偏差 9 条 |
| [17-p2c-planner-verification.md](17-p2c-planner-verification.md) | **P2c planner 验证**（T2 选定率真 LLM 冒烟）：T1 硬化验收——选定率组 5/5（hit-echo 泛化问法首跑命中 · 弱面改善实证）· P2a 回归 4/4 零劣化 · 域外负例纯 rag 正确 · skill H1 复跑命中 · 三级裁定**成立** · 新发现 F1-F4 |
| [18-p4-generalization-design.md](18-p4-generalization-design.md) | **P4 设计终稿**：通用化两线最小切片——领域包三件套文件级覆盖（prompt 目录回退 · manifest domain→tags 注入 · RAG 按域 fail-closed · 多域不得共库 · 域=部署级 OPS_DOMAIN）+ Run 树（runs 三列+uq 委派 claim · 深度 1 结构性无环 · 总闸默认 off · 帧面零新增树只进 REST 投影 · 子 run HITL 退出-重跑-消费闸放行 · 令牌子侧签发+配额归并父桶）· 双泳道任务切分 T1–T9 · 砍单序 T4→T3→T8（R9 终裁 · R1-R25 全关闭 · Q1-Q7 明判） |

## 一页结论

1. **定位**：Agent 为核心，运维面板降级为 Agent 的只读工具与可视化产物，不做"两个模式"（降级是目标态，拆可验收步骤——现状四面板仍在主导航前五位）。
2. **底座**：不嵌入 DSH；LangGraph 已是现役执行引擎（supervisor 五阶段图），薄 harness 的真正新增概念主要是 Goal 与 Schedule。
3. **执行**："异步为体、SSE 为用"的内核已在现网（进程内 RunWorker + 事件表 + cursor replay）；缺口是多副本 DB 租约/独立 worker 进程化，非新建。
4. **工具**：ToolRegistry = 现役 Capability 体系（27 文件）；权限采用现有 side_effect 四档词表；MCP client 与最小 skill 加载器同批进 P2b；FC 主路径为开放裁定项。
5. **记忆**：三层维持；L2 已有双表 + 抽取管线（默认全关）——"禁止自动写"落实为"默认关 + 人工可审"；L3 实为 Qdrant 默认、pgvector 降级。
6. **安全**：HITL 审批全链已交付并 freeze（decide→resume 两步、TTL"批准不过期执行权过期"、四入口前端）；审计为分域多表 + 统一视图；新风险：未鉴权 demo WS 端点待下线。
7. **路线**：P0' 收敛与默认开启（checkpointer 默认开、旧 chat 遗产下线、run 实体化裁定）→ P1 在既有 supervisor 图上收敛 Goal → P2a 面板数据工具化 → P2b 生态 / P3 任务化 → P4 通用化（不设排期）。
