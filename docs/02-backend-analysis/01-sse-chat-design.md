# Chat SSE 流式设计：LangGraph + FastAPI + Vue3

> 更新日期：2026-07-15  
> 范围：Ops Desk Chat v1（单轮 + issue 上下文 + 思考过程展示）

---

## 1. 设计目标

1. **实时**：用户提问后，SSE 流式返回事件，无需轮询。
2. **可观测**：清晰展示思考过程、工具调用、模型切换、最终答案。
3. **兼容**：事件 schema 尽量对齐现有 `ops_run_events`，降低前端迁移成本。
4. **简单**：v1 单轮为主，不实现复杂多轮 ReAct。

---

## 2. SSE 事件格式

### 2.1 传输格式

每个 SSE 消息：

```text
event: thinking
data: {"run_id":"...","seq":1,"ts_ms":0,"agent_role":"intent","event_type":"thinking","payload":{"content":"用户问的是 #545 issue 的内容，我需要先加载 issue 上下文。"}}

event: answer
data: {"run_id":"...","seq":5,"ts_ms":1200,"agent_role":"answer","event_type":"answer","payload":{"content":"#545 的主要内容是……"}}

event: done
data: {"run_id":"...","seq":6,"ts_ms":1500,"agent_role":"system","event_type":"done","payload":{"latency_ms":1500,"model":"deepseek-v4-pro"}}
```

### 2.2 事件类型表

| event 字段 | event_type | 说明 | 前端展示 |
|---|---|---|---|
| `run.start` | `run.start` | 运行开始 | 隐藏或显示「思考中…」 |
| `thinking` | `thinking` | LLM/Agent 思考文本 | 思考过程区 |
| `tool_call` | `tool_call` | 调用工具 | 工具区 |
| `tool_result` | `tool_result` | 工具返回 | 工具区 |
| `model.fallback` | `model.fallback` | 模型切换 | 提示条 |
| `answer` | `answer` | 最终答案文本流 | Markdown 答案区 |
| `answer.end` | `answer.end` | 答案结束 | - |
| `done` | `done` | 全部完成 | 关闭连接 |
| `error` | `error` | 错误 | 错误提示 |

### 2.3 payload 约定

```typescript
interface SseEvent {
  run_id: string;
  seq: number;
  ts_ms: number;
  agent_role: string;
  event_type: string;
  payload: Record<string, unknown>;
}

// thinking
interface ThinkingPayload {
  content: string;        // 思考文本
  step?: string;          // 步骤名，如 "intent"/"context"/"answer"
}

// tool_call
interface ToolCallPayload {
  tool: string;           // 工具名，如 "load_issue"
  args: Record<string, unknown>;
}

// tool_result
interface ToolResultPayload {
  tool: string;
  ok: boolean;
  summary?: string;
  issue_number?: number;
  citations?: Array<{ number: number; url: string }>;
}

// model.fallback
interface ModelFallbackPayload {
  from_model: string;
  to_model: string;
  reason: string;
  step: string;
}

// answer
interface AnswerPayload {
  content: string;        // 文本片段，可增量拼接
}

// done
interface DonePayload {
  latency_ms: number;
  model: string;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
  };
}

// error
interface ErrorPayload {
  stage: string;
  message: string;
  retryable?: boolean;
}
```

---

## 3. 后端：LangGraph + FastAPI 实现

### 3.1 State 定义

```python
from typing import TypedDict, Annotated
from operator import add

class ChatState(TypedDict):
    query: str
    session_id: str | None
    run_id: str
    # 上下文
    issue_context: list[dict]
    pr_context: list[dict]
    graph_context: dict | None
    # 决策
    intent: str  # "issue_qa" | "general" | "overview"
    # 输出
    answer: str
    # 事件流（LangGraph 节点内追加）
    events: Annotated[list[dict], add]
```

### 3.2 Graph 节点

```python
from langgraph.graph import StateGraph, START, END

builder = StateGraph(ChatState)
builder.add_node("intent", intent_node)
builder.add_node("load_issue_context", load_issue_context_node)
builder.add_node("answer", answer_node)
builder.add_edge(START, "intent")
builder.add_conditional_edges(
    "intent",
    route_by_intent,
    {"issue_qa": "load_issue_context", "general": "answer", "overview": "answer"},
)
builder.add_edge("load_issue_context", "answer")
builder.add_edge("answer", END)
graph = builder.compile()
```

### 3.3 节点实现示例

```python
async def intent_node(state: ChatState) -> dict:
    query = state["query"]
    # 简单规则意图识别
    intent = "general"
    if "#" in query and any(ch.isdigit() for ch in query):
        intent = "issue_qa"
    elif "总览" in query or "overview" in query.lower():
        intent = "overview"

    return {
        "intent": intent,
        "events": [{
            "event_type": "thinking",
            "agent_role": "intent",
            "payload": {
                "content": f"识别意图为 {intent}",
                "step": "intent",
            },
        }],
    }

async def load_issue_context_node(state: ChatState) -> dict:
    issue_number = extract_issue_number(state["query"])
    issue = await fetch_issue_by_number(issue_number)
    return {
        "issue_context": [issue] if issue else [],
        "events": [{
            "event_type": "tool_result",
            "agent_role": "context",
            "payload": {
                "tool": "load_issue",
                "ok": bool(issue),
                "issue_number": issue_number,
                "summary": issue["title"] if issue else "未找到",
            },
        }],
    }

async def answer_node(state: ChatState) -> dict:
    messages = build_messages(state)
    provider = get_llm_provider()

    # 流式调用 LLM
    events = []
    answer_parts = []

    for chunk in provider.complete_stream(messages, model=...):
        delta = chunk.content or ""
        answer_parts.append(delta)
        events.append({
            "event_type": "answer",
            "agent_role": "answer",
            "payload": {"content": delta},
        })

    return {
        "answer": "".join(answer_parts),
        "events": events,
    }
```

### 3.4 FastAPI SSE 路由

```python
from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse
import json
import time
import uuid

router = APIRouter()

@router.post("/chat/stream")
async def chat_stream(request: Request):
    body = await request.json()
    query = body.get("message", "").strip()
    session_id = body.get("session_id")
    model = body.get("model")

    run_id = str(uuid.uuid4())
    state = ChatState(
        query=query,
        session_id=session_id,
        run_id=run_id,
        issue_context=[],
        pr_context=[],
        graph_context=None,
        intent="",
        answer="",
        events=[],
    )

    async def event_generator():
        seq = 0
        started_at = time.perf_counter()

        def make_event(event_type: str, agent_role: str, payload: dict) -> str:
            nonlocal seq
            seq += 1
            data = {
                "run_id": run_id,
                "seq": seq,
                "ts_ms": int((time.perf_counter() - started_at) * 1000),
                "agent_role": agent_role,
                "event_type": event_type,
                "payload": payload,
            }
            return f"event: {event_type}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"

        yield make_event("run.start", "system", {"run_id": run_id})

        try:
            async for event in graph.astream_events(state, version="v2"):
                kind = event["event"]
                if kind == "on_chat_model_stream":
                    delta = event["data"]["chunk"].content
                    if delta:
                        yield make_event("answer", "answer", {"content": delta})
                elif kind == "on_chain_start":
                    yield make_event("thinking", "system", {"content": f"开始 {event['name']}"})
                elif kind == "on_chain_end":
                    # 可读取 state 中的 events
                    pass

            yield make_event("done", "system", {
                "latency_ms": int((time.perf_counter() - started_at) * 1000),
                "model": model or get_default_model(),
            })
        except Exception as e:
            yield make_event("error", "system", {
                "stage": "chat",
                "message": str(e),
                "retryable": False,
            })

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )
```

> 注：`astream_events` 的 API 随 LangGraph 版本变化，需 pin 版本并参考官方文档。

---

## 4. 前端：Vue3 + Element Plus + SSE

### 4.1 依赖

```bash
npm install @microsoft/fetch-event-source
npm install -D @types/markdown-it
npm install markdown-it highlight.js
```

### 4.2 封装 useOpsChatSse

```typescript
// src/composables/useOpsChatSse.ts
import { fetchEventSource } from "@microsoft/fetch-event-source";
import { ref } from "vue";

export interface SseEvent {
  run_id: string;
  seq: number;
  ts_ms: number;
  agent_role: string;
  event_type: string;
  payload: Record<string, unknown>;
}

export function useOpsChatSse() {
  const thinking = ref("");
  const answer = ref("");
  const toolResults = ref<Array<{ tool: string; summary: string }>>([]);
  const fallbackChain = ref<Array<{ from: string; to: string }>>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  let abortCtrl: AbortController | null = null;

  async function send(message: string, options?: { sessionId?: string; model?: string }) {
    abortCtrl?.abort();
    abortCtrl = new AbortController();

    thinking.value = "";
    answer.value = "";
    toolResults.value = [];
    fallbackChain.value = [];
    error.value = null;
    loading.value = true;

    await fetchEventSource("/api/ops/chat/stream", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message,
        session_id: options?.sessionId,
        model: options?.model,
      }),
      signal: abortCtrl.signal,
      async onopen(response) {
        if (!response.ok) {
          error.value = `请求失败: ${response.status}`;
          loading.value = false;
        }
      },
      onmessage(msg) {
        if (!msg.data) return;
        const ev: SseEvent = JSON.parse(msg.data);
        handleEvent(ev);
      },
      onclose() {
        loading.value = false;
      },
      onerror(err) {
        error.value = String(err);
        loading.value = false;
        throw err; // 默认不重连
      },
    });
  }

  function handleEvent(ev: SseEvent) {
    switch (ev.event_type) {
      case "thinking":
        thinking.value += (ev.payload.content as string) || "";
        break;
      case "tool_result":
        toolResults.value.push({
          tool: String(ev.payload.tool),
          summary: String(ev.payload.summary || ""),
        });
        break;
      case "model.fallback":
        fallbackChain.value.push({
          from: String(ev.payload.from_model),
          to: String(ev.payload.to_model),
        });
        break;
      case "answer":
        answer.value += (ev.payload.content as string) || "";
        break;
      case "error":
        error.value = String(ev.payload.message);
        break;
      case "done":
        loading.value = false;
        break;
    }
  }

  function stop() {
    abortCtrl?.abort();
    loading.value = false;
  }

  return {
    thinking,
    answer,
    toolResults,
    fallbackChain,
    loading,
    error,
    send,
    stop,
  };
}
```

### 4.3 Chat 视图组件

```vue
<template>
  <div class="ops-chat-view">
    <!-- 输入区 -->
    <el-input
      v-model="draft"
      type="textarea"
      :rows="3"
      placeholder="输入问题，例如：#545 讲了什么？"
    />
    <el-button type="primary" :loading="loading" @click="handleSend">发送</el-button>

    <!-- 思考过程 -->
    <div v-if="thinking" class="thinking-box">
      <div class="text-sm font-medium text-slate-500">思考过程</div>
      <pre class="text-xs text-slate-600">{{ thinking }}</pre>
    </div>

    <!-- 工具调用 -->
    <div v-if="toolResults.length" class="tool-box">
      <div class="text-sm font-medium text-slate-500">工具调用</div>
      <div v-for="t in toolResults" :key="t.tool" class="text-xs">
        {{ t.tool }}: {{ t.summary }}
      </div>
    </div>

    <!-- 模型 fallback -->
    <div v-if="fallbackChain.length" class="fallback-box">
      <div class="text-sm font-medium text-slate-500">模型切换</div>
      <div v-for="(step, i) in fallbackChain" :key="i" class="text-xs">
        {{ step.from }} → {{ step.to }}
      </div>
    </div>

    <!-- 最终答案 -->
    <div v-if="answer" class="answer-box">
      <div class="text-sm font-medium text-slate-500">回答</div>
      <div class="markdown-body" v-html="renderedAnswer" />
    </div>

    <!-- 错误 -->
    <el-alert v-if="error" :title="error" type="error" show-icon />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { useOpsChatSse } from "@/composables/useOpsChatSse";
import { renderMarkdown } from "@/utils/markdown";

const draft = ref("");
const { thinking, answer, toolResults, fallbackChain, loading, error, send } = useOpsChatSse();

const renderedAnswer = computed(() => renderMarkdown(answer.value));

async function handleSend() {
  if (!draft.value.trim()) return;
  await send(draft.value);
  draft.value = "";
}
</script>
```

---

## 5. iOS 侧 SSE 处理

使用 `URLSession.bytes` 解析 SSE：

```swift
func streamChat(message: String) async throws {
    let url = URL(string: "\(baseURL)/api/ops/chat/stream")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(["message": message])

    let (bytes, _) = try await URLSession.shared.bytes(for: request)
    var buffer = ""
    for try await byte in bytes {
        buffer.append(Character(UnicodeScalar(byte)))
        if buffer.hasSuffix("\n\n") {
            parseSseEvent(buffer)
            buffer = ""
        }
    }
}
```

---

## 6. 数据库持久化

每次 Chat 请求需持久化：

| 表 | 用途 |
|---|---|
| `ops_sessions` | session 元数据 |
| `ops_runs` | 单次运行记录（run_id, session_id, query, intent, status, model, latency_ms） |
| `ops_run_events` | **完整 SSE 事件流归档**，包括 `thinking` / `tool_result` / `answer` / `model.fallback` / `done` |

持久化策略：
- `run.start` 时创建 `ops_runs` 记录。
- 事件流结束后批量写入 `ops_run_events`。
- 不需要阻塞 SSE 流；后台 task 异步写入。

历史展示：
- UI 展示当前轮 + 过往对话列表。
- **历史思考过程默认折叠**，用户可点击展开。
- 最终答案默认展开。

---

## 7. 风险与注意

| 风险 | 应对 |
|---|---|
| SSE 代理缓冲 | Nginx 加 `X-Accel-Buffering: no`；FastAPI 设置 `Cache-Control: no-cache` |
| 长连接超时 | 前端使用 `@microsoft/fetch-event-source` 自动重连；但重连应创建新 run |
| LangGraph `astream_events` API 变化 | pin `langgraph>=0.2,<0.3`，详细测试 |
| 模型流式不支持 | Provider 层封装 `complete_stream()`；非流式模型降级为模拟流式 |
| 并发高 | 一人项目初期无此问题；后续可加 Redis 限流 |

---

## 8. 下一步

1. 确认 Chat 是否需要保存历史对话（v1 建议保存，但 UI 只展示当前轮）。
2. 确认 thinking 过程是否需要展示完整 LLM raw reasoning，还是展示精简步骤。
3. 输出后端 Provider 层 `complete_stream()` 封装设计。
