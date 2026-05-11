# Hermes Dev Orchestra 任务指令 — Phase 13 Plan 01

> **生成时间**: 2026-04-28
> **用途**: 直接复制粘贴到 `hermes chat` 中执行
> **目标**: Milestone v1.2 Phase 13 — Evidence Audit & Discoverability

---

```text
/dev-orchestra

【项目初始化与编排启动】

项目：hermes-dev-orchestra
目录：/data/hermes

请按以下顺序执行前置检查：
1. 运行 orch-status hermes-dev-orchestra，检查项目是否已注册
2. 如未注册，执行 orch-init hermes-dev-orchestra /data/hermes
3. 确认 /data/hermes 是 git 仓库且工作正常
4. 执行 orch-start hermes-dev-orchestra /data/hermes 启动 Claude + Codex 进程对
5. 验证 tmux 会话 hermes-hermes-dev-orchestra-claude 和 hermes-hermes-dev-orchestra-codex 已运行

【任务总述】

在 hermes-dev-orchestra 项目中执行 Milestone v1.2 Phase 13 Plan 01：Evidence Audit & Discoverability。

这是一个纯文档/规划类任务（无风险操作），包含 5 个顺序执行的子任务。

【Task 1 — 生成 13-EVIDENCE.md】

执行步骤：
1. 使用 gsd-explore 技能扫描仓库结构
2. 运行以下命令并记录输出：
   - git branch --show-current
   - git rev-parse HEAD
   - git status --short --branch
   - git log --oneline -5
   - rg -n "docs/hermes-dev-orchestra" --type md --type sh --type json
3. 创建 .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md
4. 文件必须包含以下章节：
   - ## Repository Snapshot（分支、commit SHA、git status、最近5个提交）
   - ## Pre-existing Worktree Attribution（当前脏工作区归因表，标明哪些文件是Phase 13之前已存在的）
   - ## Path Reference Summary（rg 命令的总匹配数、分类统计）
   - ## Path Reference Inventory（每行rg匹配一行表格：File | Line | Referenced Path | Context Snippet | Category）
5. 分类规则（按被引用的路径类型）：
   - scripts-bin：scripts/bin/*
   - scripts-lib：scripts/lib/*
   - scripts-setup：scripts/setup.sh
   - scripts-tests：scripts/tests/*
   - skills：skills/*
   - docs：README.md, WORKFLOW.md, SOUL.md, COVERAGE-MATRIX.md
   - other：不属于以上分类的路径
6. Context Snippet 中的管道符必须转义为 \|

【Task 2 — 创建根目录 README.md】

执行步骤：
1. 使用 gsd-docs-update 技能规范文档格式
2. 创建 /data/hermes/README.md
3. 内容结构：
   - # Hermes Dev Orchestra
   - 状态横幅："> **Status:** v1.2 migration in progress (2026-04-28)"
   - ## What This Is（1-2句话项目简介）
   - ## Documentation（导航表格，包含以下链接）：
     - docs/hermes-dev-orchestra/README.md -> Product behavior baseline and architecture
     - docs/hermes-dev-orchestra/WORKFLOW.md -> Installation and usage guide
     - AGENTS.md -> Agent rules and role boundaries
     - .planning/SPEC.md -> Canonical specification
     - .planning/ROADMAP.md -> Development roadmap and phase tracking
   - ## Quick Navigation（快速导航链接）
4. 不包含：bash setup.sh 命令、## Quick Start、## Installation、详细使用步骤

【Task 3 — 向 AGENTS.md 追加 Dev Orchestra 章节】

执行步骤：
1. 使用 gsd-verify-work 技能先读取 AGENTS.md，确认所有 GSD managed blocks 完整
2. 找到 <!-- GSD:profile-end --> 之后的位置
3. 追加以下内容（使用 HTML comment 分隔符）：

<!-- hermes-dev-orchestra-start -->
## Hermes Dev Orchestra

Project-specific rules for the Hermes Dev Orchestra adaptation layer.
These complement (not replace) the Architecture section above.

### Package Boundary

- This repository is an **adapter layer**, not a standalone runtime.
- Local entrypoints are limited to `orch-*` helpers: `orch-init`, `orch-start`, `orch-stop`, `orch-status`, `orch-bus-loop`, `orch-risk-check`, `orch-audit`, `orch-decisions`, `orch-approve`, `orch-reject`, `orch-verify`.
- Spec authority lives in `docs/hermes-dev-orchestra/`; `.planning/SPEC.md` is canonical for planning artifacts.

### Agent Role Boundary

- **Hermes** must not auto-approve L3/L4 escalations. Blocking flows through `escalation.md` or high-risk `claude-decision.md`, `orch-bus-loop`, pending decisions, and explicit user action via `orch-decisions`, `orch-approve`, or `orch-reject`.
- **Claude** must not modify upstream `NousResearch/hermes-agent` core code.
- **Codex** must not modify `~/.hermes-orchestra/rules.json`.
- `orch-risk-check` is a risk classifier/helper; it is not a replacement for the L3/L4 blocking and user-decision flow.

### Directory Navigation

| Directory | Purpose |
|-----------|---------|
| `docs/hermes-dev-orchestra/` | Product behavior baseline, SOUL, skills, scripts |
| `.planning/SPEC.md` | Canonical specification |
| `.planning/STATE.md` | Project state and decisions |
<!-- hermes-dev-orchestra-end -->

4. 不编辑、移动、删除任何现有的 <!-- GSD:* --> managed block

【Task 4 — 更新 CLAUDE.md 交叉引用】

执行步骤：
1. 读取现有 CLAUDE.md
2. 在文件末尾追加：

## Hermes Dev Orchestra References

- Agent rules and boundaries: See `AGENTS.md` -> `## Hermes Dev Orchestra`
- Canonical specification: See `.planning/SPEC.md`

3. 如果 CLAUDE.md 末尾已有 ---，在最后一个 --- 之前插入
4. 不重复 AGENTS.md 或 SPEC.md 的内容

【Task 5 — 验证交付物】

执行步骤：
1. 使用 gsd-verify-work 技能执行验证
2. 运行以下验证命令：
   - test -f README.md && echo "OK: README.md exists"
   - grep -q "hermes-dev-orchestra-start" AGENTS.md && echo "OK: delimiter found"
   - grep -q "orch-bus-loop" AGENTS.md && grep -q "orch-verify" AGENTS.md && echo "OK: helper list complete"
   - grep -q "must not auto-approve L3/L4" AGENTS.md && echo "OK: L3/L4 wording found"
   - grep -q "Hermes Dev Orchestra References" CLAUDE.md && echo "OK: CLAUDE.md reference found"
   - test -f .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md && echo "OK: 13-EVIDENCE.md exists"
   - grep -q "## Pre-existing Worktree Attribution" .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md && echo "OK: worktree baseline documented"
   - grep -q "scripts-setup" .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md && echo "OK: scripts-setup category found"
3. 运行 git diff -- README.md AGENTS.md CLAUDE.md .planning/phases/13-evidence-audit-and-discoverability/13-EVIDENCE.md 审查变更范围
4. 确认所有验证命令输出 OK

【GSD 技能底座要求】

Codex 执行端（实际编码/文档）：
- 所有任务执行使用 gsd-execute-phase 技能
- 仓库探索使用 gsd-explore 技能
- 文档更新使用 gsd-docs-update 技能
- 变更验证使用 gsd-verify-work 技能
- 遇到歧义或冲突时，暂停并写入 codex-question.md

Claude 监督端（代码审查/决策）：
- 文档审查使用 gsd-code-review 技能
- 验证检查使用 gsd-verify-work 技能
- 高风险评估使用 gsd-secure-phase 技能
- 技术决策写入 claude-decision.md

Hermes 编排端：
- 任务规划使用 gsd-plan-phase 技能
- 里程碑跟踪使用 gsd-progress 技能
- 任务完成后使用 gsd-milestone-summary 技能更新状态

【约束条件】

1. 绝对不要迁移 docs/hermes-dev-orchestra/ 目录（这是 Phase 14 的职责）
2. 绝对不要编辑任何 GSD managed blocks（<!-- GSD:* --> 包裹的内容）
3. 绝对不要直接修改 docs/hermes-dev-orchestra/scripts/* 文件
4. 不引入新依赖
5. 保持所有现有文件的格式和编码
6. 这是一个 L1/L2 风险级别的文档任务，无需阻塞用户审批

【验收标准】

- [ ] README.md 存在且轻量，含 v1.2 状态横幅和5个导航链接
- [ ] AGENTS.md 保留全部现有 GSD markers，追加的章节包含全部11个 helper 名称
- [ ] AGENTS.md 正确描述 L3/L4 阻塞流程（escalation.md -> orch-bus-loop -> pending -> orch-decisions/approve/reject）
- [ ] AGENTS.md 明确说明 orch-risk-check 是分类器不是阻塞机制
- [ ] CLAUDE.md 包含交叉引用且不重复内容
- [ ] 13-EVIDENCE.md 包含仓库快照、工作区归因、完整路径引用清单
- [ ] 所有5个任务的 acceptance criteria 全部通过
- [ ] git diff 范围正确，不引入无关变更

【通信协议】

1. Hermes 将本任务写入 /tmp/hermes-orchestra/hermes-dev-orchestra/task.md（JSON envelope）
2. Watcher 派发给 Codex tmux 会话执行
3. Codex 按 task.md 逐任务执行：
   - 遇到疑问 -> 写入 codex-question.md
   - 完成任务 -> 写入 codex-result.md
4. Watcher 将 codex-result.md 转发给 Claude 审查
5. Claude 审查后写入 review-result.md（APPROVED / NEEDS_MODIFICATION / REJECTED）
6. 如有高风险操作，Claude 写入 escalation.md
7. Hermes 汇总结果，向用户报告

请现在开始执行。
```

---

## 使用步骤

1. SSH 到 Ubuntu 开发机
2. 运行 `hermes chat`
3. 输入 `/dev-orchestra` 激活编排技能
4. 复制上方 ```text ... ``` 之间的全部内容，粘贴发送给 Hermes
5. Hermes 会自动处理项目初始化、启动编排会话、下发任务给 Codex 执行
