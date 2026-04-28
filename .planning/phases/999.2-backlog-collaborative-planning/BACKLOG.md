# Backlog: Multi-Round Collaborative Planning Mode

**Status:** Backlogged (deferred to post-v1.2)  
**Created:** 2026-04-28  
**Priority:** P2 (enhancement)  
**Estimated Effort:** 2-3 days  
**Milestone Target:** v1.3 or later  

---

## 1. Background & Motivation

The current Hermes Dev Orchestra workflow is:

```
Hermes → task.md → Codex (execute) → codex-question.md → Claude (decide) → claude-decision.md → Codex (continue) → codex-result.md → Claude (review) → review-result.md
```

This is a **single-pass** executor-supervisor pattern. Codex is purely reactive: it receives a task, executes, asks blocking questions when stuck, and produces results. Claude is purely supervisory: it reviews output and answers questions.

**Problem:** Planning is done either by Claude alone (before task dispatch) or by the human operator. Codex never participates in the planning phase, even though Codex has valuable implementation-level perspective ("this approach won't work because of X", "there's a simpler way to do Y").

**Goal:** Introduce an **adversarial collaborative planning mode** where Claude and Codex engage in multi-round discussion before execution, producing a consensus plan that both agents agree on.

---

## 2. Current Architecture Gaps

### Gap 1: No `discussion` status in `codex-question.md`

The watcher (`orch-bus-loop`) treats every `codex-question.md` as a **blocking question** that requires a decision. There is no concept of a "discussion proposal" where Codex initiates a conversation rather than asking for permission.

Current watcher logic in `process_once()`:

```bash
if [ -f "$RUNTIME_DIR/codex-question.md" ]; then
    route_question_to_claude   # Always expects a decision
    return 0
fi
```

### Gap 2: No `plan.md` file type in the file bus

The file bus schema (`task.md`, `codex-question.md`, `claude-decision.md`, `escalation.md`, `codex-result.md`, `review-result.md`) has no slot for a **plan document**. A plan produced by collaborative discussion has nowhere to go.

### Gap 3: No multi-round discussion loop

After Claude writes `claude-decision.md`, the watcher immediately calls `continue_codex_after_decision()` and injects the decision back into Codex. There is no path for Codex to write a **second round** of discussion.

The state machine assumes: `question → decision → continue`. It cannot handle: `discussion → response → discussion → response → plan`.

### Gap 4: Skills don't define collaborative behavior

- `codex-executor/SKILL.md` only defines "blocking question" protocol
- `claude-supervisor/SKILL.md` only defines "decision" and "review" protocols
- `dev-orchestra/SKILL.md` only defines the standard single-pass flow

---

## 3. Required Changes

### 3.1 Core Watcher: `scripts/bin/orch-bus-loop`

**Additions needed:**

#### A. Detect `discussion` vs `question` status

In `process_once()`, before `route_question_to_claude`, read the `status` field from `codex-question.md`:

```bash
if [ -f "$RUNTIME_DIR/codex-question.md" ]; then
    local question_status
    question_status="$(orch_json_field "$RUNTIME_DIR/codex-question.md" "status")"
    case "$question_status" in
        discussion)
            route_discussion_to_claude
            ;;
        *)
            route_question_to_claude
            ;;
    esac
    return 0
fi
```

#### B. New function: `route_discussion_to_claude()`

Similar to `route_question_to_claude()` but with a different prompt that asks Claude to write a **discussion response** instead of a **decision**:

```bash
write_runner "$runner" cat <<EOF
cat $(quote "$RUNTIME_DIR/codex-question.md") | claude -p --output-format json --permission-mode auto \
  "You are Claude Supervisor for project [$PROJECT_ID]. This is a DISCUSSION PROPOSAL from Codex, not a blocking question. Read the proposal and write a JSON response envelope to claude-decision.md with status 'discussion-response'. Challenge assumptions, evaluate options, provide counter-proposals, or confirm convergence. Set next_action to 'continue_discussion' or 'proceed_to_plan' based on whether consensus is reached." \
  > $(quote "$STATE_DIR/claude-decision.raw.json") 2>> $(quote "$STATE_DIR/claude.err")
# ... same JSON extraction logic as route_question_to_claude ...
EOF
```

#### C. New function: `route_plan_to_review()`

When `plan.md` is detected, forward it to Claude for review:

```bash
route_plan_to_review() {
    local plan_hash
    local runner="$STATE_DIR/run-claude-plan-review.sh"

    plan_hash="$(sha256sum "$RUNTIME_DIR/plan.md" | awk '{print $1}')"
    if [ -f "$STATE_DIR/last-plan.hash" ] && [ "$(cat "$STATE_DIR/last-plan.hash")" = "$plan_hash" ]; then
        return 0
    fi

    write_runner "$runner" cat <<EOF
cat $(quote "$RUNTIME_DIR/plan.md") | claude -p --output-format json --permission-mode auto \
  "You are Claude Supervisor for project [$PROJECT_ID]. Review the execution plan from stdin and write a JSON review envelope for review-result.md. Decision: APPROVED, NEEDS_MODIFICATION, or REJECTED." \
  > $(quote "$STATE_DIR/review-result.raw.json") 2>> $(quote "$STATE_DIR/claude.err")
# ... same JSON extraction logic ...
EOF

    orch_write_project_state "reviewing_plan" "$(task_id_from_bus)"
    echo "$plan_hash" > "$STATE_DIR/last-plan.hash"
    send_runner "$CLAUDE_SESSION" "$runner"
    log_loop "routed plan.md to $CLAUDE_SESSION for review"
}
```

#### D. Handle `plan.md` in `process_once()`

Insert before the `codex-result.md` check:

```bash
if [ -f "$RUNTIME_DIR/plan.md" ]; then
    route_plan_to_review
    return 0
fi
```

#### E. Handle `NEEDS_MODIFICATION` for plans

In `finalize_review_if_ready()`, when plan review returns `NEEDS_MODIFICATION`, the task should go back to Codex (not block). Add a new state transition.

### 3.2 Skill: `skills/codex-executor/SKILL.md`

Add a new section **"Collaborative Planning Protocol"**:

```markdown
### Collaborative Planning Protocol

When `task.md` contains `collaboration_mode: "adversarial-planning"`:

1. **Do not start coding.** Set `current_phase: "discuss"`.
2. Read all files specified in `discussion_phase.required_reading`.
3. Write `codex-question.md` with `status: "discussion"` (not `"question"`).
   - Include: understanding summary, proposed options with trade-offs, identified risks/assumptions, questions for Claude.
4. Wait for `claude-decision.md` with `status: "discussion-response"`.
5. If `next_action: "continue_discussion"`, write another round of `codex-question.md` with `status: "discussion"`.
6. If `next_action: "proceed_to_plan"`, write `plan.md`:
   ```json
   {
     "schema_version": "1.0",
     "status": "plan",
     "plan_steps": [...],
     "verification_criteria": [...],
     "risk_mitigations": [...]
   }
   ```
7. Wait for `review-result.md` on the plan.
8. If plan is `APPROVED`, proceed to `current_phase: "execute"`.
9. If plan is `NEEDS_MODIFICATION`, revise `plan.md` and resubmit.
```

### 3.3 Skill: `skills/claude-supervisor/SKILL.md`

Add a new section **"Handling Discussion Proposals"**:

```markdown
### Handling Discussion Proposals

When `codex-question.md` has `status: "discussion"`:

1. Read the proposal thoroughly.
2. Write `claude-decision.md` with `status: "discussion-response"`:
   - `on_understanding`: Confirm or correct Codex's understanding
   - `on_options`: Challenge options, point out blind spots, suggest alternatives
   - `on_risks`: Supplement risks Codex missed
   - `answers`: Direct answers to Codex's questions
   - `next_action`: `"continue_discussion"` or `"proceed_to_plan"`
3. Do NOT set `execution.authority_sufficient` — this is not a final decision.
4. If discussion has converged (both sides agree on approach), set `next_action: "proceed_to_plan"`.
```

Also add **"Plan Review"** section:

```markdown
### Plan Review

When `plan.md` is submitted:

1. Review each plan step for feasibility and completeness.
2. Check that verification criteria map to task requirements.
3. Write `review-result.md` with:
   - `decision`: APPROVED, NEEDS_MODIFICATION, or REJECTED
   - `rationale`: Detailed review comments
```

### 3.4 Skill: `skills/dev-orchestra/SKILL.md`

Add **"Phase 4.4: Collaborative Planning Mode"** in the task dispatch section:

```markdown
#### 4.4 Collaborative Planning Mode

When `task.md` contains `collaboration_mode: "adversarial-planning"`, the flow becomes:

```
Hermes → task.md (with collaboration_mode) → Codex
  Codex → codex-question.md (status: "discussion")
    Watcher → Claude
  Claude → claude-decision.md (status: "discussion-response")
    Watcher → Codex
  (repeat 1-N rounds)
  Codex → plan.md
    Watcher → Claude (plan review)
  Claude → review-result.md (APPROVED/NEEDS_MOD)
    Watcher → Codex (if APPROVED)
  Codex → codex-result.md (execution)
    Watcher → Claude (result review)
  Claude → review-result.md
```

Key differences from standard mode:
- `codex-question.md` can have `status: "discussion"` (not just `"question"`)
- `claude-decision.md` can have `status: "discussion-response"` (not just `"decided"`)
- New file `plan.md` enters the bus
- Plan must be approved before execution begins
```

---

## 4. File Bus Schema Extensions

### New `status` values for `codex-question.md`

| Status | Meaning | Watcher Action |
|--------|---------|----------------|
| `question` (existing) | Blocking question, needs decision | `route_question_to_claude` |
| `discussion` (new) | Discussion proposal, needs response | `route_discussion_to_claude` |

### New `status` values for `claude-decision.md`

| Status | Meaning | Next Step |
|--------|---------|-----------|
| `decided` (existing) | Final decision | Continue Codex execution |
| `discussion-response` (new) | Response to discussion | Codex writes next round or plan |

### New file: `plan.md`

```json
{
  "schema_version": "1.0",
  "message_id": "msg-{uuid}",
  "project_id": "{project}",
  "task_id": "{task_id}",
  "correlation_id": "{corr-id}",
  "status": "plan",
  "author": "codex",
  "authority": "executor",
  "timestamp": "{iso8601}",
  "body": {
    "plan_steps": [
      {"step": 1, "action": "...", "verification": "..."}
    ],
    "verification_criteria": ["..."],
    "risk_mitigations": ["..."],
    "discussion_rounds": 3
  }
}
```

---

## 5. Acceptance Criteria

- [ ] `orch-bus-loop` detects `status: "discussion"` in `codex-question.md` and routes to `route_discussion_to_claude()`
- [ ] `orch-bus-loop` detects `plan.md` and routes to `route_plan_to_review()`
- [ ] Claude receives discussion proposals with a prompt that instructs "discussion-response" behavior, not "decision" behavior
- [ ] Codex executor skill documents the collaborative planning protocol
- [ ] Claude supervisor skill documents discussion response and plan review protocols
- [ ] Dev orchestra skill documents the complete collaborative flow
- [ ] At least 2 rounds of discussion can occur before plan convergence
- [ ] Plan review can return `NEEDS_MODIFICATION` and trigger Codex revision
- [ ] Standard mode (non-collaborative) continues to work unchanged
- [ ] Smoke test covers a full collaborative planning cycle

---

## 6. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Watcher state machine becomes too complex | High | Add comprehensive unit tests for `process_once()` branching logic |
| Codex/Claude enter infinite discussion loop | Medium | Add `max_discussion_rounds` (e.g., 5) to `task.md`; watcher forces `proceed_to_plan` after limit |
| `plan.md` review blocks indefinitely | Medium | Add plan review timeout; default to `APPROVED` with warning if supervisor unresponsive |
| Backward compatibility break | High | Keep `status: "question"` as default; `"discussion"` is opt-in via `collaboration_mode` |
| File bus clutter (many round files) | Low | Watcher archives old discussion files after plan is approved |

---

## 7. Dependencies

- **Blocks:** None (backlog item)
- **Blocked by:** v1.2 completion (current milestone)
- **Related:** Phase 18 (Architecture Bounds) may need to document the "single active task per project" constraint in the context of collaborative planning

---

## 8. Notes

- This feature was identified during v1.2 Phase 13 planning discussion on 2026-04-28.
- The current workaround (without this feature) is to embed the plan directly in `task.md` as pre-computed `execution_steps`, bypassing the collaborative phase.
- When implemented, this should be considered for inclusion in the v1.3 milestone under a new phase (e.g., "Phase 19: Collaborative Planning Protocol").
