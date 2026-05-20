/sprint
编号：12
目标来源：`/data/hermes/.planning/goals/full-system-cutover/01-goal-gateway-cutover.md`

## Sprint 12: Gateway Runtime Activation Substrate

目标：
- 为 `goal-gateway-cutover` 范围内的 artifact family 建立显式 runtime activation substrate。
- 让 Gateway 默认运行路径不再依赖调用方传入 `allow_staged=True`，而是根据 cutover evidence 决定哪些 family 默认启用 full-path 模块。
- 保持 mixed-family cutover：只激活 `gateway_authority` 与 `closeout_and_self_evolution`，不波及 `debate/worker/knowledge/release/remote_decisions` 的后续 goal。

范围内 family：
- `gateway_authority`
- `closeout_and_self_evolution`

范围内模块：
- `full-schema-validation`
- `full-schema-cutover`
- `degradation-policy`
- `performance-slo`
- `fixture-policy`
- `self-evolution`

非目标：
- 不把 `config/debate/full/*`、`config/workers/full/*`、`config/knowledge/runtime-kb.json`、`config/release/*`、`config/decisions/remote-channel.json` 改成默认 active。
- 不把 Gateway run-level artifact 全量切到 `orchestra.full.v1`。
- 不实现 release / remote decision / runtime knowledge 的默认 runtime cutover。

执行切片：
1. 新增 runtime activation manifest 与 loader。
   verify: manifest 中 activated family 的 evidence 与 checks 能通过 cutover 规则校验。
2. Gateway module dispatch 默认读取 activation manifest。
   verify: 已激活 family 对应模块在不传 `allow_staged` 时可用；未激活 family 仍返回阻塞错误。
3. 增加 focused integration test 与 validator check。
   verify: `scripts/tests/test-runtime-activation.sh` 通过；`scripts/bin/orch-full-contract-validate` 报告 activation pass。
4. 更新 checklist / matrix / gap analysis。
   verify: 文档仅声明“activation substrate 已落地”，不宣称 full runtime 全量 cutover 完成。
