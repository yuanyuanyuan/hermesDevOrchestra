# Phase 12: Risk Decisions, Verification & Handoff - Pattern Map

**Mapped:** 2026-04-25
**Files analyzed:** 30 source/planning targets
**Analogs found:** 19 / 30 with executable/doc analogs; 11 smoke fixture files have no existing code analog

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` | utility | file-I/O, transform | `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` | exact |
| `docs/hermes-dev-orchestra/scripts/bin/orch-risk-check` | utility | request-response, transform | `docs/hermes-dev-orchestra/scripts/bin/orch-status` + `orch-common.sh` | role-match |
| `docs/hermes-dev-orchestra/scripts/bin/orch-audit` | utility | file-I/O, request-response | `docs/hermes-dev-orchestra/scripts/bin/orch-status` + `orch-common.sh` | role-match |
| `docs/hermes-dev-orchestra/scripts/bin/orch-decisions` | utility | file-I/O, request-response | `docs/hermes-dev-orchestra/scripts/bin/orch-status` | role-match |
| `docs/hermes-dev-orchestra/scripts/bin/orch-approve` | utility | file-I/O, request-response | `docs/hermes-dev-orchestra/scripts/bin/orch-init` + `orch-common.sh` | role-match |
| `docs/hermes-dev-orchestra/scripts/bin/orch-reject` | utility | file-I/O, request-response | `docs/hermes-dev-orchestra/scripts/bin/orch-init` + `orch-common.sh` | role-match |
| `docs/hermes-dev-orchestra/scripts/bin/orch-verify` | utility | batch | `docs/hermes-dev-orchestra/scripts/bin/orch-status` + Phase 11 validation docs | partial |
| `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` | route | event-driven, file-I/O | `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` | exact |
| `docs/hermes-dev-orchestra/scripts/bin/orch-status` | utility | request-response, file-I/O | `docs/hermes-dev-orchestra/scripts/bin/orch-status` | exact |
| `docs/hermes-dev-orchestra/scripts/bin/orch-init` | utility | file-I/O, CRUD | `docs/hermes-dev-orchestra/scripts/bin/orch-init` | exact |
| `docs/hermes-dev-orchestra/scripts/bin/orch-start` | utility | request-response, process-lifecycle | `docs/hermes-dev-orchestra/scripts/bin/orch-start` | exact |
| `docs/hermes-dev-orchestra/scripts/bin/orch-stop` | utility | request-response, process-lifecycle | `docs/hermes-dev-orchestra/scripts/bin/orch-stop` | exact |
| `docs/hermes-dev-orchestra/scripts/setup.sh` | config | file-I/O, batch | `docs/hermes-dev-orchestra/scripts/setup.sh` | exact |
| `docs/hermes-dev-orchestra/scripts/tests/lib/assert.sh` | test | batch | `12-RESEARCH.md` assertion example | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/run-all.sh` | test | batch | Phase 11 validation fake-CLI smoke guidance | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-install-probe.sh` | test | batch, request-response | Phase 10 temporary HOME smoke guidance | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-skills-load.sh` | test | batch, file-I/O | Phase 10 temporary HOME smoke guidance | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` | test | batch, file-I/O | Phase 11 validation fake-CLI smoke guidance | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` | test | batch, event-driven | Phase 11 validation fake-CLI smoke guidance | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | test | batch, request-response | `12-RESEARCH.md` risk-check examples | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | test | batch, event-driven | `12-RESEARCH.md` decision-gate examples | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | test | batch, request-response | `12-RESEARCH.md` pending-decision examples | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | test | batch, file-I/O | `12-RESEARCH.md` pending validation example | no-code-analog |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | test | batch, transform | Phase 10 grep validation pattern | no-code-analog |
| `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` | provider | request-response | `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` | exact |
| `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` | provider | event-driven, request-response | `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` | exact |
| `docs/hermes-dev-orchestra/hermes/SOUL.md` | provider | event-driven | `docs/hermes-dev-orchestra/hermes/SOUL.md` | exact |
| `docs/hermes-dev-orchestra/README.md` | documentation | transform | `docs/hermes-dev-orchestra/README.md` | exact |
| `docs/COVERAGE-MATRIX.md` | documentation | transform | `docs/hermes-dev-orchestra/README.md` + `.planning/REQUIREMENTS.md` | role-match |
| `.planning/REQUIREMENTS.md` | documentation | transform | `.planning/REQUIREMENTS.md` | exact |

## Pattern Assignments

### `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` (utility, file-I/O/transform)

**Analog:** `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh`

**Imports and root path pattern** (lines 1-8):
```bash
#!/usr/bin/env bash
set -euo pipefail

ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"
RUNTIME_ROOT="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
STATE_ROOT="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"
AUDIT_ROOT="${AUDIT_ROOT:-$HOME/.local/share/hermes-orchestra}"
CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hermes-orchestra}"
```

**Validation pattern** (lines 14-21):
```bash
orch_validate_project_id() {
    local project_id="${1:-}"

    if [[ ! "$project_id" =~ ^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$ ]]; then
        echo "Invalid project id. Use 3-32 lowercase letters, numbers, and hyphens; start and end with alphanumeric." >&2
        return 1
    fi
}
```

**Project directory derivation** (lines 32-45):
```bash
orch_project_dirs() {
    if [ "${1:-}" != "" ]; then
        PROJECT_ID="$1"
    fi

    RUNTIME_DIR="$RUNTIME_ROOT/$PROJECT_ID"
    STATE_DIR="$STATE_ROOT/$PROJECT_ID"
    AUDIT_DIR="$AUDIT_ROOT/$PROJECT_ID"
    CACHE_DIR="$CACHE_ROOT/$PROJECT_ID"
    CLAUDE_SESSION="$(orch_claude_session_name "$PROJECT_ID")"
    CODEX_SESSION="$(orch_codex_session_name "$PROJECT_ID")"

    export PROJECT_ID RUNTIME_DIR STATE_DIR AUDIT_DIR CACHE_DIR CLAUDE_SESSION CODEX_SESSION
}
```

**Atomic file write pattern** (lines 47-58):
```bash
orch_atomic_write() {
    local target="$1"
    local content_file="$2"
    local target_dir
    local temp_file

    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"
    temp_file="$(mktemp "$target_dir/.tmp.$(basename "$target").XXXXXX")"
    cp "$content_file" "$temp_file"
    mv "$temp_file" "$target"
}
```

**JSON write pattern** (lines 150-169):
```bash
orch_write_project_state() {
    local state="$1"
    local task_id="${2:-null}"

    mkdir -p "$STATE_DIR"

    python3 - "$STATE_DIR/current-task.json" "$PROJECT_ID" "$state" "$task_id" "$(orch_now)" <<'PY'
import json, sys
path, project_id, state, task_id, now = sys.argv[1:]
if task_id in ("", "null"):
    task_id = None
with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "project_id": project_id,
        "state": state,
        "task_id": task_id,
        "updated_at": now,
    }, handle, indent=2)
    handle.write("\n")
PY
}
```

**JSON read pattern** (lines 178-198):
```bash
orch_json_field() {
    local file="$1"
    local field="$2"

    python3 - "$file" "$field" <<'PY' 2>/dev/null || true
import json, sys
path, field = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as handle:
        value = json.load(handle)
    for part in field.split("."):
        value = value[part]
    if isinstance(value, bool):
        print("true" if value else "false")
    elif value is None:
        print("null")
    else:
        print(value)
except Exception:
    pass
PY
}
```

**Apply to Phase 12:** add `orch_rules_path`, `orch_audit_path`, `orch_append_audit`, `orch_pending_decision_path`, `orch_validate_approval_id`, and decision metadata helpers here. Keep Python stdlib for JSON, not shell string concatenation.

---

### `docs/hermes-dev-orchestra/scripts/bin/orch-risk-check` (utility, request-response/transform)

**Analog:** `docs/hermes-dev-orchestra/scripts/bin/orch-status`, `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh`, and `12-RESEARCH.md`

**Command envelope pattern** from `orch-status` (lines 1-13):
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"

if [ -f "$ORCHESTRA_HOME/lib/orch-common.sh" ]; then
    # shellcheck source=/dev/null
    source "$ORCHESTRA_HOME/lib/orch-common.sh"
else
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../lib/orch-common.sh"
fi
```

**Rule-floor call shape** from `12-RESEARCH.md` (lines 277-285):
```bash
risk_output="$(printf '%s\n' "$operation_text" | orch-risk-check --project "$PROJECT_ID" --task "$task_id" 2>/dev/null || true)"
risk_code=$?
case "$risk_code" in
  0|1) continue_normal_routing ;;
  2|3) create_pending_decision "$risk_output"; orch_write_project_state "blocked" "$task_id" ;;
  *) echo "risk check failed" >&2; exit 1 ;;
esac
```

**Implementation note:** accept operation text from arguments or stdin, read `~/.hermes-orchestra/rules.json`, emit parseable output, and return 0 safe, 1 L1/L2, 2 L3, 3 L4 per D-12-03.

---

### `docs/hermes-dev-orchestra/scripts/bin/orch-audit` (utility, file-I/O/request-response)

**Analog:** `docs/hermes-dev-orchestra/scripts/bin/orch-status`

**Status display pattern** (lines 62-88):
```bash
echo "=== Hermes Dev Orchestra Status ==="

if [ -z "$PROJECT_ID" ]; then
    echo "--- registered projects ---"
    if [ -f "$STATE_ROOT/projects.json" ]; then
        python3 - "$STATE_ROOT/projects.json" <<'PY'
import json, sys
try:
    projects = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    projects = []
if not projects:
    print("No registered projects")
for project in projects:
    print(f"{project.get('project_id')} {project.get('project_dir')}")
PY
    else
        echo "No registered projects"
    fi
    echo "--- active orchestra sessions ---"
    if command -v tmux >/dev/null 2>&1; then
        tmux ls 2>/dev/null | grep "hermes-" || echo "No active orchestra sessions"
    else
        echo "tmux command unavailable"
    fi
    exit 0
fi
```

**Audit JSONL append shape** from `12-RESEARCH.md` (lines 387-410):
```bash
orch_append_audit() {
  local event_type="$1"
  local project_id="$2"
  local task_id="$3"
  local approval_id="$4"
  local decision="$5"
  mkdir -p "$AUDIT_DIR"
  python3 - "$AUDIT_DIR/audit.jsonl" "$event_type" "$project_id" "$task_id" "$approval_id" "$decision" "$(orch_now)" <<'PY'
import json, os, sys
path, event_type, project_id, task_id, approval_id, decision, timestamp = sys.argv[1:]
record = {
    "timestamp": timestamp,
    "event_type": event_type,
    "project_id": project_id,
    "task_id": task_id,
    "approval_id": approval_id,
    "decision": decision,
}
with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    handle.flush()
    os.fsync(handle.fileno())
PY
}
```

**Apply to Phase 12:** `orch-audit [project-id] [--project <id>] [--level L3]` should read `$AUDIT_DIR/audit.jsonl`, default to last 20 records, and format with a simple table like `orch-status`.

---

### `docs/hermes-dev-orchestra/scripts/bin/orch-decisions`, `orch-approve`, `orch-reject` (utility, file-I/O/request-response)

**Analog:** `docs/hermes-dev-orchestra/scripts/bin/orch-init`, `docs/hermes-dev-orchestra/scripts/bin/orch-status`, and `12-RESEARCH.md`

**Argument and dependency validation pattern** from `orch-init` (lines 15-25):
```bash
if [ "$#" -ne 2 ]; then
    echo "Usage: orch-init <project-id> <project-dir>" >&2
    exit 1
fi

PROJECT_ID="$1"
PROJECT_DIR_INPUT="$2"

orch_validate_project_id "$PROJECT_ID"
orch_require_command git
orch_require_command python3
```

**Pending-decision layout pattern** from `12-RESEARCH.md` (lines 296-301):
```bash
STATE_DECISION="$STATE_DIR/decisions/$approval_id.request.json"
RUNTIME_DECISION="$RUNTIME_DIR/decisions/$approval_id.request.json"
AUDIT_LOG="$AUDIT_DIR/audit.jsonl"
```

**Replay/binding validation pattern** from `12-RESEARCH.md` (lines 417-432):
```bash
validate_pending_decision() {
  local request_json="$1"
  local expected_project="$2"
  local expected_task="$3"
  python3 - "$request_json" "$expected_project" "$expected_task" "$(date +%s)" <<'PY'
import json, sys
path, expected_project, expected_task, now = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
request = json.load(open(path, encoding="utf-8"))
if request.get("used_at"):
    raise SystemExit("DECISION_ALREADY_USED")
if request.get("project_id") != expected_project or request.get("task_id") != expected_task:
    raise SystemExit("DECISION_BINDING_MISMATCH")
if int(request.get("expires_at_epoch", 0)) < now:
    raise SystemExit("DECISION_EXPIRED")
PY
}
```

**Display pattern** from `12-CONTEXT.md` (lines 153-157):
```text
ID          Project    Level  Task      Age
esc-456     project-a  L3     auth-fix  2m
```

**Apply to Phase 12:** list pending decisions from State, expose runtime mailbox files for local fallback, accept only approve/reject commands, mark approval IDs used exactly once, append audit before writing user-authored decision output.

---

### `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` (route, event-driven/file-I/O)

**Analog:** `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop`

**Runner generation pattern** (lines 31-57):
```bash
log_loop() {
    printf '[%s] %s\n' "$(orch_now)" "$*" >> "$STATE_DIR/orch-bus-loop.log"
}

quote() {
    printf '%q' "$1"
}

write_runner() {
    local path="$1"
    shift
    {
        echo '#!/usr/bin/env bash'
        echo 'set -euo pipefail'
        printf 'cd %q\n' "$PROJECT_DIR"
        printf 'export HERMES_ORCHESTRA_PROJECT=%q\n' "$PROJECT_ID"
        "$@"
    } > "$path"
    chmod +x "$path"
}

send_runner() {
    local session="$1"
    local runner="$2"

    tmux send-keys -t "$session" "bash $(quote "$runner")" Enter
}
```

**Authority block pattern** (lines 142-146):
```bash
sufficient="$(orch_json_field "$RUNTIME_DIR/claude-decision.md" "execution.authority_sufficient")"
if [ "$sufficient" = "false" ]; then
    orch_write_project_state "blocked" "$(task_id_from_bus)"
    log_loop "authority insufficient; project blocked"
    return 0
fi
```

**Current escalation placeholder** (lines 214-218):
```bash
if [ -f "$RUNTIME_DIR/escalation.md" ]; then
    orch_write_project_state "blocked" "$(task_id_from_bus)"
    log_loop "escalation.md present; project blocked"
    return 0
fi
```

**Event loop pattern** (lines 253-265):
```bash
if [ "$ONCE" = "--once" ]; then
    process_once
    exit 0
fi

while true; do
    process_once
    if command -v inotifywait >/dev/null 2>&1; then
        inotifywait -q -e create,modify,move "$RUNTIME_DIR" >/dev/null 2>&1 || sleep 2
    else
        sleep 2
    fi
done
```

**Apply to Phase 12:** replace the placeholder with rule-floor evaluation, pending decision creation, approval/rejection consumption, and audit-before-unblock. Preserve `--once` for fixtures and the polling fallback.

---

### `docs/hermes-dev-orchestra/scripts/bin/orch-status` (utility, request-response/file-I/O)

**Analog:** `docs/hermes-dev-orchestra/scripts/bin/orch-status`

**Project status readout pattern** (lines 93-126):
```bash
project_prefix "Project: $PROJECT_ID"
project_prefix "Stage: $(orch_stage_for_project "$PROJECT_ID")"
project_prefix "Claude session: $CLAUDE_SESSION $(session_state "$CLAUDE_SESSION")"
project_prefix "Codex session: $CODEX_SESSION $(session_state "$CODEX_SESSION")"

if [ -f "$STATE_DIR/watcher.pid" ] && kill -0 "$(cat "$STATE_DIR/watcher.pid")" 2>/dev/null; then
    project_prefix "Watcher: running pid $(cat "$STATE_DIR/watcher.pid")"
else
    project_prefix "Watcher: stopped"
fi

if [ -f "$STATE_DIR/last-task.hash" ]; then
    project_prefix "Active task hash: $(cat "$STATE_DIR/last-task.hash")"
fi

project_prefix "Runtime: $RUNTIME_DIR"
project_prefix "State: $STATE_DIR/project.env"
project_prefix "Audit: $AUDIT_DIR"

for bus_file in task.md codex-question.md claude-decision.md codex-result.md review-result.md escalation.md; do
    project_prefix "$(orch_print_file_marker "$RUNTIME_DIR/$bus_file")"
done

if [ -f "$RUNTIME_DIR/escalation.md" ]; then
    project_prefix "Escalation: present — blocked pending Phase 12/user handling"
fi
```

**Apply to Phase 12:** add pending approval id, age, expiry, `STATE_DIR/decisions`, `RUNTIME_DIR/decisions`, and concrete `audit.jsonl` path.

---

### `docs/hermes-dev-orchestra/scripts/bin/orch-init`, `orch-start`, `orch-stop` (utility, process/file-I/O)

**Analogs:** `docs/hermes-dev-orchestra/scripts/bin/orch-init`, `orch-start`, `orch-stop`

**Per-project directory creation** from `orch-init` (line 41):
```bash
mkdir -p "$RUNTIME_DIR" "$STATE_DIR" "$AUDIT_DIR/archive" "$AUDIT_DIR/pending" "$CACHE_DIR"
```

**Durable project registry update** from `orch-init` (lines 82-112):
```bash
mkdir -p "$STATE_ROOT"
python3 - "$STATE_ROOT/projects.json" "$PROJECT_ID" "$PROJECT_DIR" "$RUNTIME_DIR" "$STATE_DIR" "$AUDIT_DIR" "$CACHE_DIR" "$(orch_now)" <<'PY'
import json, os, sys
path, project_id, project_dir, runtime_dir, state_dir, audit_dir, cache_dir, updated_at = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as handle:
        projects = json.load(handle)
    if not isinstance(projects, list):
        projects = []
except Exception:
    projects = []

entry = {
    "project_id": project_id,
    "project_dir": project_dir,
    "runtime_dir": runtime_dir,
    "state_dir": state_dir,
    "audit_dir": audit_dir,
    "cache_dir": cache_dir,
    "updated_at": updated_at,
}
projects = [project for project in projects if project.get("project_id") != project_id]
projects.append(entry)
projects.sort(key=lambda project: project["project_id"])

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(projects, handle, indent=2)
    handle.write("\n")
os.replace(tmp, path)
PY
```

**Session lifecycle pattern** from `orch-start` (lines 57-80):
```bash
start_or_reuse_session() {
    local label="$1"
    local session="$2"

    if orch_tmux_session_healthy "$session"; then
        if [ "$label" = "Claude" ]; then
            echo "Reusing Claude session: $session"
        elif [ "$label" = "Codex" ]; then
            echo "Reusing Codex session: $session"
        else
            echo "Reusing $label session: $session"
        fi
        return
    fi

    if orch_tmux_session_running "$session"; then
        tmux kill-session -t "$session" 2>/dev/null || true
        echo "Recreated stale $label session: $session"
    fi

    tmux new-session -d -s "$session" -x 180 -y 40 -c "$PROJECT_DIR" \
        "env HERMES_ORCHESTRA_PROJECT='$PROJECT_ID' bash"
    echo "Started $label session: $session"
}
```

**Idempotent stop pattern** from `orch-stop` (lines 24-37):
```bash
if [ -f "$STATE_DIR/watcher.pid" ]; then
    WATCHER_PID="$(cat "$STATE_DIR/watcher.pid")"
    if [ -n "$WATCHER_PID" ] && kill -0 "$WATCHER_PID" 2>/dev/null; then
        kill "$WATCHER_PID" 2>/dev/null || true
    fi
    rm -f "$STATE_DIR/watcher.pid"
fi

if command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t "$CLAUDE_SESSION" 2>/dev/null || true
    tmux kill-session -t "$CODEX_SESSION" 2>/dev/null || true
fi

echo "Stopped orchestra sessions for: $PROJECT_ID"
```

**Apply to Phase 12:** ensure decision directories and audit paths exist in `orch-init`; add audit records to init/start/stop without changing command signatures; keep `orch-start` risk checking limited to helper-owned dangerous operations and leave task/escalation enforcement in `orch-bus-loop`.

---

### `docs/hermes-dev-orchestra/scripts/setup.sh` (config, file-I/O/batch)

**Analog:** `docs/hermes-dev-orchestra/scripts/setup.sh`

**Installer roots and no-sudo pattern** (lines 10-18):
```bash
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_SKILLS_DIR="${HERMES_SKILLS_DIR:-$HERMES_HOME/skills}"
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"
ORCHESTRA_BIN_DIR="$ORCHESTRA_HOME/bin"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
RUNTIME_ROOT="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
STATE_ROOT="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"
AUDIT_ROOT="${AUDIT_ROOT:-$HOME/.local/share/hermes-orchestra}"
CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hermes-orchestra}"
```

**Logging style** (lines 26-29):
```bash
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERR]${NC} $1"; }
```

**Helper link pattern** (lines 43-48):
```bash
install_helper_link() {
    local helper="$1"
    chmod +x "$ORCHESTRA_BIN_DIR/$helper"
    ln -sf "$ORCHESTRA_BIN_DIR/$helper" "$LOCAL_BIN_DIR/$helper"
    log_ok "Helper installed: $LOCAL_BIN_DIR/$helper"
}
```

**Root directory creation pattern** (lines 83-87):
```bash
log_info "Creating orchestra directories..."
mkdir -p "$HERMES_HOME" "$HERMES_SKILLS_DIR" "$ORCHESTRA_HOME" "$ORCHESTRA_BIN_DIR" \
    "$ORCHESTRA_HOME/backups" "$ORCHESTRA_HOME/lib" "$ORCHESTRA_HOME/claude-config-template/.claude" \
    "$LOCAL_BIN_DIR" "$RUNTIME_ROOT" "$STATE_ROOT" "$AUDIT_ROOT" "$CACHE_ROOT"
log_ok "Directory roots ready"
```

**Helper install pattern** (lines 144-172):
```bash
log_info "Installing orch-* helper commands..."

HELPER_SRC_DIR="$PACKAGE_DIR/scripts/bin"
HELPER_LIB_SRC_DIR="$PACKAGE_DIR/scripts/lib"

if [ ! -f "$HELPER_LIB_SRC_DIR/orch-common.sh" ]; then
    log_err "Helper library missing: $HELPER_LIB_SRC_DIR/orch-common.sh"
    exit 1
fi

cp "$HELPER_LIB_SRC_DIR/orch-common.sh" "$ORCHESTRA_HOME/lib/orch-common.sh"
chmod +x "$ORCHESTRA_HOME/lib/orch-common.sh"
log_ok "Helper library installed: $ORCHESTRA_HOME/lib/orch-common.sh"

for helper in orch-init orch-start orch-stop orch-status orch-bus-loop; do
    if [ ! -f "$HELPER_SRC_DIR/$helper" ]; then
        log_err "Helper source missing: $HELPER_SRC_DIR/$helper"
        exit 1
    fi

    cp "$HELPER_SRC_DIR/$helper" "$ORCHESTRA_BIN_DIR/$helper"
done

for helper in orch-init orch-start orch-stop orch-status; do
    install_helper_link "$helper"
done

chmod +x "$ORCHESTRA_BIN_DIR/orch-bus-loop"
log_ok "Internal watcher installed: $ORCHESTRA_BIN_DIR/orch-bus-loop"
```

**Apply to Phase 12:** extend helper copy list to include `orch-risk-check`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, `orch-verify`; link all public helpers; keep `orch-bus-loop` internal; create default `~/.hermes-orchestra/rules.json` if absent; install tests under `~/.hermes-orchestra/tests` or keep package-relative lookup for `orch-verify`.

---

### `docs/hermes-dev-orchestra/scripts/bin/orch-verify` and `docs/hermes-dev-orchestra/scripts/tests/*` (test, batch)

**Analog:** no existing executable test suite; use Phase 10/11 validation guidance and shell style from `orch-*` helpers.

**Temporary HOME smoke pattern** from Phase 10 research (lines 155-163):
```bash
tmp_home="$(mktemp -d)"
mkdir -p "$tmp_home/.hermes/skills" "$tmp_home/.local/bin"
printf '# upstream soul\n' > "$tmp_home/.hermes/SOUL.md"
PATH="$PATH" HOME="$tmp_home" bash docs/hermes-dev-orchestra/scripts/setup.sh
test -f "$tmp_home/.hermes/SOUL.md.bak"
test -f "$tmp_home/.hermes/skills/dev-orchestra/SKILL.md"
test -x "$tmp_home/.local/bin/orch-init"
```

**Fake CLI fixture guidance** from Phase 11 research (lines 131, 145-148):
```text
Do not require real Claude/Codex authentication for phase validation.
Use temporary fake `claude`, `codex`, `hermes`, and `tmux` commands in a temporary `PATH`.
Shell syntax checks: `bash -n`.
JSON checks: `jq empty`.
Fixture smoke checks: temporary directory with fake `hermes`, `tmux`, `claude`, `codex`, and a Git project.
```

**Assertion helper shape** from `12-RESEARCH.md` (lines 437-448):
```bash
assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "$expected" != "$actual" ]; then
    printf 'FAIL %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    return 1
  fi
}
```

**Apply to Phase 12 tests:**
- Source `scripts/tests/lib/assert.sh`, set `TEST_NAME`, use `mktemp -d` and `trap` cleanup.
- Keep each test independently runnable.
- `run-all.sh` should discover `test-*.sh`, run each, aggregate pass/fail, and return non-zero on any failure.
- `orch-verify` should locate installed or package tests, run `run-all.sh`, and print a concise summary.

---

### `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md` (provider, request-response)

**Analog:** `docs/hermes-dev-orchestra/skills/escalation-handler/SKILL.md`

**Skill frontmatter convention** (lines 1-10):
```markdown
---
name: escalation-handler
description: 处理从Claude Supervisor升级的危险决策请求：评估风险等级、向用户请求最终决策、执行用户指令并记录审计日志
version: 2.0.0
metadata:
  hermes:
    tags: [escalation, risk-management, user-approval, audit]
    category: autonomous-ai-agents
    requires_version: ">=0.10.0"
---
```

**Risk table pattern** (lines 31-39):
```markdown
## Escalation Risk Levels

| 等级 | 标识 | 示例 | 响应时间 |
|------|------|------|---------|
| L1 | 注意 (Notice) | 引入新依赖、修改构建脚本 | 异步通知 |
| L2 | 警告 (Warning) | 修改数据库 schema、删除旧 API | 5 分钟内响应 |
| L3 | 危险 (Danger) | 系统级命令、修改认证逻辑 | 立即响应 |
| L4 | 紧急 (Critical) | 删除生产数据、修改密钥 | 阻塞直到用户确认 |
```

**Do not copy stale transport/audit examples** (lines 72-103, 112-117, 177-184):
```markdown
**L1-L2（异步）：**
...
target="telegram"
...
terminal(command="cat >> /tmp/hermes-orchestra/audit.log << 'EOF'
...
- 审计日志 `audit.log` 需要定期备份，防止 `tmp` 被清理
- Telegram/Discord 消息有长度限制，长内容需要分段发送
```

**Apply to Phase 12:** preserve frontmatter and risk-table structure, but replace concrete Telegram/Discord binding with abstract Remote Decision Channel plus SSH/local fallback; replace `/tmp/hermes-orchestra/audit.log` with per-project `~/.local/share/hermes-orchestra/{project}/audit.jsonl`; state that L3/L4 never auto-approve.

---

### `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md` (provider, event-driven/request-response)

**Analog:** `docs/hermes-dev-orchestra/skills/dev-orchestra/SKILL.md`

**Skill frontmatter convention** (lines 1-10):
```markdown
---
name: dev-orchestra
description: 多项目AI开发编排系统：管理Claude Code(决策监督)与Codex(执行)的协作，处理三级决策流转，支持并行多项目开发
version: 2.0.0
metadata:
  hermes:
    tags: [orchestration, claude-code, codex, multi-project, ai-development]
    category: autonomous-ai-agents
    requires_version: ">=0.10.0"
---
```

**JSON envelope contract pattern** (lines 66-80):
````markdown
2. 通过 `orch-init <project-id> <project-dir>` 创建四层项目目录：
   ```bash
   terminal(command="orch-init {project_id} {project_dir}")
   ```

3. 当用户向项目分配任务时，Hermes 写入 Runtime `task.md`。文件名保留 `.md` 兼容命名，内容必须是 JSON envelope，包含 `schema_version`、`message_id`、`project_id`、`task_id`、`correlation_id`、`status`、`author`、`authority`、`timestamp`、`description`、`requirements`、`constraints`、`priority`：
````

**Stale escalation example to update** (lines 191-214):
```markdown
Hermes 收到 escalation 后，**使用 `clarify` 工具向用户请求最终决策**：
...
如果用户配置了 Telegram/Discord，同时发送消息通知：
...
用户决策后，Hermes 将结果写入 `claude-decision.md`，Claude Code 和 Codex 继续执行。
```

**Apply to Phase 12:** add `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, and `orch-risk-check` fallback flow; clarify that "modify" is modeled as reject plus revised task unless later scope adds a first-class modify command.

---

### `docs/hermes-dev-orchestra/hermes/SOUL.md` (provider, event-driven)

**Analog:** `docs/hermes-dev-orchestra/hermes/SOUL.md`

**Core principles pattern** (lines 12-18):
```markdown
## Core Principles

1. **Never do the coding yourself.** Delegate all implementation work to Codex. Your job is management.
2. **Trust Claude for technical decisions.** If Claude approves it, let it proceed.
3. **Escalate to human only for:** system-dangerous operations, product-direction changes, security/key operations, or irreversible destructive changes.
4. **Keep projects isolated.** Each project has its own tmux sessions and communication bus.
5. **Document everything.** All decisions, escalations, and outcomes must be logged.
```

**Escalation rules to update** (lines 37-44):
```markdown
### When Claude escalates:
1. Read `/tmp/hermes-orchestra/{project}/escalation.md`
2. Assess the risk level (L1-L4)
3. For L1-L2: send async message to user, continue with default safe action
4. For L3-L4: use `clarify()` to block and request immediate user decision
5. Also send urgent notification via Telegram/Discord if configured
6. Log everything to `/tmp/hermes-orchestra/audit.log`
7. Do NOT proceed without explicit user approval for L3-L4
```

**Apply to Phase 12:** preserve concise manager persona, but update rule 2/3 wording so Claude cannot lower static risk floors; replace concrete Telegram/Discord and `/tmp` audit path; mention local fallback commands.

---

### `docs/hermes-dev-orchestra/README.md` and `docs/COVERAGE-MATRIX.md` (documentation, transform)

**Analog:** `docs/hermes-dev-orchestra/README.md`

**Install section style** (lines 128-157):
````markdown
## 五、完整部署步骤（无 sudo Ubuntu）

### Step 0: 前置依赖确认

```bash
# 这些应该已经由你的管理员安装好
git --version       # >= 2.30
node --version      # >= 18
tmux -V             # >= 3.0
python3 --version   # >= 3.10
```

### Step 1: 一键安装
...
- 安装 PATH helper：`orch-init`, `orch-start`, `orch-stop`, `orch-status`
````

**Remote decision behavior style** (lines 179-186):
```markdown
### Step 3: 配置 Remote Decision Channel（可选）

v1 将远程决策通道保持为抽象接口，不绑定 Telegram、Discord 或任何具体传输。你可以选择上游 Hermes Agent 支持的消息/gateway 能力，或在后续阶段接入本地文件 fallback。

需要保证的行为只有：
- L1/L2 可以异步通知用户
- L3/L4 必须阻塞直到用户明确批准或拒绝
- 所有用户决策必须写入审计记录
```

**Escalation scenario style** (lines 277-302):
````markdown
### 示例 2：危险操作升级

```
Codex 执行中需要修改数据库认证表结构
→ 涉及现有用户数据
...
Hermes:
  1. 记录审计日志
  2. 将用户决策写入 claude-decision.md
  3. 通知 Claude Code 更新方案
  4. Claude 更新决策后，Codex 按新方案继续执行
```
````

**Safety best-practice line to update** (lines 437-444):
```markdown
## 十一、安全最佳实践

1. **审计日志不可删**: `/tmp/hermes-orchestra/audit.log` 定期复制到 `~/logs/`
2. **git 是底线**: 任何危险操作前，Hermes 自动执行 `git stash` 或 `git branch backup-{timestamp}`
3. **L3-L4 绝不自动**: 任何标记为 DANGER/CRITICAL 的操作，必须用户明确输入 "批准"
4. **API Key 隔离**: Claude Code 用 Anthropic OAuth，Codex 用 OpenAI Key，Hermes 用 OpenRouter，互不混用
5. **tmux 会话分离**: 不同项目的会话相互隔离，防止交叉污染
```

**Coverage matrix pattern:** create a Markdown table with columns `Capability`, `Upstream native`, `Adapter-provided`, `Deferred`, `Evidence`, and `Notes` per `12-RESEARCH.md` line 586. Keep rows evidence-backed; do not claim remote adapters, container isolation, `gbrain`, dashboard, or team approvals as implemented.

---

### `.planning/REQUIREMENTS.md` (documentation, transform)

**Analog:** `.planning/REQUIREMENTS.md`

**Requirement style** (lines 33-45):
```markdown
### Safety & Local Decisions

- [ ] **SAFE-01**: 静态风险 rulebook 对 L1-L4 决策给出最低风险等级，Claude 只能升级不能降低规则下限。
- [ ] **SAFE-02**: L3/L4 决策必须阻塞对应项目，不能被 Hermes、Claude、Codex、timeout 或 fallback 自动批准。
- [ ] **DEC-01**: 当远程通道未配置时，Hermes Agent 使用 SSH/local file fallback 请求用户 approve/reject/modify。
- [ ] **DEC-02**: 用户决策写入审计记录，并以一次性 approval_id、TTL、project_id、task_id 绑定防止重放。

### Verification & Handoff

- [ ] **VER-01**: smoke/fixture 覆盖上游安装探测、skills 加载、`orch-init`、`orch-start`、文件总线问题转发、风险阻塞和状态查看。
- [ ] **VER-02**: 文档说明上游 Hermes Agent 版本、安装命令、目录布局、helper 命令、已实现范围、未实现范围和手工验证步骤。
- [ ] **VER-03**: 覆盖矩阵标注哪些 v1.0 规格由上游 Hermes Agent 原生提供、哪些由本仓库适配层提供、哪些仍待实现。
- [ ] **VER-04**: handoff 列出后续 remote adapter、生产化审计、容器隔离、gbrain 集成或 dashboard 的边界。
```

**Apply to Phase 12:** if adapter commands are implemented, update DEC-01 wording to name `orch-decisions`, `orch-approve`, and `orch-reject` rather than upstream `hermes` subcommands. Keep checkbox and requirement-ID style.

## Shared Patterns

### Shell Script Envelope
**Source:** `docs/hermes-dev-orchestra/scripts/bin/orch-start` lines 1-13
**Apply to:** all new `docs/hermes-dev-orchestra/scripts/bin/orch-*`

Use `#!/usr/bin/env bash`, `set -euo pipefail`, derive `SCRIPT_DIR`, source installed `$ORCHESTRA_HOME/lib/orch-common.sh` first, and fall back to package-relative `../lib/orch-common.sh`.

### Path and State Boundaries
**Source:** `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` lines 4-8, 32-45
**Apply to:** all helper scripts

Keep Runtime under `/tmp/hermes-orchestra`, State under `~/.local/state/hermes-orchestra`, Audit under `~/.local/share/hermes-orchestra`, Cache under `~/.cache/hermes-orchestra`, and package config under `~/.hermes-orchestra`.

### JSON Handling
**Source:** `docs/hermes-dev-orchestra/scripts/lib/orch-common.sh` lines 150-198
**Apply to:** audit records, pending decisions, project state, fixtures

Use Python stdlib `json` for serialization and field extraction. Do not hand-roll JSON with shell interpolation.

### Risk and Decision Gate
**Source:** `docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop` lines 142-146 and 214-218; `12-RESEARCH.md` lines 277-315
**Apply to:** `orch-risk-check`, `orch-bus-loop`, `orch-approve`, `orch-reject`

Evaluate the static rule floor before routing, block L3/L4, create a pending decision, validate one-time/TTL/project/task binding, append audit, then write user-authored continuation or rejection.

### Installation
**Source:** `docs/hermes-dev-orchestra/scripts/setup.sh` lines 83-87 and 144-172
**Apply to:** setup changes for new helpers/tests/rules

Install package assets only. Do not install or alias upstream `hermes`, `claude`, or `codex`. Link only public `orch-*` helpers into `$LOCAL_BIN_DIR`; keep internal watcher/test internals under `$ORCHESTRA_HOME`.

### Documentation Tone
**Source:** `docs/hermes-dev-orchestra/README.md` lines 128-186 and skill frontmatter
**Apply to:** README, SOUL, skills, coverage matrix

Keep bilingual, command-oriented docs. Preserve abstract Remote Decision Channel wording; do not bind v1.1 to Telegram/Discord or any concrete transport.

## No Analog Found

These files have no existing executable test analog in the codebase. Planner should use `12-RESEARCH.md` examples plus Phase 10/11 validation guidance.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `docs/hermes-dev-orchestra/scripts/tests/lib/assert.sh` | test | batch | No `scripts/tests` directory or assertion library exists yet. |
| `docs/hermes-dev-orchestra/scripts/tests/run-all.sh` | test | batch | No aggregate Bash test runner exists yet. |
| `docs/hermes-dev-orchestra/scripts/tests/test-install-probe.sh` | test | batch | Prior install smoke exists only as planning guidance. |
| `docs/hermes-dev-orchestra/scripts/tests/test-skills-load.sh` | test | batch | Prior skill-load checks exist only as setup smoke expectations. |
| `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` | test | batch | Prior helper fixtures exist only as Phase 11 validation guidance. |
| `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` | test | event-driven | Existing file-bus behavior exists in `orch-bus-loop`, not tests. |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | test | request-response | Risk checker does not exist yet. |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | test | event-driven | Pending decision gate does not exist yet. |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | test | request-response | Decision fallback CLI does not exist yet. |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | test | file-I/O | Approval replay/TTL logic does not exist yet. |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | test | transform | No docs grep test exists yet. |

## Metadata

**Analog search scope:** `docs/hermes-dev-orchestra/scripts`, `docs/hermes-dev-orchestra/skills`, `docs/hermes-dev-orchestra/README.md`, `docs/hermes-dev-orchestra/hermes/SOUL.md`, `.planning/phases/10-*`, `.planning/phases/11-*`, `.planning/phases/12-*`, `.planning/REQUIREMENTS.md`.

**Files scanned:** 40 unique docs/planning files plus targeted line searches.

**Pattern extraction date:** 2026-04-25

## PATTERN MAPPING COMPLETE
