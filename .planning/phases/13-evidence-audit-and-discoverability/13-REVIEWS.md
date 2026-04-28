---
phase: 13
reviewers: [claude, opencode]
successful_reviewers: [claude]
failed_reviewers: [opencode]
skipped_reviewers:
  codex: skipped because current runtime is Codex
  gemini: CLI missing
  coderabbit: CLI missing
  qwen: CLI missing
  cursor: CLI missing
reviewed_at: 2026-04-28T15:47:29+08:00
plans_reviewed:
  - .planning/phases/13-evidence-audit-and-discoverability/13-01-PLAN.md
---

# Cross-AI Plan Review - Phase 13

## Claude Review

### Summary

该计划作为 v1.2 迁移的第一个执行阶段，目标明确、任务边界清晰。采用 append-only 策略保护现有 GSD managed blocks、使用与 GSD 一致的 HTML comment delimiter、以及将 README.md 设计为轻量级导航页而非重复增强层文档，这些决策都是正确的。然而，计划对路径引用清单的规模毫无准备（rg 输出达 1084 行/210KB），category 分类系统无法覆盖实际文件结构，且 Package Boundary 遗漏了实际存在的 helper 命令。这些缺陷可能导致证据文件无法完成、验收标准无法满足、或 AGENTS.md 内容与实际代码不一致。

### Strengths

- **Append-only 策略正确**：明确声明不覆盖现有 GSD managed blocks，使用 `<!-- hermes-dev-orchestra-start/end -->` delimiter 与现有 GSD 模式保持一致，零碰撞风险。
- **README.md 轻量级设计合理**：只包含状态横幅和导航链接，不重复安装命令或详细用法，避免与 `docs/hermes-dev-orchestra/WORKFLOW.md` 产生维护负担。
- **任务边界清晰**：四个任务（证据生成、README 创建、AGENTS 追加、CLAUDE 更新）互不重叠，各自有独立的验收标准。
- **Verification 脚本完整**：5 条验证命令覆盖了所有 must-haves，执行者可快速确认完成状态。

### Concerns

- **[HIGH] Path Reference Inventory 规模失控未处理**：`rg -n "docs/hermes-dev-orchestra"` 在仓库中产生 **1084 行、210KB** 的输出。绝大多数匹配来自测试脚本中重复引用 `$REPO_ROOT/docs/hermes-dev-orchestra/scripts/bin/orch-*` 的路径。如果按计划的表格格式逐行记录，`13-EVIDENCE.md` 将成为一个数千行的不可读文件，完全丧失“审计”价值。计划中没有任何针对数据量过大时的分组、去重或汇总策略。
- **[HIGH] Category 分类系统与实际文件结构不匹配**：验收标准限定 category 只能使用 `scripts-bin`、`scripts-lib`、`skills`、`docs` 四种。但 `docs/hermes-dev-orchestra/scripts/` 根目录下存在 `setup.sh`（既非 `bin` 也非 `lib`），`scripts/tests/` 目录下的测试文件也会产生引用。执行者无法在不违反验收标准的情况下为这些路径分配 category。
- **[MEDIUM] Package Boundary 遗漏实际存在的 helper 命令**：`scripts/bin/` 下实际存在 11 个 helper：`orch-init`、`orch-start`、`orch-stop`、`orch-status`、`orch-bus-loop`、`orch-risk-check`、`orch-audit`、`orch-decisions`、`orch-approve`、`orch-reject`、`orch-verify`。计划中只列出了 9 个，遗漏了 `orch-verify` 和 `orch-bus-loop`。`orch-verify` 在 README.md “进程管理速查表”中有明确出现，遗漏会导致 `AGENTS.md` 与产品文档不一致。
- **[MEDIUM] Agent Role Boundary 表述存在误导**：“Hermes must not bypass `orch-risk-check` L3/L4 blocking” 暗示 `orch-risk-check` 是 L3/L4 阻塞机制本身。实际上 `orch-risk-check` 是一个命令行风险评估工具（用户可运行 `orch-risk-check "docker system prune"` 查看风险等级），而 L3/L4 的真正阻塞机制是 `escalation.md` 检测 + Hermes `clarify()` 调用。该规则应表述为 “Hermes must enforce L3/L4 blocking via `clarify()` and must not auto-approve” 或 “Hermes must not bypass escalation.md -> clarify() L3/L4 blocking”。
- **[MEDIUM] 未处理工作区已有变更对验证的干扰**：当前 `git status` 显示已有多个 `A`/`M`/`??` 文件（如 `gsd_commands_reference.md`、`.planning/STATE.md` 的修改、Phase 13 自身的上下文文件）。success criteria 要求 “`git diff --stat` shows only the expected files modified”，但已有变更会导致验证结果包含非 Phase 13 的变更。计划没有说明执行前是否应暂存已有变更，或验证时应如何排除。
- **[LOW] Task 4 对 Task 3 的隐式串行依赖未声明**：Task 4 的 `read_first` 要求 “AGENTS.md (after Task 3, to verify Dev Orchestra section exists)”，但两个任务在 `<tasks>` 中没有 `depends_on` 或顺序标记。虽然实际执行可以串行处理，但计划文档中应显式声明。
- **[LOW] 13-EVIDENCE.md 缺少 untracked file attribution**：D-13-09 决策要求对未跟踪文件提供归属说明（如 `gsd_commands_reference.md — project documentation (safe to commit or gitignore)`）。但 Task 1 的 action 只要求捕获 `git status --short --branch` 输出，没有要求逐条添加 attribution notes。

### Suggestions

1. **为 Path Reference Inventory 增加去重/汇总策略**：在生成表格前，先对 rg 输出按 `(File, Referenced Path)` 去重，或按 Referenced Path 分组汇总（“该路径被 N 个文件引用”）。如果保留逐行表格，应增加一个 `Reference Count` 列，并限制只展示唯一的 `(path, category)` 组合，将完整原始输出附在文件末尾的 collapsible section 中。
2. **扩展 Category 分类或调整分类规则**：增加 `scripts-setup`、`scripts-tests`、`scripts-common` 等类别以覆盖 `scripts/` 根目录和 `scripts/tests/`、`scripts/lib/` 下的文件；或者将分类规则改为按“被引用路径的第一级子目录”自动推导，而不是硬编码 4 个类别。
3. **在 Package Boundary 中补全 helper 列表**：追加 `orch-verify`（安装验证）和 `orch-bus-loop`（per-project internal watcher）到 entrypoints 列表中。`orch-bus-loop` 是文件总线 runtime 的核心组件，遗漏会造成严重的架构边界描述缺失。
4. **修正 Agent Role Boundary 中 L3/L4 的表述**：将 “Hermes must not bypass `orch-risk-check` L3/L4 blocking” 改为 “Hermes must not auto-approve L3/L4 escalations; blocking is enforced via `clarify()` and escalation.md, not via `orch-risk-check`”。
5. **在 verification 之前增加工作区基线处理步骤**：在 Task 1 的 action 中增加一步：记录当前已有变更的清单（`git status --short`），并在最终 `git diff --stat` 验证时与基线对比，只检查 Phase 13 新增的变更。
6. **在 13-EVIDENCE.md 的 Repository Snapshot 中增加 untracked attribution**：为每个 `??` 状态的文件添加一行说明其来源/归属。

### Risk Assessment

**Overall Risk: MEDIUM**

计划的核心目标（创建 README、追加 `AGENTS.md`、更新 `CLAUDE.md`、生成证据文件）在技术上都很简单，执行失败的可能性低。风险主要来自：

1. **证据文件规模问题**可能导致验收标准无法满足（HIGH 影响）。
2. **Category 分类不匹配**会导致执行者要么违反验收标准、要么随意归类（MEDIUM 影响）。
3. **AGENTS.md 内容与实际代码不一致**（遗漏 helper、误导性 L3/L4 描述）会在后续 phase 中累积为技术债务（MEDIUM 影响）。

这些问题在计划阶段修正的成本远低于执行后发现再修正。建议先修正分类系统和边界描述，再进入执行。

---

## OpenCode Review

OpenCode review failed. The CLI is installed, but both the workflow stdin invocation and a minimal health check failed before producing model output.

### Failure Details

- `cat /tmp/gsd-review-prompt-13.md | opencode run -` failed with exit status 1.
- `opencode run --file /tmp/gsd-review-prompt-13.md "Review the attached Cross-AI Plan Review Request and output the requested markdown review."` failed with exit status 1.
- `opencode run "Say ok"` health check also failed with exit status 1.
- Error observed from stderr/log: `fn3 is not a function. (In 'fn3(input)', 'fn3' is an instance of Object)`.
- OpenCode version in log: `1.1.48`.

---

## Consensus Summary

Only one reviewer (`claude`) completed successfully. Because OpenCode failed and all other non-Codex reviewer CLIs were unavailable, this run cannot produce a true multi-reviewer consensus.

### Agreed Strengths

No multi-reviewer agreement available. The successful review identified these plan strengths:

- Append-only `AGENTS.md` strategy protects existing GSD managed blocks.
- Lightweight root `README.md` avoids duplicating the enhancement-layer docs.
- Task boundaries are clear and verification commands cover the planned must-haves.

### Agreed Concerns

No multi-reviewer agreement available. The highest-priority concerns from the successful review are:

- The path-reference inventory may be too large and should use a grouping or deduplication strategy.
- The four-category classification scheme does not cover actual `scripts/` subpaths such as `setup.sh` and `scripts/tests/`.
- The `AGENTS.md` Package Boundary should include `orch-verify` and `orch-bus-loop`.
- The L3/L4 boundary wording should describe the real blocking mechanism rather than implying `orch-risk-check` is the blocker.
- Verification should account for pre-existing dirty worktree changes.

### Divergent Views

No divergent views are available because only one reviewer produced a substantive review.
