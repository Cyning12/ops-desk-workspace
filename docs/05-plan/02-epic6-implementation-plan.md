# Epic 6 详细实现计划 · LLM Provider 与 Chat 流式回答

> 创建日期：2026-07-16  
> 关联：[`01-epic-task-backlog.md`](./01-epic-task-backlog.md) · `ops-desk-api/docs/tasks/active/task_llm_provider_v1.md` · `../ops-desk-workspace/docs/02-backend-analysis/01-sse-chat-design.md`

---

## 1. 目标与范围

**目标**：实现 `POST /api/ops/chat/stream`，SSE 实时返回 `thinking` / `tool_result` / `model.fallback` / `answer` / `done` / `error` 事件，并将完整事件流持久化到 `ops_runs` / `ops_run_events`。

**范围**：

- `app/llm/factory.py`（已存在，补全）
- `app/llm/schema.py`
- `app/llm/model_catalog.py`
- `app/llm/providers/siliconflow.py`
- `app/llm/providers/bailian.py`
- `app/ops/chat/nodes.py`
- `app/ops/chat/service.py`
- `app/ops/chat/router.py`
- `app/ops/chat/sse.py`
- `app/ops/chat/state.py`
- `app/db/models.py`（只读）
- `docs/_tech_graph/10_flow_chat.graph.yaml`（锚点更新）
- `tests/test_llm_providers.py`、`tests/test_chat_nodes.py`、`tests/test_chat_service.py`、`tests/test_chat_router.py`、`tests/conftest.py`

**非范围**：

- 多轮对话上下文压缩
- 复杂 tool calling
- RAG 向量检索
- 文件上传/图片理解

---

## 2. 关键设计决策

### 2.1 统一事件 Schema

SSE 消息沿用以下结构，与 `docs/_tech_graph/10_flow_chat.md` 保持一致：

```python
{
    "run_id": str,
    "seq": int,
    "ts_ms": int,
    "agent_role": str,
    "event_type": str,
    "payload": dict,
}
```

关键 `event_type`：

- `run.start` / `done` / `error`
- `thinking`
- `tool_result`
- `model.fallback`
- `answer`
- `answer.end`（可选，若设计文档要求）

### 2.2 Provider 层统一接口

```python
# app/llm/schema.py
@dataclass
class LlmChunk:
    content: str
    meta: dict | None = None   # 用于 model.fallback 等 out-of-band 事件


class LlmProviderError(Exception):
    def __init__(
        self,
        message: str,
        *,
        retryable: bool = False,
        status_code: int | None = None,
    ) -> None:
        super().__init__(message)
        self.retryable = retryable
        self.status_code = status_code
```

### 2.3 LangGraph 流式策略

当前 `app/ops/chat/service.py` 使用 `graph.astream_events(...)`，但自定义 Provider 不会被 LangGraph 识别为 chat model，因此 token 级事件无法通过 `astream_events` 自然暴露。

**决策**：

- 主路径改用 `graph.astream(state, stream_mode="updates")`。
- 每个节点将自身产生的事件写入返回的 `events` 列表。
- `answer_node` 内部调用 `provider.complete_stream()`，将每个 chunk 收集进 `events` 后随节点输出返回。
- service 层遍历节点输出，顺序 yield 内部事件。

这样既充分利用 `ChatState.events` 的 `Annotated[list[dict], add]` reducer，又保持架构简单。

### 2.4 持久化策略

**原则**：SSE 事件发送不能被 DB 写入阻塞；持久化失败不中断流。

**决策**：

1. 路由入口处用 `Depends(get_db)` 创建 `ops_runs` 记录并立即 commit。
2. generator 内维护一个内存事件缓冲区。
3. 后台 `asyncio.create_task` 定期（每 N 条或流结束时）使用独立 short-lived session 批量 flush 到 `ops_run_events`。
4. generator 的 `finally` 中 `await` 或 cancel 后台 flush task，必要时用 `asyncio.shield` 防止客户端断连导致写入被直接取消。
5. 设置单条 run 的事件条数上限，避免内存无限增长。

### 2.5 鉴权与会话

- `chat_stream` 增加 `user: OpsUser = Depends(get_current_user)`。
- 若 `req.session_id` 为空，为该用户新建 `OpsSessionChat(title=req.message[:50])`。
- 若 `req.session_id` 非空，校验 `OpsSessionChat.id == req.session_id` 且 `user_id == user.id`，否则返回 404。
- `ops_runs.session_id` 必须关联到真实的 `ops_sessions_chat.id`。

### 2.6 默认模型真值

- 统一默认模型来源：`app/config.py` 的 `ops_llm_model` 默认值应通过 `app/llm/model_catalog.py` 的 `get_default_model()` 获取，避免双源。
- 百炼 fallback 链生产环境不应包含 `test_only=True` 模型；测试环境通过 monkeypatch 注入完整链。

---

## 3. 任务列表与依赖

```
6.1 SiliconFlow Provider 实现  ─┐
                                ├─→ 6.3 Provider 工厂与 fallback 事件
6.2 百炼 Provider 实现  ─────────┘        │
                                          ↓
6.4 load_context_node 查 DB  ─────────────┤
                                          ↓
6.5 answer_node 接入 LLM  ←───────────────┘
                                          ↓
6.6 run_chat_stream 事件映射  ←───────────┘
                                          ↓
6.7 ops_runs / ops_run_events 持久化  ←───┘
                                          ↓
6.8 Chat SSE 路由端到端  ←────────────────┘
                                          ↓
6.9 Chat 单元/集成测试  ←─────────────────┘
```

**说明**：6.1 与 6.2 可并行；6.3 依赖 6.1、6.2；6.4 与 6.5 可并行；6.6 及以后串行依赖。

---

## 4. 各任务详细说明

### 6.1 SiliconFlow Provider 实现

**目标**：实现 SiliconFlow 真实 HTTP 流式补全，返回 `AsyncIterator[LlmChunk]`。

**范围**：`app/llm/providers/siliconflow.py`、`app/config.py`（增加 `siliconflow_base_url`）、`app/llm/schema.py`。

**关键实现**：

- 配置：
  ```python
  siliconflow_base_url: str = Field(default="https://api.siliconflow.cn/v1")
  siliconflow_api_key: str | None = None
  ```
- `complete_stream(messages, model=None)` 使用 `httpx.AsyncClient(timeout=60.0)` 或 `(connect=10, read=180)`。
- 请求体 OpenAI-compatible：`model`、`messages`、`stream=True`。
- 使用 `client.stream("POST", "/chat/completions", ...)` 发送。
- 解析 `data: ` 前缀 SSE 行，遇到 `data: [DONE]` 结束。
- `complete()` 复用 `complete_stream()` 聚合。

**失败路径**：

| 触发条件 | 行为 | retryable |
|---|---|---|
| API key 缺失 | `ValueError` | 否 |
| HTTP 401/403/422 | `LlmProviderError(retryable=False)` | 否 |
| HTTP 429/5xx / 网络超时 | `LlmProviderError(retryable=True)` | 是 |
| SSE JSON 解析失败 | `LlmProviderError(retryable=True)` | 是 |
| 空流 | 正常结束 | - |

**验收标准**：mock SSE 响应验证 chunk 序列；4xx 非 retryable；5xx retryable；`ruff` 通过。

---

### 6.2 百炼 Provider 实现

**目标**：实现百炼（DashScope 兼容模式）Provider，在 Provider 内部完成模型 fallback 链。

**范围**：`app/llm/providers/bailian.py`、`app/llm/model_catalog.py`、`app/llm/schema.py`。

**关键实现**：

- 配置：
  ```python
  bailian_base_url: str = Field(default="https://dashscope.aliyuncs.com/compatible-mode/v1")
  bailian_api_key: str | None = None
  ```
- fallback 链来源 `model_catalog.get_fallback_chain("bailian")`，默认过滤 `test_only=True`。
- 切换模型时 yield：
  ```python
  LlmChunk(
      content="",
      meta={
          "event_type": "model.fallback",
          "from_model": previous_model,
          "to_model": current_model,
          "reason": str(last_error),
          "step": "answer",
      },
  )
  ```
- 链耗尽时抛出 `LlmProviderError("Bailian fallback chain exhausted", retryable=False)`。

**失败路径**：

| 触发条件 | 行为 |
|---|---|
| API key 缺失 | `ValueError` |
| 429/5xx/超时 | retryable，尝试下一模型并 emit `model.fallback` |
| 401/403/422 | 非 retryable，直接抛出 |
| 链耗尽 | 抛出非 retryable 错误 |

**验收标准**：mock 第一个模型 503、第二个正常，验证序列含 `model.fallback`；全部失败验证最终错误；`ruff` 通过。

---

### 6.3 Provider 工厂与 fallback 事件

**目标**：统一 Provider 接口、异常与 fallback 事件契约；为 `/chat/models` 提供模型目录。

**范围**：`app/llm/factory.py`、`app/llm/providers/base.py`、`app/llm/schema.py`、`app/llm/model_catalog.py`、`app/ops/chat/router.py`（`/models` 接口）。

**关键实现**：

- `schema.py` 增加 `LlmChunk` 与 `LlmProviderError`。
- `base.py` 的 `BaseProviderImpl` 保留 `complete()` / `complete_stream()` 抽象。
- `factory.py`：
  ```python
  _PROVIDERS = {
      "siliconflow": SiliconFlowProvider,
      "bailian": BailianProvider,
  }

  def get_llm_provider(provider_name: str | None = None) -> BaseProviderImpl:
      name = (provider_name or settings.ops_llm_provider).lower()
      cls = _PROVIDERS.get(name)
      if cls is None:
          raise ValueError(f"Unknown LLM provider: {name}")
      return cls()

  def get_default_model(provider_name: str | None = None) -> str:
      return model_catalog.get_default_model(provider_name or settings.ops_llm_provider)
  ```
- `model_catalog.py` 增加 `get_models_for_provider(provider: str)` 用于 `/chat/models`。
- `config.py` 的 `ops_llm_model` 默认值改为 `model_catalog.get_default_model("siliconflow")`。

**失败路径**：未知 provider 名称抛 `ValueError`；未知 provider 取默认模型抛 `ValueError`。

**验收标准**：工厂返回正确 Provider 实例；`/api/ops/chat/models` 返回非空模型列表；`ruff` 通过。

---

### 6.4 `load_context_node` 查 DB

**目标**：根据 query 中的 `#123` 从 `ops_issues` 表加载 issue 上下文，并以 `tool_result` 事件暴露结果。

**范围**：`app/ops/chat/nodes.py`。

**关键实现**：

- 正则提取 issue number：
  ```python
  def _extract_issue_number(query: str) -> int | None:
      match = re.search(r"#(\d+)", query)
      return int(match.group(1)) if match else None
  ```
- 节点内部新建 `AsyncSessionLocal()` 查询（保持节点签名纯函数，但允许内部短期 session）。
- 返回：
  ```python
  {
      "issue_context": [issue] if issue else [],
      "events": [{
          "event_type": "tool_result",
          "agent_role": "context",
          "payload": {
              "tool": "load_issue",
              "ok": issue is not None,
              "issue_number": issue_number,
              "summary": issue["title"] if issue else "未找到",
          },
      }],
  }
  ```

**失败路径**：

| 触发条件 | 行为 |
|---|---|
| query 无 `#\d+` | `ok=False`，`summary="未识别到 issue 编号"` |
| issue 不存在 | `ok=False`，`summary="未找到"` |
| DB 异常 | 捕获，`ok=False`，`summary="查询失败"` |

**验收标准**：存在/不存在/无编号/DB 异常四种场景测试通过；`ruff` 通过。

---

### 6.5 `answer_node` 接入 LLM

**目标**：调用 Provider 流式生成回答，将 chunk 映射为 `answer` 事件，透传 `model.fallback` 事件。

**范围**：`app/ops/chat/nodes.py`、`app/llm/factory.py`、`app/llm/model_catalog.py`。

**关键实现**：

- `ChatState` 增加 `model: str | None` 字段（从请求透传）。
- 构建 messages：system prompt + issue context（截断至 2000 字符）+ user query。
- 选择模型：`model = state.get("model") or get_default_model(settings.ops_llm_provider)`。
- 遍历 `provider.complete_stream(messages, model=model)`：
  - `chunk.meta["event_type"] == "model.fallback"` → emit `model.fallback`。
  - 否则 → emit `answer` 事件，并累积到 `answer_parts`。
- 异常时 emit `error` 事件。

**失败路径**：

| 触发条件 | 行为 |
|---|---|
| Provider retryable 错误 | emit `error`，`retryable=True` |
| Provider 非 retryable 错误 | emit `error`，`retryable=False` |
| 未预期异常 | 转换为 `error` 事件 |
| 空流 | `answer=""`，仅含 `thinking` |

**验收标准**：FakeProvider 产生 chunks 时事件序列正确；fallback meta 被透传；异常时以 error 结尾；`ruff` 通过。

---

### 6.6 `run_chat_stream` 事件映射

**目标**：将 LangGraph 节点输出映射为统一内部事件流，供 SSE 路由消费与持久化。

**范围**：`app/ops/chat/service.py`、`app/ops/chat/state.py`。

**关键实现**：

```python
async def run_chat_stream(state: ChatState) -> AsyncIterator[dict]:
    try:
        async for node_update in graph.astream(state, stream_mode="updates"):
            for node_name, node_output in node_update.items():
                for event in node_output.get("events", []):
                    yield {
                        "event_type": event.get("event_type", "unknown"),
                        "agent_role": event.get("agent_role", node_name),
                        "payload": event.get("payload", {}),
                    }
    except Exception as exc:
        yield {
            "event_type": "error",
            "agent_role": "system",
            "payload": {"stage": "graph", "message": str(exc), "retryable": False},
        }
```

**失败路径**：节点返回非列表 `events` 时兜底为空；Graph 异常时 yield `error`。

**验收标准**：按顺序产出 `thinking` → `tool_result`（issue intent）→ `thinking`/`answer`/`model.fallback`/`error`；FakeProvider monkeypatch 验证完整序列；`ruff` 通过。

---

### 6.7 `ops_runs` / `ops_run_events` 持久化

**目标**：SSE 流式响应的同时完成持久化，且持久化不阻塞 SSE。

**范围**：`app/ops/chat/router.py`、`app/ops/chat/service.py`、`app/db/models.py`、`app/db/session.py`。

**关键实现**：

1. 路由入口用 `Depends(get_db)` 创建 `ops_runs` 记录并立即 commit。
2. generator 维护事件缓冲区。
3. 后台 task 定期 flush 到 `ops_run_events`，使用独立 session。
4. `finally` 中确保后台 flush task 完成。
5. `OpsRun` 最终更新：
   - `status = "error"` 若事件含 `error`，否则 `"completed"`
   - `latency_ms = events[-1]["ts_ms"]`
   - `answer = "".join(answer event contents)`

**失败路径**：

| 触发条件 | 行为 |
|---|---|
| `ops_runs` 插入失败 | emit `error` 并关闭流 |
| 流正常结束但 events 写入失败 | SSE 已发送；记录日志 |
| 流异常结束 | `status="error"`，尝试归档已产生事件 |
| 客户端提前断开 | generator 停止，未 flush 部分可能丢失 |

**验收标准**：完整 SSE 请求后 `ops_runs` 与 `ops_run_events` 有正确记录；模拟 DB commit 异常不中断 SSE；`ruff` 通过。

---

### 6.8 Chat SSE 路由端到端

**目标**：完成 `POST /api/ops/chat/stream` 端到端链路。

**范围**：`app/ops/chat/router.py`、`app/ops/chat/schema.py`、`app/ops/chat/sse.py`、`app/ops/deps.py`、`app/db/models.py`、`docs/_tech_graph/10_flow_chat.graph.yaml`。

**关键实现**：

- 路由增加 `user: OpsUser = Depends(get_current_user)`。
- `session_id` 为空则新建 `OpsSessionChat`；非空则校验归属。
- 使用 `make_sse_event(...)` 格式化 SSE。
- 响应头：`text/event-stream`、`Cache-Control: no-cache`、`X-Accel-Buffering: no`、`Connection: keep-alive`。
- 改码后运行 `./scripts/graph-compile.sh` 更新锚点。

**失败路径**：

| 触发条件 | 行为 |
|---|---|
| 未认证 | 401 |
| `session_id` 无效 | 404 |
| `message` 为空 | 422 |
| Provider 失败 | SSE `error` 事件 |
| DB 写入失败 | SSE 继续；后台日志 |

**验收标准**：已认证请求返回 SSE；序列完整；Provider 失败以 `error` 结束；`ops_runs`/`ops_run_events` 有记录；`./scripts/graph-compile.sh` 通过；`ruff` 通过。

---

### 6.9 Chat 单元/集成测试

**目标**：建立 Provider、节点、service、路由的可维护测试套件。

**范围**：`tests/conftest.py`、`tests/test_llm_providers.py`、`tests/test_chat_nodes.py`、`tests/test_chat_service.py`、`tests/test_chat_router.py`。

**关键实现**：

- `FakeProvider` fixture：
  ```python
  class FakeProvider(BaseProviderImpl):
      def __init__(self, chunks: list[LlmChunk]) -> None:
          self._chunks = chunks
      async def complete_stream(self, messages, model=None):
          for chunk in self._chunks:
              yield chunk
  ```
- HTTP mock：使用 `httpx.MockTransport` 或 monkeypatch `httpx.AsyncClient.stream`。
- DB fixture：async 事务内创建 session，测试结束后 rollback。
- SSE 解析 helper：按 `\n\n` 分割，解析 `event:` 与 `data:`。
- 认证 override：在 `conftest.py` 提供 `override_auth` fixture。

**验收标准**：`pytest tests` 通过；`ruff check app tests` 通过；覆盖 general/issue_qa 两条意图；至少一个测试校验 `seq` 连续性。

---

## 5. 失败路径汇总

| 触发条件 | 系统行为 | 可重试 | 用户可见 |
|---|---|---|---|
| LLM API 不可用 | fallback 到百炼；都失败则 SSE `error` | 是 | error 事件 |
| 流式解析失败 | 关闭流并返回 error | 是 | error 事件 |
| DB 写入失败 | 流继续，但事件不持久化；日志记录 | 否 | 无（后台失败） |
| 未认证 | FastAPI 返回 401 | 是 | 401 |
| 无效 session_id | 返回 404 | 是 | 404 |
| 空 message | Pydantic 422 | 是 | 422 |

---

## 6. 验收标准汇总

- `pytest tests` 通过
- `ruff check app tests` 通过
- `./scripts/graph-compile.sh` 通过
- 本地可发起 `POST /api/ops/chat/stream` 并收到完整 SSE 事件
- `ops_runs` 表有记录，`ops_run_events` 表有事件归档
- `/api/ops/chat/models` 返回可用模型与 fallback 链

---

## 7. 关键文件

- `app/llm/schema.py`
- `app/llm/factory.py`
- `app/llm/model_catalog.py`
- `app/llm/providers/siliconflow.py`
- `app/llm/providers/bailian.py`
- `app/ops/chat/state.py`
- `app/ops/chat/nodes.py`
- `app/ops/chat/service.py`
- `app/ops/chat/router.py`
- `app/ops/chat/sse.py`
- `app/db/models.py`
- `docs/_tech_graph/10_flow_chat.graph.yaml`

---

## 8. 复查结论与修正点

本计划经 adversarial review 后修正以下关键点：

1. **使用现有 `app/llm/factory.py`**，不再新建 `app/llm/provider.py`。
2. **任务依赖顺序修正**：6.1 / 6.2 并行 → 6.3 依赖 6.1、6.2 → 6.4 / 6.5 并行 → 后续串行。
3. **LangGraph 主路径**明确为 `graph.astream(state, stream_mode="updates")`。
4. **持久化 session 生命周期与 generator 解耦**，避免连接泄漏与事务悬空。
5. **`chat_stream` 增加鉴权与 `OpsSessionChat` 处理**。
6. **Provider 增加 API key 校验、显式超时、fallback 链过滤 test_only 模型**。
7. **config 与 model_catalog 默认模型统一**。
8. **测试基础设施补充 DB fixture 与认证 override**。

---

## 9. 修订记录

| 日期 | 说明 |
|---|---|
| 2026-07-16 | 初始版本，整合 Plan agent 输出与 adversarial review 修正 |
