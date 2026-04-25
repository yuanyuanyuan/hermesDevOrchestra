# Stack Research: Hermes CLI Prototype

**Researched:** 2026-04-25
**Confidence:** MEDIUM-HIGH for prototype planning; exact package/API details must be verified during implementation.

## Recommendation

Implement the prototype as a Linux-first local CLI aligned with the v1.0 spec:

- Node.js runtime, matching the v1.0 host assumption.
- TypeScript or modern JavaScript CLI entrypoint, with no sudo requirement.
- Built-in Node filesystem/path/process modules for the first slice; add dependencies only when they directly reduce risk.
- JSON/JSONL files as canonical protocol artifacts.
- Git as rollback boundary and smoke-test fixture context.

## Stack Additions

- Local executable command named hermes for prototype commands.
- Test/fixture harness for CLI command smoke tests.
- JSON schema-ready validation layer for bus envelopes and command outputs.

## What Not To Add Yet

- Database/SQLite persistence. JSON state files are enough for the prototype.
- Remote network adapter dependencies. Local file fallback is in scope.
- Real Claude/Codex process orchestration beyond doctor probes/dry-run contracts.
