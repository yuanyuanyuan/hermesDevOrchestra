# GSD 命令与代理完整参考手册

> 生成时间: 2026-04-28
> 来源目录: `~/.claude/skills/` 和 `~/.claude/agents/`
> 适用平台: Claude Code (`.md`) / Codex (`.toml`)
>
> **命令前缀差异：** Claude Code 使用 `/gsd-<command>` 格式，Codex 使用 `$gsd-<command>` 格式。本文档示例均以 `/` 前缀为准，Codex 用户请将 `/` 替换为 `$`。

---

## 目录

1. [GSD Skills（用户可直接执行的命令）](#gsd-skills)
2. [GSD Agents（由 Orchestrator 调用的子代理）](#gsd-agents)
3. [通用说明](#通用说明)
4. [交互模式参考](#交互模式参考)

---

## GSD Skills

用户可直接通过 `/gsd-<command>` 格式执行的命令，位于 `~/.claude/skills/gsd-*/SKILL.md`。

| 命令 | 位置 | 描述 | 参数格式 | 依赖 | 执行要求 | 交互模式 |
|------|------|------|----------|------|----------|----------|
| `/gsd-add-backlog` | `~/.claude/skills/gsd-add-backlog/` | 将想法添加到 backlog 停车场（999.x 编号） | `<description>` | `.planning/` 目录 | 需有活跃项目 | 非交互 |  |
| `/gsd-add-phase` | `~/.claude/skills/gsd-add-phase/` | 在里程碑末尾添加新阶段 | `<description>` | `ROADMAP.md` | 需有里程碑 | 必须交互 |  |
| `/gsd-add-tests` | `~/.claude/skills/gsd-add-tests/` | 基于 UAT 标准为已完成阶段生成测试 | `<phase> [instructions]` | 阶段已完成 | 需有 PLAN.md | 非交互 |  |
| `/gsd-add-todo` | `~/.claude/skills/gsd-add-todo/` | 捕获想法或任务为待办 | `[description]` | `.planning/` | 无 | 必须交互 |  |
| `/gsd-ai-integration-phase` | `~/.claude/skills/gsd-ai-integration-phase/` | 为 AI 系统阶段生成 AI-SPEC.md | `[phase number]` | 框架文档 | 需联网搜索 | 必须交互 |  |
| `/gsd-analyze-dependencies` | `~/.claude/skills/gsd-analyze-dependencies/` | 分析阶段依赖并建议 ROADMAP.md 条目 | 无 | `ROADMAP.md` | 无 | 必须交互 |  |
| `/gsd-audit-fix` | `~/.claude/skills/gsd-audit-fix/` | 自动审计到修复流水线 | `--source <audit-uat>` | 审计结果 | 需有 REVIEW.md | 可选 `--dry-run` |  |
| `/gsd-audit-milestone` | `~/.claude/skills/gsd-audit-milestone/` | 归档前审计里程碑完成情况 | `[version]` | 所有阶段 SUMMARY.md | 需用户确认 | 非交互 |  |
| `/gsd-audit-uat` | `~/.claude/skills/gsd-audit-uat/` | 跨阶段审计未完成的 UAT | 无 | `.planning/` | 无 | 非交互 |  |
| `/gsd-autonomous` | `~/.claude/skills/gsd-autonomous/` | 自动运行剩余所有阶段 | `[--from N] [--to N]` | 计划完备 | 可选交互模式 | 非交互 |  |
| `/gsd-check-todos` | `~/.claude/skills/gsd-check-todos/` | 列出待办并选择一个开始 | `[area filter]` | `TODO.md` | 无 | 必须交互 |  |
| `/gsd-cleanup` | `~/.claude/skills/gsd-cleanup/` | 归档已完成里程碑的阶段目录 | 无 | 完成里程碑 | 谨慎使用 | 非交互 |  |
| `/gsd-code-review` | `~/.claude/skills/gsd-code-review/` | 审查阶段源码的 bug/安全/质量 | `<phase> [--depth]` | 代码变更 | 需有 SUMMARY.md | 非交互 |  |
| `/gsd-code-review-fix` | `~/.claude/skills/gsd-code-review-fix/` | 自动修复 REVIEW.md 中的问题 | `<phase> [--all] [--auto]` | REVIEW.md | 逐原子提交 | 非交互 |  |
| `/gsd-complete-milestone` | `~/.claude/skills/gsd-complete-milestone/` | 归档里程碑并准备下一版本 | `<version>` | 全部完成 | 需用户确认 | 非交互 |  |
| `/gsd-debug` | `~/.claude/skills/gsd-debug/` | 系统化调试（跨上下文持久化） | `[list/status/continue]` | 无 | 可选 `--diagnose` | 必须交互 |  |
| `/gsd-discuss-phase` | `~/.claude/skills/gsd-discuss-phase/` | 计划前通过提问收集阶段上下文 | `<phase> [--all/auto/chain]` | 阶段定义 | 推荐交互式 | 可选 `--auto` |  |
| `/gsd-docs-update` | `~/.claude/skills/gsd-docs-update/` | 生成/更新项目文档 | `[--force] [--verify-only]` | 代码库 | 需验证 | 可选 `--force` |  |
| `/gsd-do` | `~/.claude/skills/gsd-do/` | 自动路由到正确的 GSD 命令 | `<description>` | 无 | 智能路由 | 必须交互 |  |
| `/gsd-eval-review` | `~/.claude/skills/gsd-eval-review/` | 回溯审计 AI 阶段的评估覆盖 | `[phase number]` | AI-SPEC.md | 无 | 非交互 |  |
| `/gsd-execute-phase` | `~/.claude/skills/gsd-execute-phase/` | 波浪式并行执行阶段计划 | `<phase> [--wave N]` | PLAN.md | 需计划已审批 | 非交互 |  |
| `/gsd-explore` | `~/.claude/skills/gsd-explore/` | 苏格拉底式构思和想法路由 | 无 | 无 | 计划前使用 | 必须交互 |  |
| `/gsd-extract_learnings` | `~/.claude/skills/gsd-extract_learnings/` | 从已完成阶段提取经验教训 | `<phase-number>` | SUMMARY.md | 无 | 非交互 |  |
| `/gsd-fast` | `~/.claude/skills/gsd-fast/` | 内联快速执行（无子代理开销） | `[task]` | 无 | 简单任务专用 | 必须交互 |  |
| `/gsd-forensics` | `~/.claude/skills/gsd-forensics/` | GSD 工作流失败的事后调查 | `[problem]` | git 历史 | 分析用 | 必须交互 |  |
| `/gsd-from-gsd2` | `~/.claude/skills/gsd-from-gsd2/` | 从 GSD-2 导入回 GSD v1 | `[--path] [--force]` | `.gsd/` 目录 | 需确认 | 可选 `--force` |  |
| `/gsd-graphify` | `~/.claude/skills/gsd-graphify/` | 构建/查询项目知识图谱 | `[build/query/status/diff]` | `.planning/` | 无 | 非交互 |  |
| `/gsd-health` | `~/.claude/skills/gsd-health/` | 诊断规划目录健康并修复 | `[--repair]` | `.planning/` | 可选修复 | 非交互 |  |
| `/gsd-help` | `~/.claude/skills/gsd-help/` | 显示可用 GSD 命令和用法 | 无 | 无 | 无 | 非交互 |  |
| `/gsd-import` | `~/.claude/skills/gsd-import/` | 导入外部计划并检测冲突 | `--from <filepath>` | 外部文件 | 冲突检测 | 必须交互 |  |
| `/gsd-inbox` | `~/.claude/skills/gsd-inbox/` | 审查 GitHub issues/PRs | `[--issues] [--prs]` | GitHub CLI | 需 gh 认证 | 非交互 |  |
| `/gsd-ingest-docs` | `~/.claude/skills/gsd-ingest-docs/` | 扫描并引导 `.planning/` 设置 | `[path] [--mode]` | 混合文档 | 自动分类 | 可选 `--resolve auto` |  |
| `/gsd-insert-phase` | `~/.claude/skills/gsd-insert-phase/` | 插入小数阶段（如 72.1） | `<after> <description>` | ROADMAP.md | 紧急用 | 必须交互 |  |
| `/gsd-intel` | `~/.claude/skills/gsd-intel/` | 查询/刷新代码库情报文件 | `[query/status/diff/refresh]` | `.planning/intel/` | 无 | 非交互 |  |
| `/gsd-join-discord` | `~/.claude/skills/gsd-join-discord/` | 加入 GSD Discord 社区 | 无 | 无 | 无 | 非交互 |  |
| `/gsd-list-phase-assumptions` | `~/.claude/skills/gsd-list-phase-assumptions/` | 计划前展示阶段假设 | `[phase]` | 阶段定义 | 纠错用 | 非交互 |  |
| `/gsd-list-workspaces` | `~/.claude/skills/gsd-list-workspaces/` | 列出活跃 GSD 工作区 | 无 | 无 | 无 | 非交互 |  |
| `/gsd-manager` | `~/.claude/skills/gsd-manager/` | 多阶段管理交互中心 | 无 | `.planning/` | 管理用 | 必须交互 |  |
| `/gsd-map-codebase` | `~/.claude/skills/gsd-map-codebase/` | 并行映射代码库分析文档 | `[area]` | 代码库 | 新项目用 | 非交互 |  |
| `/gsd-milestone-summary` | `~/.claude/skills/gsd-milestone-summary/` | 生成里程碑项目摘要 | `[version]` | 归档文件 | 团队入职用 | 非交互 |  |
| `/gsd-new-milestone` | `~/.claude/skills/gsd-new-milestone/` | 开始新里程碑周期 | `[milestone name]` | PROJECT.md | 无 | 必须交互 |  |
| `/gsd-new-project` | `~/.claude/skills/gsd-new-project/` | 初始化新项目 | `[--auto]` | 无 | 深度上下文收集 | 可选 `--auto` |  |
| `/gsd-new-workspace` | `~/.claude/skills/gsd-new-workspace/` | 创建隔离工作区 | `--name <name>` | git | 可选 worktree/clone | 可选 `--auto` |
| `/gsd-next` | `~/.claude/skills/gsd-next/` | 自动推进到下一步 | 无 | `.planning/` | 智能路由 | 非交互 |  |
| `/gsd-note` | `~/.claude/skills/gsd-note/` | 零摩擦想法捕获 | `<text> | list | promote` | 无 | 可升级待办 | 必须交互 |
| `/gsd-pause-work` | `~/.claude/skills/gsd-pause-work/` | 暂停工作时创建上下文交接 | 无 | 进行中阶段 | 生成 CONTEXT.md | 非交互 |  |
| `/gsd-plan-milestone-gaps` | `~/.claude/skills/gsd-plan-milestone-gaps/` | 为审计发现创建补全阶段 | 无 | 审计结果 | 无 | 必须交互 |  |
| `/gsd-plan-phase` | `~/.claude/skills/gsd-plan-phase/` | 创建详细阶段计划 | `[phase] [--auto/research]` | gsd-planner 代理 | 推荐验证循环 | 可选 `--auto` |  |
| `/gsd-plant-seed` | `~/.claude/skills/gsd-plant-seed/` | 捕获前瞻性想法（带触发条件） | `[idea]` | 无 | 自动提醒 | 必须交互 |  |
| `/gsd-pr-branch` | `~/.claude/skills/gsd-pr-branch/` | 过滤 `.planning/` 提交创建 PR | `[target branch]` | git | 需干净分支 | 非交互 |  |
| `/gsd-profile-user` | `~/.claude/skills/gsd-profile-user/` | 生成开发者行为档案 | `[--questionnaire]` | 会话历史 | 需同意 | 必须交互 |  |
| `/gsd-progress` | `~/.claude/skills/gsd-progress/` | 检查进度并路由下一步 | `[--forensic]` | `.planning/` | 可选完整性审计 | 非交互 |  |
| `/gsd-quick` | `~/.claude/skills/gsd-quick/` | 快速任务（原子提交+状态追踪） | `[task]` | 无 | 可选完整流水线 | 可选 flag 组合 |
| `/gsd-reapply-patches` | `~/.claude/skills/gsd-reapply-patches/` | GSD 更新后重新应用本地修改 | 无 | 备份文件 | 需三向合并 | 非交互 |  |
| `/gsd-remove-phase` | `~/.claude/skills/gsd-remove-phase/` | 从路线图移除阶段并重编号 | `<phase-number>` | ROADMAP.md | 谨慎使用 | 必须交互 |  |
| `/gsd-remove-workspace` | `~/.claude/skills/gsd-remove-workspace/` | 移除工作区 | 无 | 工作区 | 无 | 非交互 |  |
| `/gsd-research-phase` | `~/.claude/skills/gsd-research-phase/` | 阶段实施前调研 | `[phase]` | 阶段定义 | 联网搜索 | 非交互 |  |
| `/gsd-resume-work` | `~/.claude/skills/gsd-resume-work/` | 恢复暂停的工作 | 无 | CONTEXT.md | 读取上下文 | 非交互 |  |
| `/gsd-review` | `~/.claude/skills/gsd-review/` | 审查工作 | 无 | 完成阶段 | 无 | 非交互 |  |
| `/gsd-review-backlog` | `~/.claude/skills/gsd-review-backlog/` | 审查 backlog | 无 | backlog | 无 | 必须交互 |
| `/gsd-scan` | `~/.claude/skills/gsd-scan/` | 扫描项目状态 | 无 | `.planning/` | 无 | 非交互 |  |
| `/gsd-secure-phase` | `~/.claude/skills/gsd-secure-phase/` | 安全审计阶段 | 无 | 阶段代码 | 生成 SECURITY.md | 非交互 |  |
| `/gsd-session-report` | `~/.claude/skills/gsd-session-report/` | 生成会话报告 | 无 | 会话历史 | 无 | 非交互 |  |
| `/gsd-set-profile` | `~/.claude/skills/gsd-set-profile/` | 设置模型配置档案 | 无 | gsd-sdk | 需 npm 安装 SDK | 非交互 |  |
| `/gsd-settings` | `~/.claude/skills/gsd-settings/` | GSD 设置管理 | 无 | 无 | 无 | 必须交互 |  |
| `/gsd-ship` | `~/.claude/skills/gsd-ship/` | 推送分支+创建 PR+跟踪合并 | 无 | verify-work 通过 | 关闭计划到执行到验证到发布循环 | 非交互 |  |
| `/gsd-sketch` | `~/.claude/skills/gsd-sketch/` | 通过 HTML 草图探索设计方向 | 无 | 无 | 生成 `.planning/sketches/` | 可选 `--quick` |  |
| `/gsd-sketch-wrap-up` | `~/.claude/skills/gsd-sketch-wrap-up/` | 草图收尾 | 无 | 草图文件 | 无 | 非交互 |
| `/gsd-spec-phase` | `~/.claude/skills/gsd-spec-phase/` | 苏格拉底式规范细化 | `<phase> [--auto] [--text]` | 阶段定义 | 输出 SPEC.md | 可选 `--auto` |  |
| `/gsd-spike` | `~/.claude/skills/gsd-spike/` | 技术探索/原型 | 无 | 无 | 快速验证 | 可选 `--quick` |  |
| `/gsd-spike-wrap-up` | `~/.claude/skills/gsd-spike-wrap-up/` | 探索收尾 | 无 | 探索结果 | 无 | 可选 `--quick` |  |
| `/gsd-spike-wrap-up` | `~/.claude/skills/gsd-spike-wrap-up/` | 探索收尾 | 无 | 探索结果 | 无 | 非交互 |
| `/gsd-thread` | `~/.claude/skills/gsd-thread/` | 线程管理 | `[list/status/resume]` | 无 | 无 | 必须交互 |  |
| `/gsd-ui-phase` | `~/.claude/skills/gsd-ui-phase/` | UI 阶段设计合同 | 无 | 前端代码 | 输出 UI-SPEC.md | 必须交互 |  |
| `/gsd-ui-review` | `~/.claude/skills/gsd-ui-review/` | UI 回顾审计 | 无 | 前端实现 | 6 维度评分 | 非交互 |  |
| `/gsd-ultraplan-phase` | `~/.claude/skills/gsd-ultraplan-phase/` | 超级计划阶段 | `[phase]` | 深度规划 | 无 | 非交互 |  |
| `/gsd-undo` | `~/.claude/skills/gsd-undo/` | 安全 git 回滚 | 无 | git | 依赖检查和确认门 | 必须交互 |  |
| `/gsd-update` | `~/.claude/skills/gsd-update/` | 更新 GSD | 无 | 无 | 可能覆盖本地修改 | 必须交互 |  |
| `/gsd-validate-phase` | `~/.claude/skills/gsd-validate-phase/` | 验证阶段 | `[phase]` | PLAN.md | 目标回溯分析 | 非交互 |  |
| `/gsd-verify-work` | `~/.claude/skills/gsd-verify-work/` | 验证工作完成 | 无 | 执行后 | 目标达成验证 | 必须交互 |  |
| `/gsd-workstreams` | `~/.claude/skills/gsd-workstreams/` | 工作流管理 | 无 | 无 | 多流并行 | 必须交互 |  |

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

---

## 交互模式参考

> 基于 [gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done) 官方文档 `docs/COMMANDS.md` 梳理

GSD 命令按交互需求分为三类：

| 类别 | 含义 | 识别方式 |
|------|------|----------|
| **必须交互** | 命令设计为向用户提问、确认或选择，无官方非交互退出路径 | 表格中标记为"必须交互" |
| **可选 `--flag`** | 默认交互，但可通过特定 flag 跳过交互直接进入自动模式 | 表格中标记为"可选 `...`" |
| **非交互** | 纯执行命令，全程无需人工介入 | 表格中标记为"非交互" |

### 必须交互的命令（无自动化退出路径）

这些命令会主动向您提问，无法通过 flag 跳过：

- `/gsd-add-phase` — 需要描述阶段内容
- `/gsd-add-todo` — 需要描述待办事项
- `/gsd-ai-integration-phase` — 交互式决策矩阵
- `/gsd-analyze-dependencies` — 确认更新分析结果
- `/gsd-check-todos` — 选择一个待办开始处理
- `/gsd-debug` — 调试诊断需交互
- `/gsd-do` — "describe what you want"
- `/gsd-explore` — 苏格拉底式构思
- `/gsd-fast` — 如省略 task 则提示
- `/gsd-forensics` — 如省略 problem 则提示
- `/gsd-import` — 冲突解决需人工介入
- `/gsd-insert-phase` — 插入位置和内容需确认
- `/gsd-manager` — 交互式指挥中心
- `/gsd-new-milestone` — 命名和配置新里程碑
- `/gsd-note` — 默认追加模式需交互
- `/gsd-plan-milestone-gaps` — 补全阶段需人工决策
- `/gsd-plant-seed` — 如省略 idea 则提示
- `/gsd-profile-user` — 生成行为档案需同意
- `/gsd-remove-phase` — 删除确认
- `/gsd-settings` / `/gsd-settings-advanced` / `/gsd-settings-integrations` — 交互式配置向导
- `/gsd-thread` — 创建/恢复线程需交互
- `/gsd-ui-phase` — UI 设计决策需确认
- `/gsd-undo` — 确认门（confirmation gate）
- `/gsd-update` — changelog 预览需确认
- `/gsd-verify-work` — 验证工作需人工审阅
- `/gsd-workstreams` — 创建/切换/完成/恢复工作流
- `/gsd-review-backlog` — 逐项：Promote/Keep/Remove

### 支持非交互模式的命令（加 flag 跳过交互）

| 命令 | 非交互 flag | 用法示例 |
|------|------------|----------|
| `/gsd-new-project` | `--auto @file.md` | `/gsd-new-project --auto @idea.md` |
| `/gsd-new-workspace` | `--auto` | `/gsd-new-workspace --name x --auto` |
| `/gsd-discuss-phase` | `--auto`, `--power` | `/gsd-discuss-phase 3 --auto` |
| `/gsd-plan-phase` | `--auto` | `/gsd-plan-phase 3 --auto --skip-research` |
| `/gsd-quick` | flag 组合 | `/gsd-quick --full --validate` |
| `/gsd-ingest-docs` | `--resolve auto` | `/gsd-ingest-docs --resolve auto` |
| `/gsd-from-gsd2` | `--force` | `/gsd-from-gsd2 --force` |
| `/gsd-code-review-fix` | `--auto` | `/gsd-code-review-fix 3 --auto` |
| `/gsd-audit-fix` | `--dry-run` | `/gsd-audit-fix --dry-run` |
| `/gsd-docs-update` | `--force` | `/gsd-docs-update --force` |
| `/gsd-spike` | `--quick` | `/gsd-spike --quick` |
| `/gsd-sketch` | `--quick`, `--text` | `/gsd-sketch --quick` |
| `/gsd-spec-phase` | `--auto` | `/gsd-spec-phase 3 --auto` |

### 本来就是非交互的命令（纯执行）

以下命令全程无需交互，可直接在脚本/流水线中使用：

`/gsd-list-workspaces` `/gsd-plan-review-convergence` `/gsd-ultraplan-phase` `/gsd-execute-phase` `/gsd-next` `/gsd-session-report` `/gsd-ship` `/gsd-ui-review` `/gsd-audit-uat` `/gsd-audit-milestone` `/gsd-complete-milestone` `/gsd-milestone-summary` `/gsd-list-phase-assumptions` `/gsd-research-phase` `/gsd-validate-phase` `/gsd-progress` `/gsd-resume-work` `/gsd-pause-work` `/gsd-help` `/gsd-autonomous` `/gsd-add-tests` `/gsd-stats` `/gsd-set-profile` `/gsd-map-codebase` `/gsd-scan` `/gsd-intel` `/gsd-graphify` `/gsd-eval-review` `/gsd-reapply-patches` `/gsd-code-review` `/gsd-review` `/gsd-pr-branch` `/gsd-secure-phase` `/gsd-add-backlog` `/gsd-extract_learnings` `/gsd-spike-wrap-up` `/gsd-sketch-wrap-up` `/gsd-cleanup` `/gsd-health` `/gsd-inbox` `/gsd-join-discord` `/gsd-remove-workspace`

### 避免交互式的 5 种方法

#### 方法 1：使用 `--auto` 标志（最常用）

```bash
# 全自动新建项目（需配合 @idea.md）
/gsd-new-project --auto @project-idea.md

# 全自动讨论阶段
/gsd-discuss-phase 3 --auto

# 全自动计划阶段
/gsd-plan-phase 3 --auto
```

#### 方法 2：使用 `--force` / `--dry-run` 标志

```bash
# 强制转换 GSD2 -> GSD3，不提示
/gsd-from-gsd2 --force

# 强制更新文档
/gsd-docs-update --force

# 仅预览审计修复，不执行
/gsd-audit-fix --dry-run
```

#### 方法 3：提供所有必需参数

```bash
# 新建工作空间时提供所有参数，避免交互提问
/gsd-new-workspace --name my-project --repos ./src --path ./planning --strategy parallel --auto
```

#### 方法 4：使用 GSD SDK CLI（完全无头模式）

适用于 CI/CD、自动化流水线（v1.30.0+）：

```bash
# 初始化项目
gsd-sdk init

# 全自动执行
gsd-sdk auto
```

这是独立的 TypeScript SDK，专为无人工介入场景设计。

#### 方法 5：安装时选择 `--minimal` 模式

```bash
# 最小化安装，减少系统提示 token 开销
npx get-shit-done-cc --claude --global --minimal
```

### 自动化流水线推荐组合

如需**完全不交互**完成完整项目：

```
1. /gsd-new-project --auto @idea.md     -> 全自动初始化
2. /gsd-plan-phase 1 --auto --skip-research  -> 全自动计划
3. /gsd-execute-phase 1                 -> 执行（本身非交互）
4. /gsd-validate-phase 1                -> 验证（本身非交互）
5. /gsd-next                            -> 推进（本身非交互）
6. 重复 2-5 直到完成
```

或一步到位：

```bash
gsd-sdk auto  # 完全无头，自动走完整个流程
```

---

## 深入代码：无交互模式的实现与使用

> 以下分析基于 `get-shit-done-cc@1.38.5` npm 包中解压的 SDK 源码 (`sdk/src/`)

### SDK 架构概览

GSD SDK (`@gsd-build/sdk@0.1.0`) 是一个基于 **Anthropic Agent SDK** (`@anthropic-ai/claude-agent-sdk@^0.2.84`) 的 TypeScript 封装层。它把 GSD 的规划、执行、验证流程编码为可编程 API，核心类关系如下：

```
GSD (index.ts:40)
├── executePlan(planPath)     → 执行单个 PLAN.md
├── runPhase(phaseNumber)     → 运行完整阶段生命周期
├── run(prompt)               → 运行完整里程碑（多阶段）
├── createTools()             → GSDTools 实例（state/roadmap 操作）
└── eventStream               → 事件流（CLI/WebSocket 双通道）

PhaseRunner (phase-runner.ts:66)
├── run(phaseNumber)          → discuss → research → plan → plan-check → execute → verify → advance
├── runSelfDiscussStep()      → AI 自讨论（auto 模式替代人类 discuss）
├── runStep()                 → 单步执行
└── retryOnce()               → 失败重试

SessionRunner (session-runner.ts)
├── runPlanSession()          → 通过 Agent SDK query() 执行计划
├── runPhaseStepSession()     → 执行阶段单步
└── processQueryStream()      → 处理消息流并提取结果
```

### 无交互模式的三层实现

GSD 的无交互不是简单的"不提问"，而是从 **CLI 层 → 编排层 → SDK 层** 的三层设计：

#### 第 1 层：CLI 入口 (`sdk/src/cli.ts`)

`gsd-sdk` 支持四个顶层命令，其中三个与无交互直接相关：

| 命令 | 作用 | 是否交互 |
|------|------|----------|
| `gsd-sdk auto` | 全自动生命周期 | **完全无交互** |
| `gsd-sdk run "<prompt>"` | 从文本提示运行里程碑 | 提示即输入，后续无交互 |
| `gsd-sdk init [input]` | 初始化项目 | 从文件/stdin 读入，无交互 |
| `gsd-sdk query <argv...>` | 查询命令（fallback 到 gsd-tools.cjs） | 取决于查询类型 |

**关键源码** (`cli.ts:565-572`)：

```typescript
// gsd-sdk auto 命令的实现
if (args.command === 'auto') {
  const gsd = new GSD({
    projectDir: args.projectDir,
    model: args.model,
    maxBudgetUsd: args.maxBudget,
    autoMode: true,        // ← 核心：开启 auto 模式
    workstream: args.ws,
  });
  // ...
  const result = await gsd.run('');  // ← 空 prompt，让 SDK 自己发现阶段
}
```

`gsd-sdk auto` 的完整 CLI 参数：

```bash
gsd-sdk auto \
  [--init @path/to/prd.md]    # 先初始化项目再自动执行
  [--project-dir <dir>]      # 项目目录（默认 cwd）
  [--ws <name>]              # 工作流名称（多工作流项目）
  [--model <model>]          # 覆盖 LLM 模型
  [--max-budget <n>]         # 每步最大预算（美元）
  [--dashboard]               # 启动实时监控面板
  [--ws-port <port>]         # WebSocket 事件流端口
```

#### 第 2 层：GSD 编排器 (`sdk/src/index.ts`)

**`autoMode` 属性的作用** (`index.ts:47-59, 140-162`)：

```typescript
export class GSD {
  private readonly autoMode: boolean;  // 默认为 false

  constructor(options: GSDOptions) {
    // ...
    this.autoMode = options.autoMode ?? false;
  }

  async runPhase(phaseNumber: string, options?: PhaseRunnerOptions): Promise<PhaseRunnerResult> {
    // Auto mode: force auto_advance on and skip_discuss off
    // so self-discuss kicks in
    if (this.autoMode) {
      config.workflow.auto_advance = true;   // ← 自动推进
      config.workflow.skip_discuss = false;  // ← 不跳过 discuss，改为 AI 自讨论
    }
    // ...
    return runner.run(phaseNumber, options);
  }
}
```

**`GSD.run()` 方法** (`index.ts:172-252`) — 里程碑级全自动：

```typescript
async run(prompt: string, options?: MilestoneRunnerOptions): Promise<MilestoneRunnerResult> {
  // 1. 发现所有未完成的阶段
  const initialAnalysis = await tools.roadmapAnalyze();
  const incompletePhases = this.filterAndSortPhases(initialAnalysis.phases);

  // 2. 循环执行每个阶段
  while (currentPhases.length > 0) {
    const phase = currentPhases[0];
    const result = await this.runPhase(phase.number, options);

    // 3. 每完成一个阶段后重新发现
    //    （支持动态插入的新阶段，如 plan-check 失败后新增的修复阶段）
    const updatedAnalysis = await tools.roadmapAnalyze();
    currentPhases = this.filterAndSortPhases(updatedAnalysis.phases);
  }
}
```

这意味着 `gsd-sdk auto` 会：
1. 读取 `ROADMAP.md` 找出所有未完成的阶段
2. 按顺序自动执行每个阶段
3. 执行完一个阶段后**重新扫描**，发现可能新插入的阶段
4. 直到所有阶段完成

#### 第 3 层：PhaseRunner 状态机 (`sdk/src/phase-runner.ts`)

这是无交互的核心。`PhaseRunner.run()` 实现了完整的阶段生命周期 (`phase-runner.ts:86-311`)：

```
discuss → research → plan → plan-check → execute → verify → advance
```

**Discuss 步骤的智能分流** (`phase-runner.ts:138-179`)：

```typescript
// ── Step 1: Discuss ──
const shouldSkip = phaseOp.has_context || this.config.workflow.skip_discuss;

if (shouldSkip && !(auto_advance && !has_context && !skip_discuss)) {
  // 有上下文或配置跳过 → 跳过 discuss
} else if (!has_context && !skip_discuss && auto_advance) {
  // 【auto 模式核心】没有上下文且需要 discuss → AI 自讨论
  const result = await this.runSelfDiscussStep(phaseNumber, sessionOpts);
} else {
  // 正常模式 → 人工 discuss（会提问）
  const result = await this.runStep(PhaseStepType.Discuss, ...);
}
```

在 auto 模式下，`runSelfDiscussStep()` 会让 AI 自己完成原本需要人类回答的上下文收集问题，然后把生成的 CONTEXT.md 写入磁盘。

**其他步骤的行为**：

| 步骤 | auto 模式行为 | 人工模式行为 |
|------|--------------|-------------|
| research | 自动运行 | 可选运行 |
| plan | 自动运行 | 自动运行 |
| plan-check | 自动运行，失败自动重 plan | 自动运行 |
| execute | 自动运行 | 自动运行 |
| verify | 自动运行，发现 gap 可自动修复 | 自动运行 |
| advance | 自动标记完成 | 自动标记完成 |

### SessionRunner：绕过权限确认 (`sdk/src/session-runner.ts`)

真正让"无交互"成为可能的是 Agent SDK 层面的权限绕过 (`session-runner.ts:79-96`)：

```typescript
const queryStream = query({
  prompt: `Execute this plan:\n\n${plan.objective}`,
  options: {
    systemPrompt: {
      type: 'preset',
      preset: 'claude_code',
      append: executorPrompt,
    },
    settingSources: ['project'],
    allowedTools,                          // ← 白名单工具
    permissionMode: 'bypassPermissions',   // ← 绕过所有权限提示
    allowDangerouslySkipPermissions: true, // ← 危险操作也自动批准
    maxTurns: 50,                          // ← 最多 50 轮对话
    maxBudgetUsd: 5.0,                     // ← 每步最多 $5
    cwd,
    ...(model ? { model } : {}),
  },
});
```

`permissionMode: 'bypassPermissions'` 意味着：
- `Bash` 命令执行不会提示确认
- `Write`/`Edit` 文件不会提示确认
- 所有工具调用自动批准

**这是双刃剑** — 方便自动化，但也意味着你需要信任计划内容。GSD 通过 `allowedTools` 白名单和 `maxBudgetUsd` 预算上限来降低风险。

### 配置系统：`auto_advance` 与相关开关 (`sdk/src/config.ts`)

GSD 的配置存储在 `.planning/config.json`，SDK 读取时与默认值合并：

```typescript
// 默认配置 (config.ts:78-109)
export const CONFIG_DEFAULTS: GSDConfig = {
  model_profile: 'balanced',
  workflow: {
    research: true,
    plan_check: true,
    verifier: true,
    auto_advance: false,        // ← 默认关闭自动推进
    skip_discuss: false,        // ← 默认不跳过 discuss
    max_discuss_passes: 3,      // ← 自讨论最大轮数
    subagent_timeout: 300000,   // ← 子代理超时 5 分钟
    // ...
  },
  mode: 'interactive',          // ← 默认交互模式
  // ...
};
```

**`auto_advance` 的作用**：
- `false`（默认）：discuss 步骤会等待人类输入
- `true`：discuss 步骤变为 AI 自讨论，整个生命周期自动推进

**手动开启 auto 模式的方法**（不通过 `gsd-sdk auto`）：

```bash
# 方法 A：修改 config.json
# .planning/config.json
{
  "workflow": {
    "auto_advance": true,
    "skip_discuss": false,
    "max_discuss_passes": 3
  }
}

# 方法 B：通过 gsd-tools 命令
node .claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.auto_advance true
```

### 实战：三种无交互使用方式

#### 方式 A：`gsd-sdk auto`（推荐，最简单）

```bash
# 1. 确保已安装（全局或本地）
npx get-shit-done-cc --claude --global

# 2. 在项目目录执行
cd my-project
gsd-sdk auto

# 3. 如果需要先初始化再自动执行
gsd-sdk auto --init @prd.md

# 4. 指定模型和预算
gsd-sdk auto --model claude-opus-4-6 --max-budget 10

# 5. 启动监控面板（可远程观察进度）
gsd-sdk auto --dashboard
```

输出示例：
```
[auto] Bootstrapping project from --init (1245 chars)
[init SUCCESS] 5/5 steps, $2.34, 45.2s
[SUCCESS] 3 phase(s), $8.71, 182.3s
```

#### 方式 B：程序化 API（Node.js/TypeScript）

```typescript
import { GSD } from '@gsd-build/sdk';

const gsd = new GSD({
  projectDir: '/path/to/project',
  autoMode: true,           // ← 开启 auto 模式
  model: 'claude-opus-4-6', // ← 指定模型
  maxBudgetUsd: 10,         // ← 每步预算
  maxTurns: 100,            // ← 每步最大轮数
});

// 监听事件（可选）
gsd.onEvent((event) => {
  if (event.type === 'phase_complete') {
    console.log(`Phase ${event.phaseNumber}: ${event.success ? 'OK' : 'FAIL'}`);
  }
  if (event.type === 'cost_update') {
    console.log(`Cost so far: $${event.cumulativeCostUsd}`);
  }
});

// 执行完整里程碑
const result = await gsd.run('');

console.log(`Success: ${result.success}`);
console.log(`Phases: ${result.phases.length}`);
console.log(`Total cost: $${result.totalCostUsd}`);
```

#### 方式 C：单个阶段无交互执行

```typescript
import { GSD } from '@gsd-build/sdk';

const gsd = new GSD({ projectDir: '/path/to/project' });

// 执行特定阶段的 PLAN.md
const result = await gsd.executePlan(
  '.planning/phases/01-auth/01-auth-01-PLAN.md'
);

if (result.success) {
  console.log(`Done in ${result.durationMs}ms, cost $${result.totalCostUsd}`);
} else {
  console.error(`Failed: ${result.error?.messages.join(', ')}`);
}
```

### 安全与预算控制

无交互模式下，GSD 通过以下机制防止失控：

| 机制 | 默认值 | 作用 |
|------|--------|------|
| `maxTurns` | 50 | 每步最多 50 轮 agentic 对话 |
| `maxBudgetUsd` | $5.0 | 每步最多花费 |
| `allowedTools` | Read/Write/Edit/Bash/Grep/Glob | 白名单工具限制 |
| `max_discuss_passes` | 3 | 自讨论最大轮数 |
| `plan_check` | true | 执行前自动检查计划质量 |
| `verifier` | true | 执行后自动验证结果 |

**注意**：`permissionMode: 'bypassPermissions'` 会绕过所有权限确认，包括文件写入和命令执行。建议在 CI 环境或沙箱中使用。

### 已知限制

根据 GitHub Issues，SDK 有以下需要注意的问题：

1. **Issue #2385**: `--sdk` flag 在某些版本的安装器中未实际实现，导致 `gsd-sdk` 未安装到 PATH
2. **Issue #2393**: `@gsd-build/sdk@0.1.0` 只暴露 `run|auto|init`，`query` 子命令缺失（workflow 文件引用它但实际不存在）
3. **Issue #2453**: 新安装时 `dist/cli.js` 权限为 644 而非 755，导致 `permission denied`
4. **Issue #2436**: 上述修复已合并到 main 但未发布到 latest npm tag

**建议**：如需稳定使用，直接从源码构建：

```bash
git clone https://github.com/gsd-build/get-shit-done.git
cd get-shit-done
npm run build:hooks
node bin/install.js --claude --local --sdk
```

### 参考源码路径

| 文件 | 作用 |
|------|------|
| `sdk/src/cli.ts` | CLI 入口（auto/run/init/query 命令） |
| `sdk/src/index.ts` | GSD 类（编排器） |
| `sdk/src/phase-runner.ts` | PhaseRunner（阶段生命周期状态机） |
| `sdk/src/session-runner.ts` | SessionRunner（Agent SDK 调用） |
| `sdk/src/config.ts` | 配置读取与默认值 |
| `sdk/src/types.ts` | 类型定义 |
| `sdk/src/gsd-tools.ts` | GSDTools（state/roadmap 操作桥接） |
| `sdk/src/prompt-builder.ts` | Prompt 构建器 |
| `bin/gsd-sdk.js` | CLI shim（转发到 sdk/dist/cli.js） |
