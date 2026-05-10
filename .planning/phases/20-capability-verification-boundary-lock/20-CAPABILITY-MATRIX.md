# Phase 20 Capability Verification Matrix

**Captured:** 2026-05-10  
**Runtime anchor:** `Hermes Agent v0.13.0 (2026.5.7)`  
**Method:** matrix-first audit; locally runnable rows use exact commands, exit codes, and key output. Rows that cannot be closed safely in the current environment are labeled `hybrid` or `doc-only` explicitly.

## Verdict Legend

- `verified` — official capability or official boundary claim is supported by Phase 20 evidence.
- `unsupported` — the phase 19 official claim could not be proven usable in the current environment to the Phase 20 standard.
- `local-extension` — the phase 19 workflow behavior depends on local orchestration semantics beyond the official capability that was actually proven.

## Matrix

### KANBAN-BOARD-TASK-LIFECYCLE
- claim_id: `KANBAN-BOARD-TASK-LIFECYCLE`
- capability_area: `Kanban`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A; `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` AE1
- official_source:
  - `hermes kanban --help`
  - `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
  - `https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `yes`
- evidence class: runtime
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban init
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban boards create phase20-matrix --name "Phase 20 Matrix" --switch
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban create "Parent task" --body "parent body" --assignee default --json
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban create "Child task" --body "child body" --assignee default --json
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban link t_5c05e93a t_be5a8617
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban comment t_be5a8617 "comment from phase20"
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban show t_be5a8617
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban complete t_5c05e93a --result "parent complete"
```
- exit code: `0`
- key_output:
  - `Board 'phase20-matrix' created.`
  - `Switched to 'phase20-matrix'.`
  - `Linked t_5c05e93a -> t_be5a8617`
  - `parents:   t_5c05e93a`
  - `Completed t_5c05e93a`
- verdict: verified
- writeback_target: `DESIGN.md` Appendix A Kanban row remains official; no requirement reclassification needed.
- backlog_ref: `none`
- notes: board creation, task creation, parent dependency, comments, `show`, and `complete` all closed locally inside a temp `HERMES_HOME`.

### KANBAN-BLOCK-UNBLOCK
- claim_id: `KANBAN-BLOCK-UNBLOCK`
- capability_area: `Kanban`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` R1/R2 evidence model; workflow narratives that rely on `kanban_block` / `kanban_unblock`
- official_source:
  - `hermes kanban block --help`
  - `hermes kanban unblock --help`
  - `https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `yes`
- evidence class: runtime
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban create "Blockable task" --body "standalone" --assignee default --json
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban block t_9af85159 "need user input"
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban show t_9af85159
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban unblock t_9af85159
HERMES_HOME=/tmp/hermes-phase20-home hermes kanban show t_9af85159 --json
```
- exit code: `0`
- key_output:
  - `Blocked t_9af85159: need user input`
  - `status:    blocked`
  - `Unblocked t_9af85159`
  - JSON `status`: `ready`
- verdict: verified
- writeback_target: no downgrade; keep block/resume flow under official Kanban primitives.
- backlog_ref: `none`
- notes: this row is the minimal closure for phase 19’s block-resume handoff primitive.

### PROFILE-ISOLATION-SURFACE
- claim_id: `PROFILE-ISOLATION-SURFACE`
- capability_area: `Profile`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A; profile sections in `DESIGN.md`
- official_source:
  - `hermes profile --help`
  - `https://hermes-agent.nousresearch.com/docs/reference/profile-commands`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `yes`
- evidence class: runtime
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home-profile hermes profile list
HERMES_HOME=/tmp/hermes-phase20-home-profile hermes profile create reviewer --no-alias --no-skills
HERMES_HOME=/tmp/hermes-phase20-home-profile hermes profile show reviewer
HERMES_HOME=/tmp/hermes-phase20-home-profile hermes profile use reviewer
```
- exit code: `0`
- key_output:
  - `Profile 'reviewer' created at /tmp/hermes-phase20-home-profile/profiles/reviewer`
  - `Profile: reviewer`
  - `Path:    /tmp/hermes-phase20-home-profile/profiles/reviewer`
  - `Switched to: reviewer`
- verdict: verified
- writeback_target: `DESIGN.md` Appendix A Profile row remains official.
- backlog_ref: `none`
- notes: the official surface for creating and inspecting isolated profiles is proven locally. Project-level merge semantics remain outside this row and stay under R3 as local work.

### DISPATCHER-DISPATCH-PASS
- claim_id: `DISPATCHER-DISPATCH-PASS`
- capability_area: `Dispatcher`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A Dispatcher row; `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` problem frame and A1 runtime description
- official_source:
  - `hermes kanban dispatch --help`
  - `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
  - `https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `yes`
- evidence class: runtime
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home-dispatch hermes kanban init
HERMES_HOME=/tmp/hermes-phase20-home-dispatch hermes kanban create "Dispatch task" --body "dispatch body" --assignee default --json
HERMES_HOME=/tmp/hermes-phase20-home-dispatch hermes kanban dispatch
HERMES_HOME=/tmp/hermes-phase20-home-dispatch hermes kanban show t_5ae9b4be --json
```
- exit code: `0`
- key_output:
  - `Spawned:      1`
  - `status`: `running`
  - `workspace_path`: `/tmp/hermes-phase20-home-dispatch/kanban/workspaces/t_5ae9b4be`
  - event stream includes `claimed` and `spawned`
- verdict: verified
- writeback_target: `DESIGN.md` Appendix A Dispatcher row remains official, but downstream docs should stay precise that this row proves dispatch/spawn surface, not the full workflow policy layer.
- backlog_ref: `none`
- notes: a one-pass dispatcher run successfully promoted a ready task into a spawned worker process inside a temp home.

### CURATOR-STATUS-BACKUP
- claim_id: `CURATOR-STATUS-BACKUP`
- capability_area: `Curator`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A Curator row; self-evolution sections
- official_source:
  - `hermes curator --help`
  - `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `partial`
- evidence class: hybrid
- command_or_probe:
```bash
mkdir -p /tmp/hermes-phase20-home-curator/skills/demo-skill
printf "# Demo\n" > /tmp/hermes-phase20-home-curator/skills/demo-skill/SKILL.md
HERMES_HOME=/tmp/hermes-phase20-home-curator hermes curator status
HERMES_HOME=/tmp/hermes-phase20-home-curator hermes curator backup
find /tmp/hermes-phase20-home-curator -maxdepth 4 -type f | sort
```
- exit code: `0`
- key_output:
  - `curator: ENABLED`
  - `curator: snapshot created`
  - temp home contains `skills/.curator_backups/.../manifest.json`
- verdict: verified
- writeback_target: `DESIGN.md` Appendix A Curator row remains official, but later implementation docs should avoid implying that semantic merge/review policy is already solved by the official runtime alone.
- backlog_ref: `none`
- notes: Phase 20 proves curator command surface and backup lifecycle, not the full cross-project review semantics planned for v1.4.

### MEMORY-BUILTIN-SURFACE
- claim_id: `MEMORY-BUILTIN-SURFACE`
- capability_area: `Memory`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A Memory row; `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` R7 family
- official_source:
  - `hermes memory --help`
  - `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `partial`
- evidence class: hybrid
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home-memory hermes memory status
HERMES_HOME=/tmp/hermes-phase20-home-memory hermes memory off
HERMES_HOME=/tmp/hermes-phase20-home-memory hermes memory status
```
- exit code: `0`
- key_output:
  - `Built-in:  always active`
  - `Provider:  (none — built-in only)`
  - `✓ Memory provider: built-in only`
- verdict: verified
- writeback_target: `DESIGN.md` Appendix A Memory row remains official. Phase 19 docs should continue to treat namespace policy and cross-project promotion as local requirements, not proven official behavior.
- backlog_ref: `none`
- notes: this row proves the built-in/external-provider boundary, not the project/global namespace policy required by R7-R7e.

### GATEWAY-COMMAND-SURFACE
- claim_id: `GATEWAY-COMMAND-SURFACE`
- capability_area: `Gateway`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A Gateway row
- official_source:
  - `hermes gateway --help`
  - `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `partial`
- evidence class: hybrid
- command_or_probe:
```bash
hermes gateway --help
hermes status
hermes gateway list
hermes gateway status
```
- exit code: `0`
- key_output:
  - CLI exposes `run/start/stop/restart/status/install/uninstall/list/setup`
  - `hermes status` reports `Gateway Service  Status: running`
  - `hermes gateway list` reports `default (current) — not running`
  - `hermes gateway status` reports `Gateway is not running`
- verdict: verified
- writeback_target: keep the Gateway row official, but split service/command surface from delivery closure in downstream docs.
- backlog_ref: `none`
- notes: official command surface is real, but live service probes conflict on 2026-05-10 and do not by themselves prove end-to-end notification delivery.

### GATEWAY-DELIVERY-CLOSURE
- claim_id: `GATEWAY-DELIVERY-CLOSURE`
- capability_area: `Gateway`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A Gateway row; workflow narratives that assume multi-platform decision delivery is already available
- official_source:
  - `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
  - Hermes docs index search results for gateway/messaging pages captured on 2026-05-10
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `partial`
- evidence class: hybrid
- command_or_probe:
```bash
hermes status
hermes gateway list
hermes gateway status
```
- exit code: `0`
- key_output:
  - all messaging platforms in `hermes status` are `not configured`
  - `hermes gateway list` and `hermes gateway status` do not provide a reproducible running delivery target
- verdict: unsupported
- writeback_target: `DESIGN.md` Appendix A Gateway delivery assumption; `WORKFLOW-EXPLAINED.md` should stop implying that message delivery is already closed by the current environment.
- backlog_ref: `Phase 20 carry-forward — add a reproducible gateway delivery probe and fixture board/profile`
- notes: official gateway capability exists, but current-environment delivery closure did not meet the Phase 20 minimum-runnable-evidence bar.

### HOOKS-EVENT-SURFACE
- claim_id: `HOOKS-EVENT-SURFACE`
- capability_area: `Hooks`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` hook rows in Appendix A and observability/risk sections
- official_source:
  - `hermes hooks --help`
  - `https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks`
  - official docs search captured `pre_tool_call`, `post_tool_call`, and `on_session_end` on 2026-05-10
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `partial`
- evidence class: hybrid
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home-hooks hermes hooks list
HERMES_HOME=/tmp/hermes-phase20-home-hooks hermes hooks doctor
HERMES_HOME=/tmp/hermes-phase20-home-hooks hermes hooks test pre_tool_call --for-tool terminal
```
- exit code: `0`
- key_output:
  - `Configured shell hooks (1 total):`
  - `Firing 1 hook(s) for event 'pre_tool_call':`
  - `exit=0`
  - `payload_exists=yes`
- verdict: verified
- writeback_target: Appendix A hook rows remain official with `verified (hybrid)` status.
- backlog_ref: `none`
- notes: the shell-hook framework and event-name surface are proven. Phase 20 does not prove the entire plugin business logic planned on top of those events.

### SESSION-SEARCH-SURFACE
- claim_id: `SESSION-SEARCH-SURFACE`
- capability_area: `Tools`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A Session Search row
- official_source:
  - `hermes sessions --help`
  - `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
  - `https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `yes`
- evidence class: runtime
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home hermes sessions stats
HERMES_HOME=/tmp/hermes-phase20-home hermes tools list
```
- exit code: `0`
- key_output:
  - `Total sessions: 0`
  - `Database size: 0.0 MB`
  - tools list shows `✓ enabled  session_search`
- verdict: verified
- writeback_target: Appendix A Session Search row remains official.
- backlog_ref: `none`
- notes: current proof is command/tool surface, not a semantic search quality evaluation.

### TERMINAL-CLARIFY-TOOLSET-SURFACE
- claim_id: `TERMINAL-CLARIFY-TOOLSET-SURFACE`
- capability_area: `Tools`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A `terminal()` and `clarify()` rows
- official_source:
  - `https://hermes-agent.nousresearch.com/docs/reference/tools-reference`
  - `https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `yes`
- evidence class: hybrid
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home hermes tools list
```
- exit code: `0`
- key_output:
  - `✓ enabled  terminal`
  - `✓ enabled  clarify`
- verdict: verified
- writeback_target: `terminal()` and `clarify()` stay official in Appendix A.
- backlog_ref: `none`
- notes: this row proves the toolset surface. Phase 20 does not attempt an LLM-driven live invocation for either tool because the capability claim in phase 19 is about official availability, not custom workflow semantics.

### APPROVALS-MODE-CONFIG
- claim_id: `APPROVALS-MODE-CONFIG`
- capability_area: `Hooks`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A `approvals.mode` row
- official_source:
  - `hermes config --help`
  - official security docs search for `approvals.mode` captured on 2026-05-10
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `yes`
- evidence class: hybrid
- command_or_probe:
```bash
HERMES_HOME=/tmp/hermes-phase20-home-approvals hermes config set approvals.mode smart
sed -n '1,80p' /tmp/hermes-phase20-home-approvals/config.yaml
```
- exit code: `0`
- key_output:
  - `✓ Set approvals.mode = smart in /tmp/hermes-phase20-home-approvals/config.yaml`
  - config file contains:
    - `approvals:`
    - `mode: smart`
- verdict: verified
- writeback_target: keep `approvals.mode` in Appendix A as official command-level approval surface.
- backlog_ref: `none`
- notes: this row proves official config surface only. The phase 19 L1/L2/L3 policy remains a local layer on top.

### SKILL-MANAGE-OFFICIAL-SURFACE
- claim_id: `SKILL-MANAGE-OFFICIAL-SURFACE`
- capability_area: `Tools`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A `skill_manage` row
- official_source:
  - `https://hermes-agent.nousresearch.com/docs/user-guide/configuration`
  - `https://hermes-agent.nousresearch.com/docs/user-guide/skills/bundled/software-development/software-development-hermes-agent-skill-authoring`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `no`
- evidence class: doc-only
- command_or_probe:
```text
Official docs only. No safe non-interactive CLI probe exposes skill_manage directly in the current runtime.
```
- exit code: `n/a`
- key_output:
  - configuration docs describe `~/.hermes/skills/` as agent-created skills managed by the `skill_manage` tool
  - skill authoring docs distinguish repo-authored skills from user-local skills and name `skill_manage(action='create')`
- verdict: verified
- writeback_target: Appendix A should retain the official `skill_manage` surface, but not overstate workflow automation coverage.
- backlog_ref: `none`
- notes: doc-only verification is accepted here because local closure is clearly impractical without an agent-driven invocation path.

### SKILL-MANAGE-WORKFLOW-AUTOMATION
- claim_id: `SKILL-MANAGE-WORKFLOW-AUTOMATION`
- capability_area: `Tools`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` self-evolution sections that imply automatic skill creation is already operational
- official_source:
  - `https://hermes-agent.nousresearch.com/docs/user-guide/configuration`
  - `https://hermes-agent.nousresearch.com/docs/user-guide/skills/bundled/software-development/software-development-hermes-agent-skill-authoring`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `no`
- evidence class: doc-only
- command_or_probe:
```text
Boundary analysis only. Phase 20 proved the official tool exists in docs, not the full workflow semantics proposed in phase 19.
```
- exit code: `n/a`
- key_output:
  - official docs expose the tool surface
  - no local Phase 20 probe proves the full "自动创建 skill + curator-driven workflow" path end-to-end
- verdict: local-extension
- writeback_target: `DESIGN.md` self-evolution wording and Appendix A `skill_manage` row need an explicit boundary note.
- backlog_ref: `Phase 20 carry-forward — decide whether to add a reproducible skill_manage runtime probe or keep skill automation as local workflow logic`
- notes: this is the main official-boundary downgrade in Phase 20. The base tool is official; the workflow semantics remain local.

### RFC-16102-USER-SPACE-APPROVAL-GATES
- claim_id: `RFC-16102-USER-SPACE-APPROVAL-GATES`
- capability_area: `Hooks`
- phase19_ref: `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A RFC row; risk-policy rationale paragraphs
- official_source:
  - `https://github.com/NousResearch/hermes-agent/issues/16102`
- runtime_anchor: `Hermes Agent v0.13.0 (2026.5.7)`
- local_feasible: `no`
- evidence class: doc-only
- command_or_probe:
```text
Issue-level policy reference only.
```
- exit code: `n/a`
- key_output:
  - RFC text captured on 2026-05-10 lists approval gates among features deliberately left to user-space via plugins or profile conventions
- verdict: verified
- writeback_target: keep the rationale note, but do not confuse issue-level policy guidance with a runtime capability row.
- backlog_ref: `none`
- notes: this row is evidence for phase 19’s architectural rationale, not a runnable feature.

## Summary

- `verified`: 12 rows
- `unsupported`: 1 row
- `local-extension`: 1 row

Unsupported / downgraded carry-forward items:

- `GATEWAY-DELIVERY-CLOSURE` → roadmap backlog entry required
- `SKILL-MANAGE-WORKFLOW-AUTOMATION` → roadmap backlog entry required
