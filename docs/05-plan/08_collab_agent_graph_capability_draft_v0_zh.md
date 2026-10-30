# 草案：图谱能力化 · 协同 Agent 需求分析

> **状态**：设想（2026-09-19）· **不授权改码** · 后续在本文件修订  
> **不是**：线上问答的 Capability 目录；不是各仓 `graph.json` 的真源  
> **现网对照**：api `docs/_tech_graph/` · `scripts/graph-compile.sh` · `scripts/graph_coverage_check.py`（仅 api · warn · 非 SpecWave）

---

## 0. 两句边界（现网 · 先保留）

1. 编译不过，图谱制品不能当真源。`graph-compile` 只保证 YAML / Markdown / `graph.json` 自洽，不读业务源码。
2. 线上问答不读这张图谱，图谱也不参与业务 Capability 的注册与调用。能力化只发生在协同 / 工程 Agent 这条线上。

代码改了、图没改、编译仍绿：现网**不能**由此证明图未过期。api 的 `graph_coverage_check.py` 只抽查路由 include，退出码恒 0，且不是 SpecWave 自带命令。web 仓没有这份脚本。

---

## 1. 图谱如何变成协同 Agent 的能力

两件不要并成一件。

| 件 | 形态 | 做什么 | 不做什么 |
|---|---|---|---|
| Skill | 读顺序纪律，注入 prompt | 先总图 / G-L0，再命中仓的 G-L1，G-L2 仅路径或符号命中后打开；禁止把对端整份 `graph.json` 抄进本仓 | 不执行查询，不改图 |
| Capability | 只读 `graph.lookup` | 入参一句需求，出参：相关仓、模块、flow id，以及「没命中」 | 不写 `graph.json`；不进线上问答的默认 allowlist；不靠 description 语义搜工具 |

调用仍走 Host 门序：查表 → enabled → Policy → schema → adapter。图谱查询是 local_fn 或只读适配，不是第五套网关。

---

## 2. 一次需求 query 的目标架构

例：「前端订单增加全国送类型」。

父图只做一次分仓。三个 subagent 不各自从零读完全部服务。

```text
query
  → graph.lookup（workspace 总图，或聚合各仓 G-L0 + 跨仓 POINTER）
  → 命中：订单服务、用户服务、前端
  → 三个 subagent，各带「只读本仓」Skill
       订单仓：G-L1 模块与 flow
       用户仓：同上
       前端仓：页面与所调用的 API
  → 结构化摘录交回父图（现有模块、现有接口、缺什么）
  → task 起草：范围、非范围、涉及哪些仓、graph_delta
```

现网差距：各仓 G-L0 是本仓总图。跨仓只有 POINTER，禁止在 api 仓伪造 web 图谱。总判断的真源应在 workspace 总图，或一次 lookup 聚合，而不是某一个实现仓。

subagent 不对等通信。父图写下「负责哪一仓」，子图回摘录。形状与 Supervisor 的 `subtasks` 相同，工人换成「读某一仓的图」。

---

## 3. 图上完全没有的新功能

lookup 应返回低命中或空，并带上邻近的已有对象（订单、配送、下单页）。不得为了有答案硬配一个服务，不得编造 `implementedBy` 路径。

task 起草的产出是草案，不是新的图谱真源：

- 范围：新对象落在哪一仓、动哪些现有模块。
- 非范围：没点名的仓不动。
- `graph_delta`：拟新增的模块或 flow，状态为待人签。
- 人签之前不写入已编译的 `graph.json`。

签了之后才实现，合并前把新节点补进图谱并让 `graph-compile` 通过。新功能的结果是「缺口 + 拟新增」的 task，不是一份已经生效的图。

---

## 4. 后续更新时不要做的

- 把 `graph.lookup` 放进 lg-rag / supervisor 的默认能力名单。
- 把 `graph_coverage_check.py` 说成 SpecWave 能力，或原样抄到 web（它绑的是 FastAPI `include_router`）。
- 在漂移门禁做成之前，声称「编译绿 = 图与代码一致」。
- 未人签就让 Agent 改 `graph.json` 或各仓 `*.graph.yaml`。

---

## 5. 修订

| 日期 | 说明 |
|---|---|
| 2026-09-19 | 初稿。面试块「图谱制品 / 否定边界 / 过期」与协同 Agent 设想落盘，供后续改。 |
