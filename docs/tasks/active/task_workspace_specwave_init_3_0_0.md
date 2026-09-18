# Task：workspace 引入 SpecWave 3.0.0（greenfield · harness-only）

> **状态**：`in_progress`  
> **类型**：基础设施 / harness 过程轨 **首次接入**（非升级）  
> **对照**：`ops-desk-api` / `ops-desk-web` 均已钉 **`spec-wave@3.0.0`**（api：`task_specwave_upgrade_3_0_0` done · web：PR #47）  
> **钉版裁定**：本仓 **直接钉 `3.0.0`**（三仓过程面齐钉；ios 除外）  
> **分支**：`task/workspace-specwave-3-0-0`（base：`main`）  
> **执行模式**：Open Folder = **`ops-desk-workspace/`**；过程轨；不改子仓业务代码、不改 `docker-compose` 运行语义  
> **编排角色**：本仓为文档 / 契约 / 总调度仓；**不做四仓 SpecWave 统一分发中心**  
> **00 授权**：2026-09-18 维护者「api 也已更新至 3.0.0，其他没有问题，统筹此升级 task」

---

## Harness 元信息

| 字段 | 值 |
|------|-----|
| **task_slug** | `workspace-specwave-init-3-0-0` |
| **git_branch** | `task/workspace-specwave-3-0-0` |
| **implement_repo** | `ops-desk-workspace` |
| **test_strategy** | `recommended` |
| **test_strategy_note** | 文档仓无业务单测；验收以 `spec-wave --version`/`check`/`verify --task` + `./scripts/graph-compile.sh` 为准（D5 不适用 required） |
| **code_quality_bar** | `not_applicable` |
| **code_quality_bar_note** | 过程轨 / 文档仓；无应用源码 |
| **graph_change_layer** | `G-L0` |
| **graph_delta** | `docs/_tech_graph/00_main.graph.yaml` |
| **graph_delta_note** | 本波只建可 compile 的最小总图（四仓锚点级）；**不**填满契约/数据流细节（另 task） |
| **wiki_delta** | `docs/01-scope/01-harness-tech-graph-strategy.md` · `docs/01-scope/00-project-brief.md` · `docs/01-scope/02-cross-repo-communication.md` · `AGENTS.md` |
| **wiki_delta_note** | 旧 `@cyning/harness` /「统一分发」口径 → SpecWave 各仓自钉；workspace = harness-only 轻量落盘 |
| **experience_capture** | `recommended` |
| **kpi_aggregator** | `CLOSE` |
| **invoke_retention_profile** | `minimal` |
| **required_invoke_hats** | `10,30` |
| **close_pr_policy** | `required` |
| **related_pr** | [#7](https://github.com/Cyning12/ops-desk-workspace/pull/7) |
| **review_hat** | `20` |

### 人工闸

| human_gate_id | status | blocks_hats | 说明 |
|---------------|--------|-------------|------|
| HG-TASK-DRAFT | approved | 20-R1, 30 | 2026-09-18 维护者确认「其他没有问题」+ 授权统筹；00 代签 |
| HG-AUDIT-R1 | approved | 30 | R1 PASS · `docs/harness/reviews/task_workspace_specwave_init_3_0_0_audit_R1_20260918.md` · 00 代签 |
| HG-GRAPH-MODULES | approved | 30 | 过程轨 · 仅最小总图骨架 · 无业务模块边界变更 · 00 代签 |

---

## 背景与目标

### 现状缺口

- **api**：已钉 **`spec-wave@3.0.0`**（`package.json` + `.coding-kit/`）。  
- **web**：已钉 **`spec-wave@3.0.0`**。  
- **ios**：显式不接入（OpenSpec）。  
- **workspace**：已有 task / invoke / review **习惯**与跨仓总单，但 **无** `package.json`、**无** `.coding-kit/`、**无** `docs/harness/prompts/`、**无** `scripts/graph-compile.sh`、**无** `docs/_tech_graph/` 物理目录 → 闸与关账无法机械校验，命令面与 api/web 漂移。

策略文 `docs/01-scope/01-harness-tech-graph-strategy.md`（2026-07）仍推荐「workspace 统一分发 `@cyning/harness`」——与四仓现实不符，须在本波改口径。

### 完成态

1. 本仓钉 **`spec-wave@3.0.0`（exact）** + `.coding-kit/manifest.json`（`version=3.0.0` · `preset=harness-only`）。  
2. 过程面可用：`check` / `verify --task` / `graph-compile`；`AGENTS.md` 含 SpecWave 产品块（`npx spec-wave verify` 字面）。  
3. 活文档命令面：`@cyning/harness` /「workspace 统一分发」→ **各仓自钉 SpecWave；workspace 仅 harness-only**。  
4. **不**物化入库 Cursor/Claude **hooks**（对齐 web/api 3.0.0 口径；门禁以 CLI `verify --task` 为准）。  
5. **不**改 api / web / ios；**不**做 harness-sync 向子仓推送。

---

## 范围

### A. 依赖与 init（greenfield）

1. 新建根 `package.json`（`private: true`；`devDependencies`: `"spec-wave": "3.0.0"` exact）+ `package-lock.json`（**npm**，对齐 api 钉包风格；不用 pnpm）。  
2. `npm install`。  
3. `npx --yes spec-wave@3.0.0 init --preset harness-only --tools cursor,claude,agents --yes`  
   - 预期写入 `.coding-kit/manifest.json`（`version=3.0.0`）。  
   - **S2 真值域不覆盖**：既有 `docs/tasks/`、`docs/harness/reviews/`、`docs/harness/invokes/by-task/` 必须保留。  
   - 若 init 与已有 `AGENTS.md` / `CLAUDE.md` 冲突 → 产品块 merge；**仓内定制**放 `<!-- cyning-harness-local:begin/end -->`（跨仓编排纪律、禁止改子仓代码等）。  
4. `.gitignore` 补齐（对照 web）：`.coding-kit/backups/`、`.coding-kit/local.json`、`.dsh/skills/`、`docs/harness/audit/`、`node_modules/`。

### B. IDE / prompts

5. `npx spec-wave sync prompts --yes`（冲突默认不 `--force`；手合保留仓内定制）。  
6. 需要时 `refresh-ide-blocks --yes`；校验 `cyning-harness-local` 块不被冲掉。  
7. （可选）`skills install` — 不入库 `.dsh/skills/`。  
8. 若 `host apply` / init 物化 **hooks**：按 web 3.0.0 处置——**删除** `.cursor/hooks.json`；还原 Claude settings 中 hook-guard；**不入库 hooks**。

### C. 图谱脚本与最小骨架

9. 新增 `scripts/graph-compile.sh`：默认 `KIT_CLI=spec-wave@3.0.0`（对照 web；workspace **无** Python `graph_yaml_to_json` —— 仅 kit compile/check）。  
10. **最小** `docs/_tech_graph/`：至少 `00_main.graph.yaml`（四仓锚点级节点即可）使 compile exit 0。  
    - **非本波**：填满契约字段、子仓 `::triggers` 细节、同步流全图（可另开 task）。

### D. 活文档口径纠偏（wiki_delta）

11. `docs/01-scope/01-harness-tech-graph-strategy.md`：`@cyning/harness` → `spec-wave`；「统一分发」改为 **废弃推荐** → **各实现仓自钉；workspace 轻量 harness-only；ios 除外**。  
12. `docs/01-scope/00-project-brief.md`：研发纪律 / 待确认项同步。  
13. `docs/01-scope/02-cross-repo-communication.md`：表格中 `@cyning/harness verify` → `npx spec-wave verify`。  
14. `AGENTS.md`：工作流补「30 前 `npx spec-wave verify --task …`」POINTER（与产品块一致）。

### E. 验收与留痕

15. `check` / `verify --task`（本文件）/ `graph-compile` 绿。  
16. FEEDBACK：`docs/spec/doc-health/feedback/`（若无目录则创建）记 init 冲突、hooks 处置、assets/pins 基线（偏差不挡）。  
17. （推荐）`assets verify` / `pins check` 留痕。

---

## 非范围

- **api / web / ios** 任何文件。  
- **不做** `harness-sync.sh` / 向子仓推 prompts。  
- 不改 `docker-compose.yml` / `deploy/` 运行配置。  
- 不强制启用 host-adapt schema v2 自定义表。  
- 不入库 hooks；不强制 pre-commit 裸 `verify`。  
- 不清零历史 invoke/review/done 中的旧叙述。  
- 不动当前工作区已有脏/未跟踪无关文件（如 `docs/contracts/*` draft、`docs/05-plan/05_*` / `06_*`、既有 post-h invokes）——除非与本波字面 grep 必须改的活文档清单命中。  
- 不写业务契约正文；总图只做最小可编译骨架。

---

## 失败路径

| ID | 触发 | 行为 |
|----|------|------|
| F-1 | `npm install` / registry 失败 | STOP；不重试超过一次；FEEDBACK |
| F-2 | `init` 覆盖/清空既有 `docs/tasks` 或 invokes/reviews | **立即 git checkout 回滚** · STOP · FEEDBACK kit |
| F-3 | `sync prompts` 冲掉 local 定制且需 `--force` | 拒盲盖；手合 · FEEDBACK |
| F-4 | hooks 入库导致后续裸 verify 扫历史 review 红 | 删 hooks · 还原 settings · FEEDBACK（预期处置） |
| F-5 | 无 `*.graph.yaml` 导致 compile 失败且未建骨架 | 按范围 C-10 补最小骨架 |
| F-6 | `verify --task` 因审查文结论节不可机读 BLOCKED | 退回 20 补结论节（通过词 + ≥20 实质字符 + 无否定共现） |
| F-7 | PR 催合但 verify/compile 未绿 | `close_pr_policy=required`；不擅自 merge |

---

## 验收标准

- [ ] 根 `package.json` `"spec-wave": "3.0.0"`（exact）；lock 对齐 3.0.0  
- [ ] `.coding-kit/manifest.json` `version`=3.0.0 · `preset`=harness-only  
- [ ] `npx --yes spec-wave@3.0.0 --version`（或 `node_modules/.bin/spec-wave --version`）= 3.0.0  
- [ ] `npx spec-wave check --target .` exit 0 ·「已是最新」  
- [ ] 存在 `docs/harness/prompts/` Starter 白名单（含 `FRAGMENT_30_gate_verify_v1_zh.md` 等）  
- [ ] `AGENTS.md` 含 `npx spec-wave verify` 字面；`cyning-harness-local`（若有）保留跨仓边界纪律  
- [ ] **无**入库 `.cursor/hooks.json`；Claude settings **无新增** hook-guard PreToolUse（或与 main 一致）  
- [ ] `grep -n 'KIT_CLI=.*spec-wave@3.0.0' scripts/graph-compile.sh` 命中；`./scripts/graph-compile.sh` exit 0  
- [ ] 活文档：`grep -n '@cyning/harness' docs/01-scope/01-harness-tech-graph-strategy.md docs/01-scope/00-project-brief.md docs/01-scope/02-cross-repo-communication.md` **零命中**（历史 done 档不扫）  
- [ ] 策略文不再把「workspace 统一分发」列为现行推荐（改为各仓自钉 + workspace harness-only）  
- [ ] `npx spec-wave verify --target . --task docs/tasks/active/task_workspace_specwave_init_3_0_0.md` PASS  
- [ ] FEEDBACK 落盘；既有 active `task_rag_embed_api_backend.md` 与 post-h invokes **仍在**  
- [ ] PR 开出且本地上列命令可核验（本仓无 CI workflow 则不挡）

---

## 依赖

| 项 | 说明 |
|----|------|
| 对照 api | `ops-desk-api` 钉 `3.0.0` · `docs/tasks/done/task_specwave_upgrade_3_0_0.md` |
| 对照 web | `ops-desk-web/docs/tasks/done/task_web_specwave_upgrade_3_0_0.md`（hooks 不入库） |
| 上游 | `spec-wave@3.0.0` 包内 `MIGRATION.md` / `README.zh-CN.md` |
| 策略旧文 | `docs/01-scope/01-harness-tech-graph-strategy.md`（本波纠偏对象） |

---

## 给执行帽（30）必读

1. 本 task 人工闸表（须 **approved**；禁止改回 pending 代签回滚）  
2. `docs/harness/prompts/FRAGMENT_30_gate_verify_v1_zh.md`（init/sync 后 GATE_VERIFY）  
3. web/api 3.0.0：**hooks 不入库**  
4. Open Folder 必须是 **ops-desk-workspace**；禁止顺手改子仓  
5. 既有脏文件与本波无关则 **不动**

---

## 思考轮控制

| 轮 | 结论 | early_stop | reason（early_stop） | residual_risks |
|----|------|------------|---------------------|----------------|
| R0 | 四仓盘点：api/web=3.0.0 · ios=除外 · workspace=空 → 引入必要 | no | — | — |
| R1 | 钉版齐钉 3.0.0（维护者确认 api 已升） | no | — | — |
| R2 | 废弃统一分发；workspace harness-only | no | — | — |
| R3 | 最小总图进范围；满图另 task | no | — | — |
| R4 | hooks 不入库（对齐 web/api 3.0.0） | no | — | — |
| R5 | 验收双锚：version/manifest + 旧字面零命中 + verify | yes | greenfield 面已钉死；无业务逻辑；hooks/S2 路径已写死 | ① init 与 AGENTS merge 手审；② 最小总图过瘦；③ assets/pins 无声明源（不挡） |

**actual_last_round**：R5 · **early_stop**：yes · **reason（early_stop）**：见 R5 行 · **residual_risks**：见 R5 行

### R0 · 四仓盘点

api/web 已钉 3.0.0；ios OpenSpec；workspace 无 kit → 本波引入。

### R1 · 钉版

直接钉 3.0.0，不经 2.4.2 中转。

### R2 · 分发模型

各仓自钉；不做 harness-sync 统一分发。

### R3 · 总图

最小 `00_main.graph.yaml` 可 compile；契约满图另 task。

### R4 · hooks

host apply 可能物化 hooks → 删除不入库；门禁仅 CLI verify。

### R5 · 验收

version/manifest/活文档字面/verify/compile 双锚落定。

- 20-task-audit 认为不足 → 退回 10-task 补轮再审 R+1

### GATE_VERIFY（30 · 2026-09-18）

| 闸 | status | 依据 |
|----|--------|------|
| HG-TASK-DRAFT | approved | 维护者统筹授权 |
| HG-AUDIT-R1 | approved | R1 审查文 |
| HG-GRAPH-MODULES | approved | 过程轨 · 最小骨架 |

→ **允许 30 开工**

### 自检结论

| 命令 | 退出码 | 备注 |
|------|--------|------|
| `spec-wave --version` | 0 | 3.0.0 |
| `check --target .` | 0 | 已是最新 |
| `./scripts/graph-compile.sh` | 0 | KIT_CLI=@3.0.0 |
| `verify --task`（本文件） | 0 | PASS（补 hat-10 invoke 后） |
| hooks 入库 | — | 已删 hooks.json · 已删 Claude hook settings |

### 验收勾选（30）

- [x] package / lock / manifest 3.0.0 · harness-only
- [x] prompts 白名单落盘 · AGENTS 含 verify 字面 + local 块
- [x] 无 hooks 入库
- [x] graph-compile · 活文档旧字面零命中 · 策略改各仓自钉
- [x] verify PASS · FEEDBACK 落盘 · S2 既有 task/invokes 仍在
- [x] PR 开出 · [#7](https://github.com/Cyning12/ops-desk-workspace/pull/7)
