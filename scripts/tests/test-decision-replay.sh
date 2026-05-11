#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="decision-replay"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home"
export RUNTIME_ROOT="$TMP_DIR/tmp/hermes-orchestra"
export STATE_ROOT="$TMP_DIR/state/hermes-orchestra"
export AUDIT_ROOT="$TMP_DIR/audit/hermes-orchestra"
export CACHE_ROOT="$TMP_DIR/cache/hermes-orchestra"
mkdir -p "$HOME"

source "$REPO_ROOT/scripts/lib/orch-common.sh"
orch_project_dirs test-proj
mkdir -p "$RUNTIME_DIR" "$STATE_DIR" "$AUDIT_DIR"

id_once="$(orch_create_pending_decision L3 SECURITY "One-time" task-1 esc-1 escalation-handler)"
"$REPO_ROOT/scripts/bin/orch-approve" "$id_once" "first approval" >/tmp/orch-replay-first.out
set +e
"$REPO_ROOT/scripts/bin/orch-approve" "$id_once" "replay approval" >/tmp/orch-replay-second.out 2>&1
second=$?
set -e
[ "$second" -ne 0 ] || fail "used_at approval replay should fail" "non-zero" "$second"

id_expired="$(orch_create_pending_decision L3 SECURITY "Expired" task-2 esc-2 escalation-handler)"
python3 - "$STATE_DIR/pending-decisions/$id_expired.json" <<'PY'
import json, os, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["expires_at_epoch"] = 1
tmp = f"{path}.tmp"
json.dump(data, open(tmp, "w", encoding="utf-8"), indent=2)
os.replace(tmp, path)
PY
set +e
"$REPO_ROOT/scripts/bin/orch-approve" "$id_expired" "expired approval" >/tmp/orch-replay-expired.out 2>&1
expired=$?
set -e
[ "$expired" -ne 0 ] || fail "expires_at_epoch approval should fail" "non-zero" "$expired"

id_project="$(orch_create_pending_decision L3 SECURITY "Project mismatch" task-3 esc-3 escalation-handler)"
python3 - "$STATE_DIR/pending-decisions/$id_project.json" <<'PY'
import json, os, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["project_id"] = "other-proj"
tmp = f"{path}.tmp"
json.dump(data, open(tmp, "w", encoding="utf-8"), indent=2)
os.replace(tmp, path)
PY
set +e
"$REPO_ROOT/scripts/bin/orch-approve" "$id_project" "project mismatch" >/tmp/orch-replay-project.out 2>&1
project_code=$?
set -e
[ "$project_code" -ne 0 ] || fail "project_id binding mismatch should fail" "non-zero" "$project_code"

id_task="$(orch_create_pending_decision L3 SECURITY "Task mismatch" task-4 esc-4 escalation-handler)"
python3 - "$STATE_DIR/pending-decisions/$id_task.json" <<'PY'
import json, os, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["task_id"] = "other-task"
tmp = f"{path}.tmp"
json.dump(data, open(tmp, "w", encoding="utf-8"), indent=2)
os.replace(tmp, path)
PY
set +e
"$REPO_ROOT/scripts/bin/orch-approve" "$id_task" "task mismatch" >/tmp/orch-replay-task.out 2>&1
task_code=$?
set -e
[ "$task_code" -ne 0 ] || fail "task_id binding mismatch should fail" "non-zero" "$task_code"

test_done
