# Ops Desk Kimi Code 迁移项目文档

本目录用于沉淀 Ops Desk Kimi Code 功能迁移到国内腾讯云自购服务器的全部立项、分析、选型与计划文档。

## 文档结构

```
docs/
├── 01-scope/                 # 项目范围与目标
│   ├── 00-project-brief.md
│   ├── 01-harness-tech-graph-strategy.md
│   └── 02-cross-repo-communication.md
├── 02-backend-analysis/      # 后端现状与改造方向
│   ├── 00-current-state.md          # 文首含 2026-09 现状快照；§1 起为迁移前分析
│   ├── 01-sse-chat-design.md
│   └── 02-api-code-reading-guide_v1_zh.md
├── 03-frontend-analysis/     # 前端现状与 Vue3 重构方向
│   └── 00-current-state.md
├── 04-infrastructure/        # 服务器、域名、备案、预算、运维
│   ├── 00-server-recommendation.md
│   ├── 00-local-postgresql-setup.md
│   ├── 01-environment-setup.md
│   ├── 02-prod-env-reload.md  # 生产改 .env 如何真正进容器
│   ├── 03-ops-desk-secret-incident.md  # 2026-08-17：密钥丢失 / 重发邀请码
│   └── 04-rag-embed-cold-start_note_20260817.md  # 记录：本地 bge-m3 冷启动 → retrieve 分钟级
├── 05-plan/                  # 迁移路线图 · Agent 完善 · RAG
│   ├── 00-migration-roadmap.md
│   ├── 01-epic-task-backlog.md
│   ├── 02-epic6-implementation-plan.md
│   ├── 03-post-go-live-hygiene-orchestration.md
│   ├── 04-agent-completion-roadmap_v1_zh.md   # 线 A · 应用 Agent（总册见 Desktop/cyning-ai-program）
│   ├── 05-rag-pipeline-walkthrough_v1_zh.md
│   └── 06-rag-week-checkin_2026W33_zh.md
├── contracts/                # 跨仓接口契约
│   ├── README.md
│   ├── auth-v1.md
│   ├── data-v1.md
│   ├── chat-stream-v1.md
│   ├── chat-tool-context-v1.md
│   ├── admin-sync-v1.md
│   └── rag-knowledge-contract-v1.md
├── tasks/                    # workspace 侧 task（多为历史/卫生）
└── harness/                  # harness invoke / review 样例
```

## 快速链接

- **现真值（实现仓）**：后端 `../ops-desk-api/` · 前端 `../ops-desk-web/` · iOS `../ops-desk-ios/`
- 前端历史源（迁移前）：`/Users/cyning/Desktop/Projects/ai-ink-brain/app/ops/kimi-code/`
- 后端历史源（迁移前）：`/Users/cyning/Desktop/Projects/ai-ink-brain-api-python/api/ops/`
- 后端 LLM Provider 历史源：`/Users/cyning/Desktop/Projects/ai-ink-brain-api-python/api/ops/llm/`
- 父工作区（历史）：`/Users/cyning/Desktop/Projects/AGENTS.md`
- **三线总册（转行/HE 分仓）**：`/Users/cyning/Desktop/cyning-ai-program/PLAN_dual_track_v1_zh.md`
- **本仓 Agent 完善**：[`05-plan/04-agent-completion-roadmap_v1_zh.md`](./05-plan/04-agent-completion-roadmap_v1_zh.md)
- **后端现网快照（2026-09）**：[`02-backend-analysis/00-current-state.md`](./02-backend-analysis/00-current-state.md) §0

## 状态

- [x] 创建文档目录
- [x] 完成前后端现状分析（**迁移前**；现网以 §0 快照为准）
- [x] 完成基础设施选型与预算
- [x] 完成迁移路线图
- [x] 人确认：四仓库结构、Element Plus、SSE 流式方案
- [x] 人确认：Chat 历史保存、数据同步、鉴权模式、默认 LLM、iOS 范围、部署编排
- [x] 人确认：废弃 graph.json、轻量版人工闸
- [x] 完成核心跨仓契约：auth / data / chat-stream / admin-sync（另有 RAG / tool-context 契约）
- [x] **迁移主线已上线**：生产域名 [cynaya.cn](https://www.cynaya.cn)；Chat 产品主路径为 **lg-rag SSE**（`POST /api/ops/lg-rag/stream`）；旧 `POST /api/ops/chat/stream` → **410**（T6）
- [x] 线 A / RAG / Capability：**已大幅推进**（supervisor + SO Gateway + Capability Gateway；`ops_knowledge_chunks`；默认 Qdrant 可降级 pgvector）
- [x] **§10.7 subtask 过程可见全链闭环**（2026-09-08）：running 起步帧 api [#125](https://github.com/Cyning12/ops-desk-api/pull/125)+web [#38](https://github.com/Cyning12/ops-desk-web/pull/38) · step 里程碑 api [#127](https://github.com/Cyning12/ops-desk-api/pull/127) · 客户端 reveal 队列 web [#39](https://github.com/Cyning12/ops-desk-web/pull/39) · 可读 `message` api [#130](https://github.com/Cyning12/ops-desk-api/pull/130)+web [#41](https://github.com/Cyning12/ops-desk-web/pull/41) · 实流响应式修复 web [#43](https://github.com/Cyning12/ops-desk-web/pull/43)；相关 task 全部 CLOSE 归档
- [ ] 线 A 剩余：按 `04-agent-completion-roadmap` 补齐评测 / Demo 证据 / 仍开放的 P1–P2 项（总册 cyning-ai-program）

> ~~AI 下一步：后端数据库 DDL + LangGraph 节点详细设计~~ — **已过时**（迁移主线与 lg-rag 编排已上线；DDL/Alembic 与节点设计随 api 仓演进）。

## 仓库地址

| 仓库 | SSH 地址 |
|---|---|
| workspace | `git@github.com:Cyning12/ops-desk-workspace.git` |
| web | `git@github.com:Cyning12/ops-desk-web.git` |
| api | `git@github.com:Cyning12/ops-desk-api.git` |
| ios | `git@github.com:Cyning12/ops-desk-ios.git` |
