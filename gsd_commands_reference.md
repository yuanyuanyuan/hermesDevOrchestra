# GSD 命令与代理完整参考手册

> 生成时间: 2026-04-28
> 来源目录: `~/.claude/skills/` 和 `~/.claude/agents/`
> 适用平台: Claude Code (`.md`) / Codex (`.toml`)

---

## 目录

1. [GSD Skills（用户可直接执行的命令）](#gsd-skills)
2. [GSD Agents（由 Orchestrator 调用的子代理）](#gsd-agents)
3. [通用说明](#通用说明)

---

## GSD Skills

用户可直接通过 `/gsd-<command>` 格式执行的命令，位于 `~/.claude/skills/gsd-*/SKILL.md`。

| 命令 | 位置 | 描述 | 参数格式 | 依赖 | 执行要求 |
|------|------|------|----------|------|----------|
| `/gsd-add-backlog` | `~/.claude/skills/gsd-add-backlog/` | 将想法添加到 backlog 停车场（999.x 编号） | `<description>` | `.planning/` 目录 | 需有活跃项目 |
| `/gsd-add-phase` | `~/.claude/skills/gsd-add-phase/` | 在里程碑末尾添加新阶段 | `<description>` | `ROADMAP.md` | 需有里程碑 |
| `/gsd-add-tests` | `~/.claude/skills/gsd-add-tests/` | 基于 UAT 标准为已完成阶段生成测试 | `<phase> [instructions]` | 阶段已完成 | 需有 PLAN.md |
| `/gsd-add-todo` | `~/.claude/skills/gsd-add-todo/` | 捕获想法或任务为待办 | `[description]` | `.planning/` | 无 |
| `/gsd-ai-integration-phase` | `~/.claude/skills/gsd-ai-integration-phase/` | 为 AI 系统阶段生成 AI-SPEC.md | `[phase number]` | 框架文档 | 需联网搜索 |
| `/gsd-analyze-dependencies` | `~/.claude/skills/gsd-analyze-dependencies/` | 分析阶段依赖并建议 ROADMAP.md 条目 | 无 | `ROADMAP.md` | 无 |
| `/gsd-audit-fix` | `~/.claude/skills/gsd-audit-fix/` | 自动审计到修复流水线 | `--source <audit-uat>` | 审计结果 | 需有 REVIEW.md |
| `/gsd-audit-milestone` | `~/.claude/skills/gsd-audit-milestone/` | 归档前审计里程碑完成情况 | `[version]` | 所有阶段 SUMMARY.md | 需用户确认 |
| `/gsd-audit-uat` | `~/.claude/skills/gsd-audit-uat/` | 跨阶段审计未完成的 UAT | 无 | `.planning/` | 无 |
| `/gsd-autonomous` | `~/.claude/skills/gsd-autonomous/` | 自动运行剩余所有阶段 | `[--from N] [--to N]` | 计划完备 | 可选交互模式 |
| `/gsd-check-todos` | `~/.claude/skills/gsd-check-todos/` | 列出待办并选择一个开始 | `[area filter]` | `TODO.md` | 无 |
| `/gsd-cleanup` | `~/.claude/skills/gsd-cleanup/` | 归档已完成里程碑的阶段目录 | 无 | 完成里程碑 | 谨慎使用 |
| `/gsd-code-review` | `~/.claude/skills/gsd-code-review/` | 审查阶段源码的 bug/安全/质量 | `<phase> [--depth]` | 代码变更 | 需有 SUMMARY.md |
| `/gsd-code-review-fix` | `~/.claude/skills/gsd-code-review-fix/` | 自动修复 REVIEW.md 中的问题 | `<phase> [--all] [--auto]` | REVIEW.md | 逐原子提交 |
| `/gsd-complete-milestone` | `~/.claude/skills/gsd-complete-milestone/` | 归档里程碑并准备下一版本 | `<version>` | 全部完成 | 需用户确认 |
| `/gsd-debug` | `~/.claude/skills/gsd-debug/` | 系统化调试（跨上下文持久化） | `[list/status/continue]` | 无 | 可选 `--diagnose` |
| `/gsd-discuss-phase` | `~/.claude/skills/gsd-discuss-phase/` | 计划前通过提问收集阶段上下文 | `<phase> [--all/auto/chain]` | 阶段定义 | 推荐交互式 |
| `/gsd-docs-update` | `~/.claude/skills/gsd-docs-update/` | 生成/更新项目文档 | `[--force] [--verify-only]` | 代码库 | 需验证 |
| `/gsd-do` | `~/.claude/skills/gsd-do/` | 自动路由到正确的 GSD 命令 | `<description>` | 无 | 智能路由 |
| `/gsd-eval-review` | `~/.claude/skills/gsd-eval-review/` | 回溯审计 AI 阶段的评估覆盖 | `[phase number]` | AI-SPEC.md | 无 |
| `/gsd-execute-phase` | `~/.claude/skills/gsd-execute-phase/` | 波浪式并行执行阶段计划 | `<phase> [--wave N]` | PLAN.md | 需计划已审批 |
| `/gsd-explore` | `~/.claude/skills/gsd-explore/` | 苏格拉底式构思和想法路由 | 无 | 无 | 计划前使用 |
| `/gsd-extract_learnings` | `~/.claude/skills/gsd-extract_learnings/` | 从已完成阶段提取经验教训 | `<phase-number>` | SUMMARY.md | 无 |
| `/gsd-fast` | `~/.claude/skills/gsd-fast/` | 内联快速执行（无子代理开销） | `[task]` | 无 | 简单任务专用 |
| `/gsd-forensics` | `~/.claude/skills/gsd-forensics/` | GSD 工作流失败的事后调查 | `[problem]` | git 历史 | 分析用 |
| `/gsd-from-gsd2` | `~/.claude/skills/gsd-from-gsd2/` | 从 GSD-2 导入回 GSD v1 | `[--path] [--force]` | `.gsd/` 目录 | 需确认 |
| `/gsd-graphify` | `~/.claude/skills/gsd-graphify/` | 构建/查询项目知识图谱 | `[build/query/status/diff]` | `.planning/` | 无 |
| `/gsd-health` | `~/.claude/skills/gsd-health/` | 诊断规划目录健康并修复 | `[--repair]` | `.planning/` | 可选修复 |
| `/gsd-help` | `~/.claude/skills/gsd-help/` | 显示可用 GSD 命令和用法 | 无 | 无 | 无 |
| `/gsd-import` | `~/.claude/skills/gsd-import/` | 导入外部计划并检测冲突 | `--from <filepath>` | 外部文件 | 冲突检测 |
| `/gsd-inbox` | `~/.claude/skills/gsd-inbox/` | 审查 GitHub issues/PRs | `[--issues] [--prs]` | GitHub CLI | 需 gh 认证 |
| `/gsd-ingest-docs` | `~/.claude/skills/gsd-ingest-docs/` | 扫描并引导 `.planning/` 设置 | `[path] [--mode]` | 混合文档 | 自动分类 |
| `/gsd-insert-phase` | `~/.claude/skills/gsd-insert-phase/` | 插入小数阶段（如 72.1） | `<after> <description>` | ROADMAP.md | 紧急用 |
| `/gsd-intel` | `~/.claude/skills/gsd-intel/` | 查询/刷新代码库情报文件 | `[query/status/diff/refresh]` | `.planning/intel/` | 无 |
| `/gsd-join-discord` | `~/.claude/skills/gsd-join-discord/` | 加入 GSD Discord 社区 | 无 | 无 | 无 |
| `/gsd-list-phase-assumptions` | `~/.claude/skills/gsd-list-phase-assumptions/` | 计划前展示阶段假设 | `[phase]` | 阶段定义 | 纠错用 |
| `/gsd-list-workspaces` | `~/.claude/skills/gsd-list-workspaces/` | 列出活跃 GSD 工作区 | 无 | 无 | 无 |
| `/gsd-manager` | `~/.claude/skills/gsd-manager/` | 多阶段管理交互中心 | 无 | `.planning/` | 管理用 |
| `/gsd-map-codebase` | `~/.claude/skills/gsd-map-codebase/` | 并行映射代码库分析文档 | `[area]` | 代码库 | 新项目用 |
| `/gsd-milestone-summary` | `~/.claude/skills/gsd-milestone-summary/` | 生成里程碑项目摘要 | `[version]` | 归档文件 | 团队入职用 |
| `/gsd-new-milestone` | `~/.claude/skills/gsd-new-milestone/` | 开始新里程碑周期 | `[milestone name]` | PROJECT.md | 无 |
| `/gsd-new-project` | `~/.claude/skills/gsd-new-project/` | 初始化新项目 | `[--auto]` | 无 | 深度上下文收集 |
| `/gsd-new-workspace` | `~/.claude/skills/gsd-new-workspace/` | 创建隔离工作区 | `--name <name>` | git | 可选 worktree/clone |
| `/gsd-next` | `~/.claude/skills/gsd-next/` | 自动推进到下一步 | 无 | `.planning/` | 智能路由 |
| `/gsd-note` | `~/.claude/skills/gsd-note/` | 零摩擦想法捕获 | `<text> \| list \| promote` | 无 | 可升级待办 |
| `/gsd-pause-work` | `~/.claude/skills/gsd-pause-work/` | 暂停工作时创建上下文交接 | 无 | 进行中阶段 | 生成 CONTEXT.md |
| `/gsd-plan-milestone-gaps` | `~/.claude/skills/gsd-plan-milestone-gaps/` | 为审计发现创建补全阶段 | 无 | 审计结果 | 无 |
| `/gsd-plan-phase` | `~/.claude/skills/gsd-plan-phase/` | 创建详细阶段计划 | `[phase] [--auto/research]` | gsd-planner 代理 | 推荐验证循环 |
| `/gsd-plant-seed` | `~/.claude/skills/gsd-plant-seed/` | 捕获前瞻性想法（带触发条件） | `[idea]` | 无 | 自动提醒 |
| `/gsd-pr-branch` | `~/.claude/skills/gsd-pr-branch/` | 过滤 `.planning/` 提交创建 PR | `[target branch]` | git | 需干净分支 |
| `/gsd-profile-user` | `~/.claude/skills/gsd-profile-user/` | 生成开发者行为档案 | `[--questionnaire]` | 会话历史 | 需同意 |
| `/gsd-progress` | `~/.claude/skills/gsd-progress/` | 检查进度并路由下一步 | `[--forensic]` | `.planning/` | 可选完整性审计 |
| `/gsd-quick` | `~/.claude/skills/gsd-quick/` | 快速任务（原子提交+状态追踪） | `[task]` | 无 | 可选完整流水线 |
| `/gsd-reapply-patches` | `~/.claude/skills/gsd-reapply-patches/` | GSD 更新后重新应用本地修改 | 无 | 备份文件 | 需三向合并 |
| `/gsd-remove-phase` | `~/.claude/skills/gsd-remove-phase/` | 从路线图移除阶段并重编号 | `<phase-number>` | ROADMAP.md | 谨慎使用 |
| `/gsd-remove-workspace` | `~/.claude/skills/gsd-remove-workspace/` | 移除工作区 | 无 | 工作区 | 无 |
| `/gsd-research-phase` | `~/.claude/skills/gsd-research-phase/` | 阶段实施前调研 | `[phase]` | 阶段定义 | 联网搜索 |
| `/gsd-resume-work` | `~/.claude/skills/gsd-resume-work/` | 恢复暂停的工作 | 无 | CONTEXT.md | 读取上下文 |
| `/gsd-review` | `~/.claude/skills/gsd-review/` | 审查工作 | 无 | 完成阶段 | 无 |
| `/gsd-review-backlog` | `~/.claude/skills/gsd-review-backlog/` | 审查 backlog | 无 | backlog | 无 |
| `/gsd-scan` | `~/.claude/skills/gsd-scan/` | 扫描项目状态 | 无 | `.planning/` | 无 |
| `/gsd-secure-phase` | `~/.claude/skills/gsd-secure-phase/` | 安全审计阶段 | 无 | 阶段代码 | 生成 SECURITY.md |
| `/gsd-session-report` | `~/.claude/skills/gsd-session-report/` | 生成会话报告 | 无 | 会话历史 | 无 |
| `/gsd-set-profile` | `~/.claude/skills/gsd-set-profile/` | 设置模型配置档案 | 无 | gsd-sdk | 需 npm 安装 SDK |
| `/gsd-settings` | `~/.claude/skills/gsd-settings/` | GSD 设置管理 | 无 | 无 | 无 |
| `/gsd-ship` | `~/.claude/skills/gsd-ship/` | 推送分支+创建 PR+跟踪合并 | 无 | verify-work 通过 | 关闭计划到执行到验证到发布循环 |
| `/gsd-sketch` | `~/.claude/skills/gsd-sketch/` | 通过 HTML 草图探索设计方向 | 无 | 无 | 生成 `.planning/sketches/` |
| `/gsd-sketch-wrap-up` | `~/.claude/skills/gsd-sketch-wrap-up/` | 草图收尾 | 无 | 草图文件 | 无 |
| `/gsd-spec-phase` | `~/.claude/skills/gsd-spec-phase/` | 苏格拉底式规范细化 | `<phase> [--auto] [--text]` | 阶段定义 | 输出 SPEC.md |
| `/gsd-spike` | `~/.claude/skills/gsd-spike/` | 技术探索/原型 | 无 | 无 | 快速验证 |
| `/gsd-spike-wrap-up` | `~/.claude/skills/gsd-spike-wrap-up/` | 探索收尾 | 无 | 探索结果 | 无 |
| `/gsd-stats` | `~/.claude/skills/gsd-stats/` | 统计信息 | 无 | `.planning/` | 无 |
| `/gsd-thread` | `~/.claude/skills/gsd-thread/` | 线程管理 | `[list/status/resume]` | 无 | 无 |
| `/gsd-ui-phase` | `~/.claude/skills/gsd-ui-phase/` | UI 阶段设计合同 | 无 | 前端代码 | 输出 UI-SPEC.md |
| `/gsd-ui-review` | `~/.claude/skills/gsd-ui-review/` | UI 回顾审计 | 无 | 前端实现 | 6 维度评分 |
| `/gsd-ultraplan-phase` | `~/.claude/skills/gsd-ultraplan-phase/` | 超级计划阶段 | `[phase]` | 深度规划 | 无 |
| `/gsd-undo` | `~/.claude/skills/gsd-undo/` | 安全 git 回滚 | 无 | git | 依赖检查和确认门 |
| `/gsd-update` | `~/.claude/skills/gsd-update/` | 更新 GSD | 无 | 无 | 可能覆盖本地修改 |
| `/gsd-validate-phase` | `~/.claude/skills/gsd-validate-phase/` | 验证阶段 | `[phase]` | PLAN.md | 目标回溯分析 |
| `/gsd-verify-work` | `~/.claude/skills/gsd-verify-work/` | 验证工作完成 | 无 | 执行后 | 目标达成验证 |
| `/gsd-workstreams` | `~/.claude/skills/gsd-workstreams/` | 工作流管理 | 无 | 无 | 多流并行 |

---

## GSD Agents

由 Orchestrator 调用的子代理，位于 `~/.claude/agents/gsd-*.md`。

| 代理名 | 位置 | 描述 | 触发命令 | 工具集 |
|--------|------|------|----------|--------|
| `gsd-advisor-researcher` | `~/.claude/agents/gsd-advisor-researcher.md` | 研究单个灰区决策，返回比较表 | `/gsd-discuss-phase` (advisor 模式) | Read, Bash, Grep, Glob, WebSearch, WebFetch, mcp__context7__* |
| `gsd-ai-researcher` | `~/.claude/agents/gsd-ai-researcher.md` | 研究 AI 框架官方文档，产出实现指南 | `/gsd-ai-integration-phase` | + Write |
| `gsd-assumptions-analyzer` | `~/.claude/agents/gsd-assumptions-analyzer.md` | 深度分析代码库假设 | `/gsd-discuss-phase` (assumptions 模式) | Read, Bash, Grep, Glob |
| `gsd-codebase-mapper` | `~/.claude/agents/gsd-codebase-mapper.md` | 探索代码库并写结构化分析文档 | `/gsd-map-codebase` | + Write |
| `gsd-code-fixer` | `~/.claude/agents/gsd-code-fixer.md` | 应用代码审查发现的问题修复 | `/gsd-code-review-fix` | Read, Edit, Write, Bash, Grep, Glob |
| `gsd-code-reviewer` | `~/.claude/agents/gsd-code-reviewer.md` | 审查源码 bug/安全/质量问题 | `/gsd-code-review` | Read, Write, Bash, Grep, Glob |
| `gsd-debugger` | `~/.claude/agents/gsd-debugger.md` | 科学方法调试 | `/gsd-debug` | Read, Write, Edit, Bash, Grep, Glob, WebSearch |
| `gsd-debug-session-manager` | `~/.claude/agents/gsd-debug-session-manager.md` | 管理多周期调试会话 | `/gsd-debug` (多周期) | + Task, AskUserQuestion |
| `gsd-doc-classifier` | `~/.claude/agents/gsd-doc-classifier.md` | 分类规划文档类型 | `/gsd-ingest-docs` | Read, Write, Grep, Glob |
| `gsd-doc-synthesizer` | `~/.claude/agents/gsd-doc-synthesizer.md` | 合成分类后的文档 | `/gsd-ingest-docs` | + Bash |
| `gsd-doc-verifier` | `~/.claude/agents/gsd-doc-verifier.md` | 验证文档事实声明 | `/gsd-docs-update` (verify) | Read, Write, Bash, Grep, Glob |
| `gsd-doc-writer` | `~/.claude/agents/gsd-doc-writer.md` | 编写/更新项目文档 | `/gsd-docs-update` | Read, Bash, Grep, Glob, Write |
| `gsd-domain-researcher` | `~/.claude/agents/gsd-domain-researcher.md` | 研究业务领域和真实应用上下文 | `/gsd-ai-integration-phase` | + WebSearch, WebFetch, mcp__context7__* |
| `gsd-eval-auditor` | `~/.claude/agents/gsd-eval-auditor.md` | 回溯审计 AI 阶段评估覆盖 | `/gsd-eval-review` | Read, Write, Bash, Grep, Glob |
| `gsd-eval-planner` | `~/.claude/agents/gsd-eval-planner.md` | 设计结构化评估策略 | `/gsd-ai-integration-phase` | + AskUserQuestion |
| `gsd-executor` | `~/.claude/agents/gsd-executor.md` | 执行 GSD 计划（原子提交等） | `/gsd-execute-phase` | + Edit, mcp__context7__* |
| `gsd-framework-selector` | `~/.claude/agents/gsd-framework-selector.md` | AI/LLM 框架交互式选择 | `/gsd-ai-integration-phase` | + AskUserQuestion |
| `gsd-integration-checker` | `~/.claude/agents/gsd-integration-checker.md` | 验证跨阶段集成和 E2E 流程 | `/gsd-validate-phase` | Read, Bash, Grep, Glob |
| `gsd-intel-updater` | `~/.claude/agents/gsd-intel-updater.md` | 分析代码库并写情报文件 | `/gsd-intel` | Read, Write, Bash, Glob, Grep |
| `gsd-nyquist-auditor` | `~/.claude/agents/gsd-nyquist-auditor.md` | 填补 Nyquist 验证缺口 | `/gsd-validate-phase` | Read |
| `gsd-pattern-mapper` | `~/.claude/agents/gsd-pattern-mapper.md` | 分析代码库模式 | `/gsd-plan-phase` (planning 前) | Read, Bash, Glob, Grep, Write |
| `gsd-phase-researcher` | `~/.claude/agents/gsd-phase-researcher.md` | 研究阶段实现方式 | `/gsd-plan-phase` / `/gsd-research-phase` | + WebSearch, WebFetch, mcp__context7__*, mcp__firecrawl__*, mcp__exa__* |
| `gsd-plan-checker` | `~/.claude/agents/gsd-plan-checker.md` | 验证计划能否达成阶段目标 | `/gsd-plan-phase` | Read, Bash, Glob, Grep |
| `gsd-planner` | `~/.claude/agents/gsd-planner.md` | 创建可执行阶段计划 | `/gsd-plan-phase` | + WebFetch, mcp__context7__* |
| `gsd-project-researcher` | `~/.claude/agents/gsd-project-researcher.md` | 路线图创建前研究领域生态 | `/gsd-new-project` / `/gsd-new-milestone` | + WebSearch, WebFetch, mcp__context7__*, mcp__firecrawl__*, mcp__exa__* |
| `gsd-research-synthesizer` | `~/.claude/agents/gsd-research-synthesizer.md` | 合成并行研究员输出 | `/gsd-new-project` (4 个研究员后) | Read, Write, Bash |
| `gsd-roadmapper` | `~/.claude/agents/gsd-roadmapper.md` | 创建项目路线图 | `/gsd-new-project` | Read, Write, Bash, Glob, Grep |
| `gsd-security-auditor` | `~/.claude/agents/gsd-security-auditor.md` | 验证威胁缓解措施 | `/gsd-secure-phase` | Read |
| `gsd-ui-auditor` | `~/.claude/agents/gsd-ui-auditor.md` | 6 维度视觉审计前端代码 | `/gsd-ui-review` | Read, Write, Bash, Grep, Glob |
| `gsd-ui-checker` | `~/.claude/agents/gsd-ui-checker.md` | 验证 UI-SPEC.md 设计合同 | `/gsd-ui-phase` | Read, Bash, Glob, Grep |
| `gsd-ui-researcher` | `~/.claude/agents/gsd-ui-researcher.md` | 产出前端设计合同 | `/gsd-ui-phase` | + WebSearch, WebFetch, mcp__context7__*, mcp__firecrawl__*, mcp__exa__* |
| `gsd-user-profiler` | `~/.claude/agents/gsd-user-profiler.md` | 分析开发者行为档案 | `/gsd-profile-user` | Read |
| `gsd-verifier` | `~/.claude/agents/gsd-verifier.md` | 验证阶段目标达成 | `/gsd-validate-phase` / `/gsd-verify-work` | Read, Write, Bash, Grep, Glob |

---

## 通用说明

### 平台差异

- `~/.claude/agents/gsd-*.md` — Claude Code 使用的 Markdown 格式代理定义
- `~/.codex/agents/gsd-*.toml` — Codex 使用的 TOML 格式代理定义
- 两者是**同一套代理的两种平台适配**，功能完全一致

### 前置要求

1. 所有 GSD 命令都需要项目根目录存在 `.planning/` 目录结构（由 `/gsd-new-project` 初始化）
2. 部分命令需要额外安装 `gsd-sdk`：
   ```bash
   npm install -g @gsd-build/sdk
   ```
3. `/gsd-inbox` 需要 GitHub CLI (`gh`) 已认证
4. `/gsd-set-profile` 必须依赖 `gsd-sdk`

### 典型工作流

```
/gsd-new-project      -> 初始化项目
  /gsd-discuss-phase  -> 讨论阶段上下文
  /gsd-plan-phase     -> 创建阶段计划
  /gsd-execute-phase  -> 执行计划
  /gsd-verify-work    -> 验证工作
/gsd-ship             -> 推送并创建 PR
```

### 参考文件

- GSD 工作流定义: `$HOME/.claude/get-shit-done/workflows/`
- 项目配置: `.planning/CONFIG.md`
- 路线图: `.planning/ROADMAP.md`
- 项目说明: `.planning/PROJECT.md`
