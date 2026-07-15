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
│   ├── 00-current-state.md
│   └── 01-sse-chat-design.md
├── 03-frontend-analysis/     # 前端现状与 Vue3 重构方向
│   └── 00-current-state.md
├── 04-infrastructure/        # 服务器、域名、备案、预算
│   ├── 00-server-recommendation.md
│   └── 01-environment-setup.md
├── 05-plan/                  # 迁移路线图
│   └── 00-migration-roadmap.md
└── contracts/                # 跨仓接口契约
    ├── README.md
    ├── auth-v1.md
    ├── data-v1.md
    ├── chat-stream-v1.md
    └── admin-sync-v1.md
```

## 快速链接

- 前端现有代码：`/Users/cyning/Desktop/Projects/ai-ink-brain/app/ops/kimi-code/`
- 后端现有代码：`/Users/cyning/Desktop/Projects/ai-ink-brain-api-python/api/ops/`
- 后端 LLM Provider：`/Users/cyning/Desktop/Projects/ai-ink-brain-api-python/api/ops/llm/`
- 父工作区：`/Users/cyning/Desktop/Projects/AGENTS.md`

## 状态

- [x] 创建文档目录
- [x] 完成前后端现状分析
- [x] 完成基础设施选型与预算
- [x] 完成迁移路线图
- [x] 人确认：四仓库结构、Element Plus、SSE 流式方案
- [x] 人确认：Chat 历史保存、数据同步、鉴权模式、默认 LLM、iOS 范围、部署编排
- [x] 人确认：废弃 graph.json、轻量版人工闸
- [x] 完成核心跨仓契约：auth / data / chat-stream / admin-sync
- [ ] AI 下一步：后端数据库 DDL + LangGraph 节点详细设计

## 仓库地址

| 仓库 | SSH 地址 |
|---|---|
| workspace | `git@github.com:Cyning12/ops-desk-workspace.git` |
| web | `git@github.com:Cyning12/ops-desk-web.git` |
| api | `git@github.com:Cyning12/ops-desk-api.git` |
| ios | `git@github.com:Cyning12/ops-desk-ios.git` |
