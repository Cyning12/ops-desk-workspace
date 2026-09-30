# Task：spec-wave 升级 3.0.2（workspace · 3.0.0 → 3.0.2）

> **状态**：`done`  
> **类型**：基础设施 / harness 过程轨 patch  
> **前置**：`task_workspace_specwave_init_3_0_0` done（本仓 greenfield 接入 3.0.0）  
> **分支**：`task/workspace-specwave-3-0-2`（base：`main`）  
> **执行模式**：Open Folder = **ops-desk-workspace**；文档仓；不改子仓  
> **00 授权**：2026-09-30「更新specwave到最新版本」（范围：web + workspace；api 另波由 api agent 处理）  
> **00 二次授权**：2026-09-30「签收当前task，后续过程文档授权00签收，完成后PR 通过CI后merge，最后CLOSE」

**思考轮豁免（A-3）**：本波为 00 直令的 patch 热修（无 SPEC 承载 · 过程轨），`task lint` W4「无思考轮节」warn 属合法豁免轨；不补 R0–R5。

---

## Harness 元信息

| 字段 | 值 |
|------|-----|
| **task_slug** | `workspace-specwave-upgrade-3-0-2` |
| **git_branch** | `task/workspace-specwave-3-0-2` |
| **implement_repo** | `ops-desk-workspace` |
| **test_strategy** | `required` |
| **test_strategy_note** | `npx spec-wave --version`=3.0.2；`upgrade --yes`；`check`；`verify --task`；`pins check --consumer`；`KIT_CLI=spec-wave@3.0.2` + graph-compile；`host update --yes`（**不入库 hooks**）；`npm ls spec-wave`。**D5 依赖（A-4）**：本仓无 `test/tests/spec` 目录与 `*.test.*` 文件，`test_strategy=required` 的 D5 探针仅靠 `.github/workflows/harness.yml:21` 步骤名 `Graph compile test` 命中——**该步骤改名会致 `verify --task` D5 BLOCKED**。 |
| **code_quality_bar** | `not_applicable` |
| **code_quality_bar_note** | 文档/编排仓；无 app runtime |
| **graph_delta** | `none` |
| **graph_delta_note** | 不改 `.graph.yaml`；重生成 `00_main.md` / `shared/graph.json` 零 diff（mtime 17:22:10 晚于钉面改动 · git clean） |
| **wiki_delta** | `docs/01-scope/01-harness-tech-graph-strategy.md` |
| **wiki_delta_note** | 策略文钉版字面 3.0.0 → 3.0.2；同类活文档同步：`.github/workflows/harness.yml`（pins 钉面）· `AGENTS.md`（R1 A-1 补漏）· `scripts/graph-compile.sh`；「子仓以 api 为例」树保留待 api 波 |
| **experience_capture** | `recommended` |
| **kpi_aggregator** | `CLOSE` |
| **invoke_retention_profile** | `minimal` |
| **required_invoke_hats** | `00,30` |
| **related_pr** | `#11` |
| **close_pr_policy** | `required` |
| **review_hat** | `20` |

### 人工闸

| human_gate_id | status | blocks_hats | 说明 |
|---------------|--------|-------------|------|
| HG-GRAPH-MODULES | approved | 30 | R1 A-2 补行：`graph_delta=none` · 未改任何 `.graph.yaml` · graph 产物零 diff → 实体不适用（本仓 `AGENTS.md` / `30-execute-code.md` / 策略文 §5.2 均引用该闸，故按惯例登记） |
| HG-TASK-DRAFT | approved | 20-R1, 30 | 00 本窗授权「更新specwave到最新版本」（web + workspace） |
| HG-AUDIT-R1 | approved | 30 | R1 PASS-with-conditions（内容零阻塞 · 6 项非阻塞发现）· 00 于 2026-09-30 签收（授权见「00 二次授权」）· 审查文 `docs/harness/reviews/task_workspace_specwave_upgrade_3_0_2_audit_R1_20260930.md` |

---

## 背景与目标

本仓 greenfield 接入时钉 **`spec-wave@3.0.0`**。上游 **`spec-wave@3.0.2`** 为 patch：tech-graph 词汇档补登记 `branches` / `triggers` 边型（W1 · 清消费仓 warning）；**新增 `pins check --consumer` 消费仓钉版保鲜闸**（W2）。

**本仓是 W2 的真实受益面**：`.github/workflows/harness.yml` 硬钉 `npx --yes spec-wave@3.0.0 check` —— 该字面正是 `pins check --consumer` 的默认钉面。升级前该闸会报 `1/1` 不一致。

**完成态**：`package.json` / lock / manifest / `host-tools#kit_semver` / `KIT_CLI` / `harness.yml` **六钉 3.0.2**；`check` / `verify --task` / `pins check --consumer` 1/1 / graph-compile 绿；FEEDBACK 落盘；**无** `.cursor/hooks.json` / `.claude/settings.json`。

## 范围

1. 钉 `"spec-wave": "3.0.2"`（exact）+ `npm install`（本仓用 npm · `npm ci` 走 lock）
2. `npx spec-wave upgrade --yes`（manifest `from_version=3.0.0`）
3. `.github/workflows/harness.yml`：`spec-wave@3.0.0` → `@3.0.2`（**pins 钉面**）
4. `scripts/graph-compile.sh`：`KIT_CLI=spec-wave@3.0.2`
5. `docs/01-scope/01-harness-tech-graph-strategy.md`：钉版字面 → 3.0.2
6. `host update --yes` 后：**删除** `.cursor/hooks.json`；**删除** `.claude/settings.json`（本仓原无 · 内容仅 hook-guard）
7. `sync prompts`：conflict 不 `--force`；`TASK_TEMPLATE.md` 手工合并新增注
8. `check` / `verify --task` / `pins check --consumer` / graph-compile
9. `AGENTS.md` 钉版字面 → 3.0.2（R1 A-1 补漏 · 活文档真值漂移）
10. FEEDBACK 落盘；`assets verify` / release 模式 `pins check` 基线留痕（缺 `assets/release-pins.yaml` exit 2 **不挡**）
11. **不**动子仓（api / web / ios）；**不**回刷历史档旧字面

## 非范围

- 子仓 pin（api 由 api agent 另波；web 由本波 `task/web-specwave-3-0-2` 自处理）
- 历史档（done task / invokes / reviews / 旧 FEEDBACK）旧字面
- 「子仓（以 api 为例）」树的 `spec-wave@3.0.0` 字面 —— 待 api 波避免代改跨仓口径
- hooks 物化入库；`.spec-wave/pins-consumer.yaml` 显式声明源（默认钉面已覆盖）
- `main` 上的既有未提交 WIP（非本波产权）

## 失败路径

| ID | 触发 | 行为 | 本波实际 |
|----|------|------|----------|
| F-1 | install/upgrade 失败 | STOP | 未触发 |
| F-2 | sync conflict 被 `--force` 盲盖 | 手合 · 拒 `--force` | 未触发（手工合并 1 件） |
| F-3 | hooks **物化**（入库前） | 删除物化件 · FEEDBACK | **已触发并处置**（生成后即删 · 从未入库 · `git log --all` 零历史） |
| F-4 | 工作树脏导致 refresh-ide-blocks fail-fast | 接受（产品块已由 host update 写） | 未触发 |
| F-5 | pins 落点遗漏 → 闸红 | 补齐 workflow 字面 | **已规避**（1/1 PASS） |
| F-6 | graph-compile 产物**非**零 diff（C-3 逆路径） | 出现即视为图谱源被误改 · STOP 复核 | 未触发（git clean） |
| F-7 | 闸序倒置（30 先于 20-R1） | R1 不得追认既成实现 · 00 签收时显式留痕 | **已触发** · 见「00 签收裁定」 |

## 验收标准

- [x] `"spec-wave": "3.0.2"` · manifest version=3.0.2 · from_version=3.0.0
- [x] `--version`=3.0.2 · `check` 已是最新
- [x] `pins check --consumer` PASS · **1/1 落点**（`harness.yml:20`）
- [x] `KIT_CLI=spec-wave@3.0.2` · graph-compile exit 0 · 零产物 diff
- [x] 无入库 `.cursor/hooks.json` / `.claude/settings.json`
- [x] `AGENTS.md` 活文档钉版字面 → 3.0.2（R1 A-1）
- [x] 未触碰 `main` 上的未提交文档 WIP（R1 §D 独立复核确认）
- [x] `verify --task` PASS
- [x] FEEDBACK 落盘
- [x] invoke 落盘 `docs/harness/invokes/by-task/workspace-specwave-upgrade-3-0-2/`
- [ ] `related_pr` `#11` · CI 全绿后 merge · CLOSE 归档

### 自检结论

| 命令 | 退出码 | 备注 |
|------|--------|------|
| `spec-wave --version` | 0 | 3.0.2 |
| `check --target .` | 0 | 已是最新 |
| `verify --task` | 0 | PASS（`HG-AUDIT-R1` 00 签收后） |
| `pins check --consumer` | 0 | PASS · 1/1 落点 |
| `./scripts/graph-compile.sh` | 0 | KIT_CLI=@3.0.2 · 00_main OK · 零产物 diff |
| `npm ls spec-wave` | 0 | spec-wave@3.0.2 |
| hooks 入库 | — | 已删 hooks.json + settings.json（从未入库） |

### KPI

Task_KPI%: 100

---

## 00 签收裁定（2026-09-30）

| 项 | 裁定 |
|----|------|
| R1 结论 | PASS-with-conditions（内容 PASS · 零内容阻塞 · 6 项非阻塞发现） |
| `HG-AUDIT-R1` | **approved** —— 00 依「后续过程文档授权00签收」签收 |
| P-1 闸序倒置 | **认可并留痕**：30 先于 R1 执行属实（task 已自陈），R1 不追认既成实现；00 承担签收判认。本波为过程轨 patch 热修，未触碰子仓与业务代码。该倒置不得成为先例。 |

### R1 非阻塞发现闭合

| ID | 处置 |
|----|------|
| A-1 `AGENTS.md` 钉字面漂移 | **已闭合**：:113 业务节 + :155 仓内定制块 均 → 3.0.2 |
| A-2 `HG-GRAPH-MODULES` 行缺失 | **已闭合**：人工闸表补行 `approved`（实体不适用 · 依仓内惯例登记） |
| A-3 缺思考轮节（W4 warn） | **已声明豁免**（见文首 · 合法豁免轨） |
| A-4 D5 依赖 CI 步骤名 | **已闭合**：`test_strategy_note` 写明该依赖 |
| A-5 关账面（related_pr / PR·CI 验收） | **已闭合**：PR 建立后回填 `related_pr` 与验收项；invoke 已落盘 |
| A-6 F-3 用语精度 | **已闭合**：触发列改「hooks **物化**（入库前）」；另补 F-6 / F-7 |

---

## 给执行帽（30）必读

1. 本 task 闸表（三闸全 approved）
2. init 波 FEEDBACK：`docs/spec/doc-health/feedback/2026-09-18_3.0.0_workspace_init.md`
3. 上游 `CHANGELOG.md` `[3.0.2]` W2（`pins check --consumer` 真值源回退链与默认钉面）
4. R1 审查文：`docs/harness/reviews/task_workspace_specwave_upgrade_3_0_2_audit_R1_20260930.md`
5. **禁入库 hooks**（F-3）；**勿提交** `main` 遗留 WIP
