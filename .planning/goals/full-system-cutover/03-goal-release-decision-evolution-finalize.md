/goal
目标：完成 Hermes Orchestra full-system 剩余 authority / operations / self-improvement 能力的 active runtime 集成，并做最终收口，使整份实现差距报告中的“部分完成 / 未完成”项全部清零。

执行方法要求：
- 全程使用 `$tdd`
- 按 red → green → refactor 的垂直切片推进
- 每次只针对一个默认运行时行为补一个失败测试，再写最小实现
- 测试优先验证公开接口、deployment/report artifact、queue/closeout 行为与 authority boundary，不允许主要验证内部实现细节

权威来源：
- /data/hermes/IMPLEMENTATION-GAP-ANALYSIS.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-PRD.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md
- /data/hermes/docs/FULL-COVERAGE-MATRIX.md

本 goal 负责的能力域：
- Release Pipeline
- Kimi-Audited Self Evolution
- 全局文档、矩阵、验证收口

目标结果：
- Release pipeline / command registry / deployment report 从 disabled formal path 变成 active runtime release authority。
- Stage 6 candidate sweep 与 cross-run review queue 从“有 policy/有代码”变成 active runtime 默认或明确定义触发路径。
- `IMPLEMENTATION-GAP-ANALYSIS.md` 与 `FULL-COVERAGE-MATRIX.md` 的剩余未完成项全部关闭。

强约束：
- 不允许仅把 `enabled: false` 改成 `true` 就算完成；必须完成 Gateway 接线、验证、安全边界和文档闭环。
- 不允许 self evolution 自动修改 protected targets，除非规格明确允许并有相应审批机制。
- 不允许 release path 继续依赖测试特判或临时注入 command config。
- `Remote Decision Channel` 明确标记为不做：不实现 adapter、不做 active runtime cutover、不作为本 goal 的完成阻塞项；相关文档应更新为 deferred / out of scope for this execution wave。
- 不允许偏离 `$tdd`，也不允许先写完整实现后再补测试。

必须完成的工作：
- 完成 release pipeline config、release command registry、Gateway Release Executor、deployment report、gate/approval/rollback evidence 的默认运行时接线。
- 完成 self evolution 在 Stage 6 closeout 与手动 cross-run review 中的真实触发与 queue integration。
- 清理 remaining staged/disabled/not implemented 的状态项，确保本 goal 负责的相关能力在 default runtime 下生效。
- 对 `Remote Decision Channel` 的相关报告和矩阵状态进行事实重述：保留未实施/递延状态，并明确它不属于本轮交付范围。
- 全量更新文档，确保实现报告、coverage matrix、规格引用、测试结论一致。

验证要求：
- release real-path integration tests
- self evolution trigger / queue / protected target tests
- end-to-end closeout and recovery tests
- final full contract validation
- final runtime regression suite

最终完成判定：
- IMPLEMENTATION-GAP-ANALYSIS.md 中表格与正文不再存在“部分完成 / 未完成”的目标项
- FULL-COVERAGE-MATRIX.md 中与本 goal 负责范围相关的条目不再是 disabled / pending / not implemented / not active runtime
- 默认 active runtime 可以完成 release / self evolution 相关流程
- Remote Decision Channel 被明确记录为本轮不做，且不会被错误宣称为已完成
- 所有变更有自动化验证支撑

最终交付：
- 所有必要代码修改
- 所有必要配置切换
- 所有必要测试补充与通过结果
- 更新后的 IMPLEMENTATION-GAP-ANALYSIS.md
- 更新后的 FULL-COVERAGE-MATRIX.md
- 一份 final closure report，逐项列出：
  - 能力域
  - 规格来源
  - 改动文件
  - 验证方式
  - 默认 runtime 生效证据
  - 剩余风险（如有）

执行方式：
- 先盘点 release / self evolution 的剩余差距，以及 remote decision 的递延边界
- 再按 release → self evolution → final docs & matrix 的顺序完成
- 不停留在计划阶段，直接实施直到全部完成或出现明确阻塞
