# Hermes Orchestra Full-System Cutover Goals

这组 `/goal` prompt 用于把 `IMPLEMENTATION-GAP-ANALYSIS.md` 中仍然“部分完成 / 未完成”的 full-system 能力，分三阶段推进到：

1. `Full Target` 完成
2. `Active Runtime` 完成

统一执行约束：

- 每个 goal 都必须使用 `$tdd` 进行开发实施，按 red-green-refactor 的垂直切片推进。
- 所有测试必须优先验证公开行为，不允许以实现细节为主要断言目标。
- `Remote Decision Channel` 当前标记为不做，不纳入这 3 个 goal 的实施范围，也不作为完成阻塞项。

权威来源：

- `/data/hermes/IMPLEMENTATION-GAP-ANALYSIS.md`
- `/data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-PRD.md`
- `/data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md`
- `/data/hermes/.planning/specs/HERMES-ORCHESTRA-FULL-SCHEMAS.md`
- `/data/hermes/docs/FULL-COVERAGE-MATRIX.md`

执行顺序：

1. `01-goal-gateway-cutover.md`
2. `02-goal-debate-worker-knowledge.md`
3. `03-goal-release-decision-evolution-finalize.md`

拆分原则：

- Goal 1 先打通主链路与 cutover 机制，否则后续 full-path 能力无法真正进入 active runtime。
- Goal 2 处理运行期最核心的子系统：debate / worker / runtime knowledge。
- Goal 3 收尾可选但必须完成的 authority/operations 路径：release / self-evolution，并完成矩阵、报告、验证闭环；`remote decision` 明确排除。

完成标准：

- 不接受仅存在 schema/config/staged target 的“表面完成”。
- 不接受仅在 `allow_staged=True`、测试特判、临时启用配置时通过。
- 必须让默认 active runtime 使用对应能力。
- 必须同步更新文档与验证矩阵。
- 必须使用 `$tdd`，不接受“先写一批实现，再补测试”的做法。
