# Capability 层 · 验收剧本

> **给谁看**：没参与过这块开发的人（同事、接手的工程师、面试官、三个月后的你自己）。
> **怎么用**：照着从上往下走。每一步都给**期望输出**和**不符合意味着什么**。
> **关联**：路线与理由见 `01_capability-observability-acceptance-roadmap_v1_zh.md`。

---

## 0. 前置

```bash
cd ops-desk-api
ls .venv/bin/python                     # 需要 venv
export JAVA_HOME=/opt/homebrew/opt/openjdk   # 仅联调层需要（桩服务）
psql -h localhost -U ops -d opsdesk_test -c 'select 1'   # 仅持久化层需要
```

| 缺什么 | 后果 |
|---|---|
| 无 venv | 脚本退出码 2（前置不满足），不是 1 |
| 无 JDK / 桩服务未构建 | **联调层被标 SKIP，不是 FAIL**——它证明的是"真发得出去"，没它就证明不了，但不该记成代码坏了 |
| 无 PostgreSQL | 持久化层 SKIP；另有 `psycopg` 相关报错要看清楚 |

---

## 1. 一条命令跑完五层

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk
./scripts/acceptance/capability_acceptance.sh
```

期望（形如）：

```
▶ 单测     capability 单测            PASS
▶ 题集     黑盒题集（含基线 diff） PASS
▶ 红线     红线（否决项）        PASS
▶ 持久化  DB 版 store/sink            PASS
▶ 联调       启动桩服务 ...
▶ 联调     真桩服务 26 项          PASS
失败 0 · 跳过 0
报告：reports/capability-acceptance-<时间戳>.md
```

**报告怎么读**：五层**分开看，不要合并成一个通过率**——它们回答五个不同问题：

| 层 | 回答 | 挂了说明什么 |
|---|---|---|
| 单测 | 内部逻辑对不对 | 代码写错了 |
| 题集 | 出口产出有没有变 | 要么改坏了，要么**有意的变化**（那就显式更新基线） |
| 红线 | 有没有踩否决项 | **不许解释，先修** |
| 持久化 | 跨实例那条链路通不通 | DB 层坏了（防重会静默失效） |
| 联调 | **真的发得出去吗** | HTTP 链路的真问题（单测覆盖不到的那一类） |

> **跳过 ≠ 通过**。SKIP 时报告里写的是原因，不是"通过"。
> 如果哪天五层全 SKIP 而结论显示"通过"，那是脚本坏了——报告里会写明 `失败 0 · 跳过 5`。

---

## 2. 打开服务，人肉看一遍

```bash
# 管理端点走 Bearer（与 /admin/sync 同一口径）
export TOKEN=$OPS_ADMIN_SYNC_TOKEN
BASE=http://127.0.0.1:8000/api/ops/admin/capability
AUTH="Authorization: Bearer $TOKEN"
```

### 2.1 现在活着吗 —— `GET /runtime`

```bash
curl -s -H "$AUTH" $BASE/runtime | python -m json.tool
```

期望看到（关键两处）：

```json
{
  "persistence": {"mode": "db", "production_safe": true,
                  "idempotency": {"enabled": true, "scope": "cross_instance"}},
  "health": {"level": "ok", "message": "持久化已按 db 装配"},
  "capabilities": {"total": 8, "write_capabilities": [...]}
}
```

**⚠️ 如果 `mode` 是 `null`**：

```json
{"persistence": {"mode": "null", "production_safe": false},
 "health": {"level": "warn", "message": "...不可上生产",
            "impact": "重复提交可能产生第二张单据；回执重启即丢"}}
```

**这就是这个端点存在的全部理由**：没配 `OPS_CAPABILITY_PERSISTENCE` 时**一切照常运行、
不报错、只是悄悄没有防重**。看到 `warn` 就去配环境变量，别继续。

> 还有一处值得看：`capabilities.write_capabilities` 列出所有写能力。
> **清单里多出一个你不认识的写能力**，就是有人改了 manifest——这正是该被看见的事。

### 2.2 为什么他没看到 —— `GET /catalog`

```bash
# 匿名主体（模拟"没带身份"）
curl -s -H "$AUTH" "$BASE/catalog" | python -m json.tool

# 财务部的人
curl -s -H "$AUTH" "$BASE/catalog?departments=finance" | python -m json.tool
```

看三样：

- `visible_ids` —— 能看到什么
- `visibility_hidden[]` —— **被裁掉的是谁、`reason` 是什么**（`department_mismatch` / `role_mismatch` / `classification_exceeded` …）
- `filter` —— 当前生效的裁剪条件（`deny_write` / `deny_high_risk` / `allow_tags_any`）

**⚠️ 一个能力既不在 `visible_ids`、也不在 `visibility_hidden` 里**——
说明它**没走到可见性判定**就被形态裁剪（`kinds`）掉了。
**裁剪顺序是「kinds 先，可见性后」**，这条顺序本身也是要被观测到的事实。

### 2.3 那笔写到底成没成 —— `GET /receipts`

```bash
curl -s -H "$AUTH" "$BASE/receipts?limit=5" | python -m json.tool
```

看 `captured`（按 manifest 的 `receipt.capture` 抓到的字段，如 `ticketId`）
与 `write_confirmed`（**这次写是在放行下执行的**）。

### 2.4 有没有卡住的写 —— `GET /idempotency?stuck_only=true`

```bash
curl -s -H "$AUTH" "$BASE/idempotency?stuck_only=true" | python -m json.tool
```

期望：`count: 0`。

**⚠️ 非 0 意味着什么**：这些是**"请求发出去了、但我们不知道下游到底生效没有"**的写
（典型成因：进程崩在"已发出请求、未落回执"之间）。
响应里的 `hint` 会明确说：**带 `idempotency_key` 去下游查，不要直接重试**。

> 这道巡检**只发现、不自动重试**——要不要重试取决于下游到底有没有生效，
> 那是人或专门的查询能力才能判断的；盲目重试可能建出第二张单。

### 2.5 整体健康 —— `GET /metrics`

```bash
curl -s -H "$AUTH" $BASE/metrics | python -m json.tool
```

**最该盯的是 `write.blocked`**：

| 现象 | 含义 |
|---|---|
| 持续升高 | 有人在反复尝试不该做的写（可能是模型在乱试，也可能是在攻击） |
| 恒为 0 | 可能是没人用，**也可能是写闸根本没装上**——**必须结合 `/runtime` 一起看** |

这条正是"指标不能单独看"的例子：`write.blocked = 0` 既可能是好事也可能是坏事。

---

## 3. 自己把红线弄响一次（**十分钟内建立信任的最快方式**）

别只信"红线全过"。自己造一个违规，看它响不响：

```bash
# 临时把写闸关掉（只在本机试，别提交）
# 做法：在 app/ops/capability/policy.py 的 check_invoke 里临时注释掉写闸那一段
pytest tests/eval/test_capability_redlines.py -q -m redline
```

期望：**R1 立刻变红**，并且错误信息说的是"红线被突破"（不是别的失败）。

> 如果 R1 **没红**——那才是真问题：说明这条红线是空的，之前一直是"假通过"。
> 这正是每条红线都配"反向对照"的原因：**只做正向断言，"一律拒绝"也能全绿。**

改完记得还原。

---

## 4. 自己让基线漂移一次

证明题集真的会拦住"悄悄变了的产出"：

```bash
# 随便改一处产出字段（例如把 visibility 的某个 reason 文案改了）
python -m evals.agent.golden.capability.runner --against-baseline
```

期望：打印 `[DRIFT]`，并**逐 case、逐字段**指出 `baseline → current`。

- 判断是"改坏了" → 修回去
- 判断是"有意的产出变化" → **显式**更新基线：
  ```bash
  python -m evals.agent.golden.capability.runner --update-baseline
  ```

> **基线更新必须是显式动作**。跑一遍就自动覆盖，等于没有基线——
> 漂移会在你不知情的时候被"接受"。

---

## 5. 不符合预期时的诊断表

| 现象 | 先查什么 |
|---|---|
| 五层全 SKIP | 前置条件（venv / 桩服务 / PG）；看报告里的 SKIP 原因 |
| 联调层 SKIP | `cd ops-desk-mock-oa && mvn package -DskipTests`；确认 `MOCK_OA_DIR` 指对 |
| 联调层 FAIL 且报 502 | **环境代理**：`env \| grep -i proxy`。能力调用默认不走代理，但这台机器上别的工具会 |
| 持久化层 FAIL | PG 在不在；`opsdesk_test` 建没建（conftest 会建） |
| 题集 DRIFT | 是不是刚改了产出字段。**看 diff 的具体字段名**，别只看"有漂移" |
| 红线 R1 红 | 写闸被摘了。**这是最高优先级，先修再谈别的** |
| `/runtime` 报 503 | DB 不可达（回执/防重表查不到）——先确认库，再怀疑代码 |
| `/runtime` 显示 `mode: null` 但你以为配了 | 环境变量名检查：`OPS_CAPABILITY_PERSISTENCE`（**不是** `OPS_CAP_PERSISTENCE`） |

---

## 6. 这套东西为什么这么分——一句话

> **红线管"不能碰"，题集管"不能变"，基线 diff 管"变在哪"，观测端点管"现在活着吗"，一键脚本管"谁来跑"。**
>
> 五件事分开做，因为它们回答的是**五个不同的问题**。
> 把它们混成一个"测试通过率"，就等于什么都没保证——
> 一次踩红线的改动，只要别处多过几个 case，通过率反而可能更高。
