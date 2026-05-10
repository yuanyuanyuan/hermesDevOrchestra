## 附录 C：全流程时间线 `[设计假设]`

```
09:30  Jacky 提交模糊需求 → t_alpha_001 (triage)
       "登录体验太差了，每次都要重新登录"

09:31  Orchestrator 被派发

09:31  自动技术发现（从 CLAUDE.md 出发，按需深入）
       读 CLAUDE.md → 项目入口
       读 Cargo.toml → 框架/依赖
       读 src/ → 代码结构
       按需: src/routes/users.rs, src/middleware/mod.rs
       输出: 技术发现报告（8 项证据）

09:33  Q1: 核心目标？→ "7天免登录"
09:34  Q2: 用户群体？→ "外部付费客户"
09:35  Q3: 时间压力？→ "1-2周"
09:36  Q4: 登录方式？→ "邮箱+密码"
09:37  Q5: 处理方式？→ "替换session"
09:38  Q6: 过期交互？→ "静默刷新"
09:39  Q7: 验收方式？→ "自动化+手动"
09:40  Q8: 影响范围？→ "仅登录接口"
09:41  Q9: 可观测性？→ "基础日志"
09:42  Q10: MVP范围？→ "完整认证流程"
09:43  Q11: 实现方式？→ "第三方库"

09:44  可行性检查（贯穿全程，Q10后发现1个冲突：范围vs时间）
09:45  冲突沟通 → Jacky选择缩小范围
09:46  生成标准化需求文档（含证据索引+可行性确认）
09:46  DoR 验证: 7项全部通过
09:46  Jacky 确认需求文档 v1
09:46  质量反馈: Jacky 评分 5/5，无遗漏

09:47  Orchestrator 读取需求文档，拆解为 6 个子任务（含需求追溯）
09:48  T1 (JWT 核心) → ready，Implementer 被派发
       T1 执行中...
10:30  T1 完成 → T2, T4 同时变为 ready
       Implementer 跑 T2 (HTTP 接口)
       Tech-Reviewer 跑 T4 (代码审查)
       并行执行中...
11:00  Implementer 遇到架构决策 (token 旋转) → block T2
11:01  Jacky 收到通知，选择方案 B (token 旋转)
11:02  T2 恢复，Implementer 继续执行
11:51  T2 完成 → T3 变为 ready
       T4 完成 → T5 变为 ready
11:52  Implementer 跑 T3 (测试)
12:47  T3 完成
12:48  Implementer 跑 T5 (修复审查问题)
13:23  T5 完成 → T6 变为 ready
13:24  DevOps-Engineer 跑 T6 (部署)
13:26  DevOps 发现 staging 环境缺失 → block T6
13:31  Jacky 选择本地验证方案
13:32  DevOps 恢复，本地 docker 验证通过
13:36  DevOps 发现生产环境不可达 → block T6
13:46  Jacky 审核完成，归档主任务

总耗时: ~4.25 小时 (Jacky 实际投入: ~15 分钟)
```

> **需求澄清阶段（09:30-09:46）** 耗时约 16 分钟：
> - 技术发现（自动）: ~2 分钟，从 CLAUDE.md 出发按需读取
> - 一次一问澄清: ~10 分钟，11 个问题（每个 ~50 秒）
> - 可行性检查+冲突沟通: ~2 分钟
> - 文档生成（自动）: ~1 分钟
>
> 一次一问的好处：老板不会被一堆问题淹没，每次只需要做一个决定。
> 需求逐步收缩：从"什么都可能"到"无歧义可执行"。

> 📎 **相关 ASCII 流程图**：
> - [`ascii-end-to-end.md`](./ascii-end-to-end.md) — 端到端完整示例（Phase 1-6）
> - [`ascii-overview.md`](./ascii-overview.md) — 流程全景图（总览）

---
