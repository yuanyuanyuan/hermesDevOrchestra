# Phase 22: External CLI Engine Protocol & Role Invocation - Pattern Map

**Mapped:** 2026-05-11
**Files analyzed:** 20
**Analogs found:** 20 / 20

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `docs/orchestra/scripts/bin/orch-profile-sync` | utility | transform | `docs/orchestra/scripts/bin/orch-profile-sync` | exact |
| `docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml` | config | transform | `docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml` | exact |
| `docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml` | config | transform | `docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml` | exact |
| `docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml` | config | transform | `docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml` | exact |
| `docs/orchestra/hermes/profile-distribution/distribution.yaml` | config | transform | `docs/orchestra/hermes/profile-distribution/distribution.yaml` | exact |
| `.hermes/profiles/README.md` | utility | transform | `.hermes/profiles/README.md` | exact |
| `docs/orchestra/README.md` | utility | request-response | `docs/orchestra/README.md` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md` | config | request-response | `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/roles/pm.md` | config | request-response | `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/roles/implementer.md` | config | request-response | `docs/orchestra/scripts/bin/orch-bus-loop` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/roles/reviewer.md` | config | request-response | `docs/orchestra/scripts/bin/orch-bus-loop` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/examples/pm.request.json` | config | request-response | `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/examples/pm.response.question.json` | config | request-response | `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/examples/implementer.request.json` | config | request-response | `docs/orchestra/scripts/bin/orch-bus-loop` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/examples/implementer.response.complete.json` | config | request-response | `docs/orchestra/scripts/tests/test-file-bus.sh` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/examples/reviewer.request.json` | config | request-response | `docs/orchestra/scripts/bin/orch-bus-loop` | role-match |
| `docs/orchestra/hermes/role-engine-protocol/v1/examples/reviewer.response.findings.json` | config | request-response | `docs/orchestra/scripts/tests/test-file-bus.sh` | role-match |
| `docs/orchestra/scripts/tests/test-profile-packaging.sh` | test | transform | `docs/orchestra/scripts/tests/test-profile-packaging.sh` | exact |
| `docs/orchestra/scripts/tests/test-project-isolation.sh` | test | transform | `docs/orchestra/scripts/tests/test-project-isolation.sh` | exact |
| `docs/orchestra/scripts/tests/test-role-engine-protocol.sh` | test | request-response | `docs/orchestra/scripts/tests/test-file-bus.sh` | role-match |

## Pattern Assignments

### `docs/orchestra/scripts/bin/orch-profile-sync` (utility, transform)

**Analog:** `docs/orchestra/scripts/bin/orch-profile-sync`

**Shell entry + Python handoff** (lines 1-18, 43-52):
```bash
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: orch-profile-sync <project-id> <project-dir>" >&2
    exit 1
fi

python3 - "$CATALOG_DIR" "$PROJECT_DIR" "$PROJECT_ID" "$WORKSPACE_ROOT" "$OVERRIDE_DIR" "$BOARD_SLUG" "$MEMORY_NAMESPACE" <<'PY'
import json
import os
import re
import shutil
import sys
```

**Config parse/merge shape** (lines 61-88, 101-115):
```python
def parse_inline_list(text: str):
    ...

def parse_config(path: str):
    data = {"model": "", "status": "", "enabled": [], "disabled": []}
    ...
    if line.startswith("model:"):
        data["model"] = line.split(":", 1)[1].strip()
    elif line.startswith("status:"):
        data["status"] = line.split(":", 1)[1].strip()
    elif line.startswith("enabled:"):
        data["enabled"] = parse_inline_list(line.split(":", 1)[1].strip())
    elif line.startswith("disabled:"):
        data["disabled"] = parse_inline_list(line.split(":", 1)[1].strip())

def merge_toolsets(base_enabled, base_disabled, override_enabled, override_disabled):
    enabled = unique(base_enabled)
    disabled = unique(base_disabled)
    ...
    return enabled, disabled
```

**Writeback pattern** (lines 135-142, 182-196):
```python
def write_config(path: str, status: str, model: str, enabled, disabled):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(f"status: {status}\n")
        handle.write(f"model: {model}\n")
        handle.write("toolsets:\n")
        handle.write(f"  enabled: [{', '.join(enabled)}]\n")
        handle.write(f"  disabled: [{', '.join(disabled)}]\n")

for role in role_names:
    base_config = parse_config(os.path.join(profiles_root, role, "config.yaml"))
    override_config = parse_config(os.path.join(override_dir, f"{role}.override.yaml"))
    enabled, disabled = merge_toolsets(...)
    model = override_config["model"] or base_config["model"]
    write_config(os.path.join(role_out, "config.yaml"), base_config["status"], model, enabled, disabled)
```

**Apply to Phase 22:** extend the existing `parse_config`/`write_config`/merge loop with `engine.cli`, `engine.mode`, `engine.flags`, `engine.fallback`; do not introduce a second compiler path.

---

### Per-role `config.yaml` defaults (config, transform)

**Files:**  
`docs/orchestra/hermes/profile-distribution/profiles/pm/config.yaml`  
`docs/orchestra/hermes/profile-distribution/profiles/implementer/config.yaml`  
`docs/orchestra/hermes/profile-distribution/profiles/reviewer/config.yaml`

**Analogs:** same files

**Current file shape**:

`pm/config.yaml` (lines 1-5)
```yaml
status: active
model: kimi-coding
toolsets:
  enabled: [kanban, memory, clarify, file_read]
  disabled: [terminal, file, code_execution, web, browser, delegation]
```

`implementer/config.yaml` (lines 1-5)
```yaml
status: active
model: codex
toolsets:
  enabled: [terminal, file, code_execution, memory, kanban]
  disabled: [delegation, messaging, browser]
```

`reviewer/config.yaml` (lines 1-5)
```yaml
status: active
model: claude
toolsets:
  enabled: [file_read, kanban_read, kanban_block, kanban_complete, clarify]
  disabled: [terminal, file_write, code_execution, delegation, messaging, browser, web]
```

**Apply to Phase 22:** add `engine:` directly under `model:` in the same minimal YAML style; keep one checked-in default per role and preserve reviewer read-only posture.

---

### `docs/orchestra/hermes/profile-distribution/distribution.yaml` (config, transform)

**Analog:** `docs/orchestra/hermes/profile-distribution/distribution.yaml`

**Catalog metadata pattern** (lines 1-5):
```yaml
version: 2026-05-10-phase21
canonical_reviewer_slug: reviewer
legacy_aliases:
  tech-reviewer: reviewer
active_profiles: [pm, orchestrator, researcher, implementer, reviewer, qa-tester, devops-engineer, sre-observer]
```

**Apply to Phase 22:** if catalog semantics change, bump `version:` here so generated `project.json` keeps reflecting the new contract generation.

---

### Override contract docs (utility, transform)

**Files:**  
`.hermes/profiles/README.md`  
`docs/orchestra/README.md`

**Analogs:** same files

**Repo-local override contract** from `.hermes/profiles/README.md` (lines 7-18):
```md
- `{role}.override.yaml` — project-local overrides for `model` and `toolsets.enabled/disabled`
- `{role}.project.md` — project-local SOUL fragment for the role

Merge rules:

- `model`: project value replaces base
- `toolsets.enabled/disabled`: merged sets, project value wins on conflict
- `SOUL.md`: assembled in `global -> project -> role` order
```

**Runtime path + JSON envelope narrative** from `docs/orchestra/README.md` (lines 240-254, 273-303):
```md
- `HERMES_HOME=.hermes/projects/{project_slug}/`
- `HERMES_KANBAN_BOARD={project_slug}`
- `HERMES_MEMORY_NAMESPACE=project:{project_slug}`

- Canonical base profile source 在 `docs/orchestra/hermes/profile-distribution/`
- 项目 override source 在 `{repo}/.hermes/profiles/`
- `reviewer` 是 runtime canonical slug

文件名保留 `.md` 兼容命名，但内容使用 canonical JSON envelopes：
`task.md`、`codex-question.md`、`claude-decision.md`、`codex-result.md`、`review-result.md`
都应包含 `schema_version`、`project_id`、`task_id`、`correlation_id`、`status`、`author`、`authority`、`timestamp` 等字段。
```

**Apply to Phase 22:** update these docs together with code so override semantics, runtime output path, canonical reviewer slug, and JSON envelope fields do not drift.

---

### `docs/orchestra/hermes/role-engine-protocol/v1/common-envelope.md` (config, request-response)

**Analog:** `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md`

**Shared request/response contract** (lines 125-165):
```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm | researcher | implementer | reviewer | qa-tester | devops | sre-observer",
  "task_type": "...",
  "correlation_id": "{role}-call-{project}-{task_id}-{turn}",
  "turn": 1,
  "project_workspace": "/data/projects/{project}",
  "task_id": "t_xxx",
  "task_body": "...",
  "conversation_history": [],
  "handoff_from_parent": {}
}
```

```json
{
  "protocol": "hermes-role-engine/v1",
  "correlation_id": "...",
  "status": "...",
  "turn": 1,
  "role_specific_payload": {},
  "next_action": "continue | wait_for_user | create_tasks | create_research_task | block | complete | defer_to_human",
  "deferred_tool_use": null,
  "conversation_context": []
}
```

**Status enum reference** (lines 167-177):
```md
| **PM** | `question`, `needs_research`, `requirement_ready`, `feasibility_issue` |
| **Implementer** | `task_complete`, `needs_decision`, `blocked`, `test_failed` |
| **Reviewer** | `approved`, `findings`, `rejected` |
```

**Apply to Phase 22:** make this file the canonical shared envelope doc, with one cross-role `next_action` enum and explicit note that `correlation_id` is trace-only.

---

### `docs/orchestra/hermes/role-engine-protocol/v1/roles/pm.md` (config, request-response)

**Analog:** `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md`

**PM request example** (lines 194-220):
```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm",
  "task_type": "clarification",
  "correlation_id": "pm-call-alpha-t42-1",
  "turn": 1,
  "project_workspace": "/data/projects/alpha",
  "task_id": "t_42",
  "task_body": "用户反馈每次重启浏览器都要重新登录",
  "conversation_history": [],
  "handoff_from_parent": null
}
```

**PM response patterns** (lines 223-252, 257-319, 324-344):
```json
{
  "role": "pm",
  "status": "question",
  "question": {
    "id": "q_1",
    "text": "核心目标是什么？",
    "options": [...]
  },
  "next_action": "wait_for_user"
}
```

```json
{
  "role": "pm",
  "status": "requirement_ready",
  "requirement_doc": {...},
  "tasks": [...],
  "next_action": "create_kanban_tasks"
}
```

```json
{
  "role": "pm",
  "status": "needs_research",
  "research": {...},
  "next_action": "create_research_task"
}
```

**Apply to Phase 22:** PM contract should stay multi-turn and metadata-backed, with role-specific payload carrying the meaning instead of inventing extra `next_action` values.

---

### `docs/orchestra/hermes/role-engine-protocol/v1/roles/implementer.md` (config, request-response)

**Analog:** `docs/orchestra/scripts/bin/orch-bus-loop`

**One-shot implementer invocation** (lines 225-240):
```bash
write_runner "$runner" cat <<EOF
{
  printf '%s\n' 'You are Codex Executor for project [$PROJECT_ID]. Read the JSON task envelope below. If blocked or uncertain, write a JSON question envelope to .../codex-question.md and stop. On completion, produce a JSON result envelope for codex-result.md.'
  cat .../task.md
} | codex exec --full-auto --json --output-last-message .../codex-result.md - > .../codex-events.jsonl 2>> .../codex.err
touch .../.codex-done
EOF
```

**Decision continuation pattern** (lines 366-427):
```bash
orch_correlation_compatible "$RUNTIME_DIR/task.md" "$RUNTIME_DIR/codex-question.md" "$RUNTIME_DIR/claude-decision.md" || {
    log_loop "correlation_id mismatch; not continuing Codex"
    return 0
}

if [ "$sufficient" != "true" ]; then
    orch_write_project_state "blocked" "$task_id"
    log_loop "authority insufficient; project blocked"
    return 0
fi

{
  printf '%s\n' 'You are Codex Executor ... Continue the task using the JSON task and Claude decision envelopes below.'
  cat .../task.md .../claude-decision.md
} | codex exec --full-auto --json --output-last-message .../codex-result.md -
```

**Apply to Phase 22:** implementer role docs should copy the repository's one-shot CLI pattern, trace `correlation_id`, and distinguish `needs_decision` / `blocked` / `task_complete` at the protocol level.

---

### `docs/orchestra/hermes/role-engine-protocol/v1/roles/reviewer.md` (config, request-response)

**Analog:** `docs/orchestra/scripts/bin/orch-bus-loop`

**Reviewer invocation + JSON unwrap** (lines 430-455):
```bash
cat .../codex-result.md | claude -p --output-format json --permission-mode auto \
  "You are Claude Supervisor ... write a JSON review envelope for review-result.md. Preserve project_id, task_id, and correlation_id when present. Include decision APPROVED, REJECTED, or NEEDS_MODIFICATION." \
  > .../review-result.raw.json 2>> .../claude.err

python3 - source target <<'PY'
import json
...
payload = wrapper.get("result", wrapper) if isinstance(wrapper, dict) else wrapper
if isinstance(payload, str):
    payload = json.loads(payload)
json.dump(payload, handle, ensure_ascii=False, indent=2)
PY
```

**Reviewer read-only boundary** from `.planning/phases/19-hermes-workflow-design/CONSISTENCY-CHECKLIST.md` (lines 120-122):
```md
Reviewer 的 Hermes toolset 和 CLI `--allowedTools` 都必须只读。
不能在示例里悄悄把 `terminal` 或写能力重新开回来。
```

**Apply to Phase 22:** reviewer contract must preserve incoming identifiers, emit structured review outcomes, and explicitly document the read-only boundary.

---

### Protocol example fixtures (config, request-response)

**Files:**  
`docs/orchestra/hermes/role-engine-protocol/v1/examples/pm.request.json`  
`docs/orchestra/hermes/role-engine-protocol/v1/examples/pm.response.question.json`  
`docs/orchestra/hermes/role-engine-protocol/v1/examples/implementer.request.json`  
`docs/orchestra/hermes/role-engine-protocol/v1/examples/implementer.response.complete.json`  
`docs/orchestra/hermes/role-engine-protocol/v1/examples/reviewer.request.json`  
`docs/orchestra/hermes/role-engine-protocol/v1/examples/reviewer.response.findings.json`

**Analogs:** Phase 19 request/response examples + existing inline JSON fixtures in `test-file-bus.sh`

**Fixture style from `test-file-bus.sh`** (lines 35-46, 62-80):
```json
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","status":"completed","author":"codex"}
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","status":"question","author":"codex","question":"Need decision"}
{"schema_version":"1.0","project_id":"test-proj","task_id":"task-1","correlation_id":"corr-1","decision":"APPROVED","author":"claude"}
```

**PM fixture content source** from Phase 19 (lines 196-252):
```json
{
  "protocol": "hermes-role-engine/v1",
  "role": "pm",
  "status": "question",
  "correlation_id": "pm-call-alpha-t42-1",
  "turn": 1,
  "question": {...},
  "next_action": "wait_for_user"
}
```

**Apply to Phase 22:** keep fixture files as pretty-printed golden JSON, not shell-generated strings; preserve `protocol`, `role`, `status`, `correlation_id`, `turn`, and role payload fields in every example.

---

### Config packaging tests (test, transform)

**Files:**  
`docs/orchestra/scripts/tests/test-profile-packaging.sh`  
`docs/orchestra/scripts/tests/test-project-isolation.sh`

**Analogs:** same files

**Temp HOME/runtime harness** from `test-profile-packaging.sh` (lines 11-19, 21-25):
```bash
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"

"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-profile-packaging-init.out
```

**Override + assert style** from `test-profile-packaging.sh` (lines 27-32, 48-50, 66-73):
```bash
cat > "$PROJECT_DIR/.hermes/profiles/implementer.override.yaml" <<'YAML'
model: claude
toolsets:
  enabled: [web]
  disabled: [code_execution]
YAML

assert_contains "model: claude" "$CONFIG_OUT" "override model not applied"
assert_contains "enabled: [terminal, file, memory, kanban, web]" "$CONFIG_OUT" "toolset merge output incorrect"

python3 - "$PROJECT_JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["project_slug"] == "test-proj"
...
PY
```

**Per-project isolation style** from `test-project-isolation.sh` (lines 27-45, 59-76):
```bash
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" alpha "$ALPHA_DIR"
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-init" beta "$BETA_DIR"

cat > "$ALPHA_DIR/.hermes/profiles/reviewer.override.yaml" <<'YAML'
model: alpha-model
YAML

assert_contains "model: alpha-model" "$ALPHA_CONFIG" "alpha override model missing"
assert_contains "model: beta-model" "$BETA_CONFIG" "beta override model missing"
```

**Apply to Phase 22:** extend these existing tests instead of inventing a new harness; add `engine` deep-merge assertions and project isolation assertions at the generated `config.yaml` output.

---

### `docs/orchestra/scripts/tests/test-role-engine-protocol.sh` (test, request-response)

**Analog:** `docs/orchestra/scripts/tests/test-file-bus.sh`

**Fixture-first shell test shape** (lines 11-18, 27-49, 66-86):
```bash
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FAKE_BIN="$TMP_DIR/bin"
make_fake_path "$FAKE_BIN"

cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
...
SH

for _ in 1 2 3 4; do
  "$REPO_ROOT/docs/orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once
done
assert_file_exists "$RUNTIME_DIR/codex-question.md" "codex-question.md not created"
...
```

**Assertion helpers** from `docs/orchestra/scripts/tests/lib/assert.sh` (lines 25-38, 47-57):
```bash
assert_contains() {
    local needle="$1"
    local file="$2"
    ...
    grep -Fq "$needle" "$file" || fail "$message" "$needle" "$(sed -n '1,40p' "$file" 2>/dev/null || true)"
}

assert_jsonl_valid() {
    local file="$1"
    python3 - "$file" <<'PY' || fail "invalid JSONL" "$file" "parse failed"
    ...
PY
}
```

**Apply to Phase 22:** new protocol smoke test should validate golden fixtures and failure taxonomy with the existing shell + inline Python assertion style, not a new test framework.

## Shared Patterns

### Profile Assembly And Deep Merge
**Source:** `docs/orchestra/scripts/bin/orch-profile-sync` lines 71-88, 101-115, 182-196  
**Apply to:** `orch-profile-sync`, per-role `config.yaml`, config packaging tests
```python
base_config = parse_config(...)
override_config = parse_config(...)
enabled, disabled = merge_toolsets(...)
model = override_config["model"] or base_config["model"]
write_config(...)
```

### Project-Scoped Runtime Contract
**Source:** `.hermes/profiles/README.md` lines 10-18; `docs/orchestra/README.md` lines 240-254  
**Apply to:** override docs, config tests, any protocol docs that mention runtime layout
```md
Generated project-scoped Hermes runtime output is written to:
`{repo}/.hermes/projects/{project_slug}/`

- `HERMES_HOME=.hermes/projects/{project_slug}/`
- `HERMES_KANBAN_BOARD={project_slug}`
- `HERMES_MEMORY_NAMESPACE=project:{project_slug}`
```

### JSON Envelope Normalization
**Source:** `docs/orchestra/scripts/bin/orch-bus-loop` lines 259-273, 441-455  
**Apply to:** reviewer/request-response docs, future adapter code, protocol tests
```python
wrapper = json.load(handle)
payload = wrapper.get("result", wrapper) if isinstance(wrapper, dict) else wrapper
if isinstance(payload, str):
    payload = json.loads(payload)
json.dump(payload, handle, ensure_ascii=False, indent=2)
```

### Guard Before Continue / Block On Mismatch
**Source:** `docs/orchestra/scripts/bin/orch-bus-loop` lines 247-279, 361-408  
**Apply to:** protocol error docs, failure taxonomy tests, future adapter layer
```bash
orch_project_matches_if_present "$RUNTIME_DIR/codex-question.md" || return 0
orch_correlation_compatible ... || return 0

if [ "$sufficient" != "true" ]; then
    orch_write_project_state "blocked" "$task_id"
    return 0
fi
```

### Failure Taxonomy
**Source:** `.planning/phases/19-hermes-workflow-design/EXTERNAL-CLI-ENGINE.md` lines 392-400  
**Apply to:** `common-envelope.md`, role docs, `test-role-engine-protocol.sh`
```md
| CLI 引擎超时 | kill → retry 1 次 → kanban_block(reason='engine-timeout') |
| CLI 引擎崩溃 | retry 1 次 → kanban_block(reason='engine-crash') |
| 输出格式错误 | log raw output → kanban_block(reason='engine-parse-error') |
| API 限流 | backoff 60s → retry → kanban_block(reason='engine-rate-limit') |
```

### Structured Test Harness
**Source:** `docs/orchestra/scripts/tests/lib/assert.sh` lines 6-76; `docs/orchestra/scripts/tests/run-all.sh` lines 4-20  
**Apply to:** all new/updated shell smoke tests
```bash
source "$TEST_DIR/lib/assert.sh"

for test_script in "$TEST_DIR"/test-*.sh; do
    if bash "$test_script"; then
        echo "PASS $test_script"
    else
        echo "FAIL $test_script"
    fi
done
```

## No Analog Found

None. There is no pre-existing standalone `role-engine-protocol/v1/` package, but Phase 19 design docs plus current `orch-bus-loop` request/review prompts provide sufficient role-match analogs for every planned file.

## Metadata

**Analog search scope:** `docs/orchestra/scripts/`, `docs/orchestra/hermes/`, `.hermes/`, `.planning/phases/19-hermes-workflow-design/`  
**Files scanned:** 15  
**Pattern extraction date:** 2026-05-11
