# Ops Desk Kimi Code 国内服务器迁移 · 项目简报

> 创建日期：2026-07-15  
> 负责人：1 人（前后端 AI Coding + iOS 手工编码）  
> 目标部署地：腾讯云自购服务器（中国大陆）  

---

## 1. 项目目标

将现有 `ai-ink-brain` 中的 **Ops Desk / Kimi Code** 功能模块迁移到国内自购服务器，并重构为 **4 个独立仓库**：

| 仓库 | 目标技术栈 | 说明 |
|---|---|---|
| `ops-desk-workspace` | Markdown + Harness 任务单 + 架构图谱 | AI 总调度工作空间，承载 AGENTS.md、docs、tasks |
| `ops-desk-web` | Vue 3 + TypeScript + Vite + Element Plus | 替换现有 Next.js 14/15 实现 |
| `ops-desk-api` | Python FastAPI + 最新 LangGraph | 替换现有自研编排，保留 FastAPI 骨架 |
| `ops-desk-ios` | Swift + SwiftUI | 仅作技能恢复，手工编码，功能从简 |

数据库：PostgreSQL 15+（部署在腾讯云服务器本地），替换现有 Supabase/pgvector。

Chat 交互：直接采用 **SSE 流式**，前端实时展示思考过程。

---

## 2. v1 功能范围（最窄可用路径）

按优先级排序：

1. **登录**（复用现有方案，不开放注册）
2. **总览（Overview）** — PR Cycle Time、Review Time、Issue Throughput、同步状态、Scan 摘要、Trend 图
3. **Issues** — 列表、分页、状态/标签/Scan/模块筛选
4. **Pull Requests** — 列表、分页、状态/CI 筛选
5. **Graph** — Graph Snapshot 摘要、模块 × Issue 矩阵
6. **Chat** — 单轮对话，但可读取对应 issue 内容作为上下文；**SSE 流式返回，展示思考过程；保存完整对话 + 思考过程，历史思考过程默认折叠**

### 2.1 明确不在 v1

- 用户注册（仅预置邀请密钥登录）
- 多轮对话/ReAct 深度路径（Chat v1 先做单轮 + 上下文注入）
- 文件上传/图片理解
- Artifact 生成与下载
- Session 的高级权限管理
- iOS 端完整功能对齐（先做只读/单轮对话骨架）

---

## 3. 关键约束

| 约束 | 说明 |
|---|---|
| 模型 | 仅通过 API Key 调用 SiliconFlow / 阿里云百炼，**不自建 GPU 服务器** |
| 数据库 | PG 部署在个人服务器本地，需自行备份 |
| 合规 | 域名 + ICP 备案 + 公安备案（国内服务器 80/443 必经之路） |
| 人力 | 1 人；前端/后端以 AI Coding 为主，iOS 以人工为主 |
| 预算 | 追求性价比最高，优先 Lighthouse 轻量服务器 |
| Git | 继续使用 GitHub 私有仓库，**4 个仓库**：workspace / web / api / ios |

---

## 4. 现存子仓位置

- 前端（待替换）：`ai-ink-brain/app/ops/kimi-code/`（Next.js App Router）
- 后端（待改造）：`ai-ink-brain-api-python/api/ops/`（FastAPI）
- LLM Provider：`ai-ink-brain-api-python/api/ops/llm/`

---

## 5. 已确认决策

1. **四仓库结构**：`ops-desk-workspace` / `ops-desk-web` / `ops-desk-api` / `ops-desk-ios`
2. **前端 UI 库**：Element Plus
3. **Chat 交互**：SSE 流式，前端展示思考过程
4. **Chat 历史**：保存完整对话 + 思考过程，历史思考过程默认折叠
5. **数据同步**：复用现有 **kimi-code fork + kimi-code-meta** 的 GHA sync 工作流
6. **鉴权**：需要 `ops_users` / `ops_sessions` 表，DB session 模式
7. **默认 LLM Provider**：SiliconFlow
8. **iOS v1 范围**：登录页 + Chat 页
9. **部署编排**：`ops-desk-workspace` 维护总 `docker-compose.yml`
10. **研发纪律**：接入 `@cyning/harness`，技术图谱采用 **`.graph.yaml` + `.md` 双轨**，无 `.ai.md`；**废弃 `graph.json`**；人工闸采用轻量版

## 6. 下一步待决策

1. **技术图谱接口完整性**：是否将 API endpoint / SSE 事件契约 / 表结构全部纳入 `_tech_graph/` 作为对接文档？（推荐：是）
2. **harness 落盘细节**：每个子仓单独初始化 `@cyning/harness`，还是 workspace 统一分发后再同步到子仓？（推荐：workspace 统一分发）
