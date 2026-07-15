# ops-desk-workspace

Ops Desk Kimi Code 的 AI 总调度工作空间。

## 仓库职责

- 项目级文档与架构图谱
- Harness 任务单与过程落盘
- 跨仓库 CI/CD 编排（docker-compose、Nginx 配置）
- 子仓库初始化与同步脚本

## 快速链接

- 项目文档：`docs/README.md`
- 范围与决策：`docs/01-scope/00-project-brief.md`
- Harness 策略：`docs/01-scope/01-harness-tech-graph-strategy.md`
- 后端现状：`docs/02-backend-analysis/00-current-state.md`
- SSE Chat 设计：`docs/02-backend-analysis/01-sse-chat-design.md`
- 前端现状：`docs/03-frontend-analysis/00-current-state.md`
- 基础设施：`docs/04-infrastructure/00-server-recommendation.md`
- 环境配置：`docs/04-infrastructure/01-environment-setup.md`
- 迁移路线图：`docs/05-plan/00-migration-roadmap.md`

## 相关仓库

| 仓库 | SSH 地址 |
|---|---|
| ops-desk-web | `git@github.com:Cyning12/ops-desk-web.git` |
| ops-desk-api | `git@github.com:Cyning12/ops-desk-api.git` |
| ops-desk-ios | `git@github.com:Cyning12/ops-desk-ios.git` |

## 本地目录结构

```
Ops-desk/
├── ops-desk-workspace/          # 本仓库
│   ├── docs/                    # 项目文档
│   ├── docker-compose.yml       # 总编排
│   ├── nginx.conf               # Nginx 配置
│   └── scripts/                 # harness 同步脚本
├── ops-desk-web/                # 前端仓库
├── ops-desk-api/                # 后端仓库
└── ops-desk-ios/                # iOS 仓库
```

## 启动全栈

```bash
cd /Users/cyning/Desktop/Ops-desk/ops-desk-workspace
docker compose up -d
```

## Harness

本仓库接入 `@cyning/harness`，详见 `docs/01-scope/01-harness-tech-graph-strategy.md`。

常用命令：

```bash
npx @cyning/harness verify --target . --task docs/tasks/active/task_xxx.md
npx @cyning/harness gate-check --target . --graph
```
