# P4 设计终稿 — 通用化（领域配置化 · 多 Agent Run 树）

> 状态：v1 终稿（三方评审合并版 · lead 整合）· 2026-11-18
> 基线：ops-desk-api master（P1/P2a/P2b/P3 已交付 · P3 终稿见 14/15/16）· 全部 file:line 引自 inv-p4 实地勘察，platform 评审逐条复核**为真**（唯一瑕疵=templates.py docstring「10 模板」陈旧注释，实际 11 个 id，初稿写 11 正确）
> 上游：/tmp/opsdesk-rfc/inv-p4.md（勘察报告）；04-roadmap.md §P4(:61-64)+§阶段纪律(:66-72)；01-architecture.md:28（Send 雏形）/:65（领域=工具包配置）；14-p3-schedule-taskcard-design.md（体例与红线范式）
> 体例：承 14-p3-schedule-taskcard-design.md
> 评审记录：architect 初稿 /tmp/opsdesk-rfc/p4-design-architect.md（294 行 · D-A~D-F · T1-T9 · Q1-Q7）→ product 条件 GO（B1-B4+N1-N5+盲点3）/tmp/opsdesk-rfc/p4-review-product-p4.md → platform 条件 GO（B1-B4+N1-N7+盲点3）/tmp/opsdesk-rfc/p4-review-platform.md → **本稿 R1-R25 全部关闭 · §14 Q1-Q7 明判落盘**

---

## 0. 一页结论

P4 两条愿景线各取**最小可证切片**，零新外部依赖、SSE 零新帧、cursor 零改动、ops 默认域零 diff：**领域线** = 「领域包三件套文件级覆盖」——prompt loader 加 `assets/<domain>/<id>.md` 目录回退（templates.py:11-26 白名单保留、域集合不硬编码）、manifest `domain:` 键消费为 tags 注入（落 types.py:160-162 既有共识，否第三状态）、RAG collection 按域 env（**domain≠ops 且 per-domain env 缺省 ⇒ fail-closed 禁用不回落**，R3）/glossary 按域文件回退（source_type 词表与 ingest 不泛化，登记）；域 = **部署级配置**（OPS_DOMAIN env 默认 ops），**不挂 tenant**；记忆面契约钉「**多域部署不得共库**」（落库键无 domain 维 · 域=部署级天然单库单域 · 零 DDL，R4）；验证域 = **真实 oa 域**（仓内唯一真实第二域 · 只读低风险 · **语料 lead 准备与断言解耦 · 结论限定机制面**，R16/R25），加域 = 只加文件零改码。**Run 树线** = tool_exec 委派子任务提升为持久化子 run：OpsLgRagRun 加 `parent_run_id`/`subtask_id`/`depth` 三列（uq(parent_run_id, subtask_id) 部分唯一 = **DB 委派 claim**，建行即认领，复用 ON CONFLICT DO NOTHING 范式 models.py:750-785），深度硬上限 1（子 run 跑非 supervisor 委派管线、结构性无环）；整线挂**新总闸 OPS_RUN_TREE_ENABLED 默认 off**（off 态 SSE 帧面+行为面零 diff · REST 投影新增字段为加性变更，R12）；子 run 继承父 run tenant/user/thread；**子 run HITL = 到写能力置 waiting_approval 退出 worker · decide 后重启 delegate worker 重跑 · _approval_consumed 消费闸放行**（复用既有 HITL 端点/审批卡 · 零新端点零新帧，R1）；**委派令牌由子 run 执行时自发签发**（父签发仅作授权凭证 · TTL 自尝试起算消解「批准后过期必败」· **配额归并父 run 预算桶**防 9× 分裂，R2）；**帧面零新增**（树关系只进 REST 投影 parent_run_id/depth 可加字段，帧仍 per-run 流，cursor "{run_id}:{seq}" 不动，老客户端看到的世界逐字节不变）；断线恢复靠 DB claim 重入不重复建行 + orphan 扫描天然覆盖子 run。验证假设 = 双样例：S1「换域零代码」（oa 端到端非 ops 问答 + ops 回归零 diff）、S2「一个目标拆成多个持久化子任务并行推进且各自可回放」（**批量巡检异质耗时场景**，R14）、S3 子 run HITL + 老契约回归（父卡徽标双态「待审批 · N」，R17）。任务切分**双泳道**：领域线 T2→T5 / Run 树线 T6→T8，契约 T1 最先行，T9 双样例验收收口（含**启用决策点** §11 · **止损线** §12 · **演示脚本** §13）；砍单序 **T4→T3→T8**（T8 是 Run 树线唯一可见证据不砍，R18）；两线互为独立可交付切片。iOS 本波不做（维护者已指示降优先，登记后续候选；契约面可加字段+零新帧保证 iOS 软兼容零触达）。

### 0.1 评审修订记录（R1–R25，全关闭）

| # | 修订 | 来源 |
|---|------|------|
| R1 | **子 run HITL 恢复机制**：既有 resume_hitl_run 是图 checkpoint 耦合（hitl/resume.py:311 → aget_state 探针 → Command(resume=...)），子 run 是非图执行体、两道既有 resume 通路恒不成立。裁定=「**退出-重跑-消费闸放行**」三段：①写类能力审批未消费 → 落 hitl.waiting 帧 + status=waiting_approval 后**退出 worker**（不占 _workers 槽）；②decide 后 resume 通路按 run 行 depth 分流 → **重启 start_delegate_run_worker 重跑该子任务执行体**；③**_approval_consumed(run_id, subtask_id, capability_id) 命中放行**（复用 nodes.py:497-533 既有消费闸 · fail-closed；重跑幂等成立因全部副作用闸在 capability_ainvoke 之前；重复 decide/resume 不重复执行）。零 checkpoint 依赖、零新端点、全程复用既有 HITL 端点/审批卡。§3.4 增段 · §3.5 矩阵行 4 改写 · T7 范围按此改写 · S3 判据对齐 | platform LB1 |
| R2 | **委派令牌身份映射**：令牌由**子 run 执行体每次执行尝试自发签发**（issuance 策略闸 nodes.py:677-702 随执行体提取复用 · TTL 自尝试起算 → HITL 挂起 >600s 批准后重跑即重签发，「REJECT_EXPIRED 批准后必败」形态消除；签发审批 delegation_issue_hitl_required 仍在父侧 dispatch 前完成 · 父签发仅作授权凭证不直接复用——verify_token 校验 run_id/subtask_id 四元组 delegation.py:567-574 与子 ctx 必撞）；T1 契约钉**身份映射表**五行（§3.9）；**配额归并：cap_ctx 预算键=父（根）run_id · 子 run 配额计入父 run 预算桶**（与图内 Send 记桶语义逐值一致 · 防 1 父+8 子约 9× 分裂 · nodes.py:2139-2142「配额按 run 记」原意）；nonce 一次性与重跑交互进 T7 用例；Q3 补注「令牌格式复用≠签发面复用」 | platform LB2 |
| R3 | **RAG 回退链改 fail-closed**：domain≠ops 且 QDRANT_COLLECTION_<DOMAIN> 缺省 ⇒ 该域本地 RAG **显式禁用**（rag 子任务报「本域未配置检索」· **不回落**全局/ops_knowledge——原三级回退使 oa 忘配 env 时静默检索 ops 语料=跨域向量泄漏）；ops 域（含缺省域）回退链零 diff；**R-P4-7 定性修正**（非「空跑」是跨域泄漏 · prompt 词表收紧不能充当数据隔离闸——与 §3.2「不让验证假设寄生于提示词遵从度」同原则）；S1 checklist 增 RAG 禁用实证 | platform LB3 |
| R4 | **记忆落库键无 domain 维**：T1 契约钉「**多域部署不得共库**」部署面约束（域=部署级 ⇒ 一次部署天然单库单域 · 零 DDL · 文档显式声明防未来误配——共库时 oa facts 会被 ops 部署召回侧无过滤命中）；「共库真实需求出现 ⇒ memory 加 domain 列+召回过滤」登记触发式后续 | platform LB4 |
| R5 | **词表分叉防护**：T1 契约写明「domain 词表 `[a-z0-9_]` 与 template id 词表（loader.py:20 _ID_RE 允许点号）**各自独立 · 禁止互拼**」——防后续把 domain 拼进 template id 的回流 | platform N1 |
| R6 | **domain 保留字 + MCP domain 真源**（N2+N3 合并）：T1 契约加「domain 保留字」条款（domain 值不得与 allow_tags_any/allow_write_tags_any 现存值及 "mcp" 冲突——baseline.py:35 DOMAIN_ALLOW_TAGS={"oa","mcp"} 豁免面 · "mcp" 同时是 MCP 翻译条目首 tag mcp/translator.py:372）；T3 单测「domain=mcp 拒载/显式告警」；**MCP 翻译条目 domain 真源=server 配置侧**（其所属 manifest 的 domain 键 · 远端 server 无 domain 声明可信面 · 翻译层禁加域逻辑进契约防回流） | platform N2+N3 |
| R7 | **run_owner 反查对子 run 兼容**：run_owner=反查事件表首行 user_id（event_store.py:100-117 · hitl/router.py:405-439 恢复段同靠此链 · 查不到归属→不落盘→前端永远停「等待授权」）；子 run 首帧 run.start 落盘 user_id=父 user_id 是全链成立前提——T7 验收加「子 run 首帧落盘 user_id → run_owner 反查成立 → decide/resume/replay 全链实证」 | platform N4 |
| R8 | **oa stub 独立进程隔离**：S1 checklist 增「OPS_DOMAIN=oa e2e 须在独立进程跑」（capability register() 是进程内全局注册表 · 防与 pytest 主进程共享态互染；FakeHttpTransport 进程内显式注入先例核实干净 capability_step_contract_gate.py:98-107） | platform N5 |
| R9 | **claim 并发核实结论记录**：ON CONFLICT DO NOTHING 并发双 INSERT 正确（败者阻塞至胜者提交后 SELECT 取回）；subtask_id 签发 `f"{run_id}:{seq}"` locked 前缀序列不回退不复用（nodes.py:876-928）⇒ replan 不撞号，uq 撞键仅发生在「同一子任务重入」的语义正确场景；create_run 现状 check-then-insert（run_store.py:52-75），claim 须新写 ON CONFLICT 路径（设计已正确识别 · 无需改 · T6「并发双建仅一胜」用例保留） | platform N6 |
| R10 | **oa manifest 手写 tags 防双写漂移**：oa 三能力已手写 tags:[oa,...]（oa.readonly.v1.yaml:29/96/157）⇒ T3 对 oa 是便利非使能；T3 验收改为「注入并集去重后 tags 集合 = 现状手写面**逐值一致**」防注入+手写双写漂移 | platform N7 |
| R11 | **skill/goal 部署级定位声明**：format_skill_catalog（skill_registry/registry.py:37）注入的 skills/ 目录与 goal 注入（continuity.py:507-535 + goals/inject.py:18-22）是**部署级资产 · 不进 assets/<domain>/ 域回退机制 · oa 部署自管其 skills 目录**——T1 契约声明，防后续误把 skill 目录塞进域回退；§9 排除 skill 面改动维持 | platform 盲点1 |
| R12 | **「off 零 diff」措辞精确化**：钉死为「**off 态 SSE 帧面+行为面零 diff** · REST 投影新增 parent_run_id/depth 字段为**加性变更**（契约豁免 · 消费方须容忍未知键 · 与 R-P4-8 兼容惯例一致）」——消解投影常加字段与 off 零 diff 的措辞张力；§3.7/§10/Q3 口径同步 | platform 盲点2 |
| R13 | **§8 补令牌过期失败路径行**：随 R2 子侧执行时自发签发**消解**（重跑即重签发 · 「批准后过期必败」路径不存在）；§8 落行记录该形态消解与语义 | platform 盲点3 |
| R14 | **S2 样例换异质耗时批量巡检场景**：「查两个 issue 状态」毫秒级并行证不出价值（并行与否/持久化与否用户感知与现役 Send 完全相同）→ 改「**巡检三台主机的磁盘与内存并汇总报告**」（异质子任务 · 各自持久化可回放 · 用户感知=「交付了三个可独立查阅的子交付」）；checklist 增「至少一腿子任务耗时显著高于其他（可注入延迟）」使并行交叠与独立回放**肉眼可感知** | product B1 |
| R15 | **T9 启用决策点**（默认面全零 diff ⇒ 不补则 P4 交付物用户感知为零）：①OPS_RUN_TREE_ENABLED 转默认判据（S1-S3 成立 + 观察窗 dogfood 无 R-P4-4 窗口事故 → 转默认 · 否则维持 opt-in 写明理由）；②oa 演示部署处置=**保留 dev 演示配置 · 文档化 · 不进 prod 默认面**；③web 树形面板随闸开放量路径；落 §11 | product B2 |
| R16 | **S1 语料与断言解耦**：oa stub 语料**不由 T5/T9 实施者自编**（真实 OA 风格制度文档摘抄改写 · lead 准备 · 实施者只拿语料约定不拿断言表——切断「stub 返回什么、断言写什么同一只手」闭环自证激励链）；**S1 结论限定「机制面验证（域隔离/回退/混合解析）」· 不外推「oa 域产品可用」**；R-P4-6 补「真实 OA 网关冒烟」为 S1 完全成立前置挂账项（无环境则 S1 上限=机制面成立） | product B3 |
| R17 | **父卡徽标双态**：任一子 run waiting_approval → 父卡徽标**变色 + 文案「待审批 · N」**（承 14 R16 计数徽标零成本插槽位 · web 仅消费 runs 投影 status · 无新端点新帧不破零 diff 纪律）——不修则审批信号藏在折叠面板缩进子卡里、用户永远不知道有审批在等（P3 R18 同型缺口在用户在场场景再造 · 恰砸 S3 核心链）；进 T8 scope 与 S3 checklist | product B4 |
| R18 | **砍单序改 T4→T3→T8**：T8 是 Run 树线**唯一**用户可见证据载体不砍（砍 T8=Run 树线整线顺延 · 不做降级验收——「两线各自独立可交付」的产品叙事对 Run 树线不成立）；T3 砍则 oa manifest 手写 tags（N7 核实现状即手写 · S1⑤「零代码」判据不变因 tags 手写仍是文件级）；T4 无 oa 消费者可整单顺移 | product N1 |
| R19 | **部分成立清单 (c) 加时限**：子 run 待审批感知延迟 **>30s 即升级复议**（HITL 链上分钟级延迟是体验红灯 · 不预设为可接受缺口——P3 R14 闭合清单纪律=清单内皆真可接受缺口） | product N2 |
| R20 | **概念跳跃可用性判据**：子任务从「折叠区过程行」升级为「可点击独立 run」是用户心智模型换代——T8 验收加「首次接触者 **30 秒内**能找到子 run 回放/审批入口」（进 S3 人工验收段） | product N3 |
| R21 | **S1③ 人工判读 rubric 四组对照**：(i) 人称与自述 (ii) 领域术语词表（issue/PR/部署 vs 合同/通讯录/待办）(iii) 路由语义残留 (iv) 记忆 key 目录残留——逐组过/不过（无对照清单则人工判读不可复现 · 承 R14 checklist 体例） | product N4 |
| R22 | **T9 报告补「双命题合并结论」段**：回答「P4 整体证明了『通用化』的哪一半、没证明哪一半」· 点明双命题本质是**供给侧命题**（加域/拆任务边际成本趋零）非需求侧命题（用户要多个域）· 防双泳道叙事割裂 | product N5 |
| R23 | **止损线条款**：做早了=①oa 验收后 **3 个月内无第二个真实域需求排队**（通用化=自我证明）②闸开后真实使用**子 run 回放 drawer 打开率趋零**（持久化子任务非真需求）；做过了=①T5 七份覆盖模板实际消残所需**不足半数**（A1 耦合点高估 · 目录回退机制投资过度）②真实使用 **MAX_CHILDREN=8 从未触达 2 以上**（扇出上限与 DB claim 为不存在的规模造）；止损动作=信号触发 → 对应线回退默认 off / 资产归档 · 登记「愿景线证伪」非无限维护；落 §12 | product 盲点1 |
| R24 | **演示脚本作叙事载体**：T9 报告附演示脚本——①oa 演示路径（env 两枚+挂 manifest → 问「劳动合同续签流程」）②Run 树路径（R14 巡检场景 → 展开面板 → 打开子 run 回放）；叙事不对称如实写（S1 受众=部署者/二开者 · S2/S3 受众=最终用户且仅闸开后）；落 §13 | product 盲点2 |
| R25 | **oa 真实域身份边界**：§2.4 明写「oa 证明的是**领域包机制** · 不证明 oa 域产品价值」（manifest 真实 · 语义真实 · **语料与网关皆 stub**）；T9 报告不得把 S1 通过表述为「oa 域可用」 | product 盲点3 |

### 0.2 裁定总表（D-A ~ D-F）

| # | 开放点 | 裁定 |
|---|--------|------|
| D-A | P4 范围 | **两线各取勘察最小切片即 P4 范围，不扩**（§1）；明确排除：RunWorker 全面 DB 租约、nonce 外置、rag/extract 子任务 run 化、树形合并流、多深度树、oa RAG ingest、memory 加 domain 列（触发式后续 R4）——全部登记后续 |
| D-B | 领域配置化 | domain 落点 = **manifest domain 键消费为 tags 注入**（否 schema 拒绝、否新建 domain 注册表）；prompt = load_asset 目录回退 + registry 白名单保留（域集合运行时发现在不硬编码）；RAG = collection 按域 env 约定（**fail-closed**：domain≠ops 缺省即禁用不回落 R3）+ glossary 按域文件回退（source_type/ingest 不泛化）；**记忆面=多域不得共库部署约束**（R4）；**验证域 = 真实 oa 域**（语料解耦 R16 · 边界注明 R25）；**域 = 部署级（OPS_DOMAIN），否租户级** |
| D-C | Run 树 | runs 表加 parent_run_id/subtask_id/depth 三列 + **uq(parent,subtask) 部分唯一 = 委派 claim**（否新表）；**深度上限 1**（结构性无环）；子 run 继承父 tenant/user/thread；**子 run HITL=退出-重跑-消费闸放行**（R1）；**令牌子 run 执行时自发签发 · 配额归并父 run 预算桶**（R2）；帧面零新增、cursor 不动、树只进 REST 投影；**总闸默认 off** |
| D-D | 触发语义 | supervisor 的 **tool_exec 子任务在闸开时提升为子 run**（plan-JSON 不加新 type）；rag/extract 留在图内；父 run 轮询子 run 终态 join（承既有子任务预算闸）；预算 = 深度 1 + 每父 run 子 run 总数上限（默认 8）+ MAX_SUBTASKS=4 既有闸；HITL = 子 run per-run 审批（R1 三段机制 · 既有端点） |
| D-E | web/iOS | runs 投影加 parent_run_id/depth（可加字段零破坏）；面板缩进渲染 + 父卡子任务计数徽标**双态「待审批 · N」变色**（R17）；子 run 待审批 → 打开子 run 视图走既有 hitl 卡审批；**不开 children 端点**；**iOS 本波不做**（登记） |
| D-F | 验证+切分 | S1 换域零代码（语料解耦 · 结论限定机制面）/ S2 **批量巡检异质耗时**持久化并行子任务可回放（R14）/ S3 子 run HITL（R1 机制链）+老契约回归；三级裁定承 14 §7 体例（部分成立清单 (c) 时限 30s · R19）；**T9 启用决策点 §11 + 止损线 §12 + 演示脚本 §13 + 合并结论段 R22**；双泳道 T1→{T2-T5 领域线 · T6-T8 Run 树线}→T9，两线独立可交付 · **砍单序 T4→T3→T8**（R18） |

---

## 1. D-A · P4 范围裁定

### 1.1 裁定：勘察两最小切片即 P4 范围，不扩

**裁定**：P4 本波 = inv-p4 要点 9（领域化最小切片）+ 要点 10（Run 树最小切片），**一条不扩、一条不复活**。roadmap :61「愿景，不设排期」不意味着「一次做完整愿景」——本波的定义是「用最小切片证伪/证实两条线的核心心智」，愿景余量（rag/extract run 化、多深度树、树形合并流、oa RAG ingest、RunWorker 全面租约化）逐条登记后续候选，由真实需求驱动再立项。

**理由**：
1. **纪律延续**（04-roadmap.md:72「P4 之前的抽象必须服务 ops 域真实闭环」→ P4 内部的抽象必须服务 P4 的验证假设）：每个机制件都必须被 S1/S2 样例直接消费，否则就是 builder.py:124-130 被摘除的 scenario 空抽象的同型复活（恒等价层，正反证据俱在）。
2. **P3 已验证的扩张成本控制法**：14 号稿把 APNs 降级为契约草案（R3）、propose→confirm 后置（§4.2），判据同为「建好即空转」——本稿对每个候选项过同一把尺（见 §3.6/§4/§9 非范围）。
3. **两切片已各自闭环**：领域切片（文件级覆盖三件套）与 Run 树切片（一迁移一 claim 一投影）互不依赖，可独立交付独立验收——范围再小就会失掉「通用化」的双线证据面，再大就触碰进程外置等 P3 已登记债的连带工程。

**被否替代**：
- **只做领域线**（Run 树推迟）：丢「多 Agent」这条 roadmap 明载愿景线的证据面，且 Send 雏形到 Run 的一步是本轮信息价值最高的一跃（子任务不可回放是现役真实缺口）；
- **只做 Run 树线**：oa domain 键静默忽略的「第三状态」（manifest.py:450-479 不读不拒）继续腐烂，违 inv-p4 要点 3「要么消费要么拒绝，不能放任」；
- **扩大到 rag/extract 也 run 化**：无消费者（rag/extract 无外溢副作用、无独立审计诉求），子 run 量 ×3 而证据不增（§3.6）；
- **扩大到 nonce/熔断/预算外置**：P3 §6 已裁定维持进程内+登记单副本声明（14 §6.2），本波单机单副本无跨进程面，外置=还无需还的债。

### 1.2 「愿景不设排期」下的防过度设计原则（P3「不做空抽象」延续）

三条判据进每节自检：①**消费者在位**——每个新机制点名消费它的验收样例编号（S1/S2/S3），点不出即砍；②**零 diff 默认面**——默认部署（ops 域 / 闸 off）行为逐字节不变，机制只经 env/文件存在性激活；③**载体复用**——优先文件级覆盖与既有表加列，否新抽象层/新注册表/新帧类型（scenario 摘除教训 builder.py:124-130 + P3 零新帧纪律 14 §2.4）。**止损线判据见 §12（R23）**——「愿景不设排期」同时要求「什么信号说明做早了/做过了」可测量。

---

## 2. D-B · 领域配置化

### 2.1 domain 维度落点：消费 manifest domain 键为 tags 注入（否第三状态）

**裁定**：加载器 _parse_and_validate（manifest.py:450-479）读取可选顶层 `domain` 键（字符串，词表校验同 capability tag 形态 `[a-z0-9_]`），**将 domain 值注入该 manifest 全部 capability 的 tags 集合**（与显式声明 tags 取并集，dedupe）；domain 键缺失 = 不注入（builtin.v1.yaml 零 diff）。消费语义锚 = types.py:160-162 既有共识「域天然落在 tags 上」：CapabilityFilter 的 tags_any/allow_tags_any 判序不动，oa 域能力经 `allow_tags_any={"oa"}` 逐批放行的用法（types.py:162 文档串内既有示例）自此有了 manifest 侧真源。

**保留字与 MCP 真源（R6 · N2+N3）**：T1 契约加「**domain 保留字**」条款——domain 值不得与 allow_tags_any/allow_write_tags_any 现存值及 "mcp" 冲突（baseline.py:35 DOMAIN_ALLOW_TAGS={"oa","mcp"} 是豁免 kinds 裁剪的消费点 · "mcp" 同时是 MCP 翻译条目首 tag mcp/translator.py:372 · 撞名即注入 tag 意外命中豁免面）；T3 单测「domain=mcp 拒载/显式告警」。**MCP 翻译条目的域归属唯一真源=server 配置侧**（其所属 manifest 的 domain 键 · T3 注入覆盖 mcp 块条目；远端 server 无 domain 声明可信面 · 现状正确 · 契约注明防后续给翻译层加域逻辑）。

**理由**：tags 是已交付、已评审、已被过滤器消费的维度——注入是纯数据面动作，零新判序零新闸面；oa.readonly.v1.yaml:22 的 domain 键从「注释级存在」转正为「加载期语义」，第三状态消除。**被否**：①schema 拒绝 domain 键（对仓内已有文件敌意，且白白丢掉一个正确的声明点）；②新建 Domain 注册表实体（domain 表/yaml 注册中心）——domain 在本设计里只是「文件命名约定 + tags 值 + env 值」三位一体的字符串，注册表没有独立状态可管，是 scenario 同型空抽象（builder.py:124-130）；③把 domain 提升为 CapabilityFilter 独立字段（动判序=动安全闸面，tags 已够载，收益为零）。

### 2.2 prompt 模板 domain 化：loader 目录回退 + registry 白名单保留

**裁定**：
1. **load_asset(template_id, domain=None)**（loader.py:52）：domain 非空时先读 `assets/<domain>/<template_id>.md`，文件不存在回退根目录 `assets/<template_id>.md`；缓存键 =(template_id, domain)。domain 词表校验复用 _ID_RE（loader.py:20，拒绝路径穿越面不变）；**domain 集合运行时发现在 assets/ 子目录，不硬编码**——registry 软化的是「域」这一维，不是「模板 id」这一维。**词表纪律（R5 · N1）**：domain 词表 `[a-z0-9_]` 无点，template id 词表允许点号——二者**各自独立、禁止互拼**（domain 只拼目录不进 template_id · T1 契约写明，防后续回流）。
2. **registry 白名单保留**：templates.py:11-26 的 11 个模板 id 仍是编译期白名单（安全面：loader 只认白名单 id + 文件名正则，不变）；TEMPLATES 保持构建 ops 默认面（import 期行为零 diff），新增 `get_template_for_domain(template_id, domain)` 薄封装。
3. **域解析**：新增 `app/ops/prompts/domain_context.py`（仿 tenant_context.py:11-26 先例）：`current_domain()` contextvar，默认 `"ops"`，由 OPS_DOMAIN env 在 run 启动处（start_run_worker 设置，与 set_current_tenant 同位 run_worker.py:117-120）注入；**全部调用点（nodes.py:196/2703/2740、lg_rag/nodes.py:85/216、intent.py:19、memory/extract.py:107）不改签名**——render 内部读 contextvar 取域。OPS_DOMAIN 默认/缺省/非法 → ops + logger.warning（非法值不进加载路径，防 env 注入路径穿越）。
4. **ops 默认零 diff 原则**：assets/ops/ 目录**不建**——ops 域解析恒走根目录回退，加载结果与现状逐字节一致；零 diff 由「回退顺序 + 不建 ops 目录」双保险构成，进 T2 验收（全量模板 on/off OPS_DOMAIN 双跑 body 逐字节对拍）。

**理由**：目录回退是文件级覆盖的最小形态——加一个域 = 加一个子目录，零代码零注册动作；contextvar 注入使 11 个调用点零 churn（改动面收敛在 loader/templates/context 三文件），与 tenant 注入同构（仓内已跑通的先例）。**被否**：①manifest 式 prompt 注册表（每域一个 yaml 声明模板映射）——文件存在性即声明，注册表是纯转发层；②模板 id 内嵌域（`lg_rag.supervisor.system.oa`）——污染白名单维度，调用点要拼 id，11 处 churn（兼触 R5 词表互拼禁令）；③front-matter 加 domain 字段自声明——文件位置已是真源，双写=漂移源（承 P3 R12「唯一真源」纪律）。

### 2.3 RAG 域化：collection/glossary 配置面，source_type/ingest 不泛化

**裁定**（三件套的诚实切分 · **R3 fail-closed 修订**）：
1. **collection**：`qdrant_collection(domain)` 改造（backend.py:39-40）——**ops 域（含缺省域）维持三级回退**：`QDRANT_COLLECTION_OPS` → `QDRANT_COLLECTION` 全局值 → `ops_knowledge`，零 diff；**domain≠ops 且 `QDRANT_COLLECTION_<DOMAIN_UPPER>` 缺省 ⇒ fail-closed：该域本地 RAG 显式禁用**（rag 子任务报「**本域未配置检索**」· **不回落全局/ops_knowledge**）。理由（LB3）：初稿三级回退意味着 oa 部署忘配 per-domain env 时 rag 子任务**静默检索 ops 语料**并喂进 oa 答案——不是「空跑」，是**跨域向量泄漏**（ops 语料含发布面/回滚面等内部细节进 oa 上下文）；oa 版 supervisor prompt 词表收紧只是缓解、**提示词遵从度不能充当数据隔离闸**（与 §3.2 自家原则「不让验证假设寄生于提示词遵从度」直接一致）。纯 env 约定，零新配置文件。
2. **glossary**：`glossary.<domain>.yaml` 文件回退（glossary.py:18 单路径 → 按域解析：存在则读域文件，否则读 glossary.yaml）；加载改按域缓存。
3. **source_type 词表 + ingest 加载器：本波不泛化**（ingest.py:43/58-89 直读 OpsIssue/OpsPullRequest 表，issue|pr|doc 词表绑死 ops 语料模型）——oa 验证域**不消费本地 RAG**（三能力 oa.doc.search/oa.org.whois/oa.todo.mine 全是 http kind 远端只读，答案由 capability 结果构成，不走本地语料检索）。泛化 ingest = 为无消费者的抽象写加载器矩阵，登记后续（触发条件：出现第二个需要本地语料 ingest 的域）。

**理由**：配置面的两个改造点（collection env 约定 / glossary 文件回退）各自有即时消费者路径——ops 默认面零 diff 回归 + 域文件回退单测；不消费的第三件（ingest）诚实不做。**被否**：domains.yaml 统一领域注册文件（把 collection/glossary/prompt 目录全收进一个注册文件）——三个载体各自的「文件存在性/env 约定」已是真源，注册文件=转发层+漂移面；oa glossary 文件**本波不随包交付**（无本地 RAG 消费=死配置，违 14 阶段纪律 2「不预搭」；glossary 回退机制由 ops 夹具单测覆盖）。

### 2.4 验证域裁定：真实 oa 域（否构造域）

**裁定**：S1 验证域 = **oa**（仓内唯一真实第二域：oa.readonly.v1.yaml 三只读能力 + OPS_CAPABILITY_EXTRA_MANIFESTS 挂接通路已交付）。oa 领域包内容 = **7 份域耦合模板的 oa 覆盖**（lg_rag.supervisor.system / lg_rag.direct.system / lg_rag.aggregator.system / lg_rag.router.system / lg_rag.rewrite.system / lg_rag.intent.system / memory.extract.system——逐份对应 inv-p4 A1 表耦合点：人设、type=rag 语义、路由规则、语料声明、intent 词表、记忆 key 目录），4 份域中立模板（session.summary / lg_rag.query_rewrite / lg_rag.extract / lg_rag.supervisor.suffix）**刻意不覆盖**——走根目录回退，恰好使「混合解析」成为回退机制的端到端实证。OA 网关依赖走 stub：验收脚本承 scripts/acceptance 既有模式（StaticCredentialVault + 假 transport，capability_step_contract_gate.py:32/:104 先例），不依赖真实 OA 系统；**e2e 在独立进程跑**（R8 · capability register() 进程内全局注册表防共享态互染）。

**oa 真实域身份边界（R25 · product 盲点3）**：oa 的真实性是相对的——manifest 真实、语义真实，但**语料与网关皆 stub**（inv-p4 :49 仅 3 只读能力 · OA_BASE 无真实环境）。因此 oa 证明的是「**领域包机制**」（域隔离/回退/混合解析），**不证明「oa 域产品价值」**；后者需真实 OA 环境冒烟（R-P4-6 登记为 S1 完全成立的前置挂账项）。**T9 报告不得把 S1 通过表述为「oa 域可用」。**

**理由**：构造域（test_domain 夹具）只能证明「回退机制会读文件」，证明不了「换域零代码」的心智——oa 有真实语义（文档检索/通讯录/待办），supervisor 拆解、capability 可见集、答案综合全链都被真实语义驱动，任何 ops 残留（人设泄漏、路由规则错配、记忆 key 污染）都会显形；且 oa 只读（side_effect=read 三能力）= 最低风险第二域。**被否**：构造域（证据力不足，见上）；先上第三个「更大」的域（无仓内真实候选，预造=空转）。

### 2.5 tenant 与 domain：正交，domain = 部署级

**裁定**：domain 是**部署级配置**（OPS_DOMAIN env，进程单值，承 QDRANT_COLLECTION 全局单值先例 backend.py:28-40）；**不挂 tenant**（tenant_context.py:11-26 维持纯租户谓词，不加域维度）。一次部署 = 一个域 + 多租户；跨租户隔离规则（F1-F6）在域内不变。

**记忆隔离推论（R4 · LB4）**：记忆落库键 = tenant+user、**无 domain 维**（memory/extract.py FactCandidate 现状核实）——「一次部署=一个域」不蕴含「一域一库」，双部署共库是现实配置，共库时 oa 部署写入的 facts（oa key 目录产物）在同库 ops 部署召回侧无任何域过滤 = 跨域污染面。裁定 = T1 契约钉「**多域部署不得共库**」为部署面约束：域=部署级 ⇒ 一次部署天然单库单域，**零 DDL**（与本波最小切片纪律一致）；契约文档显式声明防未来误配。「共库真实需求出现 ⇒ memory 加 domain 列+召回过滤」登记触发式后续（§9）。

**理由**：域改变的是语料/prompt/能力集语义——这些与部署的外部系统绑定（OA_BASE 本身就是部署 env），与「哪个租户在问」正交；inv-p4 要点 5 明判「不要把 domain 挂到 tenant」。**被否**：per-tenant domain（runs/threads 全链路加域列 + 租户→域映射表）——无消费者（两试点租户同为 ops 域），且把部署语义错配进数据模型，正是 14 §1.3 否 schedule.goal_id 的同型理由（一个 alembic 的事，等真实需求驱动）。

---

## 3. D-C · Run 树

### 3.1 数据模型：三列一索引，零新表

**裁定**（唯一新 DDL · 遵守「新 DDL 含 tenant_id」——runs 表已有 tenant_id 满足）：

| 列 | 型 | 说明 |
|---|---|---|
| parent_run_id | String(64) null | 父 run；**不加 FK**（承 run_events 顺序容错先例 models.py:285-288 注释） |
| subtask_id | String(64) null | 父图内子任务 id（委派 claim 的业务键一半） |
| depth | Integer not null default 0 | 0=根 run，1=子 run；**深度上限 1 硬约束**（§3.3） |

索引：**uq_ops_lg_rag_runs_parent_subtask (parent_run_id, subtask_id) WHERE parent_run_id IS NOT NULL（部分唯一）= 委派 claim 键**；另加 idx_ops_lg_rag_runs_parent (parent_run_id) 供投影反查。create_run（run_store.py:52-75）扩 parent_run_id/subtask_id/depth 三个可选 kw 参数——缺省调用零 diff。

**委派 claim（复用 OpsScheduleFire 范式）**：建行 = INSERT ... ON CONFLICT DO NOTHING（PG 同事务撞 uq abort 教训已在 14 R10 记录）；冲突即「该子任务已委派过」→ SELECT 取回已有 child run_id 复用。**这就是「DB claim 取代进程内单飞」的落实面**：claim 防的是 replan/resume/checkpoint 重放导致的重复建行（图节点重执行是 LangGraph 常态），不是多副本并发——多副本面维持 P3 登记债（14 §6.2-6.3），本波进程内单飞 _workers dict（run_worker.py:71）对同 child run_id 仍兜住进程内重入。nonce（delegation.py:315-351 进程内 _NonceRegistry）**维持进程内不外置**：子 run 与父 run 同进程执行，验签在本进程，无跨进程面（外置登记为多副本化债，与 14 §6.2 同口径）。**并发核实结论（R9 · platform N6 复核通过）**：ON CONFLICT DO NOTHING 并发双 INSERT 正确（败者阻塞至胜者提交后 SELECT 取回）；subtask_id 签发 `f"{run_id}:{seq}"` 且 locked 前缀序列不回退不复用（nodes.py:876-928）⇒ replan 不撞号，uq 撞键仅发生在「同一子任务重入」的语义正确场景；create_run 现状是 check-then-insert（run_store.py:52-75），claim 须新写 ON CONFLICT 路径——设计已正确识别，T6「并发双建仅一胜」用例保留即可。

**被否**：新建 ops_lg_rag_delegations 台账表（run 行本身已是状态面，claim 键挂在 run 行上=「建行即认领」单真源；再立台账=双源漂移，反 OpsScheduleFire 建表理由——fires 有独立生命周期而委派没有）；root_run_id 冗余列（depth≤1 时 root 恒等于 parent，冗余列无查询面消费）；parent 链无上限多深度（§3.3）。

### 3.2 触发语义：闸开时 tool_exec 委派提升为子 run（plan-JSON 零新 type）

**裁定**：新增总闸 `OPS_RUN_TREE_ENABLED` ∈ {off（默认）, on}，非法回退 off + warning，**off 态 SSE 帧面+行为面零 diff**（R12 · 三件套逐字承 14 §1.7 OPS_SCHEDULE_ENABLED 先例）。闸开时：route_next_subtask（nodes.py:1837-1873）对 **type=tool 的 inflight 子任务**不再发 Send(tool_exec)，改走「委派 claim（§3.1）→ 启动子 run worker（§3.4）→ 图内节点轮询子 run 终态（§3.5）」；rag/extract 子任务**留在图内不动**（无外溢副作用、无独立回放/审计诉求，run 化无消费者）。**plan-JSON 不加新 type**：提升面由「子任务 type=tool + 闸开」机械决定，不依赖 LLM 输出新词表——supervisor prompt 零改动，计划解析/校验零改动（nodes.py:94 SUBTASK_TYPES 词表不动）。

**理由**：tool_exec 是唯一有外部副作用、有委派令牌（nodes.py:1857-1866 已按子任务签发 run_id/user_id 绑定）、有独立审计诉求的子任务类型——「泛化 Send」的语义就是「有副作用的委派变成一等持久化实体」，恰好落在既有委派通路上；机械判定而非 LLM 新词表 = 行为可测试、可回归，不让验证假设寄生于提示词遵从度。**被否**：①plan-JSON 新 type=run / as_run 旗标（LLM 输出面变更，supervisor prompt 与校验双改，且 LLM 不用即机制空转）；②全部子任务 run 化（rag/extract 无消费者，子 run 量 ×3 而证据不增）；③不动图、另开「delegate capability」异步火忘式（丢失 Send 并行 join 语义——父 run 需要子结果才能 aggregate，火忘式回答不了 S2「并行推进且收口」）。

### 3.3 深度上限与环防护：深度 1 硬上限，结构性无环

**裁定**：**MAX_DEPTH = 1**（depth ∈ {0,1}）。结构性保证：子 run 执行的是**非 supervisor 委派管线**（§3.4），其执行体内不存在 route_next_subtask 通路——无 supervisor 则无派发，无派发则无孙 run，环在构造上不可能（不靠运行时检测）。claim 建行时校验：父 run depth 必须 = 0，否则拒建 + logger.exception（防御性断言，正常路径不可达）。

**被否**：深度上限参数化（MAX_DEPTH env）——多深度树无消费者（S2 一层即证），参数化=为无消费者形态留旋钮；运行时环检测（沿 parent 链走查）——深度 1 下走查集恒为空，纯死代码。

### 3.4 子 run 执行体：委派管线（提取复用，非复制）

**裁定**：子 run worker = 新增 `start_delegate_run_worker(...)`（run_worker.py 内，与 start_run_worker 同级），**共享** RunEventBus/_workers dict/单飞复用/孤儿补偿全部既有纪律（run_worker.py:71-178 同源）；执行体 = 从既有 tool_exec 节点**提取**的委派执行函数（闸链调用单一真源：idempotency/circuit/budget/HITL/delegation 验签原样），帧序 = run.start（payload 带子任务 query 摘要）→（hitl.waiting，若能力要求审批）→ answer → done（或 error）——**全部既有帧类型，零新帧**。子 run 的 mode 语义不进 status 词表（runs.status 六词表不动）。

**子 run HITL 生命周期（R1 · LB1 · S3 主链必经环节）**：既有 HITL resume 执行体是**图 checkpoint 耦合**的（resume_hitl_run hitl/resume.py:311 → _default_graph_factory :173-177 → graph.aget_state 探针 :240-259 → graph.astream(Command(resume=...)) :280；auto_resume.py:171-180 同硬依赖 postgres checkpointer + graph factory）——子 run 是从 tool_exec 提取的**非图执行体**，没有 LangGraph checkpoint，两道既有 resume 通路对其恒不成立（aget_state 拿不到快照 → stranded_checkpoint 类失败）。裁定=「**退出-重跑-消费闸放行**」三段：
1. 执行体遇写类能力且审批未消费：落 hitl.waiting 帧 + status=waiting_approval 后**退出 worker**（不占 _workers 槽 · HITL TTL 既有语义 03 §0 兜底）；
2. 用户经**既有 decide/resume 端点**（按子 run_id · **零新端点零新审批卡**）批准 → resume 通路按 run 行 depth 分流：depth=1 → **重启 start_delegate_run_worker → 重跑该子任务执行体**；
3. 重跑至同一能力调用点，**_approval_consumed(run_id, subtask_id, capability_id) 命中放行**（nodes.py:497-533 消费点既有 · fail-closed）。**重跑幂等成立**：全部副作用闸（idempotency/circuit/budget/HITL）在 capability_ainvoke 之前，重跑只重放无副作用的闸链前段；**重复 decide/重复 resume 不重复执行能力**（消费闸一次性）。T7 验收含两条实证：「approve 后子 run 重跑放行至 done」「重复 decide/重复 resume 不重复执行能力」。

**理由**：子 run 不是「小号 supervisor」——它包装的是单次能力委派的持久化与可回放，帧面恰好复用既有类型即完整表达；提取（非复制）tool_exec 执行体保证闸链单真源（P2a/P2b 评审确立的闸链纪律不双写）。**被否**：子 run 复用 mode="direct" 全图（direct 图是问答管线，包装单次工具调用要拖 router/rewrite/retrieve 全链，语义错配且帧面虚胖；且唯有如此才使 §3.4 HITL 三段机制成为必需——platform LB1 事实链起点）；新立 mode 词表值（status 词表=客户端六态契约，动即 freeze 修订）。

### 3.5 join 与断线恢复：轮询终态 + DB claim 重入

**裁定**：父图 tool_exec 提升分支的等待节点**轮询子 run 终态**（SELECT status，间隔 1s，承 runs.status 状态机；TERMINAL_STATUSES run_store.py:24），超时与失败预算**复用既有子任务闸**（is_supervisor_budget_exhausted 总步/旗标/墙钟 nodes.py:1844，MAX_SUBTASKS=4 nodes.py:95）；子 run 达终态后从**子 run 事件表读 answer/done payload** 作为子任务结果进 subtask_join 既有通路。断线恢复矩阵：

| 场景 | 行为 |
|---|---|
| 父进程崩，子 run 在飞 | 子 run 独立跑完（互不耦合）；父 run 由 orphan 扫描补 disconnected（既有）；用户续看父 run → 图从 checkpoint 恢复 → route_next_subtask 重执行 → **DB claim 撞 uq 取回已有 child run_id，零重复建行** → 继续轮询 |
| 子 run 崩（无终帧） | 子 run 由 orphan 扫描补 done{disconnected}（**orphan 扫描对子 run 天然生效，零改造**——它扫的是事件/run 行，不认父子）；父轮询见终态，按失败子任务进 observe/critic 既有通路 |
| claim 已建、worker 未起（两次写之间崩） | 父 run 恢复后轮询子 run 发现 status=running 但无活跃 worker（is_run_worker_active run_worker.py:83 为假且事件无进展超时）→ 由孤儿补偿的既有两段式兜住 + 父侧失败预算收口；登记残余窗口（§6 R-P4-4） |
| 审批中父 run 断线 | 子 run 停 waiting_approval **且 worker 已退出**（不占槽 · R1 · HITL TTL 既有语义兜底）；父恢复后继续轮询；用户 decide → **子 run 按 §3.4 三段重跑放行至终态**，链路闭合 |

**被否**：父子事件总线互联（父 bus 转发子帧——破 per-run 流契约，见 §3.7）；子 run 完成回调父图（回调=新生命周期耦合，轮询+claim 已闭环且全部复用既有件）。

### 3.6 预算防爆炸

**裁定**（三层）：①深度 1 硬上限（§3.3，结构性）；②**每父 run 子 run 总数上限 OPS_RUN_TREE_MAX_CHILDREN 默认 8**（claim 前 COUNT(parent_run_id) 校验，超限=该子任务按失败进 observe 通路 + 审计日志——覆盖 replan 多轮累计，单轮 4 + 一轮 replan 4 以内足够）；③单轮扇出 = 既有 MAX_SUBTASKS=4 不动。LLM/能力预算归因：子 run 的 usage/span key = **继承父 run user_id/tenant_id**（§3.8），start_delegate_run_worker 显式传入（承 14 §1.8 R4 预算归因纪律）；**配额记桶键 = 父（根）run_id**（R2 · §3.9——子 run 配额计入父 run 预算桶，与图内 Send 记桶语义逐值一致，防闸开后配额放大约 9×（1 父+8 子各开新桶）的分裂 · nodes.py:2139-2142「配额按 run 记，不是按子任务」注释原意）。

### 3.7 SSE 帧面与 cursor：零新帧、零 cursor 变更、树只进 REST 投影

**裁定**：
1. **帧类型零新增**（7 种 web 词表 useLgRagSse.ts:28 / 11 种 iOS 词表 LgRagFrame.swift:60-72 均不动）；**run.start payload 加可选 parent_run_id 字段**——纯可加字段（web JS 对未知键天然忽略；iOS payload 解码对未知键忽略，且老客户端**根本收不到子 run 的流**，见下）。
2. **流边界钉死**：帧永远 per-run 流。客户端订阅父 run（stream/replay 按父 run_id）收到的帧序列与今天**逐字节一致**（父图仍发自己的 subtask.progress——子任务维度的进度语义不变，web 既有「子任务过程」折叠区照常渲染）。**子 run 的帧只出现在按子 run_id 订阅的流里**；老客户端没有任何通路被动收到子 run 帧。这就是「iOS 跳帧软兼容的利用边界」的明判：**本设计不消费跳帧宽容**——跳帧是对「未知帧类型」的兜底，而我们零新帧；老客户端行为钉死为「看到的世界与 P3 完全一致」（契约 freeze 零修订）。
3. **cursor "{run_id}:{seq}"（sse_replay.py:12-14）不动**：树形回放的获取 = ①REST runs 列表投影（新增 parent_run_id/depth 可加字段）拿树关系 → ②对任意 run_id 用**既有** replay/续看端点逐 run 回放。每 run 一条流，cursor 语义恒为单 run 内 seq，破坏性变更点整体绕开。
4. **「off 态零 diff」措辞精确化（R12 · platform 盲点2）**：投影 parent_run_id/depth 是**无条件常加字段**——「off 态零 diff」钉死为「**SSE 帧面+行为面零 diff**」；**REST 投影新增字段为加性变更**（契约豁免 · 消费方须容忍未知键 · 与 R-P4-8 兼容惯例一致）。§10 红线与 Q3 口径同此。
5. **被否**：树形合并流 / 跨 run 统一 cursor（v2 cursor 版本化）——唯一的消费者会是「单窗看全树」的 UI，而 §4 裁定的 UI 是「面板树 + 逐 run 回放」，无消费者；且动 cursor=破所有存量续看客户端，成本收益倒挂。登记为后续候选（触发条件：出现跨 run 时间线合并视图的真实产品需求）。

### 3.8 归属/回放/审批语义：继承父 run，per-run 机制零扩展

**裁定**：子 run **继承**父 run 的 tenant_id/user_id/thread_id（claim 建行时从父行取值，不从请求上下文取——与 14 §1.8「请求上下文外创建须显式传身份」同纪律）。由此三个面零新机制：①**归属**：runs 列表/events/replay 的既有 thread_owner/assert_run_owned 校验（runs_router.py:67-74）对子 run 天然通过（同 user 同 thread）；**归属链实证前提（R7 · N4）**：run_owner=反查事件表首行 user_id（event_store.py:100-117 · hitl/router.py:405-439 恢复段同靠此链——查不到归属→不落盘→前端永远停「等待授权」），故**子 run 首帧 run.start 落盘 user_id=父 user_id** 是 decide/resume/replay 全链成立前提，进 T7 验收；②**回放**：子 run 可独立回放 = 既有 per-run replay + P3 回放 drawer 直接消费（§4）；③**审批**：子 run 内 hitl.waiting 走**既有 per-run HITL 端点**（decide/resume 按子 run_id），父 run 不代理审批、不感知审批内容——父只看 status。**被否**：子 run 独立归属（可指定不同 user）——无消费者且打破审计链（子 run 花的是父会话用户的预算与权限）；父 run 代理转发审批（审批面双写=状态分叉，14 R15「操作唯一」纪律同型）。

### 3.9 委派令牌与身份映射（R2 · LB2）

**事实链**（platform 复核为真）：verify_token 校验 subject 四元组含 run_id/subtask_id（delegation.py:567-574 · 不等即 REJECT_SUBJECT_MISMATCH）；令牌现状在父 route_next_subtask 签发、绑定**父 run_id**（nodes.py:690-698）；TTL 600s 墙钟、禁续期、HITL 挂起不延长（delegation.py:12/:46/:556）——子 run ctx 直接复用父令牌必撞 REJECT_SUBJECT_MISMATCH，改绑子 run_id 又与 HITL 单据/_approval_consumed 匹配键系统性错位，且审批等待 >10 分钟批准后必 REJECT_EXPIRED。

**裁定**：
1. **签发面**：委派令牌由**子 run 执行体在每次执行尝试时自发签发**（issuance 策略闸 nodes.py:677-702 已是可提取单元 · 随执行体一并复用），**TTL 自尝试起算**——HITL 长等后 decide 重跑即重签发，「批准后过期必败」形态消除（§8 落行 · R13）；**签发审批（delegation_issue_hitl_required）仍在父侧 dispatch 前完成**，子侧重签发只解决墙钟，不绕审批；**父签发的令牌仅作授权凭证、不直接复用**于子 run 验签。
2. **身份映射表**（T1 契约钉死五行）：

| 面 | 取值 |
|---|---|
| 事件/状态行 run_id | **子 run_id** |
| token binding run_id / subtask_id | **子 run_id / 子任务 id**（claim 先于签发——建行即得 child_run_id，次序天然满足） |
| cap_ctx 预算键（配额记桶） | **父（根）run_id**——子 run 配额计入父 run 预算桶（§3.6） |
| HITL 单据 run_id | **子 run_id**（「打开子 run 视图审批」decide/_run_owner_of 链成立前提 · R7） |
| _approval_consumed 匹配键 | 与 HITL 单据对齐：（子 run_id, subtask_id, capability_id）（nodes.py:497-533） |

3. **nonce 与重跑**：nonce 一次性（delegation.py:557-579）与「decide 后重跑重签发」的交互进 T7 用例（每次执行尝试新 token 新 nonce · 重跑不复用旧 nonce）；nonce 维持进程内 _NonceRegistry 不外置（§3.1 同口径）。
4. **Q3 补注**（platform）：令牌**格式**复用成立；**签发主体/时序**按本条修订——「复用既有委派通路」不等于「复用父侧签发件」。

---

## 4. D-E · web/iOS 面

### 4.1 web：投影扩字段 + 缩进渲染，不开新端点

**裁定**：
1. **投影**（runs_router.py:86-97）：runs 列表项加 `parent_run_id`（null=根）与 `depth` 两字段——纯可加（R12：加性变更契约豁免），旧 web 版本忽略未知键零影响。**不开 /runs/{id}/children 端点**：列表平铺 + parent_run_id 已够客户端 O(n) 组树，children 端点是同信息的第二投影面（被否）。
2. **渲染**：P3 任务面板（14 §2.2 el-collapse 面板 + TaskCard）内，depth=1 卡片**缩进渲染**于父卡之下（CSS 缩进，否 el-tree 重组件）；父卡标题带**子任务计数徽标双态**（承 14 R16 计数徽标先例的零成本插槽位）：默认「子任务 · N」；**任一子 run waiting_approval → 徽标变色 + 文案「待审批 · N」**（R17 · PB4——不修则审批信号藏在折叠面板内、用户不展开就永远不知道有审批在等，恰砸 S3 核心链；web 侧仅消费 runs 投影 status，无新端点新帧）。聚合态**本波不算**（父卡只显示自身 status；「全部子 run 完成度」由缩进子卡各自状态自然表达，聚合规则=新状态机，登记）。
3. **子 run 交互**：子卡 running → 点击 = 对子 run_id 走既有「续看」（replay live-tail）；waiting_approval → 点击 = **打开子 run 视图**（drawer 内对子 run_id 起续看流，hitl.waiting 帧自然渲染既有 HitlApprovalCard，审批经既有 decide 端点）——P3「锚定滚动消息流」对本波子 run 不适用（子 run 帧不在父消息流），进 T8 验收钉死；终态 → 回放 drawer（既有）。**概念跳跃可用性判据（R20 · N3）**：子任务从「折叠区过程行」升级为「可点击独立 run」是用户心智模型换代——T8 验收加「**首次接触者 30 秒内能找到子 run 回放/审批入口**」（进 S3 人工验收段）。
4. store 帧增量接线：run.start 帧带 parent_run_id 时本地插入缩进子卡（web 对未知 payload 键零成本），done 帧按 run_id 更新对应卡片——chat.ts 六态分支（chat.ts:747-752）逐 run_id  keyed 扩展。

**被否**：独立树视图路由（违「交付出现在对话里」14 §2.2 同型理由）；消息流内联子 run 帧（破 per-run 流边界 §3.7）。

### 4.2 iOS：本波不做（维护者指示降优先 · 登记）

**裁定**：iOS 端**零任务单**。兼容性断言进契约（T1）：①零新帧类型 → LgRagFrame.swift 词表不触达；②runs 列表为 REST 投影可加字段 → 旧版 iOS 若消费该端点忽略未知键（当前 iOS 无 runs 列表面消费——P3 R23 已登记 iOS 任务卡片/回放为后续候选，本波维持）；③子 run 流只有按子 run_id 订阅才出现，iOS 无此通路。**登记项**：iOS 树形任务面板 + 子 run 审批面 = 后续候选（与 P3 R23 合并跟踪）；触发条件 = web 面 S2/S3 验收通过后产品评审立项。

---

## 5. D-F · 验证假设与验收样例

**P4 心智验证 = 双命题**：A「**换域零代码**」（加一个域 = 只加文件：prompt 覆盖 + manifest，不改一行 Python）；B「**一个目标拆成多个持久化子任务并行推进且各自可回放**」（子任务从图内 Send 节点升级为一等 run 实体）。验证端 = **web 主验证端**（承 14 R21 声明口径；iOS 缺位登记为非「部分成立」掩饰口径）。

**S1 · 换域零代码（命题 A 核心样例）**：部署面 OPS_DOMAIN=oa + oa manifest 挂接（OPS_CAPABILITY_EXTRA_MANIFESTS 既有通路）→ 用户问「帮我查一下劳动合同续签的流程文件」（oa.doc.search 语义）→ 全链：supervisor 用 oa 版模板拆解 → tool_exec 调 oa.doc.search（OA stub transport，承 capability_step_contract_gate.py:104 先例）→ aggregator 用 oa 版模板综合 → 答案落盘。**语料与断言解耦（R16 · PB3）**：OA stub 响应语料**不由 T5/T9 实施者自编**——由 **lead 自真实 OA 风格制度文档摘抄改写**准备，实施者只拿到语料约定、不拿到断言表（切断「stub 返回什么、断言写什么，同一只手」的结构性激励链）。**checklist（逐项过/不过）**：①加载证据——日志/span 显示 7 份覆盖模板解析自 assets/oa/、4 份中立模板回退根目录（混合解析实证回退机制）；②capability 可见集含 oa tag 三能力（tags 注入实证）；③答案无 ops 人设/术语残留——**人工判读 rubric 四组对照（R21）**：(i) 人称与自述、(ii) 领域术语词表（issue/PR/部署 vs 合同/通讯录/待办）、(iii) 路由语义残留、(iv) 记忆 key 目录残留——逐组过/不过；④**ops 回归零 diff**——默认部署（无 OPS_DOMAIN）全量模板 body 逐字节对拍一致 + pytest 全绿；⑤diff 证据——实现 oa 域的变更集**只含新增文件**（prompt/md + 测试），Python 改动全部属于 T2-T4 机制层且 ops 面零 diff；⑥**RAG 禁用实证（R3）**：oa 域下 rag 子任务报「本域未配置检索」· 不回落 ops_knowledge（替代初稿的人工判读软覆盖 · 机制禁用非 prompt 遵从）；⑦**独立进程（R8）**：OPS_DOMAIN=oa e2e 在独立进程跑（register() 进程内全局注册表 · 防与 pytest 主进程共享态互染）。**结论措辞限定（R16/R25）**：S1 通过 = 「**机制面验证（域隔离/回退/混合解析）成立**」· **不构成 oa 域答案质量与真实 OA 行为的外推证据 · 不得表述为「oa 域可用」**（真实 OA 网关冒烟=R-P4-6 前置挂账项）。

**S2 · 持久化并行子任务（命题 B 核心样例 · R14 场景更换）**：OPS_RUN_TREE_ENABLED=on 部署 → 用户问「**巡检三台主机的磁盘与内存并汇总报告**」（**批量巡检型**：异质子任务 · 各自持久化可回放 · 用户感知=「交付了三个可独立查阅的子交付」——初稿「查两个 issue 状态」毫秒级只读并行证不出价值：并行与否/持久化与否用户感知与现役 Send 完全相同 · product B1）→ 三个子 run 建行（parent_run_id=父 run、depth=1、subtask_id 各异，uq claim 实证）→ 并行推进（子 run 事件流时间戳交叠）→ 父 run join 后 aggregate 出最终答案。**checklist**：①DB 证据——ops_lg_rag_runs 三行 depth=1 且 parent_run_id 一致，uq(parent,subtask) 生效；②并行证据——子 run 事件流时间窗交叠；③**各自可回放**——web 面板对三个子 run 分别打开回放 drawer 呈现完整时间线；④父流零污染——父 run 回放帧序列与 P3 同型 run 逐型一致（无子 run 帧混入、无新帧型）；⑤**重入幂等**——kill api 于子 run 在飞时 → 重启续看父 run → DB claim 撞 uq 零重复建行（子 run 行数恒 3）；⑥**耗时异质（R14）**——至少一腿子任务耗时显著高于其他（可注入延迟），使并行交叠与独立回放**肉眼可感知**（不只时间戳断言）。

**S3 · 子 run HITL + 老契约回归（判据按 R1 机制链对齐）**：闸开部署下委派一个 hitl.required 能力（ops.write.run_note，承 14 R17 钉死件）→ 子 run 落 hitl.waiting + status=waiting_approval **退出 worker**（不占 _workers 槽 · R1）→ 父 run 轮询等待（不超既有预算）→ web **父卡徽标变色「待审批 · N」（R17）** + 子卡待审批 → 打开子 run 视图经既有 HitlApprovalCard approve → **decide 后重启 delegate worker 重跑 → _approval_consumed 命中放行** → 子 resumed→done → 父收口。**T7 实证两条（R1）**：「approve 后子 run 重跑放行至 done」「重复 decide/重复 resume 不重复执行能力」。**可用性判据（R20）**：首次接触者 30 秒内找到子 run 回放/审批入口（人工验收段）。**回归面**：①cursor 形状 "{run_id}:{seq}" 全测试套件不动（sse_replay 零改动 diff 证据）；②iOS 帧词表 11 种 / web 词表 7 种契约测试零修订；③闸 off 部署全量测试零 diff（SSE 帧面+行为面 · R12）。

**三级裁定**（承 14 §7/R14 体例）：
- **成立** = S1-S3 checklist 全过（含两条零 diff 回归）+ 人工判读项过。
- **部分成立** = 工程判据过但心智体验有缺口——**枚举闭合清单**：(a) oa 域下个别模板残留 ops 人设但主链正确（降级=该模板补覆盖，不动机制）；(b) 子 run 在面板可见但缩进/徽标缺失致树关系不直观；(c) 子 run 待审批感知延迟 **≤30s**（R19 · N2 时限约束——**>30s 即升级复议**：HITL 链上分钟级延迟是体验红灯，不预设为可接受缺口）；(d) iOS 缺位（登记口径，非掩饰）。**清单外缺口一律升级复议，不得裁「部分成立」**。
- **不成立** = 零 diff 回归红 / claim 重复建行 / 子 run 不可独立回放 / 换域需要改 Python → 失败分流 §8，触发设计复议。

**报告两表 + 合并结论段（承 14 R19 · R22 增补）**：表一 = 双命题三级裁定（S1→命题 A、S2/S3→命题 B）；表二 = 机制面结果（零 diff 对拍数据 / claim 幂等实证 / 契约回归清单）；**「双命题合并结论」段（R22 · N5）**——回答「P4 整体证明了『通用化』的哪一半、没证明哪一半」，点明双命题本质是**供给侧命题**（加域/拆任务的边际成本趋零），**不是需求侧命题**（用户要多个域），防双泳道叙事割裂。**T9 报告附演示脚本（§13 · R24）**，并含**启用决策点三条款（§11 · R15）**。

---

## 6. 风险登记

| # | 风险 | 缓解 |
|---|------|------|
| R-P4-1 | 域目录约定被滥用成「第二个代码层」（域覆盖无限膨胀致资产矩阵失控） | 契约钉「覆盖以模板为单位、缺省回退」；域集合=部署级单值（同进程一域），无组合面；登记：第三域出现时评审资产矩阵治理 |
| R-P4-2 | contextvar 域注入漏设（非 run 通路的 prompt 调用读到错误域） | current_domain 默认 ops（与现状同值=漏设无害化）；run 启动处与 set_current_tenant 同位注入（run_worker.py:117-120 先例）；T2 验收含非 run 通路调用回归 |
| R-P4-3 | 父轮询子 run 的节拍放大 DB 读（子 run 多 + 轮询 1s） | 扇出上限 4/轮 + 总数 8 上限；轮询仅 status 单列；既有子任务墙钟预算兜底，轮询不延长生命周期上限 |
| R-P4-4 | claim 已建/子 worker 未起的残余窗口（§3.5 矩阵行 3） | 孤儿补偿两段式既有机制兜终帧；父侧失败预算收口；如实登记残余窗口（不承诺本波零窗口——彻底闭合需 RunWorker DB 租约，14 §6.3 已登记后续）；**§11 启用决策以「观察窗无本项事故」为转默认判据之一** |
| R-P4-5 | 子 run 量随使用增长推高 RunEventBus _history 内存债 | 承 14 R13-N6 登记口径合并跟踪；上限 8/父 run 抑制增速；多副本化波次同批治理 |
| R-P4-6 | OA stub 与真实 OA 行为漂移致 S1 证据力折损 + **stub 语料自编激励链**（「stub 返回什么、断言写什么同一只手」可闭环自证） | **语料与断言解耦（R16）**：语料由 lead 自真实 OA 风格制度文档摘抄改写 · 实施者不拿断言表；S1 结论措辞限定机制面（R16/R25）；**真实 OA 网关冒烟=S1 完全成立的前置挂账项**（无真实网关环境则 S1 上限=机制面成立 · 如实标注）；e2e 独立进程跑（R8） |
| R-P4-7 | **oa 域 rag 子任务跨域泄漏（定性修正 · R3 · LB3）**：domain≠ops 且 per-domain env 缺省时，初稿三级回退会**静默检索 ops 语料喂进 oa 答案**——非「空跑」，是跨域数据混库（ops 语料含发布面/回滚面内部细节）；prompt 词表收紧不能充当数据隔离闸 | **fail-closed（§2.3）**：domain≠ops 且 env 缺省 ⇒ 本地 RAG 显式禁用 · rag 子任务报「本域未配置检索」· 不回落全局/ops_knowledge；S1 checklist ⑥ 禁用实证；ops 域回退链零 diff |
| R-P4-8 | 投影加字段引发旧 web 版本兼容误判（消费方按位解析） | runs 列表消费方仅本仓 ChatView 任务面板（P3 新交付，随版本齐发）；契约注明「可加字段、消费方须容忍未知键」（承 JSON 兼容惯例 · R12 加性变更豁免口径一致） |
| R-P4-9 | 总闸 on 态下行为面扩张（子 run 生命周期、面板交互）引入回归 | 三件套含 off 态 TestClient 零 diff 验收（14 §1.7 同构 · R12 精确化为帧面+行为面）；S3③ 闸 off 全量回归进验收判据 |
| R-P4-10 | 子 run HITL「退出-重跑」机制的幂等风险：重跑重复执行副作用 / nonce 一次性与重跑交互误拒（R1/R2） | 重跑幂等**结构性成立**：全部副作用闸在 capability_ainvoke 之前 · _approval_consumed 消费闸 fail-closed 一次性（nodes.py:497-533）；T7 实证「approve 后放行至 done」「重复 decide/resume 不重复执行」· nonce 交互用例；每次尝试新 token 新 nonce（§3.9） |
| R-P4-11 | **多域部署共库误配**致记忆跨域污染：落库键 tenant+user 无 domain 维，共库时 oa facts 被 ops 召回侧无过滤命中（R4 · LB4） | T1 契约钉「多域不得共库」部署约束（域=部署级天然单库单域 · 零 DDL · 文档显式声明）；共库真实需求出现 ⇒ memory 加 domain 列+召回过滤（§9 触发式后续） |

---

## 7. 任务切分（契约先行 · 双泳道 · 两线独立可交付）

**双泳道**：**领域线** T2→T3→T4→T5（证命题 A）；**Run 树线** T6→T7→T8（证命题 B）；T1 契约最先行；T9 验收收口需两线样例但**两线各自独立可交付**（任一线滑期，另一线连 T9 对应半区先行出报告）。砍单序 = **T4 → T3 → T8**（R18 · product N1：T4 无 oa 消费者可整单顺移；T3 砍则 oa 能力在 manifest 内手写 tags——N7 核实现状即手写 · S1⑤「零代码」判据不变因 tags 手写仍是文件级，domain 键消费降级登记；**T8 是 Run 树线唯一用户可见证据载体不砍**——砍 T8=Run 树线整线顺延，不做降级验收，否则「两线各自独立可交付」的产品叙事对 Run 树线不成立）。

| 单 | 仓 | 泳道 | Scope | 验收 | 依赖 |
|----|----|------|-------|------|------|
| **P4-T1** 契约文档 | workspace | 先行 | docs/contracts 新增 domain-pack-v1（域 id 词表 · assets/<domain>/ 回退约定 · manifest domain→tags 注入语义 · OPS_DOMAIN 部署级钉死+tenant 正交声明 · 「覆盖以模板为单位缺省回退」· **「多域部署不得共库」部署约束（R4）** · **domain 保留字条款**（不与 allow_tags_any/allow_write_tags_any 现存值及 "mcp" 冲突 · R6）· **domain 词表与 template id 词表各自独立禁互拼（R5）** · **MCP 条目 domain 真源=server 配置侧非远端声明（R6）** · **skills/ 目录与 goal 注入属部署级资产不进域回退（R11）**）与 run-tree-v1（三列+部分唯一 uq 契约 · OPS_RUN_TREE_ENABLED 词表 · 「帧 per-run 流 · 树只进 REST 投影 · cursor 不动 · 老客户端世界不变」钉死 · **「off 零 diff=SSE 帧面+行为面 · REST 投影新增字段为加性变更」（R12）** · run.start 可加 parent_run_id 字段 · **委派令牌身份映射表五行（R2 · §3.9）** · **子 run HITL「退出-重跑-消费闸放行」三段（R1 · §3.4）** · **配额归并父 run 预算桶（R2）** · iOS 兼容性三断言）；04-roadmap §P4 回写占位 | 契约文档齐 + HG-AUDIT-R1 签收 | 无（最先行） |
| **P4-T2** prompt 域机制 | api | 领域线 | loader.py load_asset(domain) 目录回退 + 缓存键扩展；templates.py get_template_for_domain 薄封装（白名单不动）；domain_context.py（contextvar 默认 ops · OPS_DOMAIN env 解析非法回退 ops+warning）；start_run_worker 注入位；**不建 assets/ops/** | 单测：域文件命中/回退/非法 domain 拒入；**ops 零 diff 对拍**（11 模板 body on/off env 逐字节一致）；非 run 通路调用回归 | T1 |
| **P4-T3** manifest domain 消费 | api | 领域线 | _parse_and_validate 读 domain 键（词表校验）→ 全 capability tags 并集注入；builtin 无 domain 键零 diff；缺省/非法 domain 值行为钉死；**domain 保留字拒载（=allow_tags_any 现存值或 "mcp" · R6）** | 单测：oa manifest 加载后三能力 tags 含 oa；**注入并集去重后 tags 集合 = 现状手写面逐值一致（R10）**；builtin tags 逐值不变；非法 domain 值 422 级 ManifestError；**domain=mcp 拒载/显式告警（R6）**；filter allow_tags_any={"oa"} 放行实证 | T1（与 T2 并行） |
| **P4-T4** RAG 配置面 | api | 领域线 | qdrant_collection(domain)：**ops 域三级回退零 diff**（QDRANT_COLLECTION_OPS → 全局 → ops_knowledge）· **domain≠ops 且 per-domain env 缺省 ⇒ fail-closed 禁用不回落**（R3 · rag 子任务报「本域未配置检索」）；glossary 按域文件回退+按域缓存；**source_type/ingest 不动**；**不交付 oa glossary**（无消费者） | 单测：ops 三级回退矩阵 · **fail-closed 矩阵**（domain≠ops 缺省 env → 禁用应答 · 不配回落）；glossary 域文件命中/回退；ops 默认面零 diff | T1（并行；砍单首选） |
| **P4-T5** oa 领域包资产 | api | 领域线 | assets/oa/ 下 7 份覆盖模板（supervisor/direct/aggregator/router/rewrite/intent/memory.extract——人设、type=rag 语义、路由规则、语料声明、intent 词表 oa 化、记忆 key 目录 oa 化）；4 份中立模板刻意不覆盖；**stub 语料由 lead 准备（R16 · 实施者不拿断言表）** | S1 全 checklist（含混合解析证据 · rubric 四组对照判读 R21 · RAG 禁用实证 R3 · 独立进程 R8 · **变更集只含新增文件**证明「换域零代码」） | T2+T3 |
| **P4-T6** Run 树 DDL+store | api | Run 树线 | 迁移：runs 加 parent_run_id/subtask_id/depth + uq 部分唯一 + parent 索引（可逆）；create_run 三可选参数；claim 函数（INSERT ON CONFLICT DO NOTHING → 冲突 SELECT 取回 · **须新写 ON CONFLICT 路径**，create_run 现状 check-then-insert · R9）；runs 列表投影+路由加 parent_run_id/depth 字段 | 迁移 upgrade/downgrade；claim 并发双建仅一胜（承 test_db_claim_skip_locked 体例）；投影字段契约测试；既有用例零 diff | T1 |
| **P4-T7** 委派子 run 执行 | api | Run 树线 | tool_exec 执行体提取（闸链单真源）；start_delegate_run_worker（共享 bus/_workers/单飞）；route_next_subtask 闸开分支（tool→claim+spawn+轮询 join）；OPS_RUN_TREE_ENABLED 三件套（默认 off · 非法回退 · off 零 diff）；深度 1 断言 + MAX_CHILDREN=8 上限；预算归因继承父身份显式传入 + **配额记桶键=父 run_id（R2）**；**子 run HITL 三段：waiting_approval 退出 worker · decide 后 resume 按 depth 分流重启 delegate worker 重跑 · _approval_consumed 命中放行（R1）**；**委派令牌子 run 执行时自发签发 · TTL 自尝试起算 · 父签发仅授权凭证（R2）** · nonce 重跑交互用例；**子 run 首帧 run.start 落盘 user_id=父 user_id（R7）** | S2①②⑤工程判据（uq 实证 · 并行交叠 · kill-重启重入幂等）；off 态 TestClient 零 diff（帧面+行为面 · R12）；超上限进 observe 通路实证；孤儿扫描覆盖子 run 回归；**「approve 后子 run 重跑放行至 done」·「重复 decide/重复 resume 不重复执行能力」（R1）**；**「子 run 首帧落盘 user_id → run_owner 反查成立 → decide/resume/replay 全链实证」（R7）** | T6 |
| **P4-T8** web 树形面板 | web | Run 树线 | 投影字段消费；depth=1 缩进渲染 + 父卡徽标**双态**（默认「子任务 · N」· **任一子 run waiting_approval → 变色「待审批 · N」** R17）；子卡交互（running→续看 / waiting_approval→**打开子 run 视图经既有 HitlApprovalCard 审批** / 终态→回放 drawer）；store 帧增量按 run_id keyed 扩展 | pnpm lint/test/build 绿；S2③ 子 run 独立回放截图；S3 子 run 审批全链截图（含父卡徽标变色）；父流帧序列零污染断言；**首次接触者 30 秒内找到子 run 回放/审批入口（R20）** | T6+T7（**不砍** · R18） |
| **P4-T9** 验收样例+报告 | api+web | 收口 | S1/S2/S3 执行（**S1 语料=lead 准备的摘抄语料 · 实施者不拿断言表 R16**）+ 三级裁定（闭合清单 · (c) 时限 30s R19）+ 报告**两表 + 双命题合并结论段**（R22）· **启用决策点三条款（§11 · R15）** · **附演示脚本（§13 · R24）** · 止损线观察项登记（§12 · R23）· 承 12/13/16 体例；iOS 缺位如实登记；**S1 结论限定机制面 · 不表述「oa 域可用」（R16/R25）** | §5 判据全过 + 裁定落盘 | T5+T7+T8 |

依赖图：T1 → {领域线 T2→T5（T3/T4 与 T2 并行汇入 T5）· Run 树线 T6→T7→T8} → T9。每单 ≤1 PR，过闸体例同 P1/P2a/P2b/P3（10 起草 → 20 审查 → HG-AUDIT-R1 → 30 实施）。

---

## 8. 失败路径

| 失败 | 行为 |
|------|------|
| 域 prompt 文件存在但形态非法（front-matter 缺字段/空 body/version 非法） | PromptAssetError 显式炸点名路径（loader 既有纪律 :3-6，**域路径不豁免**——缺文件才回退，坏文件不静默） |
| OPS_DOMAIN 非法值（词表外/含路径符） | 回退 ops + logger.warning（不进加载路径） |
| manifest domain 键非法形态 | ManifestError 拒载（加载期强校验先例 manifest.py:444-447） |
| manifest domain 值撞保留字（=allow_tags_any/allow_write_tags_any 现存值或 "mcp"） | 拒载/显式告警（R6 · T3 单测）——防注入 tag 意外命中 baseline.py:35 豁免面 |
| 委派 claim 撞 uq（replan/resume 重入） | SELECT 取回已有 child run_id 复用，零重复建行（S2⑤） |
| 子 run 超 MAX_CHILDREN 上限 | 该子任务按失败进 observe/critic 既有通路 + 审计日志 |
| 父轮询期间子 run 达 error/disconnected | 按失败子任务进 subtask_join → observe 既有收口（预算尽→end 等 critic 规则不动） |
| claim 建行成功但子 worker 启动异常 | logger.exception + 子 run 留 running 无进展 → 孤儿补偿既有机制兜终帧 + 父侧预算收口（残余窗口登记 R-P4-4） |
| 父进程崩于子 run 在飞 | §3.5 矩阵：恢复后 claim 重入取回子 run 续轮询 |
| **子 run 遇 hitl.required 且审批未消费（R1）** | 落 hitl.waiting 帧 + status=waiting_approval 后**退出 worker**（不占 _workers 槽 · HITL TTL 既有语义兜底） |
| **decide 后子 run 重跑至能力调用点（R1）** | _approval_consumed(run_id, subtask_id, capability_id) 命中放行（nodes.py:497-533 · fail-closed）；未命中（重复 decide/重复 resume）→ **不重复执行能力**（消费闸一次性） |
| 子 run HITL 超时（approval_expired） | 既有 409 语义；父轮询见终态 error 按失败收口（03 §0 TTL 语义不动） |
| **子 run 令牌墙钟过期（HITL 长等 >600s · R13）** | **形态消解（R2）**：令牌由子侧**每次执行尝试自发签发 · TTL 自尝试起算** · decide 后重跑即重签发——「批准后 REJECT_EXPIRED 必败」路径不存在；签发审批（delegation_issue_hitl_required）仍在父侧 dispatch 前完成，不绕审批 |
| 闸 off 部署收到含 parent_run_id 的投影（数据残留） | 纯数据字段，消费方忽略；REST 面不加过滤（投影幂等 · R12 加性变更豁免） |
| **domain≠ops 且 QDRANT_COLLECTION_<DOMAIN> 缺省（含 oa 部署 supervisor 拆出 rag 子任务 · R3）** | **fail-closed**：本地 RAG 显式禁用 · rag 子任务报「本域未配置检索」· **不回落全局/ops_knowledge**（防跨域向量泄漏 R-P4-7） |
| QDRANT_COLLECTION_<DOMAIN> 设了但集合不存在 | RAG 检索既有降级链（grader/语义路兜底）不动；env 配置属部署面，不新增校验面 |
| **多域部署共库（误配 · R4）** | 契约禁止+文档显式声明：记忆落库键无 domain 维，共库即跨域召回污染面（R-P4-11）；触发式后续=memory 加 domain 列 |
| **oa stub 语料与断言同源（激励链 · R16）** | 流程消解：语料 lead 摘抄准备 · 实施者不拿断言表；S1 结论措辞限定机制面 |

---

## 9. 非范围

- **RunWorker 全面 DB 租约 / _SCAN_TASK 多副本改造 / nonce·熔断·预算外置**（14 §6.2-6.3 登记债原样顺延，claim 只解决委派建行幂等；nonce 维持进程内 · R2/§3.1 同口径）
- rag/extract 子任务 run 化；plan-JSON 新 type / supervisor prompt 机制改动
- 多深度树（depth>1）· root_run_id 冗余列 · 运行时环检测
- **树形合并流 / 跨 run 统一 cursor / SSE 任何新帧 / 契约 freeze 任何修订**
- oa RAG ingest / source_type 词表泛化 / oa glossary 交付（无消费者）；domains.yaml 领域注册文件（任何形态）
- per-tenant domain（域=部署级钉死）；domain 进 CapabilityFilter 判序字段（tags 已够载）
- **memory 加 domain 列+召回过滤**（触发式后续：多域共库真实需求出现时 · R4/R-P4-11）；**skill 目录域化**（skills/ 与 goal 注入=部署级资产不进 assets/<domain>/ 回退 · T1 契约声明防误配 · R11）
- 聚合态计算（父卡只显示自身 status）；children 端点；iOS 全部面（登记后续候选，合并 P3 R23 跟踪）
- FC 重估；MCP/skill 面机制改动（MCP 条目 domain 真源=server 配置侧仅契约注明 · R6）

---

## 10. 红线自检

| 红线 | 自检 |
|------|------|
| 不破 lg-rag-sse-v1 freeze | ✅ 零新帧（§3.7）；run.start 仅加可选字段且老客户端无通路收到子 run 流；cursor "{run_id}:{seq}" 零改动；iOS/web 词表契约测试零修订（S3②）；**子 run HITL 全程复用既有端点/审批卡零新端点零新帧（R1）** |
| 不破 tenant freeze F1-F6 | ✅ runs 加列无新表，tenant_id 既有列满足「新 DDL 含 tenant_id」；子 run 继承父 tenant（§3.8）；域=部署级不进租户谓词（§2.5）；**RAG 跨域 fail-closed（R3）+ 多域不得共库契约约束（R4）=数据隔离面无 fail-open** |
| 阶段纪律（≤1 新外部依赖） | ✅ **零新依赖**（文件回退/env/既有 PG） |
| 独立可回退 | ✅ OPS_RUN_TREE_ENABLED 默认 off——**「off 态零 diff」精确化为 SSE 帧面+行为面零 diff（R12）· REST 投影新增字段为加性变更契约豁免**（S3③）；OPS_DOMAIN 缺省 ops + 不建 assets/ops/ = 零 diff 双保险（§2.2）；域回退顺序保证坏域文件显式炸不静默（§8） |
| 不预搭未来形态空壳 | ✅ ingest 不泛化（§2.3）· oa glossary 不交付（无消费者）· 聚合态不算 · children 端点不开 · iOS 不做 · 多深度不参数化 · memory 不加 domain 列（触发式后续 R4）——逐条「消费者在位」判据（§1.2） |
| 不复活空抽象 | ✅ 否 domain 注册表/Domain 实体（§2.1）· 否 domains.yaml（§2.3）· 载体=三件套文件级覆盖（builder.py:124-130 教训钉死 §1.1） |
| 先盘点复用再规划新建 | ✅ 复用面：tags 既有共识（types.py:160-162）/ tenant_context contextvar 先例 / OpsScheduleFire ON CONFLICT 范式（models.py:750-785）/ hitl SKIP LOCKED 测试体例 / MAX_SUBTASKS 预算闸 / orphan 两段式 / **per-run HITL 端点 + _approval_consumed 消费闸（nodes.py:497-533 · R1）** / **委派令牌 issuance 策略闸（nodes.py:677-702 · R2）** / P3 任务面板+回放 drawer + 计数徽标插槽（14 R16 · R17）/ 14 §1.7 总闸三件套 |
| importlinter 零新边 | ✅ 域机制收敛在 prompts/capability/rag 各自模块内；委派执行体提取不出 lg_rag 包（T2/T7 验证） |

---

## 11. 启用决策（T9 报告必备三条款 · R15 · PB2）

两线默认部署面均逐字节不变是正确的工程纪律，但合起来意味着 T9 验收全过后**没有任何用户会看见任何新东西**——故验收后的去向必须随设计裁定，防 P4 沦为「存在但无人开启的能力」：

1. **OPS_RUN_TREE_ENABLED 转默认判据**：S1-S3 三级裁定成立 + 观察窗（一周 dogfood 无 R-P4-4 残余窗口事故）→ 转默认 on；否则维持 opt-in 并在 T9 报告写明理由。
2. **oa 演示部署处置**：**保留 dev 演示配置**（OPS_DOMAIN=oa + stub transport）· 文档化（作为「通用化」叙事载体 · §13 脚本 A）· **不进 prod 默认面**（prod 默认面恒 ops · 零 diff 纪律不变）。
3. **web 树形面板放量路径**：随闸开放量——闸 on 部署才出现 depth=1 缩进子卡与徽标双态；off 部署面板与 P3 逐字节一致。

---

## 12. 止损线（「愿景不设排期」的可测量判据 · R23 · product 盲点1）

信号触发 → **对应线回退默认 off / 资产归档 · 登记「愿景线证伪」而非无限维护**：

- **做早了的信号**：① oa 验收通过后 **3 个月内无第二个真实域需求排队**（说明「通用化」是自我证明）；② Run 树闸开后真实使用中**子 run 回放 drawer 打开率趋零**（说明持久化子任务不是真需求，Send 并行已够用）。
- **做过了的信号**：① T5 七份覆盖模板中实际为消除 ops 残留所需**不足半数**（说明 inv-p4 A1 耦合点清单被高估，文件级覆盖机制投资过度——2~3 份就够时目录回退机制的复杂度不划算）；② S2 真实使用中 **MAX_CHILDREN=8 从未触达 2 以上**（并行扇出上限与 DB claim 机制是为不存在的规模造的）。

观察项随 T9 报告登记（§7 T9），信号判定不设自动闸，由负责人评审触发。

---

## 13. 演示脚本与叙事载体（T9 报告附件 · R24 · product 盲点2）

P4 双命题的用户叙事强度不对称——**命题 A 受众是部署者/二开者**（最终用户无感），**命题 B 受众才是最终用户**（且仅在闸开后）；没有演示脚本，验收报告是工程文档不是产品证据。T9 报告附两条脚本固化叙事：

- **脚本 A · 换域零代码（oa 演示部署 · dev）**：env 两枚（OPS_DOMAIN=oa + OPS_CAPABILITY_EXTRA_MANIFESTS 挂 oa.readonly.v1.yaml）→ 问「劳动合同续签流程」→ 呈现：① 混合解析日志（7 份模板解析自 assets/oa/ + 4 份回退根目录）；② 变更集 diff（只含新增文件）；③ rag 子任务「本域未配置检索」禁用应答（R3）。
- **脚本 B · Run 树（闸开部署）**：巡检场景「巡检三台主机的磁盘与内存并汇总报告」（R14）→ 展开任务面板 → 父卡「子任务 · 3」徽标 → 打开任一子 run 回放 drawer 呈现完整时间线（各自可独立查阅的子交付）→ S3 段加演：父卡徽标变色「待审批 · N」（R17）→ 打开子 run 视图 → 既有 HitlApprovalCard 审批 → 子 run 重跑放行至 done（R1）→ 父收口。

---

## 14. 评审确认点明判（Q1-Q7 关闭登记）

| # | 点 | 明判 |
|---|----|------|
| Q1 | 验证域 = 真实 oa 域（否构造域） | **附条件裁可**（product PB3）：条件 = stub 语料与断言解耦（R16：lead 摘抄准备 · 实施者不拿断言表）+ 结论措辞限定机制面 · oa 身份边界注明（R25）——**两条件本稿已落实（§2.4/§5 S1/R-P4-6），Q1 关闭** |
| Q2 | domain = 部署级 env（否租户级） | **裁可**（platform/product 双方无异议）：inv-p4 要点 5 + 外部系统绑定语义属部署面；per-tenant 无消费者；叙事自洽（一次部署服务一个外部系统） |
| Q3 | Run 树总闸默认 off + 提升面仅限 tool_exec | **附条件裁可**（platform LB2）：补注「令牌**格式**复用成立 · **签发主体/时序**按子 run 执行时自发签发修订（R2 · §3.9）」+ 「off 零 diff」措辞精确化（R12）——**已落实，Q3 关闭** |
| Q4 | 委派 claim 挂在 runs 行自身 uq(parent,subtask)（否新台账表） | **裁可**（platform）：「建行即认领」单真源；并发语义经 N6 复核通过（R9 · ON CONFLICT DO NOTHING 败者阻塞至胜者提交后 SELECT 取回 · subtask_id locked 序列不回退） |
| Q5 | 深度上限 1（结构性无环，否参数化/运行时检测） | **裁可**（platform/product）：S2 一层即证；多深度等产品需求驱动 |
| Q6 | 子 run HITL 走 per-run 视图审批（父不代理、零新端点新帧） | **附条件裁可**（platform LB1 + product PB4/时限约束）：端面零新增成立 · 执行体恢复分支按「退出-重跑-消费闸放行」补设计后兑现（R1 · §3.4）· 发现性配父卡徽标双态（R17）+ 感知延迟 >30s 升级复议（R19）——**条件本稿已落实，Q6 关闭** |
| Q7 | cursor 不动、树形回放=投影+逐 run 回放（否合并流/v2 cursor） | **裁可**（platform/product：合并流无消费者 · 破 cursor 成本收益倒挂 · 登记后续候选）；附注：T7 范围已按 LB1/R1 修正（HITL 三段 + 令牌签发面 R2）落实进 §7 |
