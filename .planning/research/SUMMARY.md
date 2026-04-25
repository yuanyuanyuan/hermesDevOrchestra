# Research Summary: Hermes CLI Prototype

**Researched:** 2026-04-25

## Stack Additions

- Local hermes CLI prototype using Node.js assumptions from v1.0.
- JSON/JSONL canonical bus and durable JSON state for the first implementation slice.
- Smoke/fixture test harness for command behavior and safety invariants.

## Feature Table Stakes

- Command shell/help/version/JSON errors.
- Project init, task append, status.
- Path manifest and bus/state/audit separation.
- Doctor/preflight probes.
- Local file decision fallback with approve/reject.

## Watch Out For

- Do not implement full live agent orchestration in this milestone.
- Do not bind remote decisions to a concrete adapter.
- Do not allow any L3/L4 timeout or fallback auto-approval.

## Recommended Roadmap

Start at Phase 8 and split into CLI shell, path/bus foundation, project/task/status, doctor/safety/decisions, and verification/handoff.
