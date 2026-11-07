# 升级 19 · dsh-superagent-prototype 波次 4：Thread GC（读位标真相与计算裁决）

> **TL;DR** — 007 最后一个开放问题「thread 删除要等 read-position markers（thread.meta）
> 有留存设计」立项后发现前提不成立：读位标根本不在 thread.meta，而在 KV（Feishu seen 游标、
> GitHub cursor）。于是「位标设计」变成「计算裁决」：gcThreads 在 atomic 内由持久态判可删——
> 静默 + 无活引用 + 过龄三条件全满足才删，KV 游标全程不触碰。e599bdd。

- **指令来源**：用户 m01455「thread GC 立项」（m00562 三指令框架下，goal-824773bf 完成后追加）
- **本篇定位**：波次 4 判例——勘察 overturn 设计前提的典型案例

## 勘察推翻立项前提

立项时的设想：thread.meta 需要设计一个「已读位标」留存方案，否则删 thread 会让旧消息
以新身份重入。勘察实测（全部 grep + 读码验证）：

- Feishu 的 seen/initialized 在 KV 族：`KV.feishu.seen`=`thread-seen:`、keyed by thread.key；
  GitHub cursor 在 `KV.github.cursor`。**都不在 thread.meta**。thread.meta 是自由载荷。
- Thread key 确定性派生：`threadKey(ref)=${source}:${id}`——同 ref 重触发，引擎 get-or-create
  拿到同一把 key，KV 游标原样继承。
- 轮询面 `polled()` 只枚举有活 ticket 订阅的 thread；可删 thread 天然不在其集合内。

结论：不存在「位标丢失」问题，存在的只是「什么 thread 可以删」的裁决标准。

## 设计裁定：可删 iff 三条件（计算裁决，非存储位）

在 `store.atomic` 内由持久态纯函数判定：

1. **静默**：`pending` 空 且 `evaluating` undefined（与 `threads.active()` 互补；
   引擎也活在 atomic 里，无竞态窗口）。
2. **无活引用**：`subscriptions ∪ context` 每个 ticket 不存在或已 ended，
   且无 open ticket 的 `follows` 引用此 key（虚引用 ticket 不挡删——ticket 没了就是没了）。
3. **过龄**：`lastAt ?? createdAt` 早于 cutoff；新 volatile `threadRetentionDays` 默认 30 天，
   照 receiptRetentionDays 六处接线范式（limits/schema/machineView/runtime/host/locales+fixtures）。

**级联边界**：只删 thread 聚合行；triggers/decisions 以各自 key 留存，作 ticket-origin 审计
（decisions.byThread 对不存在 thread 安全——views 只对存在 thread 调用）。

## 实现与验收

- 红测先行：gc.spec 尾部 6 例（删旧/虚引用/createdAt 兜底/KV 游标不动/决策史留存/
  经 collector 带 threadRetentionDays report）先红 6 failed，实现后 12/12。
- 三处存储面：`ports.ts` 扩 `delete`+`gcThreads`；SQLite store（DELETE FROM thread WHERE key=?）
  与 MemoryRepositories 同构镜像。
- gc.ts：report 加 `threads` 计数；GarbageCollectorHost 加 `threadRetentionDays()`；
  run() 日度 pass 同一 atomic 事务，异常仍走 warn 绝不抛进 Runtime。
- 全量回基线：1212 passed + 唯一 environment.spec locale 基线红（本机 git 中文输出，预登记不修）；
  typecheck/build 绿。commit e599bdd（17 文件 +162/-19，含 .pnpm-store 入 .gitignore）。
- 文档销项：007 开放问题第三条划除（编号文档只链更早篇——007→009 链被 docs.spec 咬，
  去链改纯文本照 Trust 行先例）；007 两表行措辞扩线程收集；009 残余风险改写为已解决。

## 教训

- **立项前先证伪前提**：「thread.meta 位标」是文档里的旧假设，真值在 KV。勘察一小时，
  省下给一个不存在的问题设计存储方案的两天。
- **安全论证找现成机制**：「旧消息不重入」不靠新锁，靠 key 确定性派生 + KV 游标不被触碰
  + polled() 集合天然排除——三条既有性质拼出不变式。
- **红测工厂要对齐真类型**：Mandate/Strength/TicketEnd 的字面量造错四次（normal/host/done
  全不是合法值）——typecheck 在 test 之后跑，红测阶段只按 runtime 报错修，
  后面被 tsc 逐个咬回。先 grep 真类型再写工厂。

## 同步落点（m00562 三指令）

- arch-browser live 卡：「五个升级波次全部交付」，波次 4 一行带设计要点（151df6f）。
- 原型架构至此无已知开放问题：GC/Trust/隔离/对齐账/Thread GC 全闭。

