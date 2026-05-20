/goal
目标：完成 Hermes Orchestra full-system 运行期核心子系统的 active runtime cutover，使 Debate Engine、Worker Execution、Runtime Domain Knowledge Base 同时达到：

1. Full Target 完成
2. Active Runtime 完成

执行方法要求：
- 全程使用 `$tdd`
- 按 red → green → refactor 的垂直切片推进
- 每次只为当前默认运行时行为写一个失败测试，再写最小实现使其通过
- 测试应覆盖公开行为、Gateway 集成路径、artifact 输出、authority boundary 和 degraded behavior，不以内部实现细节为主

权威来源：
- /data/hermes/IMPLEMENTATION-GAP-ANALYSIS.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-PRD.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md
- /data/hermes/docs/FULL-COVERAGE-MATRIX.md

本 goal 负责的能力域：
- Full Debate Package
- Worker Execution
- Runtime Domain Knowledge Base

目标结果：
- `config/debate/full/*` 不再只是 staged full package，而是 active runtime authority。
- `config/workers/full/*` 与 capability negotiation / worker session / parallel integration 不再只是 staged target，而是默认 worker runtime path。
- `config/knowledge/runtime-kb.json` 与 gbrain runtime integration 不再默认 disabled，而是受 Gateway 真实消费。

强约束：
- 不允许只保留 full config 在仓库里，但默认 runtime 仍走 legacy debate/runtime worker path。
- 不允许 release、security、parallel、authority-impacting worker 流程继续绕开 full capability negotiation。
- 不允许 runtime knowledge 只在测试中临时启用；必须进入默认 active runtime，并遵守 freshness / provenance / degradation / audit 边界。
- 不允许模板 debate、fake backend、fixture backend 被误当成强证据。
- 不允许偏离 `$tdd`，也不允许先写完整实现后再补测试。

必须完成的工作：
- 完成 Debate team/mode/coverage/assembly/backend policy 到默认 runtime 的接线。
- 完成 debate report / debate audit trail / member invocation / degraded evidence 处理的默认运行流集成。
- 完成 Worker backend registry / role registry / capability negotiation / session lifecycle / worker output gate / parallel group plan / conflict handling 的默认运行流集成。
- 完成 Runtime Knowledge 的 entry / ingestion / query / result / freshness / provenance / degradation / gbrain integration 默认运行流接入。
- 让 Gateway 在真实 run 过程中消费这些 full-path 组件，而不是测试专用激活。

验证要求：
- full contract validation
- debate end-to-end runtime tests
- worker end-to-end runtime tests
- runtime knowledge real-path tests
- parallel integration / conflict / worker session lifecycle tests
- authority-boundary and degraded-evidence tests
- regression tests to prove default runtime no longer falls back to legacy-only path

完成判定：
- FULL-COVERAGE-MATRIX 中 debate / worker / runtime knowledge 相关条目不再是 staged / disabled / not active runtime / not implemented
- IMPLEMENTATION-GAP-ANALYSIS 中这三类能力域不再是“部分完成 / 未完成”
- 默认 Gateway runtime 对这三类能力不依赖 `allow_staged=True`
- 文档、配置、代码、测试结论一致

交付要求：
- 所有必要代码与配置切换
- 所有必要测试补充与通过结果
- 更新 IMPLEMENTATION-GAP-ANALYSIS.md
- 更新 FULL-COVERAGE-MATRIX.md
- 输出一份阶段完成报告，逐项说明：
  - Debate cutover 证据
  - Worker cutover 证据
  - Runtime Knowledge cutover 证据
  - 剩余风险

执行方式：
- 先盘点这三类子系统当前 default path 与 staged path 的差异
- 按 debate → worker → runtime knowledge 或依赖顺序实施
- 每完成一类子系统，就同步补测试、跑验证、更新矩阵和报告
