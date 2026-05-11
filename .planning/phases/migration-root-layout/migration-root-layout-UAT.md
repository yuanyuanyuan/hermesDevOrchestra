---
status: complete
phase: migration-root-layout
source: README.md, WORKFLOW.md, Makefile, specs/README.md, specs/file-bus.md, specs/commands.md, specs/risk-decisions.md, .planning/PROJECT.md, .planning/STATE.md, docs/COVERAGE-MATRIX.md
started: 2026-05-11T08:25:40Z
updated: 2026-05-11T08:35:20Z
---

## Current Test

[testing complete]

## Tests

### 1. Root Package Layout
expected: 在仓库根目录可以直接看到活动实现包：`README.md`、`WORKFLOW.md`、`scripts/`、`skills/`、`config/`、`hermes/`、`claude-config/`；`docs/` 不再承载主实现包。
result: pass

### 2. Root Documentation Entry
expected: 打开根 `README.md` 和根 `WORKFLOW.md`，看到它们直接描述当前产品行为与安装/使用流程，并引用根级 `scripts/`、`hermes/`、`config/` 路径，而不是 `docs/orchestra/`。
result: pass

### 3. Root Command Surface
expected: 本地开发入口仍然工作，但路径已经切到根目录：`bash scripts/tests/run-all.sh` 能通过，`make test` 只会因为已知的 `upstream-status` pin mismatch 失败，不会再因为旧路径引用失败。
result: pass

### 4. Docs Directory Semantics
expected: `docs/` 现在只保留说明性/辅助材料，例如 `docs/COVERAGE-MATRIX.md` 和 `docs/poc-headless-gsd-execution.md`；主实现文件不应再位于 `docs/orchestra/`。
result: pass

### 5. Active Rules and Specs Updated
expected: 活动规则和规格文件（如 `specs/*.md`、`.planning/PROJECT.md`、`.planning/STATE.md`）描述的活动路径已经切到根目录布局，不再把 `docs/orchestra/` 当成当前实现包路径。
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
