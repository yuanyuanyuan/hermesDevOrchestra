# Phase 15: Specification System - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `specs/README.md` | config/specification index | transform | `docs/COVERAGE-MATRIX.md` | role-match |
| `specs/file-bus.md` | config/specification | transform | `.planning/SPEC.md` BUS sections | role-match |
| `specs/risk-decisions.md` | config/specification | transform | `.planning/SPEC.md` AUTH/RISK/REMOTE sections | role-match |
| `specs/commands.md` | config/specification | transform | `.planning/SPEC.md` CMD sections | role-match |
| `docs/orchestra/scripts/tests/test-specs.sh` | test | file-I/O, batch | `docs/orchestra/scripts/tests/test-docs.sh` | exact |

## Pattern Assignments

### `specs/README.md` (config/specification index, transform)

**Analog:** `docs/COVERAGE-MATRIX.md`

**Index table pattern** (`docs/COVERAGE-MATRIX.md` lines 1-14):
```markdown
# Hermes Dev Orchestra Coverage Matrix

| Capability | Upstream native | Adapter-provided | Deferred | Evidence | Notes |
|---|---:|---:|---:|---|---|
| `orch-init/start/stop/status` | No | Yes | No | `docs/orchestra/scripts/bin/` | Local entrypoints remain `orch-*`. |
| File bus task/question/decision/review routing | No | Yes | No | `orch-bus-loop`; Runtime `/tmp/hermes-orchestra/{project}/` | JSON envelopes use `.md` compatibility filenames. |
| Static risk rulebook | No | Yes | No | `config/rules.json`; `orch-risk-check` | Defines L3/L4 minimum floors. |
| Local decision fallback | No | Yes | No | `orch-decisions`; `orch-approve <approval_id>`; `orch-reject <approval_id>` | SSH/local fallback only; concrete remote adapter deferred. |
| Per-project Audit JSONL | No | Yes | No | `~/.local/share/hermes-orchestra/{project}/audit.jsonl`; `orch-audit` | Durable Audit layer, not Runtime. |
| `orch-verify` smoke fixtures | No | Yes | No | `scripts/tests/run-all.sh`; `orch-verify` | Pure Bash fixtures, no live Claude/Codex auth required. |
```

**Canonical source pattern** (`.planning/SPEC.md` lines 14-20):
```markdown
### SPEC-01 - Unified specification map

This `SPEC.md` is the unified v1 specification package. Appendix C maps every v1 requirement from `.planning/REQUIREMENTS.md` to a concrete section in this document.

### SPEC-02 - Inline implementable contracts

This document restates the implementable contracts inline.
```

**Apply to new file:**
- Index exactly `specs/file-bus.md`, `specs/risk-decisions.md`, and `specs/commands.md`.
- State that `.planning/SPEC.md` is canonical and `specs/*.md` are derived projections.
- List concrete consumers with repo-relative backticked paths so `test-specs.sh` can parse them.

---

### `specs/file-bus.md` (config/specification, transform)

**Analog:** `.planning/SPEC.md` BUS sections, plus current projection in `docs/orchestra/README.md`

**Source contract pattern** (`.planning/SPEC.md` lines 211-213):
```markdown
### BUS-01 - Canonical protocol

JSON/JSONL is the canonical file-bus protocol. Markdown is a human-readable projection only. Every bus file that carries structured data MUST be valid JSON (single file) or JSON Lines (one JSON object per line).
```

**Envelope contract pattern** (`.planning/SPEC.md` lines 217-242):
```json
{
  "schema_version": "1.0",
  "message_id": "uuid-v4",
  "project_id": "string",
  "task_id": "string",
  "correlation_id": "uuid-v4",
  "status": "pending|active|completed|failed|cancelled|stalled",
  "author": "hermes|claude|codex|user",
  "authority": "L1|L2|L3|L4",
  "timestamp": "2026-04-25T14:30:00Z",
  "payload": { ... }
}
```

**Writer/reader table pattern** (`.planning/SPEC.md` lines 248-258):
```markdown
| File | Writer | Readers | Notes |
|------|--------|---------|-------|
| `task.md` | Hermes | Codex, Claude | Overwritten on new task dispatch |
| `codex-question.md` | Codex | Hermes, Claude | Created when Codex pauses; deleted on resolution |
| `claude-decision.md` | Claude, User(via Hermes) | Hermes, Codex | Appended on challenge rounds; see Appendix B for schema |
| `escalation.md` | Claude | Hermes | Created on risk detection; deleted after resolution |
| `codex-result.md` | Codex | Hermes, Claude | Overwritten on each execution attempt |
| `review-result.md` | Claude | Hermes | Written after code review |
| `*.jsonl` (events) | Claude Code hooks | Hermes | Appended; never overwritten |
```

**Current projection pattern** (`docs/orchestra/README.md` lines 48-60):
```markdown
### 文件通信总线 (per-project)

每个项目在 `/tmp/hermes-orchestra/{project}/` 下有：

| 文件 | 写入者 | 读取者 | 用途 |
|------|--------|--------|------|
| `task.md` | Hermes | Codex | 任务描述与需求 |
| `codex-question.md` | Codex | Hermes/Claude | Codex 遇到的疑问 |
| `claude-decision.md` | Claude | Hermes/Codex | Claude 的技术决策 |
| `escalation.md` | Claude | Hermes | 危险/产品级升级请求 |
| `codex-result.md` | Codex | Hermes/Claude | 执行结果与产出 |
| `review-result.md` | Claude | Hermes | 代码审查意见 |
```

**Apply to new file:**
- `## Source`: `.planning/SPEC.md` §§BUS-01..BUS-06 as primary source.
- `## Consumers`: include `docs/orchestra/scripts/bin/orch-bus-loop`, `docs/orchestra/scripts/tests/test-file-bus.sh`, `docs/orchestra/README.md`, and `docs/orchestra/WORKFLOW.md`.
- Keep the contract narrow: file names, envelope fields, writer/reader ownership, atomic/archive behavior, and JSON/JSONL canonicality.

---

### `specs/risk-decisions.md` (config/specification, transform)

**Analog:** `.planning/SPEC.md` AUTH/RISK/REMOTE sections, plus `docs/orchestra/WORKFLOW.md`

**L3/L4 authority pattern** (`.planning/SPEC.md` lines 83-85):
```markdown
### AUTH-03 - L3/L4 decisions require explicit user approval

L3 (Danger) and L4 (Critical) risk decisions MUST block the affected project until the user explicitly approves or rejects the proposal. No timeout-based auto-approval is permitted.
```

**Risk level table pattern** (`.planning/SPEC.md` lines 484-491):
```markdown
| Level | Name | Examples | Owner | Default Action | Timeout |
|-------|------|----------|-------|---------------|---------|
| L1 | Notice | Add new dependency, update build script, refactor internal function | Claude (async notify user) | Proceed with notification | Configurable, default 30 min auto-proceed |
| L2 | Warning | Delete old API, modify CI/CD config, breaking internal changes | Claude (async notify user) | Configurable, default 30 min auto-reject | Configurable, default 30 min auto-reject |
| L3 | Danger | System commands, modify auth logic, database schema change | User (blocking) | Block until user response | Configurable, default 24h, then auto-reject |
| L4 | Critical | Delete production data, modify secrets | User (blocking) | Block until user response | Configurable, default 24h, then auto-reject |
```

**Blocking behavior pattern** (`.planning/SPEC.md` lines 512-520):
```markdown
L3 and L4 decisions block the affected project until the user explicitly approves or rejects the proposal. During the block:

1. The project's state is set to `blocked`.
2. No new tasks are dispatched to this project.
3. Codex's current execution is paused.
4. Hermes continues polling other projects.
5. The decision request is written to the active decision channel.
```

**Fallback command pattern** (`.planning/SPEC.md` lines 606-615):
```markdown
When no remote adapter is configured, Hermes provides a file-based fallback:

- Decision requests written to `${RUNTIME}/decisions/{project-id}/{decision-id}.request.json`
- User lists pending decisions: `orch-decisions`
- User responds: `orch-approve <approval_id>` or `orch-reject <approval_id>`
- Response written to `${RUNTIME}/decisions/{project-id}/{decision-id}.response.json`
- Hermes polls the decisions directory at configurable interval (default: 5 seconds)
- On read: validates one-time use, TTL, project/task binding, writes final decision to Audit, deletes response file
```

**Decision envelope pattern** (`.planning/SPEC.md` lines 953-996):
```typescript
interface HermesDecision {
  schema_version: "1.0";
  message_id: string;
  project_id: string;
  task_id: string;
  correlation_id: string;
  timestamp: string;
  author: "claude" | "user" | "hermes";
  authority: "L1" | "L2" | "L3" | "L4";
  decision_type: "risk_classification" | "technical_decision" | "implementation_approval" | "user_override";
  rulebook: {
    version: string;
    matched_rules: string[];
    baseline_level: "L1" | "L2" | "L3" | "L4";
    overridable: boolean;
  };
  assessment: {
    assessed_level: "L1" | "L2" | "L3" | "L4";
    escalation_required: boolean;
    escalation_reason?: string;
    confidence: "high" | "medium" | "low";
    conditions?: string[];
  };
  execution: {
    authority_sufficient: boolean;
    granted_by?: "claude" | "user";
    granted_at?: string;
    expires_at?: string;
    challenge_count: number;
    max_challenges: 3;
  };
}
```

**Apply to new file:**
- `## Source`: `.planning/SPEC.md` §§AUTH-03, RISK-01..RISK-05, REMOTE-05, Appendix A, Appendix B.
- `## Consumers`: include `docs/orchestra/scripts/bin/orch-risk-check`, `docs/orchestra/config/rules.json`, `docs/orchestra/scripts/bin/orch-decisions`, `docs/orchestra/scripts/bin/orch-approve`, `docs/orchestra/scripts/bin/orch-reject`, `docs/orchestra/scripts/tests/test-risk-check.sh`, `docs/orchestra/scripts/tests/test-risk-decisions.sh`, `docs/orchestra/scripts/tests/test-decision-cli.sh`, and `docs/orchestra/scripts/tests/test-decision-replay.sh`.
- Optionally list `docs/orchestra/scripts/bin/orch-bus-loop` as supporting consumer if the spec covers L3/L4 enforcement flow; research flagged this as an open planner decision.

---

### `specs/commands.md` (config/specification, transform)

**Analog:** `.planning/SPEC.md` CMD sections, plus command tables in `docs/orchestra/WORKFLOW.md`

**Command contract table pattern** (`.planning/SPEC.md` lines 141-156):
```markdown
| Command | Purpose | Input | Output | Idempotency |
|---------|---------|-------|--------|-------------|
| `hermes init <project-id> <project-dir>` | Register a project | project-id, project-dir path | project config JSON | Yes |
| `hermes start <project-id>` | Start Claude + Codex tmux sessions | project-id | session IDs or error | No |
| `hermes stop <project-id>` | Stop sessions for a project | project-id | termination confirmation | Yes |
| `hermes status` | Show all projects and their states | none | JSON array of project status rows | Yes |
| `orch-decisions` | List pending local fallback decisions | optional project-id | tabular pending decisions | Yes |
| `orch-approve <approval_id>` | Approve a pending local fallback decision | approval_id | user-authored approved decision envelope | No |
| `orch-reject <approval_id>` | Reject a pending local fallback decision | approval_id | user-authored rejected decision envelope | No |
```

**Structured error pattern** (`.planning/SPEC.md` lines 158-187):
```json
{
  "success": false,
  "command": "hermes start api-gateway",
  "timestamp": "2026-04-25T14:30:00Z",
  "data": null,
  "error": {
    "code": "SESSION_EXISTS",
    "message": "Project api-gateway already has active sessions",
    "suggestion": "Run 'hermes stop api-gateway' first, or use 'hermes status' to inspect."
  }
}
```

**Current command surface pattern** (`docs/orchestra/WORKFLOW.md` lines 746-764):
```markdown
| 命令 | 用途 |
|------|------|
| `hermes chat` | 启动 Hermes 主控 |
| `/dev-orchestra` | 激活编排技能 |
| `orch-init <id> <dir>` | 初始化新项目 |
| `orch-start <id> <dir>` | 启动项目的 Claude + Codex |
| `orch-stop <id>` | 停止项目进程 |
| `orch-status [id]` | 查看项目状态 |
| `orch-decisions` | 查看待决策列表 |
| `orch-approve <id> [reason]` | 批准决策 |
| `orch-reject <id> [reason]` | 拒绝决策 |
| `orch-risk-check <cmd>` | 检查命令风险等级 |
| `orch-audit <id> --limit N` | 查看审计日志 |
| `orch-verify` | 运行 smoke 验证 |
```

**Apply to new file:**
- `## Source`: `.planning/SPEC.md` §§CMD-01..CMD-02, with projection references to `docs/orchestra/README.md` and `docs/orchestra/WORKFLOW.md`.
- `## Consumers`: list concrete `docs/orchestra/scripts/bin/orch-*` paths: `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-audit`, and `orch-verify`.
- Include docs/test consumers: `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md`, and `docs/orchestra/scripts/tests/test-docs.sh`.
- Do not add Makefile targets in this phase.

---

### `docs/orchestra/scripts/tests/test-specs.sh` (test, file-I/O, batch)

**Analog:** `docs/orchestra/scripts/tests/test-docs.sh`

**Imports/setup pattern** (`docs/orchestra/scripts/tests/test-docs.sh` lines 1-12):
```bash
#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="docs-contract"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
```

**Positive assertion pattern** (`docs/orchestra/scripts/tests/test-docs.sh` lines 14-34):
```bash
assert_contains "orch-decisions" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-decisions"
assert_contains "orch-approve" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-approve"
assert_contains "orch-reject" "$REPO_ROOT/docs/orchestra/README.md" "README must document orch-reject"
assert_file_exists "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing"
assert_contains "Upstream native" "$REPO_ROOT/docs/COVERAGE-MATRIX.md" "coverage matrix missing upstream column"

test_done
```

**Assertion helper pattern** (`docs/orchestra/scripts/tests/lib/assert.sh` lines 6-38):
```bash
fail() {
    local message="$1"
    local expected="${2:-}"
    local actual="${3:-}"

    echo "FAIL $TEST_NAME: $message" >&2
    [ -n "$expected" ] && echo "expected: $expected" >&2
    [ -n "$actual" ] && echo "actual: $actual" >&2
    exit 1
}

assert_contains() {
    local needle="$1"
    local file="$2"
    local message="${3:-missing expected content}"

    grep -Fq "$needle" "$file" || fail "$message" "$needle" "$(sed -n '1,40p' "$file" 2>/dev/null || true)"
}

assert_file_exists() {
    local file="$1"
    local message="${2:-file missing}"

    [ -f "$file" ] || fail "$message" "$file" "missing"
}
```

**Inline Python parser pattern** (`docs/orchestra/scripts/tests/lib/assert.sh` lines 47-58):
```bash
assert_jsonl_valid() {
    local file="$1"

    python3 - "$file" <<'PY' || fail "invalid JSONL" "$file" "parse failed"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            json.loads(line)
PY
}
```

**Path traversal negative check pattern** (`docs/orchestra/scripts/tests/test-decision-cli.sh` lines 34-41):
```bash
set +e
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-decisions" "../outside" >/tmp/orch-decision-cli-traversal.out 2>&1
decisions_traversal=$?
"$REPO_ROOT/docs/orchestra/scripts/bin/orch-audit" "../outside" >/tmp/orch-audit-traversal.out 2>&1
audit_traversal=$?
set -e
[ "$decisions_traversal" -ne 0 ] || fail "orch-decisions must reject project path traversal" "non-zero" "$decisions_traversal"
[ "$audit_traversal" -ne 0 ] || fail "orch-audit must reject project path traversal" "non-zero" "$audit_traversal"
```

**Runner discovery pattern** (`docs/orchestra/scripts/tests/run-all.sh` lines 8-20):
```bash
shopt -s nullglob
for test_script in "$TEST_DIR"/test-*.sh; do
    if bash "$test_script"; then
        echo "PASS $test_script"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL $test_script"
        FAILED=$((FAILED + 1))
    fi
done

echo "Smoke summary: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
```

**Apply to new file:**
- Use the exact Bash prologue from `test-docs.sh`, but set `TEST_NAME="specs-contract"`.
- Set `SPECS_DIR="$REPO_ROOT/specs"` and `SPEC_INDEX="$SPECS_DIR/README.md"`.
- Assert required sections for every non-index `specs/*.md`: `## Source`, `## Consumers`, `## Drift Check`, `## Conformance Checks`.
- Assert each derived spec cites `.planning/SPEC.md`, each has at least one concrete consumer path, and each is indexed by `specs/README.md`.
- Use Python only for structured Markdown section/path extraction where Bash parsing becomes brittle.

## Shared Patterns

### Derived Spec Shape

**Source:** `.planning/phases/15-specification-system/15-CONTEXT.md` lines 23-33

**Apply to:** `specs/file-bus.md`, `specs/risk-decisions.md`, `specs/commands.md`

```markdown
## Source

## Consumers

## Drift Check

## Conformance Checks
```

Required checks:
- `## Source` must cite `.planning/SPEC.md`.
- `## Consumers` must contain concrete repo-relative paths.
- `## Drift Check` must include a concrete command or check description that can fail.
- `## Conformance Checks` must name at least one automated check.

### Canonical Authority

**Source:** `.planning/phases/15-specification-system/15-CONTEXT.md` lines 36-41

**Apply to:** all `specs/*.md`

```markdown
- `.planning/SPEC.md` always wins over `specs/*.md`.
- `specs/*.md` files are projections, not authorities.
- Downstream agents should read in this order: `.planning/SPEC.md`, then relevant `specs/*.md`, then `docs/orchestra/*` implementation projections.
```

### Consumer Path Convention

**Source:** `.planning/phases/15-specification-system/15-RESEARCH.md` lines 197-210 and 331-355

**Apply to:** all `## Consumers` sections and `test-specs.sh`

```markdown
## Consumers

- `docs/orchestra/scripts/bin/orch-bus-loop` - routes file-bus messages.
- `docs/orchestra/scripts/tests/test-file-bus.sh` - smoke-tests bus routing.
```

Parser requirements:
- Extract only backticked paths from `## Consumers`.
- Reject absolute paths.
- Reject paths containing `..`.
- Fail when `os.path.exists(os.path.join(repo_root, path))` is false.

### Smoke Test Integration

**Source:** `docs/orchestra/scripts/tests/run-all.sh` lines 8-20 and `docs/orchestra/scripts/bin/orch-verify` lines 9-16

**Apply to:** `docs/orchestra/scripts/tests/test-specs.sh`

```bash
for test_script in "$TEST_DIR"/test-*.sh; do
    if bash "$test_script"; then
        echo "PASS $test_script"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL $test_script"
        FAILED=$((FAILED + 1))
    fi
done
```

`orch-verify` already delegates to the package runner:
```bash
PACKAGE_RUNNER="$(cd "$SCRIPT_DIR/.." && pwd)/tests/run-all.sh"
if [ -x "$PACKAGE_RUNNER" ]; then
    exec "$PACKAGE_RUNNER"
fi
```

### Scope Guard

**Source:** `.planning/phases/15-specification-system/15-CONTEXT.md` lines 29-35 and 122-128

**Apply to:** phase planning and execution

```markdown
- Add `docs/orchestra/scripts/tests/test-specs.sh` for derived spec conformance checks.
- Rely on existing `docs/orchestra/scripts/tests/run-all.sh` discovery.
- Do not add Makefile targets in Phase 15.
- Full split of all major `.planning/SPEC.md` sections is deferred until concrete consumers exist.
```

## No Analog Found

All planned files have at least a role-match analog. There is no exact existing `specs/*.md` template, so planner should apply the fixed derived-spec shape from CONTEXT/RESEARCH and use the role-match documentation analogs above.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| _None_ | - | - | Every planned file has a usable local analog. |

## Metadata

**Analog search scope:** `.planning/`, `docs/`, `docs/orchestra/scripts/tests/`, `docs/orchestra/scripts/bin/`
**Files scanned:** 182
**Strong analogs read:** 13 files
**Primary analogs:** `.planning/SPEC.md`, `docs/COVERAGE-MATRIX.md`, `docs/orchestra/README.md`, `docs/orchestra/WORKFLOW.md`, `docs/orchestra/scripts/tests/test-docs.sh`, `docs/orchestra/scripts/tests/lib/assert.sh`, `docs/orchestra/scripts/tests/run-all.sh`
**Pattern extraction date:** 2026-04-28
