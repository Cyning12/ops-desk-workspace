# Chat 工具化上下文契约 v1

> **状态**:主路径 T1/T3/T4/T13 已定稿(2026-08-08)· T8 指标随实现再定 · **实现暂缓(RAG 先行)**

## 1. 范围与边界

- 形态：M1 工具化 Graph 节点；不是 LLM Function Calling / `bind_tools`
- 允许：仅读取已 sync 入 Ops DB 的 Issue / Pull 数据
- 禁止：写 DB、触发 sync、调用 GitHub 写 API
- 主路径：`Issue #n → T1 → T4（内部可读 T3）→ T13 → answer`

## 2. T1 · load_issue

### 输入

| 字段 | 来源 | 规则 |
|---|---|---|
| `issue_number` | 用户消息中的 `#<整数>` | 必须为正整数；无匹配则不查库 |

### 只读数据源

`ops_issues`：`number`、`title`、`body`、`state`、`labels`、`module_tag`、`html_url`。

### 结果与错误语义

| 条件 | `ok` | 行为 |
|---|---:|---|
| 找到 Issue | true | 写入 `issue_context`，继续 T4 |
| 未带 `#n` | false | 不查库；结束工具链，回答提示用户提供编号 |
| Issue 不存在 | false | 不调用 T3/T4；不得编造 PR、状态或链接 |
| DB 异常 / 超时 | false | 不调用 T3/T4；回答说明暂时无法查询 |

### SSE tool_result

```json
{
  "event_type": "tool_result",
  "agent_role": "context",
  "payload": {
    "tool": "load_issue",
    "ok": true,
    "issue_number": 42,
    "summary": "登录失败修复",
    "citations": [
      {
        "kind": "issue",
        "number": 42,
        "url": "https://github.com/org/repo/issues/42"
      }
    ]
  }
}
```

## 3. T3 · load_pull(T4 内部依赖 · 不直接路由)

### 输入

| 字段 | 来源 | 规则 |
|---|---|---|
| `pr_number` | T4 关联解析结果(见 §4) | 正整数;**不由用户消息直接路由**——issue/PR 共享 number 序列,`#n` 直路由有歧义 |

### 只读数据源

`ops_pull_requests`:`number`、`title`、`body`、`state`、`draft`、`ci_status`、`author`、`reviewers`、`html_url`、`merged_at`、`first_review_at`。

### 结果与错误语义

| 条件 | `ok` | 行为 |
|---|---:|---|
| 找到 PR | true | 写入 `pull_context`,返回 T4 |
| PR 不存在 | false | 返回 T4 标注「关联 PR 未 sync / 已失效」;不得编造 |
| DB 异常 / 超时 | false | T4 降级为「仅 issue 上下文 + 说明 PR 查询失败」 |

## 4. T4 · compare_issue_pr(主路径核心)

### 输入

| 字段 | 来源 | 规则 |
|---|---|---|
| `issue_number` | T1 已写入的 `issue_context` | T1 `ok=true` 才进入 T4 |

### 关联规则(确定性匹配 · 不用 LLM)

按优先级,命中即收(2026-08-08 人定):

1. PR `body` 含 closing 引用:`close[sd]?|fix(e[sd])?|resolve[sd]? #<issue_number>`(大小写不敏感)
2. PR `title` 含 `#<issue_number>`
3. ~~branch 名匹配~~(v1 不做:branch 只在 `raw_payload`,不稳定)

### 输出结构

写入 `comparison_context`:

| 字段 | 含义 |
|---|---|
| `linked_prs[]` | 关联 PR 的 number / state / draft / ci_status / merged_at / first_review_at / html_url |
| `verdict` | 结论枚举(2026-08-08 定):`fixed`(有 merged PR)/ `in_progress`(有 open PR)/ `stale`(PR closed 未 merged)/ `no_linked_pr`(未找到) |
| `evidence_note` | 一句话判定依据(供答案引用) |

### 错误语义

- 无关联 PR → `verdict = no_linked_pr`,**明说未找到**,不得编造关联
- T3 全部失败 → verdict 不得升为 `fixed` / `in_progress`

## 5. T13 · 回答强制引用(答案侧约束)

| 规则 | 内容 |
|---|---|
| 必须引用 | 答案陈述任何具体 issue/PR 的**事实**(状态、verdict、时间、CI)时,必带 `#n` + url |
| 引用来源 | 仅限本会话 T1/T3/T4 **实际取到**的号;未取到的号禁止出现在引用中(防编造闸) |
| 格式 | citations:`{kind: issue|pr, number, url}`;SSE `tool_result` 与最终答案一致 |
| 无引用答案 | 仅当答案为「提示提供编号 / 说明查询失败 / 一般性建议」时允许 |

## 6. T8 · load_overview_stats(不阻塞 Demo)

指标清单(暂缓 · 随实现再定)建议起跑集(全部可由 DB 聚合):

- open issues / open PRs 计数
- 近 7 天新建与关闭 issue 数
- (可选)按 `module_tag` 的 open issue 分布

## 7. 与 RAG 检索节点的分工

工具节点(本契约)查「**这一条** issue/PR」(按 `#n` 精确取);检索节点(`rag-knowledge-contract-v1`)答「**哪条** issue/文档相关」(模糊语义找)。两路互不替代。

## 修订

| 日期 | 说明 |
|---|---|
| 2026-07-30 | T1 契约首版(人写) |
| 2026-08-08 | 补 T3/T4/T13/T8 骨架(AI 搭)· 修复未闭合代码块 · §7 RAG 分工 |
| 2026-08-08 | §4 关联规则与 verdict 人定稿;T8 暂缓;**工具线实现暂缓,RAG 先行** |
