/goal
目标：完成 Hermes Orchestra full-system 的主链路切换，使 Gateway、Six-Stage evidence、artifact-family cutover 机制从当前 MVP/current runtime 主导状态，推进到默认 active runtime 可真实消费 full contract。

执行方法要求：
- 全程使用 `$tdd`
- 按 red → green → refactor 的垂直切片推进
- 每次只为当前行为写一个失败测试，再写最小实现使其通过
- 测试必须以公开行为、API、artifact、runtime side effect 为主，不允许主要验证内部实现细节

权威来源：
- /data/hermes/IMPLEMENTATION-GAP-ANALYSIS.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-PRD.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md
- /data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md
- /data/hermes/docs/FULL-COVERAGE-MATRIX.md

本 goal 负责的能力域：
- Run 与 Gateway Authority
- Six-Stage Evidence 与 Closeout
- Cutover Policy
- Degradation Policy active runtime enforcement path
- Performance SLO active runtime enforcement path
- Fixture policy 与 runtime boundary 对齐

目标结果：
- Gateway 默认消费 full contract 所需的主链路能力，不再只是局部支持或 staged readiness。
- Six-Stage 关键 artifact family 在默认路径下由 Gateway 真实写入、读取、校验、推进。
- `config/cutover/full-readiness-gates.json` 不再只是规划文件，而是与实际 runtime activation 机制对接。
- `docs/FULL-COVERAGE-MATRIX.md` 中与 Gateway / cutover / closeout / policy enforcement 相关的“pending / staged / not runtime / not active runtime / not implemented”项，按事实更新到完成状态。

强约束：
- 不允许只补文档或只补 schema。
- 不允许通过 `allow_staged=True` 作为默认运行路径。
- 不允许保留“代码支持 full contract，但默认 runtime 仍走 MVP contract”的状态。
- 不允许一次性全局切换而绕过 artifact-family cutover 规则；必须符合 SPEC 里的 staged cutover 要求。
- 必须保留历史 artifact 兼容策略，不重写历史 run。
- 不允许偏离 `$tdd`，也不允许先批量写测试再批量写实现。

必须完成的工作：
- 对齐 full schema artifact families 与当前 Gateway 实际读写路径。
- 识别当前哪些 run artifacts 仍由 MVP schema/legacy path 驱动，并改造成 full-family-aware runtime path。
- 完成 Gateway 对 closeout gates、global evaluation、system improvement proposals、idempotency retention、command reconciliation、event/task/run projection 的 full-contract 消费。
- 将 degradation policy、performance SLO policy、fixture boundary 从“可验证 policy”变成 active runtime enforcement logic。
- 保证 default Gateway runtime 在不依赖测试特判的情况下，能够走通 full-path run create → stage progression → evaluation → closeout。

验证要求：
- 运行 full contract validation
- 增加并通过 gateway end-to-end tests
- 增加并通过 full artifact family activation tests
- 增加并通过 closeout / authority-chain / idempotency / reconciliation regression tests
- 明确证明默认运行路径不再依赖 `allow_staged=True`

交付要求：
- 修改代码、配置、cutover 接线、测试、矩阵、报告
- 更新 IMPLEMENTATION-GAP-ANALYSIS.md
- 更新 FULL-COVERAGE-MATRIX.md
- 输出一份阶段完成报告，列出：
  - 本 goal 覆盖的能力域
  - 每项能力的 cutover 证据
  - 默认 runtime 生效证据
  - 剩余风险

执行方式：
- 先盘点当前 Gateway 主链路与 full contract 的错位点
- 给出按 artifact family 的实施顺序
- 直接实施并验证，直到本 goal 范围全部完成或遇到明确阻塞
