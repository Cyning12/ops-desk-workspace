# 20 · arch-browser W1 源文档查看器（对外页面自身升级）

## 背景

- 用户 m01699 授权开 arch-browser W1（SPEC 轨 docs/spec/arch-browser/01_execution_waves.md）。
- HG-SPEC-SIGNOFF 原判据「人签前不开 W1」：用户口头授权=人签，由 lead 代行并写入 SPEC v0 状态行+修订记录留痕。
- Q2 裁定：源 MD 查看器按建议默认实施（白名单全文进 dist + #/doc 查看器）。

## 交付（ops-desk-api 41b18bc，PR #363 squash merge，CI 4/4 绿）

- **build_site.py**：`_doc_whitelist()`/`_copy_whitelisted_docs()`——白名单 45 篇源 MD（34 modules + 总览/扩展策略 2 篇 + `_tech_graph/l1` 9 篇，仅 .md，graph yaml 不拷）复制进 `dist/docs/`，产 `docs_index` 入 site-data.json；白名单外绝不拷入。
- **app.js**：`docHref` helper + `renderDoc` 查看器——`#/doc` 索引页 / 白名单外显式拒绝页 / marked.parse + mermaid 代码块就地渲染；详页源链命中白名单改站内链接。
- index.html marked@12 CDN；style.css .md/.doclist 样式。
- SPEC v0 + 01_execution_waves + README 修订记录全部落痕。

## 坑与教训

1. **dist 路径 bug**：拷贝目标 `DIST/docs/<rel>` 的 rel 若用 repo 相对路径会叠出 `docs/docs/...`——必须 `src.relative_to(ROOT/'docs')`。
2. ** squash 合并携带历史**：W1 分支误从含 5 个未推 live 卡提交的本地 master 切出，squash merge 后远端实际连五波宣告一起合入（内容等价于已验收态，无重复无丢失）——分支切出前先核对 `git status`/`git log origin/master..HEAD` 是否干净。
3. 查看器冒烟以断言替代浏览器：docs_index 全在 / copied==expected / 无非 .md 泄漏 / overview 与 l1 md 含 mermaid 围栏 / node --check。

## 状态

- W2–W4（Nginx 公开入口 / 场景模块填占位 / 简历包装韧性）待逐波人签后拆 task。
- arch-browser 首页 1 live 卡（五波全交付文案）+ 3 设想卡不受影响。
