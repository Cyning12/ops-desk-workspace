# Admin Sync API v1 契约

> 更新日期：2026-07-15  
> 范围：GHA sync 工作流将 GitHub issue/PR/graph/scan 数据写入本地 PG 的管理接口

---

## 1. 设计原则

- 复用现有 **kimi-code fork + kimi-code-meta** 的 GHA sync 工作流。
- sync target 从 Supabase 改为 `ops-desk-api` 的 PostgreSQL。
- GHA 不直接连 PG，而是调用 `ops-desk-api` 的 admin sync endpoint。
- 仅 `maintainer` 角色可触发 sync。

---

## 2. 数据模型

### 2.1 ops_repos

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| owner | string | 仓库所有者 |
| name | string | 仓库名 |
| full_name | string | owner/name |
| default_branch | string | 默认分支 |
| created_at | datetime | 创建时间 |

### 2.2 ops_sync_runs

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| repo_id | UUID | 关联 ops_repos |
| started_at | datetime | 开始时间 |
| finished_at | datetime | 结束时间 |
| status | enum | "pending" / "running" / "success" / "failed" / "partial" |
| cursor | string | GitHub API cursor |
| records_issue | int | 同步 issue 数 |
| records_pr | int | 同步 PR 数 |
| error_message | text | 错误信息 |
| trigger | enum | "cron" / "manual" / "initial" |

### 2.3 ops_issues

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| repo_id | UUID | 关联 ops_repos |
| number | int | issue 编号 |
| title | string | 标题 |
| state | "open" / "closed" | 状态 |
| labels | string[] | 标签数组 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |
| closed_at | datetime | 关闭时间 |
| author | string | 作者 |
| html_url | string | GitHub 链接 |
| body | text | issue 正文 |
| scan_tags | string[] | scan 标签 |

### 2.4 ops_pull_requests

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| repo_id | UUID | 关联 ops_repos |
| number | int | PR 编号 |
| title | string | 标题 |
| state | "open" / "closed" / "merged" | 状态 |
| draft | bool | 是否 draft |
| labels | string[] | 标签 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |
| closed_at | datetime | 关闭时间 |
| merged_at | datetime | 合并时间 |
| author | string | 作者 |
| html_url | string | GitHub 链接 |
| checks_conclusion | string | CI 结论 |
| review_decision | string | review 状态 |
| first_review_at | datetime | 首次 review 时间 |

### 2.5 ops_scan_snapshots

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| repo_id | UUID | 关联 ops_repos |
| scan_version | string | scan 版本 |
| total_open | int | open issue 数 |
| p0_items | JSONB | P0 列表 |
| p1_items | JSONB | P1 列表 |
| p2_items | JSONB | P2 列表 |
| deferred_items | JSONB | deferred 列表 |
| parsed_summary | JSONB | 解析摘要 |
| raw_markdown_url | string | 原始 markdown URL |
| created_at | datetime | 创建时间 |

### 2.6 ops_graph_snapshots

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| repo_id | UUID | 关联 ops_repos |
| source_branch | string | 来源分支 |
| source_commit | string | 来源 commit |
| manifest_version | string | manifest 版本 |
| schema_version | string | schema 版本 |
| freeze_id | string | freeze ID |
| payload | JSONB | nodes/edges/graphs |
| created_at | datetime | 创建时间 |

---

## 3. 接口

### 3.1 POST /api/ops/admin/sync

**说明**：接收 GHA sync payload，写入或更新 PG。

**Request**

```http
POST /api/ops/admin/sync
Content-Type: application/json
Authorization: Bearer <SYNC_ADMIN_SECRET>
```

```json
{
  "repo": {
    "owner": "MoonshotAI",
    "name": "kimi-code",
    "full_name": "MoonshotAI/kimi-code",
    "default_branch": "main"
  },
  "sync_run": {
    "id": "uuid",
    "started_at": "2026-07-15T09:00:00Z",
    "finished_at": "2026-07-15T09:05:00Z",
    "status": "success",
    "cursor": "...",
    "records_issue": 120,
    "records_pr": 45,
    "error_message": null,
    "trigger": "manual"
  },
  "issues": [...],
  "pull_requests": [...],
  "scan_snapshot": {...},
  "graph_snapshot": {...}
}
```

**Response 200**

```json
{
  "ok": true,
  "data": {
    "sync_run_id": "uuid",
    "issues_upserted": 120,
    "pull_requests_upserted": 45
  }
}
```

**Response 401**

```json
{
  "ok": false,
  "error": "Unauthorized",
  "code": "UNAUTHORIZED"
}
```

---

## 4. 写入策略

- `ops_repos`：按 `owner` + `name` 唯一键 upsert。
- `ops_issues`：按 `repo_id` + `number` 唯一键 upsert。
- `ops_pull_requests`：按 `repo_id` + `number` 唯一键 upsert。
- `ops_sync_runs`：直接 insert。
- `ops_scan_snapshots` / `ops_graph_snapshots`：直接 insert。

---

## 5. GHA 调用方式

现有 kimi-code fork 的 GHA sync 工作流需要修改 target：

```yaml
- name: Sync to ops-desk-api
  run: |
    curl -X POST https://your-domain/api/ops/admin/sync \
      -H "Authorization: Bearer ${{ secrets.OPS_DESK_SYNC_TOKEN }}" \
      -H "Content-Type: application/json" \
      -d @sync_payload.json
```

或使用 `SYNC_ADMIN_SECRET` 作为 Bearer token。

---

## 6. 环境变量

```bash
SYNC_ADMIN_SECRET=your-sync-admin-secret
```
