# Hermes Dev Orchestra Coverage Matrix

| Capability | Upstream native | Adapter-provided | Deferred | Evidence | Notes |
|---|---:|---:|---:|---|---|
| Upstream install/probe | Yes | No | No | `hermes --version`; pinned commit `023b1bff11c2a01a435f1956a0e2ac1773a065f3` | Upstream remains the `hermes` entry point. |
| SOUL load | Yes | Yes | No | `hermes/SOUL.md`; `setup.sh` | Adapter installs orchestra SOUL into upstream layout. |
| Four skills load | Yes | Yes | No | `dev-orchestra`, `claude-supervisor`, `codex-executor`, `escalation-handler` | Installed under `~/.hermes/skills/`. |
| `orch-init/start/stop/status` | No | Yes | No | `scripts/bin/` | Local entrypoints remain `orch-*`. |
| tmux Claude/Codex sessions | No | Yes | No | `orch-start`; `hermes-{project}-claude`; `hermes-{project}-codex` | Persistent PTY envelopes. |
| File bus task/question/decision/review routing | No | Yes | No | `orch-bus-loop`; Runtime `/tmp/hermes-orchestra/{project}/` | JSON envelopes use `.md` compatibility filenames. |
| Static risk rulebook | No | Yes | No | `config/rules.json`; `orch-risk-check` | Defines L3/L4 minimum floors. |
| Local decision fallback | No | Yes | No | `orch-decisions`; `orch-approve <approval_id>`; `orch-reject <approval_id>` | SSH/local fallback only; concrete remote adapter deferred. |
| Per-project Audit JSONL | No | Yes | No | `~/.local/share/hermes-orchestra/{project}/audit.jsonl`; `orch-audit` | Durable Audit layer, not Runtime. |
| `orch-verify` smoke fixtures | No | Yes | No | `scripts/tests/run-all.sh`; `orch-verify` | Pure Bash fixtures, no live Claude/Codex auth required. |
| concrete remote adapter | No | No | Deferred | N/A | Requires identity/replay/delivery design. |
| production audit hardening | No | No | Deferred | N/A | Retention, backup, and tamper evidence remain future work. |
| container/worktree isolation | No | No | Deferred | N/A | Current slice uses tmux/process isolation only. |
| gbrain integration | No | No | Deferred | N/A | Explicitly outside v1.1 scope. |
| dashboard | No | No | Deferred | N/A | Optional product extension. |
| team approvals | No | No | Deferred | N/A | Single-developer workflow first. |
