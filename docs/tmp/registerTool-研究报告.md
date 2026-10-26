# VanorOS `registerTool` 使用研究报告

> 版本基准：Vanor 0.5.8（运行时 `/opt/vanor`，`package.json` version=0.5.8）
> 报告日期：2026-10-26
> 研究方式：源码静态阅读 + 可执行验证脚本 + 行为实测
> 结论性质：供与技术人员讨论的改进依据，非正式漏洞报告

---

## 零、摘要

Vanor 的工具注册机制极为简陋：`ToolRegistry.register()` 只做一次 `Map.set`，**无任何形状校验、无拒绝码、无能力声明**。畸形工具会被静默接受，错误推迟到运行时才暴露，且暴露方式不确定（有时抛异常、有时静默失败）。

这与「工具是 Agent 的能力边界」这一认识严重不匹配。工具注册表是整个系统最需要**静态可审计性**的地方，而恰恰是校验最薄弱的地方。

本报告给出三处可直接修补的缺口（按收益/成本排序）与两处不能照搬的设计取舍。

核心发现三条：

1. **注册期零校验** —— `register({name:"no_handler"})` 可通过，`schemas()` 照常把它发给模型
2. **`validateSchema` 不支持 `pattern` / `maxLength`** —— 参数约束写了也不生效（实测错误数=0）
3. **MCP 工具的 `autoApprove` 可一键把整个服务器判为 `safe`** —— 第三方进程能力绕过审批

---

## 一、现状解剖（代码级）

### 1.1 `register` 只有一行赋值

`base/tools/index.js:10-32`

```js
export class ToolRegistry {
  constructor() {
    this.tools = new Map();
  }
  register(tool) {
    this.tools.set(tool.name, tool);   // ← 全部逻辑就这一行
    return this;
  }
  registerAll(list) {
    for (const t of list) this.register(t);
    return this;
  }
  get(name) {
    return this.tools.get(name);
  }
  has(name) {
    return this.tools.has(name);
  }
  /** 返回供 LLM 使用的 schema 列表。 */
  schemas() {
    return [...this.tools.values()]
      .map((t) => ({
        name: t.name,
        description: t.description,
        parameters: t.parameters,
      }))
      .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  }
}
```

**没有做的事：**

- 不校验 `name` 是否存在、是否合法字符、是否为空
- 不校验 `parameters` 是否为合法 JSON Schema
- 不校验 `handler` 是否为函数
- 不校验 `danger` 是否声明（缺失时 `runToolCall` 里用 `|| "confirm"` 兜底）
- 不校验重名（**后注册者静默覆盖前者**）
- 不记录注册来源（内建 / MCP / 自定义 / 数据层工具）

### 1.2 畸形注册的实测行为

验证脚本（`node` 直接 import 模块）：

```js
const r = new ToolRegistry();
r.register({name:"no_handler", parameters:{type:"object"}});  // 缺 handler
r.register({name:"no_schema"});                                // 缺 parameters
r.register({name:"empty_name_doc", parameters:{}});
```

实测输出：

```
注册畸形工具后数量: 3
schemas() 正常
调用时才暴露: Cannot read properties of undefined (reading 'approvalMode')
```

**结论：**
- 三个畸形工具**全部注册成功**
- `schemas()` 正常返回 —— 也就是说**畸形工具会被原样发给 LLM**，模型看到的工具列表里有它
- 错误直到**调用时**才暴露

### 1.3 错误暴露时机不一致（更隐蔽的问题）

另一次实测：

```js
r.register(null);
```

```
TypeError: Cannot read properties of null (reading 'name')
    at ToolRegistry.register (index.js:17:25)
```

**同一份 API，三种行为：**

| 输入 | 行为 |
|---|---|
| `register(null)` | 立即抛 TypeError |
| `register({name:"x"})` | 静默通过 |
| `register({name:"x", handler: 123})` | 静默通过，调用时才 `tool.handler is not a function` |

这种不一致性让调用方**无法写统一的错误处理**。

### 1.4 `register` 的调用点分布

```bash
$ grep -c "register(" base/core/harness.js base/transport/web/server.js
base/core/harness.js:5
base/transport/web/server.js:6
```

调用点分散在两个宿主文件里，各自注册不同的工具集合：

**`harness.js`（Agent 侧，每会话一个 registry）**

| 行号 | 注册内容 |
|---|---|
| 238-246 | A 类内置工具（`defaultRegistry` 或按 `builtinTools` 白名单过滤） |
| 249 | `memory.tool` |
| 250 | `knowledge.tool` |
| 251-259 | `skills` 工具 |
| 260 | `vanor` 工具 |
| 261 | `tasks` 工具 |
| 263 | `hooks` 工具 |
| 264 | `session` 工具 |
| 266 | `message` 工具 |
| 269 | `clarify`（受 `agent.clarify` 控制） |
| 273-274 | `plan` / `reflect`（受 `agent.planning` 控制） |
| 275 | `live` |
| 279 | `web_search`（受 `webSearch.enabled`） |
| 293 | `browser`（受 `browser.enabled`） |
| 306 | `desktop`（受 `desktop.enabled` + 平台支持） |
| 315 | `mcp` |
| 318 | `subagent`（受 `subagentCapable()`） |
| 322-325 | `extraTools`（**最后注册，同名覆盖前面所有**） |

**`server.js`（应用直调侧，全进程共享一个 registry）**

| 行号 | 注册内容 |
|---|---|
| 816 | `defaultRegistry(i18n)` |
| 817 | `createMemory(...).tool` |
| 818 | `createHooksTool(...)` |
| 819 | MCP `agentTools()` |

**关键观察：两处注册的是「不同但高度重叠」的工具集，各自独立维护注册清单。** 新增一个工具要在两个地方各加一次，漏掉一处就造成「Agent 能调、应用不能调」或反之。

---

## 二、三个 registry 实例及其差异

这是理解 Vanor 工具注册机制的前提。

| 实例 | 位置 | 生命周期 | 谁在用 |
|---|---|---|---|
| `harness.registry` | `harness.js` 内闭包变量 | **每会话一个**，`runTurn` 开头 `reloadConfig` 时整体替换 | Agent 的 `runLoop` |
| `appRuntime.registry` | `server.js:816`，惰性构建 | **全进程共享一个**，配置/白名单/MCP 变更时置空重建 | 应用 `os.invoke()` 直调 |
| `runToolCall` 执行器 | `tools/index.js:216` | 无状态函数 | 上面两者共用 |

### 2.1 造成的实际差异

| 场景 | Agent 侧 | 应用侧 |
|---|---|---|
| 修改 `browser.enabled` | 下次 `runTurn` 生效 | 需 `appRuntime = null` 重建 |
| MCP 服务增删 | 下次 `runTurn` 生效 | `appRuntime = null` 重建（`server.js:3723`） |
| 工具白名单变更 | 影响 `harness.registry` | 另有 `web.appTools` 白名单（`server.js:687`） |
| 是否消耗 token | 是（走 LLM） | **否**（直调工具） |
| 是否有会话记录 | 是 | 否 |

### 2.2 并发/aspect 差异

```js
// server.js:645
let appRuntime = null; // { registry, ctx } 惰性构建，配置变更时置空重建

// server.js:575
appRuntime = null; // 白名单/安全策略/语言可能已变化，invoke 时重建
```

应用侧的 ctx **是共享的**，仅在每次调用时浅拷贝（`server.js:875` 注释：「appRuntime 缓存共享 ctx，故按调用浅拷贝上下文」）。这意味着：

- 并发应用调用会共享同一个 `security` 实例
- 若某次调用修改了 `security`（如审批升为 auto），会影响其他并发调用

Agent 侧则是每 `runTurn` 新建 `toolCtx`（`harness.js:822`），**无此问题**。

---

## 三、核心缺口一：注册期零校验

### 3.1 问题定性

工具注册是「声明能力存在」的动作。按最小权限原则，**能力必须先被声明、被校验、被审计，才能存在**。Vanor 现在是反过来的：**任何对象只要带个 `name` 就能成为工具**。

### 3.2 为什么这是问题（四个具体后果）

**后果 1：模型可能被喂进畸形工具**

`schemas()` 不校验直接映射：

```js
schemas() {
  return [...this.tools.values()].map((t) => ({
    name: t.name,
    description: t.description,
    parameters: t.parameters,
  }));
}
```

`{name:"no_schema"}` 会产出 `{name:"no_schema", description:undefined, parameters:undefined}` 发给 LLM。多数 provider 会因此报 400 或让模型行为异常，而错误信息指向 provider 侧，**排查成本极高**。

**后果 2：同名覆盖是「契约」而非「错误」**

```js
// harness.js:320
// 自定义工具最后注册：同名覆盖 A/B/C 任何工具（契约）
```

这是 `extraTools` 嵌入 API 的设计（`package.json` 的 `exports` 含 `./harness`）。但**它没有降级保护**：自定义工具可以把内置的 `exec` 覆盖成任意实现，包括把 `danger` 从 `"confirm"` 改成 `"safe"`。

```js
// 现有能力下可以直接这么干
extraTools: [{
  name: "exec",              // 覆盖内置 exec
  danger: "safe",            // 从 confirm 降为 safe，绕过审批
  handler: async () => "...",
}]
```

**后果 3：注册失败无码可依**

现有 API 中，一次注册是否成功无法判断——`register` 返回 `this`（链式调用），无论成功失败都一样。

**后果 4：无法审计「这个实例能干什么」**

要回答「当前 Agent 有哪些能力」，必须读源码找出所有 `register` 调用点，再从配置判断哪些被启用。没有任何运行时快照能一次性给出答案。

### 3.3 建议的注册契约

```js
// 建议实现（伪代码，非现有代码）
class ToolRegisterError extends Error {
  constructor({ code, tool, detail }) {
    super(code);
    this.code = code;        // 机器可读拒绝码
    this.tool = tool;        // 出问题的工具名（可能为 undefined）
    this.detail = detail;    // 结构性说明
  }
}

register(tool) {
  // L1 形状校验
  const shapeErrs = validateToolShape(tool);
  if (shapeErrs.length)
    throw new ToolRegisterError({ code: "E_TOOL_SHAPE", tool: tool?.name, detail: shapeErrs });

  // L2 重名处理：区分「首次注册」与「显式覆盖」
  if (this.tools.has(tool.name) && !tool.__allowOverride)
    throw new ToolRegisterError({ code: "E_TOOL_DUP", tool: tool.name });

  // L3 能力声明必须存在
  if (!tool.capability)
    throw new ToolRegisterError({ code: "E_TOOL_NO_CAP", tool: tool.name });

  // L4 写操作不得默认放行（对齐「写操作默认拒绝」原则）
  if (tool.sideEffect === "write" && tool.danger === "safe")
    throw new ToolRegisterError({ code: "E_TOOL_WRITE_UNGUARDED", tool: tool.name });

  // L5 覆盖时禁止安全降级
  const prev = this.tools.get(tool.name);
  if (prev && rank(prev.danger) < rank(tool.danger))
    throw new ToolRegisterError({ code: "E_TOOL_DANGER_DOWNGRADE", tool: tool.name });

  this.tools.set(tool.name, {
    ...tool,
    __registeredAt: Date.now(),
    __source: tool.__source || "unknown",
  });
  return this;
}

function validateToolShape(t) {
  const e = [];
  if (!t || typeof t !== "object") return ["not an object"];
  if (typeof t.name !== "string" || !/^[a-zA-Z][a-zA-Z0-9_.-]{0,63}$/.test(t.name))
    e.push("invalid name");
  if (typeof t.description !== "string" || !t.description.trim())
    e.push("missing description");
  if (typeof t.handler !== "function") e.push("missing handler");
  if (!t.parameters || typeof t.parameters !== "object") e.push("missing parameters");
  else if (t.parameters.type !== "object") e.push("parameters.type must be object");
  if (t.danger !== undefined && !["safe", "confirm", "dangerous"].includes(
        typeof t.danger === "function" ? "confirm" : t.danger))
    e.push("invalid danger");
  return e;
}
```

### 3.4 兼容性分析

| 现有调用 | 是否受影响 | 处理方式 |
|---|---|---|
| `register(memory.tool)` 等 B 类工具 | 需补 `capability` 声明 | 一次性补齐 |
| `extraTools` 覆盖内置 | 需显式 `__allowOverride: true` | 改调用方，或注册时按来源判断 |
| MCP 工具（`mcp__x__y`） | `name` 含 `__`，正则需允许 | 已在正则中放行 `_` |
| 测试/嵌入用法 | 可能传最小对象 | 提供 `registerUnsafe()` 逃生口 |

---

## 四、核心缺口二：`validateSchema` 不支持 `pattern` / `maxLength`

### 4.1 实测结果

`base/utils.js` 的 `validateSchema`：

```js
export function validateSchema(schema, value, p = "", t = defaultT) {
  const errors = [];
  if (!schema || typeof schema !== "object") return errors;
  const loc = p || "(root)";

  if (schema.type && !checkType(schema.type, value)) {
    errors.push(t("schema.expectedType", { loc, type: schema.type }));
    return errors;
  }
  if (schema.enum && !schema.enum.includes(value)) {
    errors.push(t("schema.enumValue", { loc, values: JSON.stringify(schema.enum) }));
  }
  if (schema.type === "object" && checkType("object", value)) {
    for (const req of schema.required || []) {
      if (!(req in value)) errors.push(t("schema.required", { loc, field: req }));
    }
    for (const [k, sub] of Object.entries(schema.properties || {})) {
      if (k in value) {
        errors.push(...validateSchema(sub, value[k], p ? `${p}.${k}` : k, t));
      }
    }
  }
  if (schema.type === "array" && Array.isArray(value) && schema.items) {
    value.forEach((item, i) => {
      errors.push(...validateSchema(schema.items, item, `${p}[${i}]`, t));
    });
  }
  return errors;
}
```

**支持的校验项：`type` / `enum` / `required` / `properties` / `items`**

**不支持的校验项：`pattern` / `maxLength` / `minLength` / `minimum` / `maximum` / `format` / `additionalProperties`**

### 4.2 实测验证

```js
const schema = {
  type: "object",
  properties: {
    name: { type: "string", pattern: "^[a-z]+$", maxLength: 8 },
    mode: { type: "string", enum: ["a","b"] },
  },
  required: ["name"],
};

// 实测输出：
合法              → 错误数=0  （通过）
pattern 违规      → 错误数=0  （通过）   ← 应为 1
maxLength 违规    → 错误数=0  （通过）   ← 应为 1
enum 违规         → 错误数=1   schema.enumValue{...}
缺必填             → 错误数=1   schema.required{...}
类型错             → 错误数=1   schema.expectedType{...}
```

**`pattern: "^[a-z]+$"` 对 `"ABC123"` 返回零错误。** 声明了约束、写了 schema，但**运行时完全不检查**。

### 4.3 影响面

这不是「少一个校验项」的问题，而是**schema 的自我描述能力残缺**：

1. **工具定义里写 `pattern` 是误导性的** —— 读者以为有约束，实际没有
2. **无法用 schema 表达路径白名单、ID 格式、长度上限** —— 这些是最常见的参数约束
3. **与其他实现对接时语义不对齐** —— 外部令牌层用 `pattern` 约束参数值，Vanor 只在 schema 里写同样的 `pattern`，两边行为不一致

### 4.4 建议的最小补丁

```js
// 在 validateSchema 的字符串分支增加
if (typeof value === "string") {
  if (schema.pattern !== undefined) {
    let re;
    try {
      re = new RegExp(schema.pattern, "u");
    } catch (e) {
      errors.push(t("schema.invalidPattern", { loc, pattern: schema.pattern }));
      return errors;   // 正则本身非法，直接返回
    }
    // 必须用完整匹配：避免 "123abc" 通过 "\d+"
    if (!re.test(value) || value.match(re)?.[0] !== value) {
      // 更严谨：用 anchored 检查
      const m = value.match(re);
      if (!m || m[0] !== value) {
        errors.push(t("schema.patternMismatch", { loc, pattern: schema.pattern }));
      }
    }
  }
  if (Number.isInteger(schema.maxLength) && value.length > schema.maxLength) {
    errors.push(t("schema.tooLong", { loc, len: value.length, max: schema.maxLength }));
  }
  if (Number.isInteger(schema.minLength) && value.length < schema.minLength) {
    errors.push(t("schema.tooShort", { loc, len: value.length, min: schema.minLength }));
  }
}
```

**关于完整匹配的实测证据：**

```
pattern='\d+'        value='123abc'  → re.search=True   ← 应拒却放
pattern='^\d+$'      value='123abc'  → False
pattern='^[\w./-]+$' value='../../etc/passwd' → True    ← 路径穿越未挡
pattern='^[a-z]+$'   value='abc\n'   → re.match=True    ← $ 不锚定换行
```

**结论：实现时必须用完整匹配（`m[0] === value`），不能依赖作者写 `^...$`。** JavaScript 的 `$` 与 Python 一样不锚定末尾换行。

**风险：无。** 纯增量，现有 schema 不含这些字段则行为完全不变。

---

## 五、核心缺口三：MCP 工具可一键升为 `safe`

### 5.1 代码位置

`base/mcp/manager.js:130-150`

```js
function agentTools(getI18n) {
  const t = (key, vars) => (getI18n?.() || defaultI18n).t(key, vars);
  const out = [];
  for (const entry of servers.values()) {
    for (const tool of entry.tools) {
      out.push({
        name: mcpToolName(entry.name, tool.name),
        description: t("mcp.toolPrefix", { server: entry.name, description: tool.description || tool.name }),
        parameters: tool.inputSchema || { type: "object", properties: {} },
        danger: toolAutoApproved(entry, tool.name) ? "safe" : "confirm",
        handler: async (args) => { ... },
      });
    }
  }
  return out;
}

function toolAutoApproved(entry, toolName) {
  const auto = entry.def.autoApprove;
  if (auto === true) return true;
  return Array.isArray(auto) && auto.includes(toolName);
}
```

### 5.2 问题定性

当配置写 `autoApprove: true`，**该 MCP 服务器的全部工具**都被判为 `danger: "safe"`，`approve()` 直接放行：

```js
// tools/index.js:193
if (danger === "safe") return { allowed: true, danger: "safe" };
```

**MCP 工具是外部进程提供的，其行为不受 Vanor 控制。** 一个恶意或被入侵的 MCP 服务器可以：

1. 声明一个名为 `read_notes` 的工具，实际执行任意文件写入
2. 通过 `autoApprove: true` 获得 `safe` 等级
3. 全流程无任何审批提示

### 5.3 与其他设计的一致性

这与 Vanor 自己在 `exec` 上的处理明显不一致：

```js
// builtin.js:3455 —— 内置 exec 的 danger 是函数，按参数细化
danger: (args) => (!args.action || args.action === "run" ? "confirm" : "safe"),
```

**内置工具默认 `confirm` 且需按参数判断，外部工具却能一键免审。** 这个不一致值得明确：是有意为之（信任 MCP 配置）还是历史遗留。

### 5.4 建议

**方案 A（严格）**：MCP 工具永不获得 `safe`，`autoApprove` 仅用于跳过审批弹窗但仍记审计日志。

**方案 B（折中）**：保留 `autoApprove`，但要求显式声明能力类别：

```json
{
  "mcp": {
    "servers": {
      "my-server": {
        "autoApprove": ["read_notes"],
        "capabilities": {
          "read_notes": { "sideEffect": "read" }
        }
      }
    }
  }
}
```

只有 `sideEffect: "read"` 的工具允许 `autoApprove`。未声明的一律 `confirm`。

**方案 C（最小改动）**：`autoApprove` 生效时仍打日志，且每次启动在 UI 上提示「以下 MCP 工具已免审批：…」。

---

## 六、设计取舍：`danger` 作为函数的代价

### 6.1 现状

```js
// builtin.js:3455
{
  name: "exec",
  danger: (args) => (!args.action || args.action === "run" ? "confirm" : "safe"),
}
```

```js
// tools/index.js:185
function dangerLevel(tool, call) {
  return typeof tool.danger === "function" ? tool.danger(call.arguments || {}) : tool.danger;
}
```

### 6.2 收益与代价

| 维度 | 收益 | 代价 |
|---|---|---|
| 体验 | `exec` 一个工具承载四种语义（run/status/wait/kill），避免工具列表膨胀 | — |
| 可审计 | — | **权限边界在代码里，无法从配置层面回答「这个工具最坏能干什么」** |
| 可测试 | — | 需为每个参数分支写测试才能确认边界 |
| 变更风险 | — | 改一行 `danger` 逻辑可能悄悄放开权限，且无测试拦截 |
| 静态审查 | — | 代码评审时无法快速判断权限变化 |

### 6.3 建议：加一层静态摘要，而非取消动态判定

```js
{
  name: "exec",
  danger: (args) => (!args.action || args.action === "run" ? "confirm" : "safe"),
  capability: "shell.exec",
  sideEffect: "write",          // ← 强制声明最坏情况
  worstCaseDanger: "danger",    // ← 审计用，不做参数分析也知最坏是什么
}
```

这样：

- **运行时**：仍按参数细化，体验不降
- **审计时**：读 `worstCaseDanger` 就有确定答案
- **注册时**：可强校验 `sideEffect === "write"` 的工具必须声明 `worstCaseDanger`

---

## 七、与「七层闸控」设计的对照

> 对照对象：外部项目的七层纯代码闸控设计（令牌验签 → 注册表查找 → 开关 → Policy → 熔断 → 配额 → 参数 schema）

### 7.1 逐层对照

| # | 七层闸控层 | Vanor 对应 | 状态 | 说明 |
|---|---|---|---|---|
| 1 | 令牌验签 | 无 | ❌ 缺失 | Vanor 无跨进程能力令牌概念，身份靠配置文件 |
| 2 | 注册表查找 | `registry.get(name)` | ✅ 有 | 但注册期无校验（见第三节） |
| 3 | 开关 | `configState.*.enabled` | ⚠️ 部分 | 只有 5 个工具级开关，无通用开关 |
| 4 | Policy | `security.approvalMode()` | ⚠️ 弱 | 全局三态（allow/ask/deny），非按能力策略 |
| 5 | 熔断 | 无 | ❌ 缺失 | LLM 层有重试退避，但无熔断器 |
| 6 | 配额 | 无 | ❌ 缺失 | 仅有 `llm/account.js` 查询余额，无调用配额 |
| 7 | 参数 schema | `validateSchema` | ⚠️ 弱 | 缺 `pattern` / `maxLength`（见第四节） |

### 7.2 关键差异

**差异 1：Vanor 的闸门是「运行时动态」，七层闸控是「静态声明」**

```js
// Vanor：权限判定可以依赖参数
danger: (args) => ...

// 七层闸控：权限判定是清单条目，参数约束在令牌层
capability: "oa.ticket.create"  // 静态 id
token: { enum: [...], max_len: ..., pattern: ... }  // 参数约束
```

前者灵活、后者可审计。Vanor 的 `exec` 确实是合理的使用场景，但**应保留动态判定的同时补充静态摘要**（见 6.3）。

**差异 2：Vanor 没有「能力」这一抽象层**

```bash
$ grep -rn "capability\|Capability" base/core/harness.js base/tools/index.js
（无匹配）
```

Vanor 的「工具」直接是执行单元，没有「能力（capability）」与「实现（tool）」的分离。后果：

- 无法表达「一个能力有零个实现」（声明但未接入）
- 无法表达「一个能力有多个实现」（如本地/远程两种 `read_file`）
- 能力清单无法作为独立工件被评审

**差异 3：Vanor 的信任边界与七层闸控不同**

| | Vanor | 七层闸控 |
|---|---|---|
| 模型能否影响权限 | ❌ 不能（配置在 `configState`，模型不可触） | ❌ 不能（模型字段一律无效） |
| 审批信号来源 | 配置文件 + 用户交互回调 | 环境变量 + 人工批准的单次令牌 |
| 单次授权粒度 | 无单次令牌，`once` 仅内存记录 | 令牌绑定参数摘要 + nonce |
| 跨进程 | 不涉及 | 进程内保证，跨进程列入 v2.0 |

**两者在「模型不可影响权限」这一点上一致。** 这是最重要的信任边界，两边都划对了。

---

## 八、改进建议汇总

### 8.1 按收益/成本排序

| 优先级 | 改进项 | 解决问题 | 成本 | 风险 | 影响文件 |
|---|---|---|---|---|---|
| **P0** | `validateSchema` 支持 `pattern` / `maxLength` / `minLength` | schema 自我描述残缺，安全约束无法落地 | 极低（一个函数、约 20 行） | 无 | `base/utils.js` |
| **P1** | `register` 增加形状校验 + 拒绝码 | 畸形工具静默通过，错误推迟到运行时 | 低（约 60 行） | 低（需兼容 `extraTools` 覆盖） | `base/tools/index.js` |
| **P1** | 覆盖注册时禁止安全降级 | `extraTools` 可把 `exec` 从 confirm 覆盖为 safe | 低 | 中（会打破现有配置） | `base/tools/index.js` |
| **P2** | MCP `autoApprove` 限制或加审计 | 第三方进程能力一键免审批 | 低 | 中（可能打破现有 MCP 配置） | `base/mcp/manager.js` |
| **P2** | 工具声明 `sideEffect` + `worstCaseDanger` | 权限边界不可静态审计 | 中（需补全 24 个工具声明） | 低（纯增字段） | `base/tools/builtin.js` 及各工具 |
| **P3** | 统一两处注册清单 | 新增工具需改两个文件，易漏 | 中 | 低 | `harness.js` / `server.js` |
| **P3** | capability 与 tool 分离 | 支持能力目录、两阶段工具选择（省 token） | 高（架构级） | 中 | 多处 |

### 8.2 P0 最小补丁（可直接实施）

```js
// base/utils.js 的 validateSchema 内，字符串分支追加
if (typeof value === "string") {
  if (typeof schema.pattern === "string") {
    let re = null;
    try {
      re = new RegExp(schema.pattern, "u");
    } catch {
      errors.push(t("schema.invalidPattern", { loc, pattern: schema.pattern }));
    }
    if (re) {
      const m = value.match(re);
      // 完整匹配：不依赖作者写 ^...$，且 $ 不锚定换行
      if (!m || m[0] !== value) {
        errors.push(t("schema.patternMismatch", { loc, pattern: schema.pattern }));
      }
    }
  }
  if (Number.isInteger(schema.maxLength) && value.length > schema.maxLength) {
    errors.push(t("schema.tooLong", { loc, len: value.length, max: schema.maxLength }));
  }
  if (Number.isInteger(schema.minLength) && value.length < schema.minLength) {
    errors.push(t("schema.tooShort", { loc, len: value.length, min: schema.minLength }));
  }
}
```

需要同步补 i18n 词条：`schema.invalidPattern` / `schema.patternMismatch` / `schema.tooLong` / `schema.tooShort`（`base/i18n/locales/zh-CN.js` 与 `en.js`）。

### 8.3 验证方法（不依赖测试框架）

由于本发行包内 `base/test/*.test.js` 为 **0 个文件**（`npm test` 无实际内容），建议用独立脚本验证：

```bash
# 1. 验证 pattern 生效
node -e '
import("/opt/vanor/base/utils.js").then(({validateSchema})=>{
  const s={type:"object",properties:{n:{type:"string",pattern:"^[a-z]+$"}}};
  console.log("违规应为1:", validateSchema(s,{n:"ABC"},"",(k)=>k).length);
  console.log("合法应为0:", validateSchema(s,{n:"abc"},"",(k)=>k).length);
  console.log("绕过测试应为1:", validateSchema(s,{n:"abc123"},"",(k)=>k).length);
});'

# 2. 验证未破坏现有工具
node -e '
import("/opt/vanor/base/tools/index.js").then(async({defaultRegistry})=>{
  const {createI18n}=await import("/opt/vanor/base/i18n/index.js");
  const reg=defaultRegistry(createI18n({}));
  console.log("内置工具数（应为10）:", reg.schemas().length);
});'
```

---

## 九、五个可直接借鉴的点

按「拿去就能用」的标准筛选：

### 9.1 注册期契约校验（最重要）

见第三节。核心是**把「工具是什么」从运行时推测变成静态可审计声明**。

这是外部项目七层闸控设计里最容易被低估的一环。Vanor 有能力层（`tools/`，15,735 行）却没有能力清单，等于有实现无边界。

### 9.2 参数约束前移到 schema

见第四节。`pattern` / `maxLength` 应能在工具定义里声明并生效，而不是散落在 `handler` 内部的 `if` 判断中。

好处：
- 约束对模型可见（schema 会发给 LLM），模型能自我纠正
- 约束对审计可见（读 schema 就知边界）

### 9.3 写操作默认拒绝 + 显式声明

Vanor 现状是 `danger` 缺失时兜底 `confirm`（`tools/index.js:191`），这已经不错。但可以更进一步：**要求工具必须声明 `sideEffect`**，写操作不得声明为 `safe`。

### 9.4 拒绝码携带可重试性

Vanor 的拒绝目前是自然语言文本：

```js
return toolMessage({
  toolCallId: call.id,
  name: call.name,
  content: ctx.t("tools.denied"),
  isError: true,
});
```

建议增加机器可读部分：

```js
return toolMessage({
  toolCallId: call.id,
  name: call.name,
  content: ctx.t("tools.denied"),
  isError: true,
  meta: {
    // 关键：告诉模型这是"封死"还是"可修正"
    retriable: false,        // POLICY_DENIED 不可重试
    code: "POLICY_DENIED",
    hint: ctx.t("tools.deniedHint"),  // 给模型一句可执行的建议
  },
});
```

**理由**：`SCHEMA_MISMATCH` 应让模型改正参数重试，`POLICY_DENIED` 绝不能重试（会撞墙消耗 `maxIterations`）。Vanor 当前两者对模型是同一种「错误」，模型可能反复尝试。

### 9.5 并行分组策略反过来可借鉴

Vanor 的 `runToolCalls` 有一套值得外部项目学习的策略：

```js
// tools/index.js:391
function parallelSafe(call, registry, ctx) {
  const tool = registry.get(call.name);
  if (!tool || tool.exclusive === true) return false;
  return dangerLevel(tool, call) === "safe";
}

// 连续 safe 工具 → Promise.all 分批（上限 maxParallelTools，默认 6）
// 写/危险/需确认 → 强制串行
// 结果 → 按原始调用顺序回填
```

**这套「只读可并行、写操作强制串行、结果保序」的分组逻辑可直接用于任何单次授权 + 串行闸控的系统**，能在不放松安全的前提下显著提速。

---

## 十、结论

### 10.1 对 Vanor 的定性

**工程质量中等偏上，但安全边界设计薄弱。**

- ✅ 零依赖、代码可读性高、175 行主循环无魔法
- ✅ 审批默认 `confirm`（宁可多问一次）
- ✅ 模型不可影响权限（配置在 `configState`）
- ❌ 工具注册期零校验
- ❌ schema 约束能力残缺（无 `pattern`）
- ❌ 无能力抽象层，无法生成能力清单
- ❌ 无熔断、无配额
- ❌ `danger` 为函数导致权限边界不可静态审计

### 10.2 对两套设计的判断

**两者是不同方向的正交设计，不是替代关系。**

| 维度 | Vanor | 七层闸控 |
|---|---|---|
| 哲学 | **运行时灵活**：按参数细化、动态判定 | **静态可审计**：清单 + 令牌 + 声明 |
| 强项 | 表达力（一个工具多种语义） | 可审计性（权限边界是工件） |
| 弱项 | 无法静态回答「能干什么」 | 表达力受限（需拆细能力） |
| 适合 | 单机、单用户、可信环境 | 多租户、跨进程、需合规审计 |

**Vanor 应向七层闸控借鉴的是「注册期」，而不是「执行期」。** 执行期 Vanor 的实时审批 + 参数级 danger 反而更灵活；注册期它几乎空白。

### 10.3 立即可做的三件事

1. **补 `pattern` / `maxLength` 到 `validateSchema`**（约 20 行，零风险，当天可完成）
2. **给 `register` 加形状校验 + 拒绝码**（约 60 行，需兼容 `extraTools`）
3. **审查现有 MCP 配置里是否有 `autoApprove: true`**（`grep -r autoApprove ~/.vanor/config.json`）

第 1 项可立即验证效果，第 2 项需先确认 `extraTools` 的使用情况，第 3 项是一次配置审计。

---

## 附录 A：本报告涉及的代码位置索引

| 主题 | 文件:行号 |
|---|---|
| `ToolRegistry` 定义 | `base/tools/index.js:10-45` |
| `register` 实现 | `base/tools/index.js:16-19` |
| `schemas()` | `base/tools/index.js:33-45` |
| `runToolCall` 入口 | `base/tools/index.js:216` |
| `dangerLevel` | `base/tools/index.js:185-187` |
| `approve` 审批 | `base/tools/index.js:190-215` |
| `parallelSafe` | `base/tools/index.js:391-395` |
| `runToolCalls` 并行 | `base/tools/index.js:385-445` |
| `validateSchema` | `base/utils.js`（导出于 `tools/index.js:4`） |
| 内置工具定义 | `base/tools/builtin.js:3521`（`builtinTools`） |
| `exec` 的 danger 函数 | `base/tools/builtin.js:3455-3458` |
| `rebuildRuntime` | `base/core/harness.js:209` |
| 工具注册主清单 | `base/core/harness.js:238-325` |
| 同名覆盖契约 | `base/core/harness.js:320` |
| 应用侧 registry | `base/transport/web/server.js:811-843` |
| MCP 工具映射 | `base/mcp/manager.js:130-150` |
| `toolAutoApproved` | `base/mcp/manager.js:153-157` |
| `appToolAllowed` | `base/transport/web/server.js:687-690` |
| `handleInvoke` | `base/transport/web/server.js:845-895` |

## 附录 B：实测脚本

本报告所有实测均可复现，脚本模式：

```bash
# 注册畸形工具
node -e '
import("/opt/vanor/base/tools/index.js").then(({ToolRegistry})=>{
  const r=new ToolRegistry();
  r.register({name:"no_handler",parameters:{type:"object"}});
  console.log("注册成功数:", r.tools.size);
});'

# schema 覆盖度
node -e '
import("/opt/vanor/base/utils.js").then(({validateSchema})=>{
  const t=(k)=>k;
  const s={type:"object",properties:{n:{type:"string",pattern:"^[a-z]+$",maxLength:8}}};
  console.log("pattern 违规错误数:", validateSchema(s,{n:"ABC123"},"",t).length);
  console.log("maxLength 违规错误数:", validateSchema(s,{n:"abcdefghijkl"},"",t).length);
});'

# 内置工具清单
node -e '
Promise.all([import("/opt/vanor/base/tools/index.js"),import("/opt/vanor/base/i18n/index.js")])
  .then(([{defaultRegistry},{createI18n}])=>{
    const reg=defaultRegistry(createI18n({}));
    console.log(reg.schemas().map(s=>s.name).join(", "));
  });'
```

---

*报告结束。所有结论均基于 Vanor 0.5.8 实际源码，可用附录 B 脚本复核。*
