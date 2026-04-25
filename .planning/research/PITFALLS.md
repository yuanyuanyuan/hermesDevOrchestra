# Pitfalls Research: Hermes CLI Prototype

**Researched:** 2026-04-25

## Pitfalls

| Risk | Prevention | Phase |
|------|------------|-------|
| Treating Markdown as canonical state | Write JSON/JSONL canonical artifacts and keep Markdown docs separate | 9 |
| Conflating Runtime, State, and Audit paths | Implement path resolver first and test physical separation | 9 |
| Building live agent orchestration too early | Keep live Claude/Codex control out of this prototype except doctor probes | 8-12 |
| L3/L4 accidental auto-approval | Encode no-auto-approval as a smoke-tested invariant | 11 |
| Status command reading stale runtime files as truth | Status reads durable State and Audit, then references Runtime as active scratch only | 10 |
| No-sudo path assumptions drifting | Smoke test fallback paths and document local install/dev command | 8, 12 |
