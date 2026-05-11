# Phase 22: External CLI Engine Protocol & Role Invocation - Research

**Researched:** 2026-05-11  
**Domain:** Hermes profile assembly + external CLI engine contract  
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Engine Configuration Ownership
- **D-22-01:** Project overrides may override all `engine` fields: `cli`, `mode`, `flags`, and `fallback`. Base profile definitions only provide defaults.
- **D-22-02:** Canonical engine defaults live directly in each role's checked-in `config.yaml`; there will be no centralized engine matrix file.
- **D-22-03:** `orch-profile-sync` must merge `engine` with field-level deep-merge semantics. A project override may replace only one field such as `flags` without redefining the full object.
- **D-22-04:** `fallback` is opt-in only. It is active only when the profile explicitly declares it.

### Protocol Surface for v1
- **D-22-05:** Phase 22 only has to fully close the protocol loop for `pm`, `implementer`, and `reviewer`. Other workflow roles must align to the same protocol model later, but they are not required to be fully landed in this phase.
- **D-22-06:** The repository must contain a common protocol envelope plus role-specific schema/example contracts for `pm`, `implementer`, and `reviewer`.
- **D-22-07:** `next_action` uses one small shared cross-role enum. Role-specific meaning belongs in role payloads, not in custom `next_action` values.
- **D-22-08:** `status` is role-specific. Each role defines its own `status` enum, while the docs keep a cross-role comparison table for orchestrator and adapter authors.
- **D-22-09:** `correlation_id` is a tracing field only. It does not carry session resume semantics or authority semantics.

### Canonical Context State
- **D-22-10:** Canonical per-task context retained in Kanban metadata is limited to the minimum runtime set: `conversation_history`, `handoff_from_parent`, `task_summary` / `current_stage`, `last_engine_error`, and `rollback_count`.
- **D-22-11:** `conversation_history` must be stored as structured turn data, not as a raw transcript blob. Each turn keeps `role`, `content`, `turn`, and decision tags.
- **D-22-12:** Task comments are for human audit summaries only. They are not a recovery truth source and may not be used as a fallback for missing metadata state.
- **D-22-13:** `handoff_from_parent` may contain structured summaries plus references/paths to richer artifacts, but may not inline large raw upstream outputs as canonical state.
- **D-22-14:** When history grows, compaction must use a two-layer form: summarized earlier context plus the most recent N raw turns. Phase 22 must not use silent oldest-first truncation.

### Failure and Fallback Normalization
- **D-22-15:** The default recovery ladder is fixed: retry once, then block. Fallback execution is only considered when the profile explicitly declares `fallback`.
- **D-22-16:** Any fallback activation must be recorded as an explicit audit event in task metadata/comments, including original engine, trigger reason, and fallback engine.
- **D-22-17:** `JSON parse-error` and protocol/schema mismatch are hard-stop failures. They must `kanban_block` immediately and may not auto-fallback.
- **D-22-18:** Timeout handling uses one shared recovery model across roles, but default timeout thresholds may differ by role.
- **D-22-19:** A successful fallback only applies to that single invocation. The next invocation still starts with the primary engine unless the checked-in profile config changes later.

### the agent's Discretion
- Research and planning may choose the exact file layout for the protocol artifacts (for example, Markdown contracts plus JSON examples, or Markdown plus machine-readable fixtures), as long as the repo clearly ships one common envelope contract and separate role contracts for `pm`, `implementer`, and `reviewer`.
- Research and planning may decide the exact metadata key names for audit/fallback events and summary compaction bookkeeping, as long as they preserve the locked semantics above.
- Research and planning may propose exact default timeout values per role and the exact "recent N turns" compaction threshold, because the user locked the shape of the policy but not the numeric defaults.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENG-01 | 每个 workflow profile 都可以独立声明 Hermes 路由层 `model` 与外部 CLI `engine`（`cli/mode/flags/fallback`），并允许项目级 override 在不污染全局 profile 的前提下切换底层执行引擎。 | 现有 per-role `config.yaml`、repo-local `.hermes/profiles/*.override.yaml`、`.hermes/projects/{project_slug}/` 组装路径和 `orch-profile-sync` 已经存在；Phase 22 只需要把 `engine` 扩展到同一条合并链路里，而不是发明第二套配置编译器。 [VERIFIED: docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml] [VERIFIED: docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml] [VERIFIED: docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml] [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: .hermes/profiles/README.md] |
| ENG-02 | Hermes Profile 与外部 CLI 引擎之间统一使用 `hermes-role-engine/v1` JSON request/response envelope；CLI timeout、crash、parse-error 和 rate-limit 都按可审计的 retry → block 策略处理。 | `hermes-role-engine/v1`、角色 status/next_action、无状态上下文恢复和 retry/block 语义已在 Phase 19 设计源中定义，但仓库里还没有 machine-readable contract；Phase 22 应补齐协议文档、示例 fixtures 和失败归一化测试。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] [VERIFIED: .planning/phases/19-hermes-workflow-design/REQUIREMENTS.md] [VERIFIED: .planning/phases/19-hermes-workflow-design/DESIGN.md] |
</phase_requirements>

## Summary

Phase 22 应扩展 Phase 21 已落成的 profile 装配链，而不是替换它。当前 canonical base profile 已经按角色存放在 `docs/orchestra/hermes/profile-distribution/profiles/*/config.yaml`，项目 override 已经固定在 `{repo}/.hermes/profiles/`，运行时输出已经固定在 `{repo}/.hermes/projects/{project_slug}/`，并且 `orch-profile-sync` 负责把 base config + override 编译到项目级 Hermes home。当前实现只会解析和写回 `status`、`model`、`toolsets.enabled/disabled`，所以 `engine` 深合并的正确落点就是这一个脚本。 [VERIFIED: docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml] [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: docs/orchestra/README.md]

协议面现在只存在于设计文档，还没有可执行产物。Phase 19 已经把 `hermes-role-engine/v1` 的 request/response 轮廓、`pm`/`implementer`/`reviewer` 的角色语义、以及无状态恢复依赖 Kanban metadata 的基线写清楚；但 `docs/orchestra/hermes/` 下还没有公共 envelope、角色 contract 或 JSON fixtures。Phase 22 最合适的交付是一个很小的 contract package：一份公共 envelope 说明、三个角色 contract、以及一组可被 shell+Python smoke tests 验证的 golden fixtures。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md] [VERIFIED: docs/orchestra/hermes]

迁移边界必须保持清楚。当前 `orch-bus-loop` 和 `docs/orchestra/README.md` 仍然以 tmux + Runtime bus `.md` envelopes 驱动 `codex exec` 与 `claude -p`，并且已经内嵌了 JSON unwrap、`correlation_id` 一致性检查、L3 block 审计和 reviewer 回路；这些实现是 Phase 22 的迁移参考，不是新的真相源。新的 canonical 状态应落在 Hermes Kanban run metadata / handoff 上，因为官方 Kanban 把 handoff metadata 和 attempt history 都建模为 `task_runs` 上的结构化数据，而不是 comments 或 session。 [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop] [VERIFIED: docs/orchestra/README.md] [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban]

**Primary recommendation:** 把本 phase 规划成“扩 `orch-profile-sync` + 新增 `role-engine-protocol/v1` 合约包 + fixture 驱动的失败归一化测试”，不要在同一 phase 顺手重写 dispatcher、hook guardrails 或完整 Kanban 路由。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `engine` 默认值与项目 override 合并 | API / Backend | Database / Storage | 这是 repo 内配置编译职责，由 `orch-profile-sync` 生成项目级 Hermes home，不是客户端或数据库自行决定。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] |
| `hermes-role-engine/v1` 请求/响应 contract | API / Backend | — | 协议由 role adapter 负责发起和解析，Hermes Profile 是 authority，外部 CLI 只是执行端。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] |
| 上下文累积与 handoff 真相源 | Database / Storage | API / Backend | 官方 Kanban 将 summary/metadata 和 run history 存在 `task_runs`，下游任务从 parent handoff 读取，不应退回 comments/session。 [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban] [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md] |
| timeout / crash / rate-limit / parse-error 归一化 | API / Backend | Database / Storage | 归一化策略属于 adapter/dispatcher 逻辑，但审计结果和 fallback 事件必须落到 task metadata/comments。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md] |

## Project Constraints (from AGENTS.md)

- 回答和研究文档必须使用简体中文。 [VERIFIED: AGENTS.md]
- 对 Hermes Agent 相关问题必须先走 `reference/hermes-docs-index/` 检索，再取官方文档内容，不能只靠预训练知识。 [VERIFIED: AGENTS.md] [VERIFIED: reference/hermes-docs-index/SKILL.md]
- 优先 retrieval-led reasoning；不确定时先查证，再下结论。 [VERIFIED: AGENTS.md]
- 计划应偏向最小实现、外科式修改、每一步都有验证闭环。 [VERIFIED: AGENTS.md]
- 通用搜索优先用 Codex 原生 web search；原生搜索不足时才降级到 Agent Reach，且先执行 `agent-reach doctor`。 [VERIFIED: AGENTS.md] [VERIFIED: agent-reach doctor]

## Standard Stack

### Core

| Library / Runtime | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `bash` | `5.2.21` | 承载 `orch-*` 入口脚本、smoke tests 与现有 adapter glue。 [VERIFIED: bash --version] | 现有 `docs/orchestra/scripts/bin/*` 和 `Makefile` 全部以 shell 为入口。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: Makefile] |
| `python3` | `3.12.3` | 负责 `orch-profile-sync` 的配置编译、JSON unwrap、测试中的结构化断言。 [VERIFIED: python3 --version] | 仓库已经把配置编译和 smoke assertions 放在 Python 内联脚本里。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: docs/orchestra/scripts/tests/test-profile-packaging.sh] |
| `Hermes Agent` | `v0.13.0` | 提供 profile、kanban、dispatcher、hooks 的宿主能力。 [VERIFIED: hermes --version] | Phase 22 只应站在 Hermes 官方 substrate 上实现增量 contract。 [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/profiles] [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban] |
| `Claude Code CLI` | `2.1.133` | 第一批支持的 `pm` / `reviewer` 外部 CLI 引擎。 [VERIFIED: claude --version] | 当前设计文档与 legacy adapter 都已把 `claude -p --output-format json` 作为 PM / review 参考调用面。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop] |
| `Codex CLI` | `0.130.0` | 第一批支持的 `implementer` 外部 CLI 引擎。 [VERIFIED: codex --version] | 当前设计文档与 legacy adapter 都已把 `codex exec --full-auto --json` 作为 implementer 参考调用面。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop] |

### Supporting

| Library / Runtime | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `tmux` | `3.4` | 仅用于 legacy watcher / bus-loop 参考路径。 [VERIFIED: tmux -V] | 在 Phase 22 中保留为迁移参照，不作为新协议真相源。 [VERIFIED: docs/orchestra/README.md] |
| `bubblewrap` | `0.9.0` | Codex Linux sandbox 依赖。 [VERIFIED: bwrap --version] | 需要解释为什么 headless Codex 在某些环境下会因为 user namespace 而失败。 [VERIFIED: docs/orchestra/poc-headless-gsd-execution.md] |
| `jq` | `1.7` | 可选 CLI JSON 辅助工具。 [VERIFIED: jq --version] | 当前 `docs/orchestra/scripts/` 主路径没有对它的直接依赖；只有在新增调试脚本时才值得用。 [VERIFIED: rg -n "jq" docs/orchestra/scripts] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 继续发明第二套 profile compiler | 扩展现有 `orch-profile-sync` | Phase 21 已经把 base/override/runtime 路径和测试固定下来；另起编译器只会复制同样的路径与 merge 规则。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: docs/orchestra/scripts/tests/test-profile-packaging.sh] |
| 只写 Markdown 协议说明 | Markdown + golden JSON fixtures | 仅文档不足以证明 shared enum、role status 和 failure taxonomy 真能被校验；fixtures 更适配当前 shell+Python smoke 测试风格。 [VERIFIED: docs/orchestra/scripts/tests/run-all.sh] |
| 在 Phase 22 顺手切掉 bus-loop | 先把 bus-loop 降级为 migration reference | 现有 README、smoke fixtures 和 v1.1/v1.2 运行路径仍依赖 legacy 叙事；过早删除会把协议 phase 扩大成运行时替换 phase。 [VERIFIED: docs/orchestra/README.md] [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop] |

**Installation:**
```bash
command -v bash python3 hermes claude codex
```

**Version verification:** 当前 phase 的推荐栈是现有系统 runtime，不是新增 npm package，因此以本机命令版本为准。 [VERIFIED: bash --version] [VERIFIED: python3 --version] [VERIFIED: hermes --version] [VERIFIED: claude --version] [VERIFIED: codex --version]

## Architecture Patterns

### System Architecture Diagram

```text
checked-in role config.yaml + SOUL.md
        +
repo-local .hermes/profiles/{role}.override.yaml
        |
        v
  orch-profile-sync
  - merge model/toolsets/engine
  - emit project-scoped Hermes home
        |
        v
.hermes/projects/{project_slug}/profiles/{role}/config.yaml
        |
        v
role adapter builds hermes-role-engine/v1 request
        |
        v
claude -p / codex exec
        |
        v
normalized hermes-role-engine/v1 response
        |
        +--> retry / fallback / block policy
        |
        v
kanban run summary + metadata + audit comment
```

### Recommended Project Structure

```text
docs/orchestra/hermes/
├── profile-distribution/          # checked-in role defaults
└── role-engine-protocol/
    └── v1/
        ├── common-envelope.md     # shared fields + next_action enum
        ├── roles/
        │   ├── pm.md
        │   ├── implementer.md
        │   └── reviewer.md
        └── examples/
            ├── pm.request.json
            ├── pm.response.question.json
            ├── implementer.request.json
            ├── implementer.response.complete.json
            ├── reviewer.request.json
            └── reviewer.response.findings.json

docs/orchestra/scripts/
├── bin/orch-profile-sync          # extend existing merge path
└── tests/
    ├── test-profile-packaging.sh  # extend for engine deep-merge
    └── test-role-engine-protocol.sh
```

### Pattern 1: Extend The Existing Profile Compiler
**What:** 直接在 `orch-profile-sync` 现有 Python merge path 上增加 `engine` 解析、deep-merge 和写回，不要创建第二套 runtime assembly。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync]  
**When to use:** 所有 `pm` / `implementer` / `reviewer` 的 engine 默认值和项目 override 都走同一条链路。  
**Example:**
```yaml
# Source: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md
status: active
model: codex
engine:
  cli: codex
  mode: exec
  flags: --full-auto --json
  fallback: claude
toolsets:
  enabled: [terminal, file, code_execution, memory, kanban]
  disabled: [delegation, messaging, browser]
```

### Pattern 2: Contract-First, Fixture-Driven Protocol Package
**What:** 用一个 shared envelope contract + 三个角色 contract + golden JSON fixtures，先把协议表面固定住，再让后续 phase 消费。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md]  
**When to use:** 需要落地 ENG-02，但又不想在本 phase 实现完整 dispatcher/routing。  
**Example:**
```json
// Source: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm",
  "task_type": "clarification",
  "correlation_id": "pm-call-alpha-t42-1",
  "turn": 1,
  "task_id": "t_42",
  "task_body": "用户反馈每次重启浏览器都要重新登录",
  "conversation_history": [],
  "handoff_from_parent": null
}
```

### Pattern 3: Metadata Truth In Runs, Comments For Audit Only
**What:** Canonical context state 留在 Kanban run `summary` / `metadata`，comments 只保留给人读的审计摘要。 [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]  
**When to use:** PM 多轮澄清、implementer block/resume、fallback audit、review handoff。  
**Example:**
```json
{
  "conversation_history": {
    "summary": "earlier turns compacted",
    "recent_turns": [
      {"turn": 11, "role": "pm", "content": "请确认登录态目标", "decision_tags": ["clarify"]},
      {"turn": 12, "role": "user", "content": "7天免登录", "decision_tags": ["approved"]}
    ]
  },
  "handoff_from_parent": {
    "summary": "reviewer requested CSRF check",
    "artifact_refs": ["docs/security/csrf-notes.md"]
  },
  "current_stage": "clarification",
  "last_engine_error": null,
  "rollback_count": 0
}
```

### Anti-Patterns to Avoid
- **新建 centralized engine matrix 文件：** 用户已经锁定 engine 默认值属于各角色 `config.yaml`，集中矩阵只会和 per-role config 双写。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
- **把 comments 当恢复真相源：** 官方 Kanban 已经为 run summary/metadata 和 attempt history 提供结构化承载面，comments 只适合审计摘要。 [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
- **让 parse-error / schema mismatch 自动 fallback：** 用户已锁定这两类为 hard-stop；如果继续 fallback，会把协议 drift 隐藏起来。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
- **把 tmux/file-bus 继续写成 Phase 22 主路径：** Phase 19 一致性清单明确这些只能作为历史迁移背景出现。 [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| profile runtime assembly | 第二套 profile compiler | 扩展 `orch-profile-sync` | 路径、SOUL 组装顺序、project slug 派生、已有 smoke tests 都已经围绕它固定下来。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: docs/orchestra/scripts/tests/test-profile-packaging.sh] |
| role engine contract | 分散在 prompt 文案里的隐式字段约定 | 一个 shared envelope + role fixtures | 后续 Phase 23/24/25 要消费同一协议；fixture 比 prose 更抗漂移。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] |
| failure taxonomy | 按厂商输出各写一套分支 | 先归一化成 `timeout` / `crash` / `rate_limit` / `parse_error` / `schema_mismatch` | `orch-bus-loop` 已经证明 vendor wrapper 格式不同；不先归一化，planner 会在 Phase 23/24 反复返工。 [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop] |
| session continuity | CLI `--resume` / raw transcript blob | Kanban run metadata + structured `conversation_history` | Phase 19 和 Phase 22 都已锁定 metadata-based recovery。 [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md] |

**Key insight:** 这个 phase 的难点不是“怎么再包一层 CLI”，而是“怎么把已有 profile compiler、Kanban handoff 和 legacy adapter 命令面收束成一个可测 contract”。扩面比重写更重要。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop]

## Common Pitfalls

### Pitfall 1: Flat Parser Meets Nested `engine`
**What goes wrong:** 计划里只写“给 config 加 `engine`”，实现时才发现 `orch-profile-sync` 不是通用 YAML parser，只认少数字段。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync]  
**Why it happens:** 当前 `parse_config()` 只读取 `model`、`status`、`enabled`、`disabled`，`write_config()` 也只会输出这几个字段。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync]  
**How to avoid:** 把“扩展 parser + writer + smoke tests”作为 Phase 22 的显式子任务，而不是隐藏在协议任务下面。  
**Warning signs:** `engine` 写进 base config 后，生成的 `.hermes/projects/{project_slug}/profiles/*/config.yaml` 里完全没有 `engine`。

### Pitfall 2: Override Contract Drift
**What goes wrong:** 代码支持 `engine` override，但 `.hermes/profiles/README.md`、README 示例和 smoke tests 仍只写 `model` / `toolsets`，导致后续 phase 继续按旧 contract 写文件。 [VERIFIED: .hermes/profiles/README.md] [VERIFIED: docs/orchestra/README.md]  
**Why it happens:** Phase 21 文档和测试是围绕旧 surface 收口的。 [VERIFIED: .planning/phases/21-profiles-overrides-board-isolation/21-VERIFICATION.md]  
**How to avoid:** 把 override README、README 片段和 `test-profile-packaging.sh` 一起更新。  
**Warning signs:** PR 只改脚本，不改任何 docs/tests。

### Pitfall 3: Legacy Bus-Loop Semantics Leak Into New Contract
**What goes wrong:** Phase 22 把 `task.md` / `codex-question.md` / `claude-decision.md` 的字段直接当成 `hermes-role-engine/v1` 正式 schema，结果把 v1.1 legacy envelope 和 v1.3 protocol 混在一起。 [VERIFIED: docs/orchestra/README.md] [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop]  
**Why it happens:** legacy adapter 已经有现成 JSON unwrap、decision/review loop，看起来像“差一点就能复用”。  
**How to avoid:** 明确把 bus-loop 定位成 invocation reference，只复用命令行 flags、wrapper unwrap 和 block 审计思路，不复用它的文件总线路径和 envelope 名字。  
**Warning signs:** 新协议目录里出现 `codex-question.md` 或 `review-result.md` 这类 legacy 文件名。

### Pitfall 4: Fallback Masks Protocol Bugs
**What goes wrong:** parse-error 或 schema mismatch 被 fallback 吞掉，问题表面上“恢复成功”，但 protocol drift 被带进后续 phase。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]  
**Why it happens:** 旧 adapter 已经有 retry / pending approval / continue 逻辑，容易把所有错误都往“再试一次”归并。 [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop]  
**How to avoid:** 在测试里单独列出 hard-stop matrix，要求 parse/schema 两类直接 block。  
**Warning signs:** failure table 里只有 `retryable=true/false`，没有明确 `hard_stop` 列。

### Pitfall 5: Codex Sandbox Assumptions Cause False Debugging Work
**What goes wrong:** 计划默认 `codex exec` 在任何 Ubuntu 主机都能无头执行，结果实现阶段把环境问题误判成协议问题。 [VERIFIED: docs/orchestra/poc-headless-gsd-execution.md]  
**Why it happens:** 当前环境已装 `bwrap`，但 POC 明确记录过 Codex 在 bubblewrap user namespace 上失败过。 [VERIFIED: bwrap --version] [VERIFIED: docs/orchestra/poc-headless-gsd-execution.md]  
**How to avoid:** Phase 22 的验证优先做 fixture contract 和 merge semantics；不要把“真实无头执行稳定性”当成本 phase 通过条件。  
**Warning signs:** 计划把 `codex exec` 真实跑通当作 ENG-02 唯一验收点。

## Code Examples

Verified patterns and recommended contract shapes:

### 项目级 `engine` 局部 override
```yaml
# .hermes/profiles/implementer.override.yaml
engine:
  flags: "--full-auto --json --skip-git-repo-check"
```

这样可以保持 `cli/mode/fallback` 继承 base，只替换单字段，符合 D-22-03。 [VERIFIED: docs/orchestra/scripts/tests/test-profile-packaging.sh] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]

### `kanban_complete(summary, metadata)` 作为 handoff 真相源
```python
# Source: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban
kanban_complete(
    summary="implemented token bucket, keys on user_id with IP fallback, all tests pass",
    metadata={"changed_files": ["limiter.py", "tests/test_limiter.py"], "tests_run": 14},
)
```

### Plugin hooks 注册方式
```python
# Source: https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks
def register(ctx):
    ctx.register_hook("pre_tool_call", my_tool_observer)
    ctx.register_hook("post_tool_call", my_tool_logger)
    ctx.register_hook("on_session_end", my_cleanup_callback)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| tmux + Runtime bus 文件 (`task.md`, `codex-question.md`, `review-result.md`) 作为角色调用主路径 | Hermes 调度 + stateless external CLI execution + `hermes-role-engine/v1` contract | 2026-05-11 Phase 19 设计更新 / commit `3976c42`。 [VERIFIED: .planning/PROJECT.md] | Phase 22 应先落协议，不应再把新行为绑回旧 watcher/file-bus。 |
| CLI session / comments 容易被当作恢复上下文 | run summary + metadata + structured `conversation_history` 才是恢复真相源 | 2026-05-11 在 Phase 19 一致性清单和 Phase 22 context 中锁定。 [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md] | 计划必须单独列 metadata shape 和 compaction 任务。 |
| role `model` 和执行引擎概念容易混成一个字段 | `model` 只属于 Hermes 路由层，`engine` 只属于外部 CLI 调用层 | Phase 19 R31-R32 + Phase 22 D-22-01 至 D-22-04。 [VERIFIED: .planning/phases/19-hermes-workflow-design/REQUIREMENTS.md] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md] | Phase 22 tests 必须同时验证 `model` 保持可 override，且 `engine` 独立 deep-merge。 |

**Deprecated/outdated:**
- 把 `orch-bus-loop` / watcher 描述成 v1.3 canonical routing path：已经过时，只能作为迁移参考。 [VERIFIED: docs/orchestra/README.md] [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md]
- 依赖 `--resume` 或 session authority：已经被 metadata-based recovery 替代。 [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | All material claims in this research were verified from repo evidence, runtime probes, or official docs. | — | — |

## Open Questions

1. **`engine.fallback` 的最终 shape 需不需要从标量升级成对象？**
   - What we know: 设计文档示例把 `fallback` 写成 `claude` / `null`，而 Phase 22 锁定的可 override 字段只有 `cli/mode/flags/fallback`，没有再展开 fallback 子结构。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
   - What's unclear: 如果未来 fallback 也需要自己的 `mode/flags`，Phase 22 当前 schema 会不够。
   - Recommendation: 本 phase 保持 `fallback` 为标量或 `null`，把“fallback 是否升级为完整 engine object”显式留给后续 phase，避免把 parser 和 tests 扩成递归 merge 问题。

2. **role-specific timeout 常量是否在 Phase 22 锁数值？**
   - What we know: 用户锁定了“共享恢复模型 + role-specific defaults”，但没有锁具体数值。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
   - What's unclear: repo 当前没有可执行 timeout config surface，只有设计文档中的策略叙述。 [VERIFIED: .planning/phases/19-hermes-workflow-design/REQUIREMENTS.md]
   - Recommendation: 计划里要有一个小任务专门确定并记录首批默认值，但不要让它阻塞 protocol artifacts 和 merge semantics 主线。

3. **`conversation_history` compaction 的 “recent N” 是否现在就固化？**
   - What we know: 用户要求两层结构，禁止 silent truncation。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
   - What's unclear: 当前没有真实 task volume 数据来证明合适阈值。
   - Recommendation: 先在 contract 中固定 compaction shape 和字段名，把 N 作为常量位于 role engine adapter 层，允许后续验证阶段微调。

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `bash` | `orch-*` scripts, smoke tests | ✓ | `5.2.21` [VERIFIED: bash --version] | — |
| `python3` | `orch-profile-sync`, JSON/fixture validation | ✓ | `3.12.3` [VERIFIED: python3 --version] | — |
| `hermes` | profile / kanban substrate | ✓ | `v0.13.0` [VERIFIED: hermes --version] | 无替代；这是宿主。 |
| `claude` | `pm` / `reviewer` engine baseline | ✓ | `2.1.133` [VERIFIED: claude --version] | 若单机缺失，只能降级为 contract-only tests；本 phase 不应强制真实调用。 |
| `codex` | `implementer` engine baseline | ✓ | `0.130.0` [VERIFIED: codex --version] | 同上。 |
| `tmux` | legacy bus-loop reference path | ✓ | `3.4` [VERIFIED: tmux -V] | 仅 legacy 参考；Phase 22 主验收不依赖它。 |
| `bwrap` | Codex sandbox runtime | ✓ | `0.9.0` [VERIFIED: bwrap --version] | 无；环境异常时退回 contract-only validation。 |
| `rtk` | repo test runner conventions | ✓ | `0.37.2` [VERIFIED: rtk --version] | 可直接 `bash` 运行脚本。 |

**Missing dependencies with no fallback:**
- None for contract research and fixture validation. [VERIFIED: command probes]

**Missing dependencies with fallback:**
- None detected. [VERIFIED: command probes]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `bash` smoke tests + `python3` inline assertions。 [VERIFIED: docs/orchestra/scripts/tests/run-all.sh] |
| Config file | `none`；由 `Makefile` 和 `docs/orchestra/scripts/tests/run-all.sh` 发现并执行。 [VERIFIED: Makefile] [VERIFIED: docs/orchestra/scripts/tests/run-all.sh] |
| Quick run command | `bash docs/orchestra/scripts/tests/test-profile-packaging.sh` |
| Full suite command | `make test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENG-01 | base profile `engine` defaults + project override deep-merge 到 `.hermes/projects/{project_slug}/profiles/*/config.yaml` | smoke | `bash docs/orchestra/scripts/tests/test-profile-packaging.sh` | ✅ existing; needs extension for `engine`. [VERIFIED: docs/orchestra/scripts/tests/test-profile-packaging.sh] |
| ENG-01 | 两个项目对同一 role 使用不同 `engine` override 时，生成结果不串线 | smoke | `bash docs/orchestra/scripts/tests/test-project-isolation.sh` | ✅ existing; needs engine assertions. [VERIFIED: docs/orchestra/scripts/tests/test-project-isolation.sh] |
| ENG-02 | `pm` / `implementer` / `reviewer` fixtures 都满足 shared envelope、shared `next_action` enum、role-specific `status` enum | fixture validation | `bash docs/orchestra/scripts/tests/test-role-engine-protocol.sh` | ❌ Wave 0 |
| ENG-02 | `timeout` / `crash` / `rate_limit` 触发 retry→block；`parse_error` / `schema_mismatch` 直接 block，且 fallback 仅在声明时可用 | table-driven unit | `bash docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bash docs/orchestra/scripts/tests/test-profile-packaging.sh`
- **Per wave merge:** `bash docs/orchestra/scripts/tests/test-profile-packaging.sh && bash docs/orchestra/scripts/tests/test-role-engine-protocol.sh`
- **Phase gate:** `make test`，同时补跑本 phase 新增的协议测试脚本。

### Wave 0 Gaps

- [ ] `docs/orchestra/scripts/tests/test-role-engine-protocol.sh` — 校验 common envelope、shared `next_action`、role status fixtures，覆盖 ENG-02。
- [ ] `docs/orchestra/scripts/tests/test-role-engine-failure-policy.sh` — 校验 retry/block/fallback normalization，覆盖 ENG-02。
- [ ] 扩展 `docs/orchestra/scripts/tests/test-profile-packaging.sh` — 增加 `engine` deep-merge 断言，覆盖 ENG-01。
- [ ] 扩展 `docs/orchestra/scripts/tests/test-project-isolation.sh` — 增加跨项目 `engine` override 不串线断言，覆盖 ENG-01。

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | 本 phase 不处理登录态或身份验证。 [VERIFIED: .planning/ROADMAP.md] |
| V3 Session Management | no | 本 phase 明确避免把 CLI session 当 authority；只定义 stateless role-engine contract。 [VERIFIED: .planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md] |
| V4 Access Control | yes | 通过 profile `toolsets`、readonly reviewer 边界和 role-specific engine contract 控制能力面。 [VERIFIED: docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml] [CITED: https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference] |
| V5 Input Validation | yes | request/response envelope、role status、failure taxonomy 和 metadata keys 都要做 fixture validation。 [VERIFIED: docs/orchestra/scripts/tests/run-all.sh] |
| V6 Cryptography | no | 本 phase 不实现加密算法或密钥管理。 [VERIFIED: .planning/ROADMAP.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 父任务 handoff 内联大段原始输出，污染下游 prompt | Tampering | 只允许 structured summary + artifact refs；禁止 raw dump 成为 canonical metadata。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md] |
| reviewer / pm engine override 偷开写能力或越权工具 | Elevation of Privilege | Phase 21 的 toolset allowlist 保持主防线；Phase 22 只新增 engine，不改变 reviewer readonly toolset 基线。 [VERIFIED: docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml] |
| parse-error / schema mismatch 被 fallback 掩盖 | Repudiation | 明确 hard-stop，记录 block 和 fallback 审计字段。 [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md] |
| 跨项目 engine override 串线到别的 Hermes home | Information Disclosure | 继续使用 `.hermes/projects/{project_slug}/` 输出树和单一 `project_slug` 派生规则。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: docs/orchestra/scripts/tests/test-project-isolation.sh] |

## Sources

### Primary (HIGH confidence)
- `https://hermes-agent.nousresearch.com/docs/user-guide/profiles` — verified official profile model, separate Hermes home, per-profile `config.yaml` / `SOUL.md`. [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/profiles]
- `https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban` — verified run metadata, handoff model, `kanban_complete(summary, metadata)`, `task_runs` semantics. [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban]
- `https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks` — verified plugin hook registration and hook names. [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks]
- `https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference` — verified toolsets are configured via `config.yaml`. [CITED: https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference]
- `https://hermes-agent.nousresearch.com/docs/user-guide/profile-distributions` — verified distribution model keeps config/skills in git while leaving local memories/sessions/API keys untouched. [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/profile-distributions]
- `docs/orchestra/scripts/bin/orch-profile-sync` — current merge/compiler surface. [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync]
- `docs/orchestra/hermes/profile-distribution/` — current role config ownership surface. [VERIFIED: docs/orchestra/hermes/profile-distribution/distribution.yaml]
- `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` — current protocol design source. [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md]
- `.planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md` — locked scope and decisions. [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]

### Secondary (MEDIUM confidence)
- `docs/orchestra/scripts/bin/orch-bus-loop` — migration reference for existing `claude -p` / `codex exec` invocation and audit normalization. [VERIFIED: docs/orchestra/scripts/bin/orch-bus-loop]
- `docs/orchestra/README.md` — current user-facing runtime behavior and remaining legacy wording. [VERIFIED: docs/orchestra/README.md]
- `docs/orchestra/poc-headless-gsd-execution.md` — observed headless CLI behavior and Codex sandbox landmines. [VERIFIED: docs/orchestra/poc-headless-gsd-execution.md]
- `docs/orchestra/scripts/tests/test-profile-packaging.sh` and `test-project-isolation.sh` — current verification surface to extend. [VERIFIED: docs/orchestra/scripts/tests/test-profile-packaging.sh] [VERIFIED: docs/orchestra/scripts/tests/test-project-isolation.sh]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - 直接来自本机 runtime probes、repo scripts 和官方 Hermes 文档。 [VERIFIED: command probes] [CITED: https://hermes-agent.nousresearch.com/docs/user-guide/profiles]
- Architecture: MEDIUM - repo 现状与 Phase 19/22 设计约束一致，但 Phase 22 的具体协议目录与 failure fixtures 仍需实现。 [VERIFIED: .planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md] [VERIFIED: .planning/phases/22-external-cli-engine-protocol-role-invocation/22-CONTEXT.md]
- Pitfalls: HIGH - 大多来自已存在脚本、docs drift 和 POC 失败记录，不是推测。 [VERIFIED: docs/orchestra/scripts/bin/orch-profile-sync] [VERIFIED: docs/orchestra/poc-headless-gsd-execution.md]

**Research date:** 2026-05-11  
**Valid until:** 2026-06-10
