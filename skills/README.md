# skills/ — Ops Desk 技能目录包（P2b-T4）

> 消费方：`ops-desk-api` 的 `app/ops/skill_registry/loader.py`（`OPS_SKILL_LOADER_ENABLED` 默认关）。
> 形态约定承 Anthropic Agent Skills：每技能一个目录，内含 `SKILL.md`（yaml frontmatter + 正文）。

## 目录包契约

- 布局：`<kebab-case-name>/SKILL.md`（仅目录包被扫描，根下裸文件忽略）。
- frontmatter 必填：`name`（kebab-case，`^[a-z0-9]+(?:-[a-z0-9]+)*$`）、`description`；可选 `when_to_use`（进 catalog 摘要「何时用」列）。
- 加载闸（拒载 + warn，不炸启动）：坏/缺 frontmatter、缺 name 或 description、非 kebab name、全文 > 20000 字符（R9a）、含 slots 伪造标记字面（slot 边界/节首标记——拒载优于转义）。
- 加载时机：进程启动一次（无热更新）；改文件后重启 API 生效。

## 运行时

- 容器路径：`/ops-desk-workspace/skills`（compose 只读卷）；本地默认解析 `../ops-desk-workspace/skills`，可用 `OPS_SKILL_LOADER_ROOT` 覆盖。
- 摘要节预算：`OPS_SKILL_CATALOG_MAX_CHARS`（默认 4000）截断 catalog；全文注入走 `skill_content` trusted 槽逐字节。
- 声明方式：supervisor plan JSON 的 subtask 增 `skill_ref`（取值为技能 `name`）；未知 ref 仅 span warn，fail-open 不炸 plan。
