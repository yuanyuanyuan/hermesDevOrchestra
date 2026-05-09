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

> **⚠️ Linux Sandbox Requirement:** All `codex exec` invocations inside `orch-bus-loop` (including existing `dispatch_codex_task()` and `continue_codex_after_decision()` functions) must include `-s danger-full-access` to bypass Codex CLI's default Linux bubblewrap sandbox (`bwrap: setting up uid map: Permission denied`). This applies to every `codex exec` call in the watcher. Example:
> ```bash
> codex exec --full-auto --json -s danger-full-access ...
> ```
> **Security note:** Only use in trusted local/container environments.

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
  "You are Claude Supervisor for project [$PROJECT_ID]. Review the execution plan from stdin and write a JSON review envelope for plan-review-result.md. Decision: APPROVED, NEEDS_MODIFICATION, or REJECTED." \
  > $(quote "$STATE_DIR/plan-review-result.raw.json") 2>> $(quote "$STATE_DIR/claude.err")
# ... JSON extraction: parse wrapper -> write to $RUNTIME_DIR/plan-review-result.md ...
EOF

    orch_write_project_state "reviewing_plan" "$(task_id_from_bus)"
    echo "$plan_hash" > "$STATE_DIR/last-plan.hash"
    send_runner "$CLAUDE_SESSION" "$runner"
    log_loop "routed plan.md to $CLAUDE_SESSION for review"
}
```

#### D. Update `process_once()` priority order

The existing `process_once()` needs to handle the new file types in the correct order. Replace the existing `review-result.md` check with separate handlers for plan and result reviews, and insert `plan.md` between decision consumption and new question routing:

```bash
process_once() {
    local task_hash

    if handle_escalation_if_present; then
        return 0
    fi

    if [ -f "$RUNTIME_DIR/.codex-done" ] || [ -f "$RUNTIME_DIR/.codex-signal" ]; then
        rm -f "$RUNTIME_DIR/.codex-done" "$RUNTIME_DIR/.codex-signal"
        log_loop "codex signal consumed"
    fi

    # NEW: Handle plan review results before result review results
    if [ -f "$RUNTIME_DIR/plan-review-result.md" ]; then
        finalize_plan_review_if_ready
        return 0
    fi

    # NEW: Handle result review results (adapted from existing finalize_review_if_ready)
    if [ -f "$RUNTIME_DIR/result-review-result.md" ]; then
        finalize_review_if_ready   # existing function, adapted to read result-review-result.md and clean up result-review-result.md
        return 0
    fi

    # NEW: Route plan.md for review
    if [ -f "$RUNTIME_DIR/plan.md" ]; then
        route_plan_to_review
        return 0
    fi

    # Existing: Continue Codex after decision
    if [ -f "$RUNTIME_DIR/claude-decision.md" ] && [ -f "$RUNTIME_DIR/codex-question.md" ]; then
        continue_codex_after_decision
        return 0
    fi

    # Existing: Route questions/discussions to Claude
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

    # Existing: Dispatch task to Codex
    if [ -f "$RUNTIME_DIR/task.md" ]; then
        task_hash="$(orch_current_task_hash)"
        if [ -n "$task_hash" ] && { [ ! -f "$STATE_DIR/last-task.hash" ] || [ "$(cat "$STATE_DIR/last-task.hash")" != "$task_hash" ]; }; then
            dispatch_codex_task "$task_hash"
        fi
    fi
}
```

**Priority rationale (high to low):**
1. `escalation.md` — safety always first
2. `plan-review-result.md` / `result-review-result.md` — consume review outputs before generating new ones
3. `plan.md` — route plan for review before starting new discussion rounds
4. `claude-decision.md` + `codex-question.md` — consume pending decisions
5. `codex-question.md` — route new questions or discussions
6. `task.md` — dispatch new tasks

#### E. Handle `NEEDS_MODIFICATION` for plans

In `finalize_plan_review_if_ready()`, when plan review returns `NEEDS_MODIFICATION`, dispatch the review feedback back to Codex for revision (not block). Add a new state transition.

**New function: `route_plan_review_to_codex()`**

When `plan-review-result.md` contains `NEEDS_MODIFICATION`, dispatch the review feedback back to Codex for plan revision:

```bash
route_plan_review_to_codex() {
    local review_hash
    local runner="$STATE_DIR/run-codex-plan-revision.sh"

    orch_project_matches_if_present "$RUNTIME_DIR/plan-review-result.md" || {
        log_loop "plan-review-result.md project_id mismatch; not routing"
        return 0
    }

    review_hash="$(sha256sum "$RUNTIME_DIR/plan-review-result.md" | awk '{print $1}')"
    if [ -f "$STATE_DIR/last-plan-review.hash" ] && [ "$(cat "$STATE_DIR/last-plan-review.hash")" = "$review_hash" ]; then
        return 0
    fi

    write_runner "$runner" cat <<EOF
{
  printf '%s\n' 'You are Codex Executor for project [$PROJECT_ID]. The execution plan was reviewed and needs modification. Read the review feedback and the current plan, then revise plan.md accordingly. Output the revised plan as a JSON envelope following the plan.md schema (schema_version, status, plan_steps, verification_criteria, risk_mitigations).'
  cat $(quote "$RUNTIME_DIR/plan-review-result.md") $(quote "$RUNTIME_DIR/plan.md")
} | codex exec --full-auto --json --output-last-message $(quote "$RUNTIME_DIR/plan.md") - >> $(quote "$STATE_DIR/codex-events.jsonl") 2>> $(quote "$STATE_DIR/codex.err")
EOF

    orch_write_project_state "revising_plan" "$(task_id_from_bus)"
    echo "$review_hash" > "$STATE_DIR/last-plan-review.hash"
    send_runner "$CODEX_SESSION" "$runner"
    log_loop "routed plan-review-result.md (NEEDS_MODIFICATION) to $CODEX_SESSION for revision"
}
```

**`finalize_review_if_ready()` extension for plan reviews:**

```bash
finalize_plan_review_if_ready() {
    local decision
    local task_id
    local review_task_id

    task_id="$(task_id_from_bus)"
    review_task_id="$(orch_json_field "$RUNTIME_DIR/plan-review-result.md" "task_id")"
    if [ -z "$review_task_id" ] || [ "$review_task_id" = "null" ] || [ "$review_task_id" != "$task_id" ]; then
        mkdir -p "$AUDIT_DIR/pending"
        mv "$RUNTIME_DIR/plan-review-result.md" "$AUDIT_DIR/pending/plan-review-result.$(date +%s).md"
        log_loop "plan-review-result.md missing or mismatched task_id; archived stale review"
        return 0
    fi

    # Extract decision value from plan-review-result.md (inline, since review_decision_value() targets review-result.md)
    decision="$(orch_json_field "$RUNTIME_DIR/plan-review-result.md" "decision")"
    if [ -z "$decision" ] || [ "$decision" = "null" ]; then
        if grep -q "APPROVED" "$RUNTIME_DIR/plan-review-result.md" 2>/dev/null; then
            decision="APPROVED"
        elif grep -q "REJECTED" "$RUNTIME_DIR/plan-review-result.md" 2>/dev/null; then
            decision="REJECTED"
        elif grep -q "NEEDS_MODIFICATION" "$RUNTIME_DIR/plan-review-result.md" 2>/dev/null; then
            decision="NEEDS_MODIFICATION"
        else
            decision="unknown"
        fi
    fi
    case "$decision" in
        APPROVED)
            orch_write_project_state "plan_approved" "$task_id"
            rm -f "$RUNTIME_DIR/plan-review-result.md" "$STATE_DIR/last-plan-review.hash"
            log_loop "plan review approved; proceeding to execution"
            ;;
        REJECTED)
            orch_write_project_state "failed" "$task_id"
            orch_archive_task_artifacts "$task_id"
            rm -f "$RUNTIME_DIR/plan-review-result.md" "$STATE_DIR/last-plan-review.hash"
            log_loop "plan review rejected; project failed"
            ;;
        NEEDS_MODIFICATION)
            # Archive the old review result before dispatching to prevent re-processing loops
            mkdir -p "$AUDIT_DIR/pending"
            mv "$RUNTIME_DIR/plan-review-result.md" "$AUDIT_DIR/pending/plan-review-result.$(date +%s).md"
            route_plan_review_to_codex
            ;;
    esac
}
```

#### F. Branch `continue_codex_after_decision()` for `discussion-response`

The existing `continue_codex_after_decision()` assumes every `claude-decision.md` is a **final decision** with `decision`, `execution.authority_sufficient`, and risk fields. When `status` is `"discussion-response"`, these fields are absent. Add a guard clause at the top:

```bash
continue_codex_after_decision() {
    local decision_status
    decision_status="$(orch_json_field "$RUNTIME_DIR/claude-decision.md" "status")"

    # Collaborative planning: discussion responses bypass all approval checks
    if [ "$decision_status" = "discussion-response" ]; then
        local decision_hash
        local runner="$STATE_DIR/run-codex-discussion.sh"
        local task_id

        orch_project_matches_if_present "$RUNTIME_DIR/claude-decision.md" || {
            log_loop "claude-decision.md project_id mismatch; not routing"
            return 0
        }

        task_id="$(orch_json_field "$RUNTIME_DIR/claude-decision.md" "task_id")"
        [ -n "$task_id" ] && [ "$task_id" != "null" ] || task_id="$(task_id_from_bus)"

        decision_hash="$(sha256sum "$RUNTIME_DIR/claude-decision.md" | awk '{print $1}')"
        if [ -f "$STATE_DIR/last-discussion.hash" ] && [ "$(cat "$STATE_DIR/last-discussion.hash")" = "$decision_hash" ]; then
            return 0
        fi

        write_runner "$runner" cat <<EOF
{
  printf '%s\n' 'You are Codex Executor for project [$PROJECT_ID]. Continue the collaborative discussion using the JSON task and Claude response envelopes below. Based on the discussion response, either write a new codex-question.md (status: "discussion") for another round, or write plan.md if consensus is reached.'
  cat $(quote "$RUNTIME_DIR/task.md") $(quote "$RUNTIME_DIR/claude-decision.md")
} | codex exec --full-auto --json - >> $(quote "$STATE_DIR/codex-events.jsonl") 2>> $(quote "$STATE_DIR/codex.err")
# Note: --output-last-message is NOT used here; Codex writes codex-question.md or plan.md directly via file bus protocol
touch $(quote "$RUNTIME_DIR/.codex-done")
EOF

        orch_write_project_state "discussing" "$task_id"
        echo "$decision_hash" > "$STATE_DIR/last-discussion.hash"
        send_runner "$CODEX_SESSION" "$runner"
        log_loop "continued Codex after discussion-response"
        return 0
    fi

    # --- existing final-decision logic below (unchanged) ---
    # ... (original continue_codex_after_decision code) ...
}
```

**Key points:**
- `discussion-response` skips `execution.authority_sufficient` checks, risk level checks, and escalation logic.
- A separate hash file (`last-discussion.hash`) prevents duplicate dispatches.
- The runner instructs Codex to continue the discussion, not execute code.

#### G. 轻量阶段追踪（混合方案）

为控制讨论边界同时保持最小侵入性，Watcher 采用**轻量计数文件**而非全状态机：

**计数文件：** `$STATE_DIR/discussion-count`
- 类型：纯文本，仅包含一个整数
- 生命周期：任务开始时为 0，每检测到一次新的 `codex-question.md` (status: "discussion") 时 +1
- 清理时机：`plan.md` 被 `APPROVED` 后，或任务进入 `completed`/`failed` 状态时
- 回退策略：文件不存在时视为 0

**`max_discussion_rounds` 解析顺序：**
1. `task.md` → `collaboration.max_discussion_rounds`（整数，默认 5）
2. 环境变量 → `$HERMES_MAX_DISCUSSION_ROUNDS`（整数，默认 5）

**强制终止逻辑（`process_once()` 中 `route_discussion_to_claude()` 之前）：**

```bash
local discussion_count=0
local max_rounds=5

[ -f "$STATE_DIR/discussion-count" ] && discussion_count=$(cat "$STATE_DIR/discussion-count")
max_rounds="$(orch_json_field "$RUNTIME_DIR/task.md" "collaboration.max_discussion_rounds")"
[ -z "$max_rounds" ] || [ "$max_rounds" = "null" ] && max_rounds="${HERMES_MAX_DISCUSSION_ROUNDS:-5}"

if [ "$discussion_count" -ge "$max_rounds" ]; then
    log_loop "discussion count $discussion_count >= max $max_rounds; forcing to question mode"
    # 强制覆盖 status 为 question，走标准决策路径
    # 或：写入一个特殊信号文件让 Codex 知晓强制收敛
    echo "forced_convergence" > "$RUNTIME_DIR/.discussion-forced"
    route_question_to_claude  # 使用标准决策提示，不再走讨论路径
    return 0
fi
```

**状态泄漏防护：**
- 每个项目任务完成后，`orch_archive_task_artifacts()` 负责清理 `$STATE_DIR/discussion-count`
- Watcher 启动时若检测到遗留的 `discussion-count`（无对应 `task.md`），自动归零

### 3.2 Skill: `skills/codex-executor/SKILL.md`

Add a new section **"Collaborative Planning Protocol"**:

```markdown
### Collaborative Planning Protocol

When `task.md` contains `collaboration_mode: "adversarial-planning"`:

1. **Do not start coding.** Set `current_phase: "discuss"`.
2. Read all files specified in `discussion_phase.required_reading`.
3. Execute `$gsd-discuss-phase` to generate structured discussion content.
4. Write `codex-question.md` with `status: "discussion"` (not `"question"`).
   - Content follows GSD discuss-phase output format: understanding summary, proposed options with trade-offs, identified risks/assumptions, questions for Claude.
5. Wait for `claude-decision.md` with `status: "discussion-response"`.
6. If `next_action: "continue_discussion"`, execute `$gsd-discuss-phase` again and write another round of `codex-question.md` with `status: "discussion"`.
7. If `next_action: "proceed_to_plan"`, execute `$gsd-plan-phase` to generate the execution plan.
8. Write `plan.md` following GSD PLAN.md format:
   ```json
   {
     "schema_version": "1.0",
     "status": "plan",
     "plan_steps": [...],
     "verification_criteria": [...],
     "risk_mitigations": [...]
   }
   ```
9. Wait for `plan-review-result.md` on the plan.
10. If plan is `APPROVED`, proceed to `current_phase: "execute"`.
    - **Self-verification:** Codex 执行自动化测试（`npm test` / `make test` / 项目对应的测试命令），将测试结果摘要写入内部日志。
    - ⚠️ **注意：`$gsd-verify-work` 在无头模式下不可用**（无任何 `--auto` 支持，必然卡死在交互输入点）。如需 UAT 验证，须留待 Claude Code 交互式会话中执行 `/gsd-verify-work`。
11. If plan is `NEEDS_MODIFICATION`, execute `$gsd-plan-phase` to revise `plan.md` and resubmit.

### GSD Command Reference for Codex

> ⚠️ **Codex CLI Sandbox 要求：** 所有 Codex 执行命令必须附加 `-s danger-full-access` 以绕过 Linux bubblewrap 限制（`bwrap: setting up uid map: Permission denied`）。
>
> ```bash
> codex exec "$gsd-discuss-phase <phase> --auto" -s danger-full-access
> ```
> **注意：** `danger-full-access` 授予完全文件系统访问权限，仅在受信任的本地/容器环境中使用。

When generating file bus content, Codex invokes GSD skills using the `$` prefix:

| GSD Command | Used When | Output Target | 无头可用性 |
|-------------|-----------|---------------|----------|
| `$gsd-discuss-phase <phase> --auto` | Generating `codex-question.md` (status: `discussion`) | `codex-question.md` body | ✅ 安全 |
| `$gsd-plan-phase <phase> --auto --skip-research` | Generating or revising `plan.md` | `plan.md` body | ⚠️ 有条件（见 Section 9.3） |
| `$gsd-debug` | Debugging execution issues | Debug analysis (logged, not on bus) | ✅ 安全 |
| `$gsd-add-tests` | Adding tests for verification criteria | Test files (committed, not on bus) | ✅ 安全 |

**❌ 以下命令在无头模式下不可用，不得在无值守流程中使用：**
- `$gsd-verify-work` — 无任何 `--auto` 支持，3 个核心交互点必然卡死
```

### 3.3 Skill: `skills/claude-supervisor/SKILL.md`

Add a new section **"Handling Discussion Proposals"**:

```markdown
### Handling Discussion Proposals

When `codex-question.md` has `status: "discussion"`:

1. Read the proposal thoroughly.
2. Execute `/gsd-discuss-phase` to generate structured response content.
3. Write `claude-decision.md` with `status: "discussion-response"` following GSD decision format:
   - `on_understanding`: Confirm or correct Codex's understanding
   - `on_options`: Challenge options, point out blind spots, suggest alternatives
   - `on_risks`: Supplement risks Codex missed
   - `answers`: Direct answers to Codex's questions
   - `next_action`: `"continue_discussion"` or `"proceed_to_plan"`
4. Do NOT set `execution.authority_sufficient` — this is not a final decision.
5. If discussion has converged (both sides agree on approach), set `next_action: "proceed_to_plan"`.
```

Also add **"Plan Review"** section:

```markdown
### Plan Review

When `plan.md` is submitted:

1. 审查 plan.md 的每个步骤的可行性和完整性。
2. 检查 verification criteria 是否映射到 task requirements。
3. ⚠️ **注意：** `/gsd-code-review` 是代码审查工具，不适合审阅计划文档。Plan Review 应以结构化检查清单方式进行。
4. Write `plan-review-result.md` following GSD REVIEW.md format:
   - `decision`: APPROVED, NEEDS_MODIFICATION, or REJECTED
   - `rationale`: Detailed review comments with structured issue list
   - `review_dimensions`: Scored dimensions (feasibility, completeness, correctness, backward_compatibility, security)
```

**❌ 以下命令在无头/自动化流程中不应使用：**
- `/gsd-verify-work` — 交互式 UAT，只能在 Claude Code 交互式会话中手动执行
- `/gsd-complete-milestone`, `/gsd-new-milestone`, `/gsd-plan-milestone-gaps` — 全局状态操作，由人工 GSD 流程控制，不应由普通任务自动触发

### GSD Command Reference for Claude Code

When generating file bus content, Claude Code invokes GSD skills using the `/` prefix:

| GSD Command | Used When | Output Target | 无头可用性 |
|-------------|-----------|---------------|----------|
| `/gsd-discuss-phase <phase> --auto` | Responding to `codex-question.md` (status: `discussion`) | `claude-decision.md` body | ✅ 安全 |
| `/gsd-validate-phase` | Verifying phase completion | Phase validation report | ✅ 安全 |

**📝 仅可在交互式会话中使用的命令（需用户在场）：**
| GSD Command | Used When |
|-------------|-----------|
| `/gsd-verify-work` | 交互式 UAT 验证 — **不能自动化，需用户确认每一步** |

**❌ 不应在自动化流程中使用的命令：**
| GSD Command | 原因 |
|-------------|------|
| `/gsd-code-review` | 用于代码审查，不是计划文档审查 |
| `/gsd-complete-milestone` | 全局状态操作，由人工 GSD 流程控制 |
| `/gsd-new-milestone` | 全局状态操作，由人工 GSD 流程控制 |
| `/gsd-plan-milestone-gaps` | 全局状态操作，由人工 GSD 流程控制 |
| `/gsd-extract_learnings` | 通常在人工审阅后触发 |

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
  Claude → plan-review-result.md (APPROVED/NEEDS_MOD)
    Watcher → Codex (if APPROVED)
  Codex → codex-result.md (execution)
    Watcher → Claude (result review)
  Claude → result-review-result.md
```

Key differences from standard mode:
- `codex-question.md` can have `status: "discussion"` (not just `"question"`)
- `claude-decision.md` can have `status: "discussion-response"` (not just `"decided"`)
- New file `plan.md` enters the bus
- Plan must be approved before execution begins
```

### 3.5 GSD Skill Integration into File Bus

To align collaborative planning content quality with the GSD framework, all file bus documents follow GSD output format conventions. Claude Code and Codex invoke GSD commands at key nodes to assist content generation. Hermes, as the orchestrator, does **not** execute GSD commands but follows GSD format conventions when generating `task.md`.

#### 3.5.1 Content Protocol Layer (All Agents)

All file bus documents follow GSD output formats:

| File Bus File | GSD Format Template |
|--------------|---------------------|
| `task.md` | GSD `PLAN.md` structure (Goal / Context / Deliverables / Assumptions / Risks) |
| `codex-question.md` | GSD `discuss-phase` output (understanding / assumptions / risks / options / questions) |
| `claude-decision.md` | GSD decision format (on_understanding / on_options / on_risks / answers / next_action) |
| `plan.md` | GSD `PLAN.md` structure (plan_steps / verification_criteria / risk_mitigations) |
| `plan-review-result.md` | GSD `REVIEW.md` structure for plan review (decision / rationale / review_dimensions) |
| `result-review-result.md` | GSD `REVIEW.md` structure for result review (decision / rationale / review_dimensions) |
| `codex-result.md` | GSD verification format (summary / verification_results / tests_status) |

#### 3.5.2 Command Invocation Layer (Claude Code and Codex Only)

**Claude Code (Supervisor) — `/gsd-xxx` prefix**

Claude Code runs in its own tmux session with full Claude Code capabilities, including GSD skills. When generating file bus content, it invokes the corresponding GSD commands:

| File Bus Action | GSD Command(s) Invoked | 备注 |
|-----------------|------------------------|------|
| Respond to `codex-question.md` (status: `discussion`) | `/gsd-discuss-phase <phase> --auto` | ✅ 无头安全 |
| Review `plan.md` | 结构化检查清单（非 GSD 命令） | ⚠️ code-review 不适用于计划文档 |
| Review `codex-result.md` | 结构化检查清单 + `/gsd-validate-phase` | ✅ 验证可用 |
| Verify phase completion | `/gsd-validate-phase` | ✅ 无头安全 |

**❌ Claude Code 不应在无头流程中调用的命令：**
- `/gsd-verify-work` — 交互式 UAT，需用户在场
- `/gsd-complete-milestone`, `/gsd-new-milestone`, `/gsd-plan-milestone-gaps` — 全局状态操作，由人工控制
- `/gsd-extract_learnings` — 通常在人工审阅后触发

**Codex (Executor) — `$gsd-xxx` prefix**

Codex runs in its own tmux session and uses the `$` prefix for GSD skill invocations (platform duality: Codex uses `~/.codex/agents/` with `.toml` files). When generating file bus content, it invokes:

| File Bus Action | GSD Command(s) Invoked | 备注 |
|-----------------|------------------------|------|
| Generate `codex-question.md` (status: `discussion`) | `$gsd-discuss-phase <phase> --auto` | ✅ 无头安全 |
| Generate `plan.md` | `$gsd-plan-phase <phase> --auto --skip-research` | ⚠️ 有条件（见 Section 9.3） |
| Debug issues during execution | `$gsd-debug` | ✅ 无头安全 |
| Add tests for verification | `$gsd-add-tests` | ✅ 无头安全 |

**❌ Codex 不应在无头流程中调用的命令：**
- `$gsd-verify-work` — 无任何 `--auto` 支持，必然卡死

**⚠️ Codex Sandbox 配置（必须）：**
```bash
# 所有 Codex 命令必须附加 sandbox 绕过标志
codex exec "$gsd-discuss-phase <phase> --auto" -s danger-full-access
```

**Hermes (Orchestrator) — NO GSD commands**

Hermes is the top-level orchestrator and does **not** run inside Claude Code or Codex environments. Therefore it **does not execute any GSD commands**. However, when generating `task.md`, the `description` field follows GSD `PLAN.md` format conventions (Goal / Context / Deliverables / Assumptions / Risks).

#### 3.5.3 Flow Example with GSD Integration

```
Hermes writes task.md (GSD PLAN.md format, no command execution)
  |
  v
Codex reads task.md -> detects collaboration_mode
  Codex internally: $gsd-discuss-phase -> generates codex-question.md
  (GSD discuss format, status: "discussion")
  |
  v
Claude Code reads codex-question.md
  Claude internally: /gsd-discuss-phase -> generates claude-decision.md
  (GSD decision format, status: "discussion-response")
  |
  v
(repeat 1-N rounds)
  |
  v
Codex internally: $gsd-plan-phase -> generates plan.md
(GSD PLAN.md format)
  |
  v
Claude Code reads plan.md
  Claude internally: structured checklist review -> generates plan-review-result.md
  (GSD REVIEW.md format)
  |
  v
If APPROVED:
  Codex executes code -> self-verification (tests) -> generates codex-result.md
  (GSD verification format)
  |
  v
  Claude Code reads codex-result.md
    Claude internally: structured checklist review + /gsd-validate-phase -> final result-review-result.md
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

### 4.1 详细 Schema 字段定义（方案C补充）

#### `codex-question.md` — `status: "discussion"` 扩展

```json
{
  "schema_version": "1.0",
  "message_id": "msg-{uuid}",
  "project_id": "{project}",
  "task_id": "{task_id}",
  "correlation_id": "{corr-id}",
  "status": "discussion",
  "author": "codex",
  "authority": "executor",
  "timestamp": "{iso8601}",
  "body": {
    "understanding_summary": "Codex 对需求的理解摘要",
    "proposed_options": [
      {
        "option_id": "A",
        "description": "方案描述",
        "trade_offs": { "pros": ["..."], "cons": ["..."] },
        "estimated_effort": "2-3 days"
      }
    ],
    "identified_risks": [
      { "risk": "...", "severity": "medium", "mitigation_idea": "..." }
    ],
    "identified_assumptions": ["假设1", "假设2"],
    "questions_for_claude": ["问题1", "问题2"],
    "discussion_round": 1,
    "gsd_phase": "19"
  }
}
```

**关键字段说明：**
- `status`: **必须**为 `"discussion"`，Watcher 据此路由到 `route_discussion_to_claude()`
- `body.discussion_round`: 当前讨论轮次，从 1 开始。Watcher 用此验证计数文件一致性
- `body.gsd_phase`: GSD Phase 编号，Claude/Codex 执行 `$gsd-discuss-phase {{gsd_phase}} --auto` 时使用

#### `claude-decision.md` — `status: "discussion-response"` 扩展

```json
{
  "schema_version": "1.0",
  "message_id": "msg-{uuid}",
  "project_id": "{project}",
  "task_id": "{task_id}",
  "correlation_id": "{corr-id}",
  "status": "discussion-response",
  "author": "claude",
  "authority": "supervisor",
  "timestamp": "{iso8601}",
  "body": {
    "on_understanding": "确认或纠正 Codex 的理解",
    "on_options": {
      "challenges": ["选项A的盲区", "选项B的遗漏"],
      "alternatives": ["补充方案C"]
    },
    "on_risks": {
      "supplemental_risks": ["Codex 遗漏的风险1"],
      "risk_assessment_updates": { "...": "..." }
    },
    "answers": ["对 Codex 问题的直接回答"],
    "next_action": "continue_discussion",
    "convergence_notes": "可选：当接近共识时的总结"
  }
}
```

**关键字段说明：**
- `status`: **必须**为 `"discussion-response"`，Watcher 据此决定路由回 Codex 而非调用 `continue_codex_after_decision()`
- `body.next_action`: `"continue_discussion"` 或 `"proceed_to_plan"`。Watcher 不验证此字段内容，仅作为 Codex 的输入；但 Watcher 的 `max_discussion_rounds` 逻辑会覆盖此字段的语义
- **禁止字段**：`execution.authority_sufficient` — 这不是最终决策，不设置执行权限

#### `plan.md` — 完整 Schema

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
      {
        "step": 1,
        "action": "具体执行动作",
        "verification": "如何验证此步骤完成",
        "estimated_time": "30m",
        "dependencies": []
      }
    ],
    "verification_criteria": ["验收标准1", "验收标准2"],
    "risk_mitigations": [
      { "risk": "风险描述", "mitigation": "缓解措施" }
    ],
    "discussion_rounds": 3,
    "gsd_phase": "19",
    "source": "gsd-plan-phase"
  }
}
```

**关键字段说明：**
- `body.discussion_rounds`: 记录产生此 plan 前经过了多少轮讨论（用于审计）
- `body.gsd_phase`: 生成计划时使用的 GSD Phase 编号
- `body.source`: `"gsd-plan-phase"`（正常路径）或 `"fallback-self-generated"`（超时后 Codex 自行生成）或 `"human-approved-fallback"`（人工确认后）。Watcher 据此决定是否允许进入自动化 plan review。

#### `plan-review-result.md` — 新增文件（区分 review 目标）

```json
{
  "schema_version": "1.0",
  "message_id": "msg-{uuid}",
  "project_id": "{project}",
  "task_id": "{task_id}",
  "correlation_id": "{corr-id}",
  "status": "review",
  "author": "claude",
  "authority": "supervisor",
  "timestamp": "{iso8601}",
  "body": {
    "review_target": "plan",
    "decision": "APPROVED",
    "rationale": "详细审阅意见",
    "structured_issues": [
      {
        "severity": "major|minor|info",
        "category": "feasibility|completeness|correctness|backward_compatibility|security",
        "description": "...",
        "recommendation": "..."
      }
    ],
    "review_dimensions": {
      "feasibility": { "score": 4, "max": 5, "notes": "..." },
      "completeness": { "score": 3, "max": 5, "notes": "..." },
      "correctness": { "score": 4, "max": 5, "notes": "..." },
      "backward_compatibility": { "score": 5, "max": 5, "notes": "..." },
      "security": { "score": 4, "max": 5, "notes": "..." }
    }
  }
}
```

**关键字段说明：**
- `body.review_target`: **必须**为 `"plan"`，Watcher 据此调用 `route_plan_review_to_codex()`
- `body.decision`: `APPROVED`、`NEEDS_MODIFICATION` 或 `REJECTED`
- `body.review_dimensions`: 五维评分，与 GSD REVIEW.md 格式对齐

#### `result-review-result.md` — 新增文件（区分 review 目标）

结构与 `plan-review-result.md` 相同，仅 `body.review_target` 为 `"result"`，Watcher 据此调用 `route_result_review_to_codex()`（即现有的 `finalize_review_if_ready()` 逻辑）。

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
- [ ] Codex executor skill documents `$gsd-discuss-phase`, `$gsd-plan-phase` usage, `$` prefix convention, and `-s danger-full-access` sandbox requirement
- [ ] Codex executor skill explicitly documents `$gsd-verify-work` as **unavailable in headless mode**
- [ ] Claude supervisor skill documents `/gsd-discuss-phase` usage and `/` prefix convention
- [ ] Claude supervisor skill documents which GSD commands are **interactive-only** (`/gsd-verify-work`) and **must not be automated**
- [ ] All file bus documents (`task.md`, `codex-question.md`, `claude-decision.md`, `plan.md`, `plan-review-result.md`, `result-review-result.md`, `codex-result.md`) follow GSD format conventions as documented in Section 3.5.1
- [ ] Hermes `task.md` generation follows GSD `PLAN.md` format in the `description` field (Goal / Context / Deliverables / Assumptions / Risks)
- [ ] Codex executor environment is configured with `-s danger-full-access` for all automated executions
- [ ] **（方案C）** `$STATE_DIR/discussion-count` 文件在任务完成后被正确清理，不泄漏到下一个任务
- [ ] **（方案C）** 当 `discussion-count` 达到 `max_discussion_rounds` 时，Watcher 强制终止讨论并走标准决策路径
- [ ] **（方案C）** 无 `collaboration_mode` 的 `task.md` 完全不读取/不写入 `$STATE_DIR/discussion-count`，现有流程 100% 不变
- [ ] **（方案C）** `plan-review-result.md` 和 `result-review-result.md` 的 `review_target` 字段被 Watcher 正确解析和路由
- [ ] **（方案C）** `plan.md` 的 `body.source` 字段正确反映 `"gsd-plan-phase"` 或 `"fallback-self-generated"`
- [ ] `route_plan_to_review()` 检测到 `body.source: "fallback-self-generated"` 时写入 `escalation.md` 而非进入自动化 plan review
- [ ] `body.source` 缺失时默认视为 `"gsd-plan-phase"`，不触发 escalation
- [ ] Escalation 包含足够的上下文（原始命令、超时秒数、讨论轮数）供人工判断
- [ ] 人工修改 `body.source` 为 `"human-approved-fallback"` 后可正常进入 plan review

---

## 6. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Watcher state machine becomes too complex | High | Add comprehensive unit tests for `process_once()` branching logic |
| Codex/Claude enter infinite discussion loop | Medium | Add `max_discussion_rounds` (e.g., 5) to `task.md`; watcher forces `proceed_to_plan` after limit |
| `plan.md` review blocks indefinitely | Medium | Add plan review timeout; default to `APPROVED` with warning if supervisor unresponsive |
| Backward compatibility break | High | Keep `status: "question"` as default; `"discussion"` is opt-in via `collaboration_mode` |
| `plan.md` 来源不可信（Fallback 自生成） | High | Fallback plan 强制走 `escalation.md` 关卡；`body.source` 字段 + `route_plan_to_review()` 前置检查 |
| File bus clutter (many round files) | Low | Watcher archives old discussion files after plan is approved |
| Codex sandbox bypass security risk | Medium | `-s danger-full-access` 仅用于受信任的本地/容器环境；CI/CD 中需评估是否接受此风险或寻求其他方案 |

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

---

## 9. POC 测试记录与结论

> 本节记录 2026-04-28 针对本 Backlog 进行的架构对齐讨论和两轮 POC 测试结果。
> 完整 POC 报告见 `docs/orchestra/poc-headless-gsd-execution.md`。

### 9.1 架构关系澄清（已确认）

**已达成一致的架构关系：**

```
用户 → Hermes（调度器，分配 phase，管理文件总线）
  ↓
Hermes → Claude Code（监督者 tmux session）：读取需求/PRD，执行 /gsd-xxx
  ↓
Claude Code → Codex（执行者 tmux session）：监督 Codex 执行 $gsd-xxx
  ↓
Codex 有问题时 → 文件总线（codex-question.md）→ Claude Code 决策
Codex 无问题时 → 继续执行 GSD 命令
```

**关键约定：**
- ✅ Hermes **不执行** GSD 命令，只负责基础调度和文件总线管理
- ✅ Claude Code 在自己的 tmux session 中执行 `/gsd-xxx` 命令
- ✅ Codex 在自己的 tmux session 中执行 `$gsd-xxx` 命令（自定义约定前缀）
- ✅ GSD 命令只安装在 Claude Code 和 Codex 环境中

### 9.2 执行环境要求（新增）

#### Codex CLI Sandbox 配置

POC 测试确认：**Codex CLI 在 Linux 默认 sandbox 下完全无法执行本地命令**（`bwrap: setting up uid map: Permission denied`）。

**必须配置：**
```bash
# Codex 执行命令必须添加 sandbox 绕过标志
codex exec "<skill> <args>" -s danger-full-access
```

**影响范围：**
- 所有 Codex 自动化脚本、CI/CD 流水线、无人值守执行场景
- 仅 Codex 需要此配置；Claude Code 无此限制

**风险说明：**
- `-s danger-full-access` 授予 Codex 对文件系统的完全读写权限
- 仅在受信任的本地/容器环境中使用，不要在共享/生产环境使用
- 这是当前 Linux 环境下 Codex 能执行任何本地操作的**唯一可行方案**

### 9.3 GSD 命令无头模式可用性评估

### 9.3 GSD 命令无头模式可用性评估

基于对 GSD 技能源代码（`~/.claude/skills/gsd-*/SKILL.md`）和工作流文件（`~/.claude/get-shit-done/workflows/*.md`）的实际读取和两轮 POC 测试。

| GSD 命令 | 无头模式可用性 | 说明 |
|----------|--------------|------|
| `/gsd-discuss-phase <phase> --auto` | ✅ 可用 | `auto.md` 完整覆盖所有 AskUserQuestion 点，可安全无人值守运行 |
| `/gsd-plan-phase <phase> --auto` | ⚠️ 有条件可用 | `--auto` 只控制步骤 15 的自动推进，**不覆盖** 4 个中间交互点（Phase Split, Source Audit Gaps, Revision Stall, Decision Coverage Gate） |
| `/gsd-verify-work` | ❌ **不可用** | **无任何 `--auto` 支持**，3 个核心交互点全部要求 "Wait for user response"，无头模式必然卡住 |
| TTY 环境检测 | ❌ 不存在 | GSD 工作流没有任何 `isatty`/`stdin` 检测逻辑，`--text` 仍需要用户输入 |

**关键结论：**
1. **`gsd-verify-work` 是无头模式的绝对禁区**——其设计哲学「Show expected, ask if reality matches」本质就是交互式 UAT，不可能通过 `--auto` 绕过
2. **`gsd-plan-phase` 的交互风险是概率性的**——取决于代码库状态，不是每次都触发，但一旦触发就会卡住
3. **只有 `gsd-discuss-phase --auto` 是真正的无人值守安全命令**

---

### 9.4 已确认需修正的内容

| BACKLOG.md 位置 | 原内容 | 需修正为 | 原因 |
|----------------|--------|---------|------|
| Section 3.2 Step 3 | `$gsd-discuss-phase` | `$gsd-discuss-phase <phase> --auto` | 需要 phase 参数和 --auto |
| Section 3.2 Step 7 | `$gsd-plan-phase` | `$gsd-plan-phase <phase> --auto --skip-research` | 需要参数；加 `--skip-research` 规避一个交互点 |
| Section 3.2 Step 10 | `$gsd-verify-work` | **删除** → 改为人工验收步骤 | verify-work 无 --auto，无头模式不可用 |
| Section 3.3 Step 2 | `/gsd-discuss-phase` | `/gsd-discuss-phase <phase> --auto` | 需要 phase 参数和 --auto |
| Section 3.3 Plan Review | `/gsd-code-review` 审阅 plan.md | **手动审阅**或结构化检查清单 | code-review 审的是代码，不是计划文档 |
| Section 3.3 Plan Review | `/gsd-verify-work` 验证 plan | **删除** | verify-work 是交互式 UAT |
| Section 3.3 Milestone | `/gsd-complete-milestone` 等 | **删除** → 交给人工 GSD 流程 | 里程碑是全局状态操作，不应由普通任务自动触发 |
| Section 3.5.2 Codex | `$gsd-verify-work` 映射 | **删除该映射** | 无人值守不可用 |
| Section 3.5.2 Claude | `/gsd-verify-work` 验证 plan/result | **删除或标注"需交互式会话"** | 只能在 Claude Code 交互式会话中使用 |
| Section 3.5.2 Claude | `/gsd-complete-milestone` 等 | **删除** | 不应自动化触发 |

---

### 9.5 待确认问题

以下问题需要昴君拍板：

#### 问题 1：Phase 参数传递机制 ✅ 已确认

**方案：A — Hermes 在 `task.md` 中写入 `gsd_phase` 字段**

```yaml
# task.md 新增字段
gsd_phase: "19"           # GSD Phase 编号，Codex/Claude 读取后用于 GSD 命令参数
gsd_phase_name: "collaborative-planning-protocol"  # 可选：人类可读的 phase 名称
```

Codex 执行时：`$gsd-discuss-phase {{gsd_phase}} --auto`
Claude 执行时：`/gsd-discuss-phase {{gsd_phase}} --auto`

---

#### 问题 2：GSD 产物与文件总线内容的关系 ✅ 已确认

**方案：C — 分离式**

| 维度 | GSD 产物 (`.planning/phases/`) | 文件总线 (`$RUNTIME_DIR/`) |
|------|-------------------------------|---------------------------|
| **用途** | GSD 框架的标准规划产物 | Codex-Claude 之间的沟通媒介 |
| **消费者** | GSD 命令本身、人类审阅 | Watcher、Codex、Claude |
| **生命周期** | 长期保留，归档后仍在 | 任务完成后清理 |
| **格式** | GSD 标准格式 (CONTEXT.md, PLAN.md) | 文件总线 JSON/Markdown 混合 |
| **关系** | 文件总线 `plan.md` 可引用 GSD PLAN.md，但不直接映射 | 独立存在，不反向写入 GSD 产物 |

**关键原则：** 文件总线不污染 GSD 产物目录；GSD 产物不直接作为文件总线消息。

---

#### 问题 3：`$gsd-plan-phase` 的交互风险缓解 ✅ 已确认

**方案：B + C 组合 — 前置配置缓解 + Fallback 自行生成**

**第一层缓解（配置层）：**
调用 plan-phase 前，Codex 先写入 `auto_advance` 配置（参考 `gsd_commands_reference.md` 中 GSD SDK 的 `autoMode` 机制）：

```bash
# Codex 执行 plan-phase 前的前置步骤
echo '{"workflow":{"auto_advance":true,"skip_discuss":false,"max_discuss_passes":3}}' \
  > .planning/config.json
codex exec "$gsd-plan-phase {{gsd_phase}} --auto --skip-research" -s danger-full-access
```

这能消除 **discuss 步骤**的交互阻塞，但对 planner 代理输出的 4 个条件交互点（Phase Split, Source Audit Gaps, Revision Stall, Decision Coverage Gate）**无法预知**。

**第二层保底（Fallback）：**
如果 Watcher 检测到 plan-phase 调用超时（>5 分钟无输出），强制 kill 并 fallback：

```bash
# Watcher 中的超时处理
if timeout 300 codex exec "$gsd-plan-phase {{gsd_phase}} --auto --skip-research" -s danger-full-access; then
    # 正常完成，plan.md 已生成
else
    # 超时或卡住 → 通知 Codex 自行生成 plan.md（不调用 GSD 命令）
    echo "plan_phase_timeout" > "$RUNTIME_DIR/codex-signal.md"
fi
```

Codex 收到 timeout 信号后，自行根据讨论内容生成 `plan.md`（借用 GSD PLAN.md 格式规范，但不调用 `$gsd-plan-phase`）。

---

#### 问题 4：`review-result.md` 的双重用途 ✅ 已确认

**方案：C — 使用不同的文件名**

| 审阅目标 | 文件名 | Watcher 路由 |
|---------|--------|-------------|
| 审阅 `plan.md` | `plan-review-result.md` | `route_plan_review_to_codex()` |
| 审阅 `codex-result.md` | `result-review-result.md` | `route_result_review_to_codex()` |

**Watcher 处理逻辑：**

```bash
# process_once() 中新增
if [ -f "$RUNTIME_DIR/plan-review-result.md" ]; then
    route_plan_review_to_codex
    return 0
fi

if [ -f "$RUNTIME_DIR/result-review-result.md" ]; then
    route_result_review_to_codex
    return 0
fi
```

**优势：** 文件名即语义，无需解析文件内容即可路由；避免 `review_target` 字段的解析复杂性和状态推断的不确定性。

---

### 9.6 总体评估

**BACKLOG.md 当前状态：整体架构设计正确，但 GSD 集成细节需要修正，且需正视无头模式的硬边界。**

| 维度 | 评估 |
|------|------|
| 协作规划模式概念 | ✅ 正确且有价值 |
| 文件总线状态机扩展 | ✅ 正确（discussion / plan / review 状态） |
| Watcher 路由逻辑 | ✅ 正确 |
| GSD 命令调用方式 | ⚠️ 需要修正（加 --auto、phase 参数、处理交互风险） |
| **无头模式边界认知** | ⚠️ **需要明确：哪些步骤必须转人工** |
| verify-work 的使用 | ❌ **必须删除或转人工** |
| code-review 审阅 plan | ❌ **语义不匹配，需替换** |
| milestone 自动化触发 | ❌ **全局状态操作，不应自动化** |
| Codex sandbox 配置 | ❌ **未提及，必须补充** |
| GSD 产物与文件总线关系 | ❌ 未定义 |

**已明确的硬边界（无需昴君确认）：**
- `gsd-verify-work` 在任何无头/无人值守场景下都**不可用**
- 里程碑操作（`gsd-complete-milestone` 等）**不应由普通任务自动触发**
- Codex CLI 在 Linux 下**必须**使用 `-s danger-full-access`

**所有待确认问题已解决（昴君 2026-04-29 确认）：**
- ✅ 问题 1：Phase 参数通过 `task.md` 中 `gsd_phase` 字段传递（方案 A）
- ✅ 问题 2：GSD 产物与文件总线完全分离（方案 C）
- ✅ 问题 3：plan-phase 交互风险采用 B+C 组合（前置 `auto_advance` 配置 + Watcher 超时 fallback）
- ✅ 问题 4：review-result 使用不同文件名区分（`plan-review-result.md` / `result-review-result.md`，方案 C）

**下一步建议：**
1. 蕾姆根据所有确认结果起草 BACKLOG.md 修正版本（本节内容已可直接作为最终规范）
2. 将协作规划模式作为 Phase 19 纳入 v1.3 里程碑规划
3. 同步更新 Codex 执行环境的 sandbox 配置文档
4. 更新 `skills/codex-executor/SKILL.md`、`skills/claude-supervisor/SKILL.md`、`skills/dev-orchestra/SKILL.md` 以反映最终方案

---

## 10. 边界条件处理（方案C补充）

本节详细定义协作规划模式下的边界条件处理机制，作为方案C的核心补充。

### 10.1 max_discussion_rounds 强制终止

**触发条件：** `$STATE_DIR/discussion-count` >= `max_discussion_rounds`

**处理流程：**

```
1. Watcher 在 process_once() 中检测到 codex-question.md (status: "discussion")
2. 读取 discussion-count（默认为 0）
3. 若 count >= max_rounds:
   a. 记录日志："max discussion rounds reached; forcing convergence"
   b. 写入信号文件：echo "forced_convergence" > "$RUNTIME_DIR/.discussion-forced"
   c. 调用 route_question_to_claude() —— 使用标准决策提示
   d. 标准决策提示中附加说明："注意：讨论已达到最大轮数，请做出最终决策"
   e. Claude 写入的 claude-decision.md 应设置 execution.authority_sufficient
   f. 后续走标准 continue_codex_after_decision() 路径
4. 若 count < max_rounds:
   a. count += 1
   b. 写入 $STATE_DIR/discussion-count
   c. 调用 route_discussion_to_claude()
```

**Codex 侧配合：**
- Codex 在读取 `claude-decision.md` 时，若发现存在 `$RUNTIME_DIR/.discussion-forced`，应理解为讨论被强制收敛，不再发起新一轮讨论，直接进入 `$gsd-plan-phase`
- 这是 Codex 的合作性行为，Watcher 不强制检查

### 10.2 plan-phase 超时 fallback

**触发条件：** Codex 执行 `$gsd-plan-phase {{gsd_phase}} --auto --skip-research` 超过 300 秒无输出

**前置缓解（配置层）：**

```bash
# Codex 执行 plan-phase 前的前置步骤
cat > .planning/config.json <<'EOF'
{
  "workflow": {
    "auto_advance": true,
    "skip_discuss": false,
    "max_discuss_passes": 3
  }
}
EOF
```

**Watcher 超时处理：**

```bash
# 在 dispatch_codex_task 或专门的 plan-phase 触发函数中
timeout 300 bash -c '
  codex exec "$gsd_plan_phase_cmd" -s danger-full-access
' && plan_success=true || plan_success=false

if [ "$plan_success" = "false" ]; then
    log_loop "plan-phase timeout after 300s; signaling fallback"
    echo "plan_phase_timeout" > "$RUNTIME_DIR/.codex-signal"
    # 不阻止 Codex 继续，Codex 读取信号后自行生成 plan.md
fi
```

**Codex fallback 行为：**
- Codex 检测到 `.codex-signal` 内容为 `plan_phase_timeout` 时：
  1. 不调用 `$gsd-plan-phase`
  2. 基于已有的讨论内容，自行构建 `plan.md`
  3. `body.source` 设置为 `"fallback-self-generated"`
  4. `body.plan_steps` 格式遵循 GSD PLAN.md 规范

#### 10.2.1 Fallback 计划审阅关卡（补丁A）

**问题：** Codex 在 plan-phase 超时后自行生成的 `plan.md`，其质量依赖于前几轮讨论的
文字摘要，而非 GSD 框架的代码库分析、依赖检查和风险评估。这种 plan 存在隐性缺陷：
假设的前提可能已不成立、文件路径可能已变更、依赖关系可能未验证。

**决策：** 所有 `body.source` 为 `"fallback-self-generated"` 的 `plan.md` **不得**进入自动化
plan review 流程。必须强制升级到人工确认。

**Watcher 实现：**

在 `route_plan_to_review()` 函数顶部增加 `source` 字段检查：

```bash
route_plan_to_review() {
    local plan_source
    plan_source="$(orch_json_field "$RUNTIME_DIR/plan.md" "body.source")"

    if [ "$plan_source" = "fallback-self-generated" ]; then
        orch_write_escalation \
            "plan.md was generated by Codex after plan-phase timeout (source: fallback-self-generated). " \
            "This plan bypassed GSD framework analysis and may contain unverified assumptions. " \
            "Human review required before proceeding to execution." \
            "$RUNTIME_DIR/escalation.md"
        orch_write_project_state "escalated_plan_fallback" "$(task_id_from_bus)"
        log_loop "plan.md source is fallback-self-generated; escalated to human review"
        return 0
    fi

    # --- existing plan review logic below (unchanged) ---
    ...
}
```

**Escalation 内容格式：**

```json
{
  "schema_version": "1.0",
  "message_id": "msg-{uuid}",
  "project_id": "{project}",
  "task_id": "{task_id}",
  "correlation_id": "{corr-id}",
  "status": "escalation",
  "author": "hermes-watcher",
  "authority": "orchestrator",
  "timestamp": "{iso8601}",
  "body": {
    "escalation_type": "plan_fallback_quality",
    "severity": "medium",
    "summary": "Plan was self-generated after GSD plan-phase timeout; unverified assumptions",
    "required_action": "Human operator must review plan.md and either (a) approve as-is, (b) reject and request Codex to retry with GSD, or (c) manually provide corrected plan.md",
    "artifacts_to_review": ["$RUNTIME_DIR/plan.md", "$RUNTIME_DIR/.codex-signal"],
    "context": {
      "original_plan_phase_cmd": "$gsd_plan_phase_cmd",
      "timeout_seconds": 300,
      "discussion_rounds": "{from plan.md body.discussion_rounds}"
    }
  }
}
```

**人工操作员选项：**

| 操作 | 效果 |
|------|------|
| 删除 `escalation.md` 并保留 `plan.md` | Watcher 下一循环检测到 plan.md，重新进入 `route_plan_to_review()`，此时 source 仍为 fallback，**再次 escalation** |
| 修改 `plan.md` 的 `body.source` 为 `"human-approved-fallback"` | Watcher 允许进入自动化 plan review |
| 删除 `plan.md` 并写新的 `task.md`（调整 gsd_phase 或 execution_steps）| 重置流程，绕过协作规划 |
| 手动在 `$RUNTIME_DIR/` 放置经人工校验的 `plan.md` | 需同时修改 source 字段，否则继续 escalation |

**向后兼容性：**
- 非协作模式（无 `collaboration_mode`）的 task.md 不触发此检查
- `body.source` 字段缺失时，默认视为 `"gsd-plan-phase"`（即正常流程），避免对未实现 source 字段的旧版本 plan.md 产生误报

### 10.3 状态泄漏防护

**问题：** `$STATE_DIR/discussion-count` 若未清理，下一个任务可能错误继承计数。

**防护措施：**

| 场景 | 清理动作 | 执行者 |
|------|---------|--------|
| 任务完成（APPROVED/REJECTED） | `rm -f "$STATE_DIR/discussion-count"` | `finalize_review_if_ready()` |
| Watcher 启动/重启 | 检查 `$RUNTIME_DIR/task.md` 存在性；若不存在则清理 | `process_once()` 入口 |
| 新任务 dispatch | `echo 0 > "$STATE_DIR/discussion-count"` | `dispatch_codex_task()`（仅在协作模式下） |
| 项目停止 (`orch-stop`) | 清理所有 `$STATE_DIR/discussion-*` | `orch-stop` 脚本 |

**向后兼容性保证：**

```bash
# 在 process_once() 中，非协作模式必须完全跳过协作逻辑
is_collaborative_mode() {
    local mode
    mode="$(orch_json_field "$RUNTIME_DIR/task.md" "collaboration_mode")"
    [ "$mode" = "adversarial-planning" ]
}

# 所有新增分支前加保护
if is_collaborative_mode; then
    # 协作模式逻辑
else
    # 原有逻辑，100% 不变
fi
```

### 10.4 文件总线冲突防护

**问题：** 如果 `codex-question.md` 和 `plan.md` 同时存在（理论上不应发生），Watcher 的处理优先级。

**优先级顺序（`process_once()` 中从上到下）：**

1. `escalation.md`（最高优先级，安全优先）
2. `plan-review-result.md`（plan 审阅结果需要处理）
3. `result-review-result.md`（result 审阅结果需要处理）
4. `plan.md`（plan 等待审阅）
5. `claude-decision.md` + `codex-question.md`（标准决策后继续）
6. `codex-question.md`（新问题/讨论）
7. `task.md`（派发新任务）

此顺序确保：plan 审阅结果优先于 plan 本身；plan 本身优先于新一轮讨论。

### 10.5 计数文件与 Codex 自报轮次的一致性检查

**问题：** Codex 在 `codex-question.md` 的 `body.discussion_round` 中自报轮次，Watcher 在 `$STATE_DIR/discussion-count` 中独立计数。两者可能不一致（如 Codex 写入失败导致重试）。

**处理策略：**
- Watcher 以 `$STATE_DIR/discussion-count` 为权威来源（它是 Watcher 自己维护的）
- `body.discussion_round` 仅用于审计和日志记录，不参与路由决策
- 若两者差异 > 1，记录警告日志：`log_loop "WARNING: discussion_round mismatch: codex=$codex_round watcher=$watcher_count"`
