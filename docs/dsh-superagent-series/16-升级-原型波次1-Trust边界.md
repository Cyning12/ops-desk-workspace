# 升级 16 · dsh-superagent-prototype 波次 1：Trust 边界

> **TL;DR** — 007 的两个开放问题之一「哪些 Trigger 字段可信」本轮作答：Source 自录的 actor/thread/
> 范围 meta 可信，text/引用不可信，且任何代码路径都不让内容影响授权。答案是文档（docs/009-trust.md）
> + 四个钉死不变式的测试（tests/trust.spec.ts，9a7c340）：策略门对 text 全盲。

- **指令来源**：同 15 篇（用户 m00562 三条 + goal-824773bf 波次制）
- **本篇定位**：波次 1 判例；波次协议同 15 篇六步

## 设计裁定：这道开放题是文档题，但要用测试钉死

007:614 的开放问题问的是「哪些字段可信」——本质是边界的**声明**。但只写文档会在下一次重构时悄悄漂移，
所以本轮交付成双件套：

1. **docs/009-trust.md**——边界正典：可信类（actor=Source 从平台 API 自录的身份、threads=Source 自录的归属、
   meta 范围键、addressed/human/at）vs 不可信类（text、meta 自由载荷、一切引用）；每条边界的执行点
   （allowedSender/listedBot、scope、participating、ack 禁引用、save 只认显式请求、评估结构化输出、
   blockedCommands+shellQuote）；两条明示接受的残余风险（prompt injection 无法读 intent，目标是内容永远不能**扩大**授权；thread GC 位标保留未设计前不删 thread）。
2. **tests/trust.spec.ts**——四个不变式：①显式通道任意 text 门结果一致；②admission 表通道任意 text 一致；
   ③机器门 text-blind 且未列 bot 无论什么内容都拒；④可信范围 meta 翻转结果而 text 不翻转。

## 实现要点（9a7c340，3 文件）

- 无 src/ 代码改动——边界早已写在代码里（model.ts:22 已注 text/meta untrusted），本轮是把它从注释升级为契约。
- 007 开放问题行划除并指 009（注意 docs.spec 的链接规则：编号文档只能链更早编号，007→009 不能链，用纯文本指引）。
- 007 测试表补 tests/trust.spec.ts 行（docs.spec 穷举表强制）。

## 验收

- 全量回到基线形态：1207 tests = 1206 passed + 唯一环境基线红（locale）；typecheck/build 过。
- 中途两处自伤已修：009 初链 002-gates.md（实际 002-authorization.md）被 docs.spec「resolves every local link」咬住；
  trust.spec 夹具构造跨行字符串时用 String.fromCharCode(10) 避开转义层坑（本会话写文件\n 层出错两次的教训）。

## arch-browser 同步（3afd138）

live 场景卡 desc 更新：波次 0 + 波次 1 均已交付，后续波次缩为部署隔离、文章方向项。重建脚本同前。

## 教训

- **文档题也要配测试**：开放问题的价值在「答了之后怎么不丢」——text-blind 不变式让重构者改动即红。
- 写多行文件时本通道转义层会吃掉换行：用数组 join 或 String.fromCharCode(10)，写后必读回。

## 后续

- **波次 2 · 部署隔离**：agent profile 独立 pinned DSH 安装（007 第二个开放问题）。
- **波次 3 · 文章方向项**：speculative/fast-slow/inline&spill/BYOM/watchdog 均为 0 命中，需先写设计文再谈实现。
