# Multi-Agent Plan Review 指令模板

请显式创建 3 个 sub agents（multi-agent 显式调用），分别基于当前 Codex 可用且适合任务的 skills，完成对目标文档的审查。

目标文档：
`{PLAN_PATH}`

## 总体要求

1. 必须显式创建 3 个 sub agents。
2. 每个 agent 必须只读审查，不要修改文件。
3. 所有结论必须有交付证据，不能只给主观判断。
4. 证据优先：引用文件路径、行号、命令输出摘要。
5. 如果证据不足，明确标记为“证据不足”，不要包装成 finding。
6. 最终需要汇总三方结论，并区分：
   - 可直接采纳的结论
   - 需要降级的推断
   - 需要补证据的问题

## Sub Agent 1：Feasibility / Execution Reviewer

使用适合的 feasibility / plan review skill。

任务：
从可行性、执行难度、潜在风险角度 review `{PLAN_PATH}`。

必须检查：

1. plan 是否符合当前 repo 现实状态。
2. 是否有 dirty/staged worktree 风险。
3. 目录迁移、路径替换、submodule、Makefile、测试、lint 是否可执行。
4. 是否缺少回滚策略、提交边界、迁移顺序、数据/证据保留策略。
5. 是否引用不存在的文件、命令或测试。

输出要求：

- `Reviewer: feasibility-reviewer`
- `Evidence collected`
- `Findings`：按严重程度排序
- 每条 finding 包含：
  - severity
  - confidence
  - evidence
  - why it matters
  - suggested fix
- `Residual risks / missing evidence`
- `Bottom line`

## Sub Agent 2：Adversarial Document Reviewer

使用适合的 adversarial / document review skill。

任务：
对 `{PLAN_PATH}` 做对抗性审查，重点挑战前提、假设、路径依赖和未来放大风险。

必须覆盖三类反事实：

1. 如果不做这个 plan，会怎样？
2. 如果照这个 plan 做，会怎样？
3. 如果未来工作量、项目数、agent 数或消息量扩大到 10 倍，会怎样？

重点挑战：

- 问题定义是否正确。
- 是否在解决真实问题。
- 是否引入高反转成本决策。
- 是否过早抽象。
- 是否制造多源事实或规格漂移。
- 安全/审批/风险规则是否有证据闭环。

输出要求：

- `Reviewer: adversarial-document-reviewer`
- `Depth calibration`
- `Findings`
- 每条 finding 包含：
  - severity
  - confidence
  - evidence
  - counterfactual
  - consequence
  - falsification test
  - suggested plan change
- `Do nothing / Do it / 10x stress` 对比表
- `Residual risks / missing evidence`
- `Bottom line`

## Sub Agent 3：Evidence / Anti-Hallucination Auditor

独立审计前两个 agents 的交付质量。

任务：
确保前两个 agents 没有出现迷惑、欺诈、幻觉、行号错误、证据不足或严重性夸大。

必须做：

1. 读取 `{PLAN_PATH}` 并核对行号。
2. 读取前两个 agents 引用到的所有本地文件。
3. 运行必要的只读命令验证证据。
4. 逐条审计前两个 agents 的 findings。

每条 finding 审计字段：

- evidence_valid：证据是否真实存在且行号正确
- reasoning_valid：推理是否能从证据推出
- severity_valid：严重程度是否合理
- missing_evidence：还缺什么证据
- verdict：PASS / PARTIAL / FAIL

输出要求：

- `Reviewer: evidence-auditor`
- `Evidence commands/files checked`
- `Audit table`
- `Unsupported or overstated claims`
- `Verified findings worth carrying forward`
- `Evidence quality score`：0-100
- `Bottom line`

## 最终汇总要求

在三个 agents 都完成后，主线程输出最终结论：

1. 三个 agents 是否都已显式创建并完成。
2. 哪些 findings 可直接采纳。
3. 哪些结论只是合理推断，需要降级。
4. 哪些地方需要补证据。
5. 对目标 plan 的最终判断：
   - 可以直接执行
   - 需要修订后执行
   - 不建议执行
6. 给出最小修订集。

使用时把 `{PLAN_PATH}` 换成目标 plan 文件路径即可。
