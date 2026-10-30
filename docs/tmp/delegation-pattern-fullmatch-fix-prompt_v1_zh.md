# 修复委派参数约束 pattern 校验（re.search → re.fullmatch）· 00 委托 Prompt v1

> 适用仓：**ops-desk-api**。角色纪律：你是 00，**禁止亲自改业务代码**——走 Harness 全流程：
> 10-task 起草 → HG-AUDIT-R1 人签 → `task/fix-delegation-pattern-fullmatch` 分支实施 → PR 合并。
> 禁直推 master；PR 前 `pytest tests` 绿 + `./scripts/graph-compile.sh` 过。

## 1. 问题真值（已核实，master）

文件：`app/ops/capability/delegation.py`，函数 `check_param_constraints`（:289-307）。问题行：

```python
# delegation.py:303-306 —— 用 re.search，只要求串中「存在一段」匹配
if _CONSTRAINT_PATTERN in rule and (
    not isinstance(value, str) or re.search(rule[_CONSTRAINT_PATTERN], value) is None
):
    return str(arg_name)
```

实测复现（外部评审第三轮实弹，全部成立）：

| 签发侧声明 | 调用方传值 | 期望 | 实际 |
|---|---|---|---|
| `pattern: \d+`（本意纯数字） | `"123abc"` | 拒 | **放行**（search 找到 `123`） |
| `pattern: ^[a-z]+$` | `"abc\n"` | 拒 | **放行**（Python `$` 匹配换行前） |
| `pattern: ^[\w./-]+$`（本意文件名） | `"../../etc/passwd"` | 拒 | **放行**（字符集过宽） |

定性：约束由 Host 签发侧声明（模型写不了 pattern），攻击面小，非 P0 安全洞；
但约束作者未写锚点时闸门**静默放宽且无任何报错**——「看起来有闸的假门」，与本仓
`budget.py:103-105` 注释批判的 subtask 分桶假门同类。

## 2. 修法

1. `delegation.py:304` `re.search` → `re.fullmatch`（一行）。fullmatch 要求整串匹配，
   天然消解「缺锚点」与「`$` 匹配换行前」两个坑，无需依赖作者写 `^...$`。
2. 同步检查模块 docstring / 注释中对 search 语义的描述，改为 fullmatch 语义。
3. **兼容性检查（task 的 R 轮必做）**：`grep -rn "pattern" app/ops/capability/manifests/*.yaml`
   与全仓 `param_constraints` 出现点——fullmatch 化会改变未锚定 pattern 的语义
  （`\d+` 从「包含数字」变为「整串纯数字」）。这正是修复意图，但若存量约束依赖
   search 语义需在 task 中显式改写并说明。委派令牌 TTL 600s 无持久化，无线上兼容负担。
4. 不受影响的分支（**不要动**）：enum 分支（:297 值比较）、max_len 分支（:299-302）。

## 3. 验收标准（task 验收节直接抄）

新增对抗测试（建议 `tests/test_capability_delegation.py` 或现有委派测试文件内，先 glob 确认）：

1. `pattern=\d+` + `value="123abc"` → **拒**（返回字段名）
2. `pattern=^[a-z]+$` + `value="abc\n"` → **拒**
3. `pattern=^[\w./-]+$` + `value="../../etc/passwd"` → **拒**
4. 正向防误伤：`pattern=\d+` + `value="123"` → 通过；`pattern=^[a-z]+$` + `value="abc"` → 通过
5. 非 str 值（int/list/None）配 pattern 约束 → **拒**（:304 前半分支语义不变）
6. `pytest tests` 全绿；既有委派验签测试零 diff（除语义本意改变者）。

## 4. 非范围

- 不改 enum / max_len 分支；不改签发侧 `validate_param_constraints`（:252）；
- 不动委派三档模式开关与 `_delegation_gate`（gateway.py:277-334）；
- 不顺手「加固」任何其他闸层——发现新问题记入 task 的 out_of_scope。

## 5. 背景一句话（给执行者理解用）

委派令牌 param_constraints（enum/max_len/pattern）是「本次派发的参数授权范围」，
随令牌走、逐子任务签发；pattern 是其正则锁参数值的手段。本次修复把锁从「虚掩」
变为「整串匹配」，属 fail-closed 方向的收紧。