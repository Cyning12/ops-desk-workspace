# Data API v1 契约

> 更新日期：2026-07-15  > 范围：Overview、Issues、Pull Requests、Graph、Chat Models 等只读/管理接口

---

## 1. 通用约定

- 所有接口需要鉴权，读取 `Cookie: ops_session`。
- 返回 JSON 统一包装为 `{ ok: true, data: ... }` 或 `{ ok: false, error, code }`。
- 分页默认 `page=1`，`pageSize=25`，最大 `pageSize=100`。

---

## 2. GET /api/ops/overview

**说明**：总览页指标。

**Request**

```http
GET /api/ops/overview
Cookie: ops_session=session-id-uuid
```

**Response 200**

```json
{
  "ok": true,
  "data": {
    "cycleTime": {
      "medianDays": 2.5,
      "sampleSize": 12
    },
    "reviewTime": {
      "medianDays": 0.8,
      "sampleSize": 8
    },
    "issueThroughput": {
      "count": 23,
      "periodDays": 30
    },
    "asOf": "2026-07-15T10:00:00Z",
    "syncStatus": "success",
    "syncRun": {
      "id": "uuid",
      "started_at": "2026-07-15T09:00:00Z",
      "finished_at": "2026-07-15T09:05:00Z",
      "status": "success",
      "records_issue": 120,
      "records_pr": 45
    },
    "scanSnapshot": {
      "scan_version": "v1.2",
      "total_open": 15,
      "p0_items": [],
      "p1_items": [],
      "p2_items": [],
      "deferred_items": [],
      "parsed_summary": {},
      "raw_markdown_url": "https://...",
      "created_at": "2026-07-15T08:00:00Z"
    },
    "trend": [
      {
        "date": "2026-06-15",
        "closedIssues": 1,
        "mergedPrs": 2
      }
    ]
  }
}
```

---

## 3. GET /api/ops/issues

**说明**：Issue 列表 + 筛选 + 分页。

**Request**

```http
GET /api/ops/issues?state=open&labels=bug&scanTag=P0&page=1&pageSize=25
Cookie: ops_session=session-id-uuid
```

**Query Parameters**

| 参数 | 类型 | 说明 |
|---|---|---|
| state | "open" / "closed" | 可选 |
| labels | string[] | 可选，逗号分隔 |
| scanTag | string | 可选 |
| moduleId | string | 可选，Graph 模块筛选 |
| numbers | number[] | 可选，精确 issue 号 |
| page | int | 默认 1 |
| pageSize | int | 默认 25 |

**Response 200**

```json
{
  "ok": true,
  "data": {
    "rows": [
      {
        "id": "uuid",
        "repo_id": "uuid",
        "number": 545,
        "title": "修复 xxx 问题",
        "state": "open",
        "labels": ["bug", "module:core"],
        "created_at": "2026-07-01T00:00:00Z",
        "updated_at": "2026-07-14T00:00:00Z",
        "closed_at": null,
        "author": "alice",
        "html_url": "https://github.com/MoonshotAI/kimi-code/issues/545",
        "scan_tags": ["P0"]
      }
    ],
    "count": 128
  }
}
```

---

## 4. GET /api/ops/pulls

**说明**：Pull Request 列表 + 筛选 + 分页。

**Request**

```http
GET /api/ops/pulls?state=merged&checks=failure&page=1&pageSize=25
Cookie: ops_session=session-id-uuid
```

**Query Parameters**

| 参数 | 类型 | 说明 |
|---|---|---|
| state | "open" / "closed" / "merged" | 可选 |
| checks | "success" / "failure" / "pending" / "skipped" | 可选 |
| page | int | 默认 1 |
| pageSize | int | 默认 25 |

**Response 200**

```json
{
  "ok": true,
  "data": {
    "rows": [
      {
        "id": "uuid",
        "repo_id": "uuid",
        "number": 123,
        "title": "Add feature X",
        "state": "merged",
        "draft": false,
        "labels": ["enhancement"],
        "created_at": "2026-07-01T00:00:00Z",
        "updated_at": "2026-07-10T00:00:00Z",
        "closed_at": "2026-07-05T00:00:00Z",
        "merged_at": "2026-07-05T00:00:00Z",
        "author": "bob",
        "html_url": "https://github.com/MoonshotAI/kimi-code/pull/123",
        "checks_conclusion": "success",
        "review_decision": "APPROVED",
        "first_review_at": "2026-07-02T00:00:00Z"
      }
    ],
    "count": 64
  }
}
```

---

## 5. GET /api/ops/graph

**说明**：Graph Snapshot + 模块 × Issue 矩阵。

**Request**

```http
GET /api/ops/graph
Cookie: ops_session=session-id-uuid
```

**Response 200**

```json
{
  "ok": true,
  "data": {
    "snapshot": {
      "id": "uuid",
      "source_branch": "main",
      "source_commit": "abc123",
      "manifest_version": "v2.0",
      "schema_version": "v1",
      "freeze_id": "freeze-001",
      "node_count": 120,
      "edge_count": 340,
      "graph_count": 5,
      "created_at": "2026-07-15T08:00:00Z"
    },
    "modules": [
      {
        "module_id": "core",
        "module_name": "Core Engine",
        "issue_count": 12,
        "open_count": 8,
        "p0_count": 2,
        "p1_count": 3,
        "p2_count": 1,
        "issue_numbers": [545, 546, 547]
      }
    ]
  }
}
```

---

## 6. GET /api/ops/chat/models

**说明**：获取当前可用模型列表。

**Request**

```http
GET /api/ops/chat/models
Cookie: ops_session=session-id-uuid
```

**Response 200**

```json
{
  "ok": true,
  "data": {
    "provider": "siliconflow",
    "models": [
      { "id": "deepseek-ai/DeepSeek-V4-Pro", "label": "DeepSeek V4 Pro", "test_only": false },
      { "id": "moonshotai/Kimi-K2.7-Code", "label": "Kimi K2.7 Code", "test_only": false }
    ],
    "default_model": "deepseek-ai/DeepSeek-V4-Pro",
    "auto_fallback": false
  }
}
```

---

## 7. 错误响应

通用错误格式：

```json
{
  "ok": false,
  "error": "描述文本",
  "code": "ERROR_CODE"
}
```

常见 code：

| code | 含义 |
|---|---|
| UNAUTHORIZED | 未登录或 session 过期 |
| FORBIDDEN | 权限不足 |
| NOT_FOUND | 资源不存在 |
| VALIDATION_ERROR | 参数错误 |
| INTERNAL_ERROR | 服务端内部错误 |
