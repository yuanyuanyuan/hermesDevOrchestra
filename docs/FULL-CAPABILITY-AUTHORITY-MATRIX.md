# Hermes Orchestra Full Capability Authority Matrix

This matrix is the full-target actor capability map. It answers who may request, decide, approve, execute, or advance each major workflow capability.

Legend:

- `request`: may ask Gateway to perform the operation through the product API or local client.
- `decide`: may choose among Gateway-presented options below the listed authority gate.
- `approve`: may satisfy an approval gate.
- `execute`: may perform the side effect.
- `validate/enforce`: must check policy, state, and evidence before advancement.
- `output only`: may produce evidence or a request, but cannot mutate authority state.
- `no`: must not perform the capability.

Kimi and Human are decision actors. Gateway is the state and execution authority boundary. Workers and backends produce evidence or perform scoped work only after Gateway dispatch.

| Capability | Kimi | Human | Gateway | Worker / Backend | Notes |
|---|---|---|---|---|---|
| Create Run | request | request via local client or Kimi | validate/enforce, execute | no | Gateway creates one Active Run per project. |
| Inspect Run status | request/read | request/read | execute projection read | no | Events are projection, not authority. |
| Subscribe to Run events | request/read | request/read | execute projection stream | no | Gaps require resync from status/tasks/artifacts. |
| Stop Run | request | request | validate/enforce, execute Partial Closeout | graceful stop only when asked | Stop preserves lineage and unresolved decisions. |
| Resume blocked Run | decide below human gates | approve when required | validate/enforce, execute | no | Terminal runs continue through a new run with lineage. |
| Fail Run terminally | request with evidence | approve when required | validate/enforce, execute | no | Failure Boundary must be crossed. |
| Mutate raw Kanban | no | no through product API | execute internally through workflow rules | no | Kimi sees Task Projection, not raw Kanban CRUD. |
| Advance Kanban task | no direct mutation | no direct mutation | validate/enforce, execute | output only | Worker completion is a request to Gateway. |
| Emit workflow event | no | no | execute after authority persistence | no | Events must be post-commit projection. |
| Repair Event Projection | request resync | request resync | validate/enforce, execute rebuild | no | Only projection corruption is repairable without blocking the run. |
| Command reconciliation repair | decide below human gates | approve when required | validate/enforce, execute chosen repair | no | Authority Chain Divergence blocks blind replay. |
| Approve L1/L2 stage advancement | decide | approve/override | validate/enforce | no | Requires schema-valid evidence. |
| Approve L3/L4 risk | no | approve | validate/enforce | no | Human Approval is mandatory. |
| Approve destructive or publishing work | no | approve | validate/enforce | no | Includes production deploy, secrets, permissions, CI/CD, and policy changes. |
| Approve root rule changes | no | approve | validate/enforce | output only after approval | System proposals do not self-apply. |
| Create Structured Ticket / PRD | request/provide | request/provide | validate schema | no | Short intent is intake only. |
| Start implementation | decide below human gates | approve when required | validate/enforce, dispatch | execute scoped task | Requires approved plan and evidence gates. |
| Dynamic Debate Assembly | request debate / review output | request/review | validate/enforce deterministic policy | debate backend output only | Selection is policy-driven, not free-form model choice. |
| Produce Debate Member Opinion | possible backend with self-review risk | no | dispatch/record | output only | Kimi-as-backend needs independent non-Kimi evidence. |
| Advance from Debate Report | decide below human gates | approve when required | validate/enforce | no | Debate Report is input, not final authority. |
| Select Worker Backend | request pairing | request/approve when required | validate/enforce capability negotiation | no | No silent backend substitution. |
| Worker fallback | decide if explicit low-risk fallback applies | approve when required | validate/enforce registry policy | execute only if dispatched | Forbidden for parallel, release, security, rule-change, and authority-impacting work. |
| Direct project fallback | decide only for allowed low-risk single-worker cases | approve when required | validate/enforce | execute only if dispatched | Task workspace remains the default. |
| Tmux session cleanup | review blocked evidence | manual intervention if escalated | execute via Gateway Worker Session Sweeper | graceful stop attempt only | Cleanup failure blocks the worker task. |
| Parallel worker execution | decide plan below human gates | approve when required | validate/enforce plan and dispatch | execute isolated child tasks | Requires write scopes, locks, and merge order. |
| Conflict scan | review report | approve repair if required | execute mechanical and authority-boundary scan | output refs only | Semantic compatibility is not claimed. |
| Serial integration merge | decide conflict repair below human gates | approve when required | execute controlled merge and gates | repair when dispatched | Tests and review gates validate behavior. |
| Release dev/test command | request | request | execute through Gateway Release Executor | no | Command ref must resolve through registry. |
| Release staging command | request after evidence | approve required | execute after approval | no | Raw stdout/stderr stay behind artifact refs. |
| Release production command | no approval authority | approve required | execute after Human Approval | no | Production approval is always Human Approval. |
| Rollback or recovery command | request | approve required for protected targets | execute registered command | no | Rollback success requires its own deployment report. |
| Remote decision delivery | request decision | respond/approve | validate/enforce response before advancement | transport only | Remote channel does not mutate state. |
| Runtime knowledge query | request/review | request/review | dispatch adapter and record artifacts | use results as context | Retrieval is not final authority. |
| Promote runtime knowledge | audit candidate | approve if authority-impacting | record promotion evidence | output only | Candidate or expired knowledge is warning context. |
| System Improvement Proposal | audit/accept/reject | approve protected changes | record proposal and approved changes | propose/output only | Stage 6 sweep always writes candidate proposal artifact. |
| Cross-Run Evolution Review | trigger | request/approve protected outcomes | collect and record evidence | output only | Not an automatic background process. |
| Full contract validation | request/review | request/review | run harness or record results | no | Independent from runtime advancement path. |
| Full contract readiness cutover | recommend/audit | approve | validate/enforce artifact-family activation | no | No one-shot MVP-to-full schema switch. |
| Run completion | final acceptance below human gates | approve when required | execute Closeout Completion Gate | no | Requires closeout artifacts, Audit, Kanban, Gateway State, and schema-valid evidence. |
