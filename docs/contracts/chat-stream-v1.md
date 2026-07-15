# Chat SSE API v1 契约

> 更新日期：2026-07-15  
> 范围：SSE 流式对话接口、事件格式、历史保存

---

## 1. 设计原则

- 单轮对话为主，但保存完整历史。
- SSE 流式返回事件：`thinking` / `tool_result` / `answer` / `done` / `error`。
- 可读取 issue 内容作为上下文。
- 支持模型选择，支持百炼自动 fallback。
- 思考过程保存但历史 UI 默认折叠。

---

## 2. 数据模型

### 2.1 ops_sessions（与 auth 共用）

Chat session 借用 auth session 的 `session_id` 作为用户会话标识。

### 2.2 ops_chat_sessions

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| user_id | UUID | 关联 ops_users |
| title | string | 会话标题（首条问题摘要） |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

### 2.3 ops_runs

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键，即 run_id |
| session_id | UUID | 关联 ops_chat_sessions |
| user_id | UUID | 关联 ops_users |
| query | text | 用户问题 |
| intent | string | "issue_qa" / "general" / "overview" |
| status | enum | "running" / "done" / "failed" |
| model | string | 实际使用模型 |
| latency_ms | int | 总耗时 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

### 2.4 ops_run_events

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | 主键 |
| run_id | UUID | 关联 ops_runs |
| seq | int | 事件序号 |
| ts_ms | int | 相对 run.start 的毫秒 |
| agent_role | string | 事件角色 |
| event_type | string | 事件类型 |
| payload | JSONB | 事件载荷 |
| created_at | datetime | 创建时间 |

---

## 3. 接口

### 3.1 POST /api/ops/chat/stream

**说明**：发起对话，返回 SSE 流。

**Request**

```http
POST /api/ops/chat/stream
Content-Type: application/json
Cookie: ops_session=session-id-uuid
```

```json
{
  "message": "#545 讲了什么？",
  "session_id": "chat-session-uuid",
  "model": "deepseek-ai/DeepSeek-V4-Pro"
}
```

**字段说明**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| message | string | 是 | 用户问题 |
| session_id | string | 否 | 会话 ID，不传则新建 |
| model | string | 否 | 模型 ID，不传则用默认 |

**Response**

```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
X-Accel-Buffering: no
```

---

## 4. SSE 事件格式

每个事件：

```text
event: <event_type>
data: <json>

```

### 4.1 run.start

```json
{
  "run_id": "run-uuid",
  "seq": 1,
  "ts_ms": 0,
  "agent_role": "system",
  "event_type": "run.start",
  "payload": {
    "run_id": "run-uuid",
    "session_id": "chat-session-uuid"
  }
}
```

### 4.2 thinking

```json
{
  "run_id": "run-uuid",
  "seq": 2,
  "ts_ms": 120,
  "agent_role": "intent",
  "event_type": "thinking",
  "payload": {
    "content": "用户询问 #545，需要先加载 issue 上下文。",
    "step": "intent"
  }
}
```

### 4.3 tool_call

```json
{
  "run_id": "run-uuid",
  "seq": 3,
  "ts_ms": 250,
  "agent_role": "context",
  "event_type": "tool_call",
  "payload": {
    "tool": "load_issue",
    "args": { "issue_number": 545 }
  }
}
```

### 4.4 tool_result

```json
{
  "run_id": "run-uuid",
  "seq": 4,
  "ts_ms": 480,
  "agent_role": "context",
  "event_type": "tool_result",
  "payload": {
    "tool": "load_issue",
    "ok": true,
    "issue_number": 545,
    "summary": "修复 core 模块内存泄漏",
    "citations": [
      { "number": 545, "url": "https://github.com/.../issues/545" }
    ]
  }
}
```

### 4.5 model.fallback

```json
{
  "run_id": "run-uuid",
  "seq": 5,
  "ts_ms": 600,
  "agent_role": "llm",
  "event_type": "model.fallback",
  "payload": {
    "from_model": "deepseek-v4-pro",
    "to_model": "deepseek-v4-flash",
    "reason": "quota_exceeded",
    "step": "answer"
  }
}
```

### 4.6 answer

```json
{
  "run_id": "run-uuid",
  "seq": 6,
  "ts_ms": 800,
  "agent_role": "answer",
  "event_type": "answer",
  "payload": {
    "content": "#545 的主要内容是..."
  }
}
```

### 4.7 answer.end

```json
{
  "run_id": "run-uuid",
  "seq": 7,
  "ts_ms": 1500,
  "agent_role": "answer",
  "event_type": "answer.end",
  "payload": {}
}
```

### 4.8 done

```json
{
  "run_id": "run-uuid",
  "seq": 8,
  "ts_ms": 1520,
  "agent_role": "system",
  "event_type": "done",
  "payload": {
    "latency_ms": 1520,
    "model": "deepseek-v4-flash",
    "usage": {
      "prompt_tokens": 1200,
      "completion_tokens": 350
    }
  }
}
```

### 4.9 error

```json
{
  "run_id": "run-uuid",
  "seq": 9,
  "ts_ms": 300,
  "agent_role": "system",
  "event_type": "error",
  "payload": {
    "stage": "llm",
    "message": "模型调用失败",
    "retryable": false
  }
}
```

---

## 5. 历史展示规则

| 内容 | 默认状态 | 说明 |
|---|---|---|
| 用户问题 | 展开 | 始终可见 |
| 最终答案 | 展开 | 始终可见 |
| thinking 过程 | 折叠 | 可点击展开 |
| tool_call / tool_result | 折叠 | 可点击展开 |
| model.fallback | 提示条 | 短暂显示或常驻提示 |

---

## 6. 前端/iOS 消费方式

### web

使用 `@microsoft/fetch-event-source`：

```typescript
fetchEventSource("/api/ops/chat/stream", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ message, session_id, model }),
  onmessage(msg) {
    const ev = JSON.parse(msg.data);
    // 按 event_type 分发
  }
});
```

### iOS

使用 `URLSession.bytes` 逐字节解析 SSE：

```swift
let (bytes, _) = try await URLSession.shared.bytes(for: request)
var buffer = ""
for try await byte in bytes {
    buffer.append(Character(UnicodeScalar(byte)))
    if buffer.hasSuffix("\n\n") {
        parseSseEvent(buffer)
        buffer = ""
    }
}
```

---

## 7. 持久化策略

- `run.start` 时创建 `ops_runs` 记录，状态 `running`。
- 流式事件**异步**写入 `ops_run_events`，不阻塞 SSE。
- 收到 `done` 或 `error` 后更新 `ops_runs.status`。
- 历史会话列表从 `ops_chat_sessions` + `ops_runs` 聚合。

---

## 8. 环境变量

```bash
OPS_LLM_PROVIDER=siliconflow
SILICONFLOW_API_KEY=...
BAILIAN_API_KEY=...
OPS_LLM_MODEL=deepseek-ai/DeepSeek-V4-Pro
BAILIAN_MODEL=deepseek-v4-pro
```
