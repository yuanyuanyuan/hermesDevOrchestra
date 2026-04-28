# Phase 13 Evidence Audit

> Generated: 2026-04-28
> Task: Evidence Audit & Discoverability

## Repository Snapshot

| Field | Value |
|-------|-------|
| Branch | `main` |
| Commit SHA | `ec964af46d1fff2fd06749176afae9192270ff26` |

### Git Status

```
## main
A  .planning/BACKLOG-COLLABORATIVE-PLANNING.md
A  .planning/phases/13-evidence-audit-and-discoverability/13-CONTEXT.md
A  .planning/phases/13-evidence-audit-and-discoverability/13-DISCUSSION-LOG.md
A  gsd_commands_reference.md
?? .claude/
?? task_phase13_hermes_chat.md
```

### Recent Commits

```
ec964af docs: incorporate phase 13 review feedback
feaeead docs: cross-AI review for phase 13
3cba6a4 docs: update STATE.md for v1.2 roadmap completion
449f0d2 docs: create milestone v1.2 roadmap (6 phases)
98cc1a7 docs: define milestone v1.2 requirements
```

## Pre-existing Worktree Attribution

| File | Status | Phase 13 Pre-existing |
|------|--------|------------------------|
| `.planning/BACKLOG-COLLABORATIVE-PLANNING.md` | Added (staged) | Yes |
| `.planning/phases/13-evidence-audit-and-discoverability/13-CONTEXT.md` | Added (staged) | Yes |
| `.planning/phases/13-evidence-audit-and-discoverability/13-DISCUSSION-LOG.md` | Added (staged) | Yes |
| `gsd_commands_reference.md` | Added (staged) | Yes |
| `task_phase13_hermes_chat.md` | Untracked | No (task artifact) |

## Path Reference Summary

| Category | Count |
|----------|-------|
| scripts-bin | 29 |
| scripts-lib | 2 |
| scripts-setup | 3 |
| scripts-tests | 0 |
| skills | 0 |
| docs | 11 |
| other | 5 |
| **Total** | **50** |

## Path Reference Inventory

| File | Line | Referenced Path | Context Snippet | Category |
|------|------|-----------------|-----------------|----------|
| `task_phase13_hermes_chat.md` | 39 | `docs/hermes-dev-orchestra` | `   - rg -n "docs/hermes-dev-orchestra" --type md --type sh --type json` | other |
| `task_phase13_hermes_chat.md` | 66 | `docs/hermes-dev-orchestra` | `     - docs/hermes-dev-orchestra/README.md -> Product behavior baseline and architecture` | docs |
| `task_phase13_hermes_chat.md` | 67 | `docs/hermes-dev-orchestra` | `     - docs/hermes-dev-orchestra/WORKFLOW.md -> Installation and usage guide` | docs |
| `task_phase13_hermes_chat.md` | 91 | `docs/hermes-dev-orchestra` | `- Spec authority lives in `docs/hermes-dev-orchestra/`; `.planning/SPEC.md` is canonical for planning artifacts.` | other |
| `task_phase13_hermes_chat.md` | 104 | `docs/hermes-dev-orchestra` | `\| `docs/hermes-dev-orchestra/` \| Product behavior baseline, SOUL, skills, scripts \|` | other |
| `task_phase13_hermes_chat.md` | 163 | `docs/hermes-dev-orchestra` | `1. 绝对不要迁移 docs/hermes-dev-orchestra/ 目录（这是 Phase 14 的职责）` | other |
| `task_phase13_hermes_chat.md` | 165 | `docs/hermes-dev-orchestra` | `3. 绝对不要直接修改 docs/hermes-dev-orchestra/scripts/* 文件` | other |
| `docs/COVERAGE-MATRIX.md` | 6 | `docs/hermes-dev-orchestra` | `\| SOUL load \| Yes \| Yes \| No \| `docs/hermes-dev-orchestra/hermes/SOUL.md`; `setup.sh` \| Adapter installs orchestra SOUL into upstream layout. \|` | docs |
| `docs/COVERAGE-MATRIX.md` | 8 | `docs/hermes-dev-orchestra` | `\| `orch-init/start/stop/status` \| No \| Yes \| No \| `docs/hermes-dev-orchestra/scripts/bin/` \| Local entrypoints remain `orch-*`. \|` | scripts-bin |
| `docs/hermes-dev-orchestra/README.md` | 147 | `docs/hermes-dev-orchestra` | `bash docs/hermes-dev-orchestra/scripts/setup.sh` | scripts-setup |
| `docs/hermes-dev-orchestra/WORKFLOW.md` | 76 | `docs/hermes-dev-orchestra` | `bash docs/hermes-dev-orchestra/scripts/setup.sh` | scripts-setup |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | 12 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-risk-check" "npm install lodash" >/tmp/orch-risk-safe.out; safe=$?` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | 13 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-risk-check" "CREATE TABLE users" >/tmp/orch-risk-create.out; create=$?` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | 14 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-risk-check" "sudo chmod 777 /tmp/x" >/tmp/orch-risk-sudo.out; sudo_code=$?` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | 15 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-risk-check" "docker system prune" >/tmp/orch-risk-docker.out; docker=$?` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-check.sh` | 16 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-risk-check" "修改 JWT 密钥" >/tmp/orch-risk-jwt.out; jwt=$?` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | 48 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-risk-decisions-init.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | 60 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | 65 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$approval_id" "approved fixture" >/tmp/orch-risk-approved.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | 66 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-risk-decisions.sh` | 82 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | 20 | `docs/hermes-dev-orchestra` | `source "$REPO_ROOT/docs/hermes-dev-orchestra/scripts/lib/orch-common.sh"` | scripts-lib |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | 26 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-decisions" test-proj > /tmp/orch-decision-cli-list.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | 29 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_approve" "APPROVED fixture" >/tmp/orch-decision-cli-approve.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | 31 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-reject" "$id_reject" "REJECTED fixture" >/tmp/orch-decision-cli-reject.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | 35 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-decisions" "../outside" >/tmp/orch-decision-cli-traversal.out 2>&1` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-cli.sh` | 37 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-audit" "../outside" >/tmp/orch-audit-traversal.out 2>&1` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | 20 | `docs/hermes-dev-orchestra` | `source "$REPO_ROOT/docs/hermes-dev-orchestra/scripts/lib/orch-common.sh"` | scripts-lib |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | 25 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_once" "first approval" >/tmp/orch-replay-first.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | 27 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_once" "replay approval" >/tmp/orch-replay-second.out 2>&1` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | 43 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_expired" "expired approval" >/tmp/orch-replay-expired.out 2>&1` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | 59 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_project" "project mismatch" >/tmp/orch-replay-project.out 2>&1` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-decision-replay.sh` | 75 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-approve" "$id_task" "task mismatch" >/tmp/orch-replay-task.out 2>&1` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 14 | `docs/hermes-dev-orchestra` | `assert_contains "orch-decisions" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-decisions"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 15 | `docs/hermes-dev-orchestra` | `assert_contains "orch-approve" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-approve"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 16 | `docs/hermes-dev-orchestra` | `assert_contains "orch-reject" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-reject"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 17 | `docs/hermes-dev-orchestra` | `assert_contains "orch-risk-check" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-risk-check"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 18 | `docs/hermes-dev-orchestra` | `assert_contains "orch-audit" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-audit"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 19 | `docs/hermes-dev-orchestra` | `assert_contains "orch-verify" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document orch-verify"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 20 | `docs/hermes-dev-orchestra` | `assert_contains "~/.local/share/hermes-orchestra/{project}/audit.jsonl" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must document Audit JSONL path"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-docs.sh` | 21 | `docs/hermes-dev-orchestra` | `assert_contains "docs/COVERAGE-MATRIX.md" "$REPO_ROOT/docs/hermes-dev-orchestra/README.md" "README must reference docs/COVERAGE-MATRIX.md"` | docs |
| `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` | 49 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-init-start-init.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` | 50 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-start" test-proj "$PROJECT_DIR" >/tmp/orch-init-start-start.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` | 51 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-status" test-proj > /tmp/orch-init-start-status.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-init-start-status.sh` | 52 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-stop" test-proj >/tmp/orch-init-start-stop.out \|\| true` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-install-probe.sh` | 39 | `docs/hermes-dev-orchestra` | `bash "$REPO_ROOT/docs/hermes-dev-orchestra/scripts/setup.sh" >/tmp/orch-install-probe.out` | scripts-setup |
| `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` | 60 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-init" test-proj "$PROJECT_DIR" >/tmp/orch-file-bus-init.out` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` | 67 | `docs/hermes-dev-orchestra` | `  "$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` | 73 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once` | scripts-bin |
| `docs/hermes-dev-orchestra/scripts/tests/test-file-bus.sh` | 82 | `docs/hermes-dev-orchestra` | `"$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-bus-loop" test-proj "$PROJECT_DIR" --once` | scripts-bin |
