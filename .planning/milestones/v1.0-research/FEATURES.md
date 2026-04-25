# Feature Landscape: Hermes Dev Orchestra

**Domain:** Single-developer AI development orchestration specification package  
**Researched:** 2026-04-25  
**Confidence:** HIGH for v1 scope from project materials; MEDIUM for external ecosystem alignment because implementation details must be revalidated against installed CLI versions  

## Scope Anchor

v1 is a **specification package**, not a runnable orchestrator. Requirements should define product behavior, command contracts, file-bus schemas, agent responsibilities, escalation policy, acceptance scenarios, and implementation roadmap.

The core workflow is: a developer connects through SSH/Hermes CLI, appends tasks at any time, Hermes routes tasks to the right project, Claude supervises technical decisions/review, Codex executes implementation, and Hermes interrupts the user only for high-risk or product-level decisions. Remote decision support must remain an abstract channel, not a Telegram-specific feature.

## Table Stakes for v1 Spec Package

These are required for the spec to be useful for requirements generation. Missing items make the package incomplete.

| Feature / Spec Section | Requirement to Define | Why Expected | Complexity | Acceptance Check |
|---|---|---|---|---|
| Product scope and non-goals | Define persona, target environment, primary workflow, explicit out-of-scope list | Prevents drift from “spec package” into implementation or team platform | Low | Reader can state who v1 serves, what it does not build, and why |
| SSH/Hermes CLI entry contract | Define required user entry points, command names, arguments, outputs, idempotency, and error cases | SSH is the required primary channel | Medium | Spec includes command contracts for init/start/stop/status/task append/decision reply |
| Append-anytime task intake | Define how a user appends one or many tasks while projects are already running | This is the priority workflow | High | Spec covers append, route, queue, reject, pause, resume, and duplicate handling |
| Project registry and isolation | Define project id, workspace path, tmux naming, task prefixing, per-project state, and cleanup rules | Multi-project orchestration fails without hard isolation | Medium | Two projects can be reasoned about without shared files, sessions, or ambiguous messages |
| Three-agent role boundaries | Define Hermes, Claude Supervisor, Codex Executor, and Escalation Handler authority limits | Prevents agents from approving decisions outside their role | Medium | Every file/action has one owner and “must not do” rules |
| Per-project file-bus protocol | Define files, schema envelope, required fields, status enums, writers/readers, atomic writes, stale-file handling, and archive rules | The file bus is the durable coordination contract | High | A future implementer can build parsers from the spec without guessing |
| Task state machine | Define canonical states and transitions from project init through completion/failure/cancel/recovery | Required for supervision, restart, and blocked-project yielding | High | Invalid transitions and recovery paths are explicitly listed |
| Claude decision and review protocol | Define question intake, technical decision format, review result format, escalation trigger fields, and approval meanings | Claude is the technical supervisor, not another executor | Medium | A Codex question can produce either an actionable decision or escalation |
| Codex execution/result protocol | Define task input expectations, pause rules, result format, tests field, dependency reporting, and partial/failure states | Codex must be controllable and auditable when executing work | Medium | Result files always include status, modified files, tests, dependencies, issues |
| Risk escalation policy | Define risk levels, examples, default actions, timeout behavior, blocking rules, and user authority | L3/L4 must never be auto-approved | High | Each risk level has owner, notification style, timeout policy, and audit behavior |
| Remote Decision Channel abstraction | Define transport-neutral operations: notice, decision request, reply, healthcheck, acknowledgement | Keeps Telegram/Discord/mobile support future-proof | Medium | Spec can support SSH-only v1 and later adapters without changing core protocol |
| Audit and evidence model | Define audit log contents, correlation ids, user-decision records, task archive bundle, and backup expectations | Agentic systems need post-hoc accountability | Medium | A completed or rejected task has an inspectable trace |
| Installation and environment assumptions | Define no-sudo Ubuntu setup, required tools, auth prerequisites, directory layout, and version assumptions | User’s target environment is constrained | Medium | A future installer can be written from the spec |
| Health, recovery, and troubleshooting | Define SSH disconnect behavior, tmux survival, process loss, `/tmp` cleanup, stale bus files, and CLI auth failures | Long-running orchestration needs failure semantics | Medium | Spec includes expected recovery action for each common failure |
| Verification scenarios | Define acceptance fixtures for happy path, Codex question, Claude escalation, L3 block, append-while-running, multi-project block/yield, restart recovery | v1 must be testable despite being spec-only | Medium | Requirements can be validated by scenario walkthroughs without implementation |
| Roadmap handoff | Define implementation phases ordered by protocol dependencies | Allows spec to become build plan | Low | Roadmap starts with contracts before automation and adapters |

## Differentiators to Preserve

These are not generic “AI coding assistant” features; they make Hermes Dev Orchestra distinctive and should survive scope trimming.

| Differentiator | Value Proposition | Complexity | Preserve By |
|---|---|---|---|
| Manager / Supervisor / Executor split | Separates orchestration, technical judgment, and code execution instead of giving one agent all authority | Medium | Keep authority matrix and “must not do” rules in the spec |
| File bus as source of truth | Makes orchestration inspectable, restartable, debuggable, and tool-neutral | High | Specify schemas and state transitions before prompt wording |
| Append-anytime multi-project scheduling | Matches the real use case: one developer constantly adds tasks across projects | High | Prioritize task append, blocked-project yielding, and project-prefixed notifications |
| Human interruption only for meaningful risk | Reduces user interruptions while preserving control over destructive/product/security decisions | High | Define L0-L4/L1-L4 policy with explicit blocking for L3/L4 |
| Remote Decision Channel abstraction | Enables phone/remote decisions later without binding the core product to Telegram | Medium | Specify an interface and leave adapters out of v1 core |
| SSH-first operator workflow | Fits the developer’s actual environment better than a web dashboard | Medium | Treat CLI/Hermes chat as baseline and remote as optional extension |
| Spec-first deliverable with acceptance fixtures | Converts an existing proposal into a buildable contract rather than another vague concept doc | Medium | Include examples, schemas, command contracts, and scenario walkthroughs |
| No-sudo local development assumption | Keeps the system usable on constrained Ubuntu machines | Medium | Use `$HOME`, `~/.hermes-orchestra/`, `~/.hermes/`, and `/tmp/hermes-orchestra/` in specs |

## Anti-Features / Explicitly Out of Scope

These should be called out to prevent v1 scope creep.

| Anti-Feature | Why Avoid in v1 | What to Do Instead |
|---|---|---|
| Implementing the runnable orchestrator | User chose a specification package first | Produce contracts, examples, acceptance criteria, and roadmap |
| Telegram as required transport | User explicitly rejected binding the design to Telegram | Define Remote Decision Channel and list Telegram as a future adapter example |
| `gbrain` integration | User explicitly excluded it for this milestone | Keep Hermes Dev Orchestra standalone |
| Team collaboration platform | v1 user is one developer, not a team/org | Keep project state local and single-operator |
| Web dashboard / mobile app | Distracts from SSH-first workflow and protocol design | Use CLI flows and abstract remote messages |
| High-throughput AI factory | Adds queueing, tenancy, quotas, and fleet orchestration too early | Support “single developer, multiple projects” only |
| Automatic L3/L4 approval | Violates safety requirement and auditability | Block until explicit user decision |
| Dangerous sandbox bypass flags | Creates unacceptable local-machine risk | Specify forbidden modes and safe defaults |
| Production database operations | Sandbox and local git checkpoints do not protect external systems | Treat as L4/manual-only and outside normal automation |
| Concrete remote adapter implementation | Turns protocol work into integration work | Define adapter contract and health semantics only |
| MCP/GitHub/PR automation | Useful later, not necessary for append-supervise-execute core | Put into roadmap extensions |
| Claude Agent Teams or multi-agent swarms inside a project | Experimental/complex compared with the current Claude+Codex split | Preserve one supervisor and one executor per project in v1 |
| Model optimization/cost routing | Secondary to protocol correctness | Allow config placeholders; defer policy details |
| Persistent learning/memory productization | Risks privacy and increases data-model complexity | Specify minimal project state and audit records only |

## Feature Dependencies

```text
Scope + glossary
  → Role authority matrix
  → Project identity and directory layout
  → File-bus schemas
  → Task state machine
  → CLI command contracts
  → Agent prompt/skill contracts
  → Scheduling and recovery rules
  → Risk escalation policy
  → Remote Decision Channel interface
  → Verification scenarios
  → Implementation roadmap
```

Detailed dependency notes:

- **Scope before commands:** commands cannot be specified until v1 states that SSH/Hermes CLI is the primary interface and remote channels are optional.
- **Roles before file bus:** file ownership depends on whether Hermes, Claude, or Codex is allowed to write each artifact.
- **Project identity before scheduling:** tmux names, bus paths, task prefixes, audit entries, and remote messages need the same sanitized project id.
- **File bus before state machine:** state transitions must be triggered by canonical files, not raw terminal output.
- **State machine before recovery:** restart, stale-file handling, and blocked-project yielding need explicit state semantics.
- **Escalation before remote channel:** remote prompts need risk level, choices, timeout policy, and correlation id from the escalation spec.
- **Acceptance scenarios last:** scenario fixtures should validate the final command, file, role, risk, and recovery contracts together.

## MVP Recommendation

Prioritize these v1 spec sections:

1. **Scope, glossary, and authority boundaries** — locks the project to single-developer, SSH-first, spec-only goals.
2. **File-bus protocol and state machine** — creates the buildable core contract.
3. **CLI command contract and append-anytime workflow** — captures the highest-value user interaction.
4. **Risk escalation and Remote Decision Channel interface** — preserves safety and future remote support.
5. **Verification scenarios and roadmap** — makes the spec actionable for implementation phases.

Defer:

- **Concrete remote adapters:** only specify the interface in v1.
- **MCP/GitHub/PR integrations:** useful after the core orchestration loop exists.
- **UI/dashboard work:** not aligned with SSH-first operation.
- **Advanced multi-agent swarms:** unnecessary for the current Claude Supervisor + Codex Executor model.

## Requirement Quality Rules

Generated requirements should be:

- **Specific:** name the exact command, file, field, state, role, or risk level.
- **Testable:** include an acceptance check or scenario for every major feature.
- **Authority-aware:** state who may decide, who may write, and who must stop.
- **Protocol-first:** prefer schemas and state transitions over prose-only behavior.
- **Scope-safe:** mark all implementation, adapter, and platform work as roadmap items unless required for the spec package.

## Sources

- Internal project context: `.planning/PROJECT.md` — HIGH confidence for scope and user choices.
- Internal proposal: `docs/hermes-dev-orchestra/README.md` — HIGH confidence for existing feature proposal.
- Internal role contracts: `docs/hermes-dev-orchestra/hermes/SOUL.md`, `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md`, `docs/hermes-dev-orchestra/skills/claude-supervisor/SKILL.md`, `docs/hermes-dev-orchestra/skills/codex-executor/SKILL.md`, `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` — HIGH confidence for intended workflow.
- Anthropic Claude Code docs on hooks and subagents: `https://docs.anthropic.com/en/docs/claude-code/hooks`, `https://docs.anthropic.com/en/docs/claude-code/sub-agents` — MEDIUM confidence for ecosystem alignment.
- OpenAI Codex CLI docs on CLI, non-interactive execution, and sandboxing: `https://developers.openai.com/codex/cli`, `https://developers.openai.com/codex/noninteractive`, `https://developers.openai.com/codex/concepts/sandboxing` — MEDIUM confidence for implementation assumptions.
- LangGraph docs on durable agent workflows and interrupts: `https://docs.langchain.com/oss/python/langgraph/overview`, `https://docs.langchain.com/oss/python/langgraph/interrupts` — MEDIUM confidence for human-in-the-loop orchestration patterns.
- GitHub Copilot coding agent task-assignment docs: `https://docs.github.com/en/copilot/concepts/about-assigning-tasks-to-copilot` — MEDIUM confidence for background coding-agent task workflow comparison.

## Research Notes

- Context7 lookup for LangGraph failed with a fetch error; official LangGraph docs were used as fallback.
- External sources support the importance of human-in-the-loop decisions, sandbox/permission boundaries, durable workflow state, and background task assignment, but v1 feature boundaries are primarily driven by the user’s explicit scope choices.
