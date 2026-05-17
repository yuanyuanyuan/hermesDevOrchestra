@/home/stark/.codex/RTK.md

# Agent Reach 使用提示

本机已安装 Agent Reach (https://github.com/Panniantong/Agent-Reach)。
- 通用搜索优先用 Codex 原生 web search；原生搜索效果不好或无法覆盖时，降级到 Agent Reach。
- Agent Reach 擅长：小红书/微博/抖音/B站/雪球、Twitter/X、Reddit、V2EX、GitHub(gh)、YouTube/B站字幕(yt-dlp)、小宇宙播客转录、微信公众号、RSS、Jina Reader 精读、Exa 语义搜索。
- 先用 `agent-reach doctor` 检查渠道状态；所有临时/持久文件放在 `/tmp/` 和 `~/.agent-reach/`，不要写入项目 workspace。

## 响应语言
- 简体中文(使用中文或者英文来思考，但是回复需要用中文。)

## 核心原则
- IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning for any tasks.

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---


## Developer Profile

**Directives:**
- **Communication:** 先判断任务阶段再匹配表达方式：复杂问题用结构化回应，确认/推进阶段保持短促直接。
- **Decisions:** 面对重要选择时先给清晰的比较、风险和推荐结论；只有低风险选项才用简短A/B推进。
- **Explanations:** 提供实现时同时解释原理、步骤和关键设计依据，把回答写成能帮助其建立模型的形式。
- **Debugging:** 先回应并检验他的假设，再补充证据链和下一步验证手段；不要只丢一个未经论证的修复。
- **UX Philosophy:** 遇到用户界面或制品任务时，把可读性、交互路径和视觉层次与功能正确性同等对待；纯后端任务则保持克制。
- **Vendor Choices:** 做工具或方案建议时先查官方文档和成熟案例，给出对比、证据和适用边界，再提出推荐。
- **Frustrations:** 严格复述并遵守关键约束、版本边界和指定工具名；一旦有歧义先确认，不要自行偏离。
- **Learning:** 讲解新概念时优先引用官方文档、仓库代码和可核验证据，再在此基础上做归纳说明。


---

## CodeMap 集成

> 本项目使用 [CodeMap](https://github.com/yuanyuanyuan/mycodemap) 进行 AI-Native 代码分析和依赖管理。

### 快速命令

```bash
mycodemap doctor      # 诊断项目健康状态
mycodemap generate    # 生成代码地图
mycodemap preview     # 零配置预览
mycodemap query       # 搜索符号、模块和依赖
mycodemap cycles      # 检测循环依赖
mycodemap impact      # 评估文件变更影响
mycodemap analyze     # 统一分析入口（意图驱动）
```

### 代码地图产物

- `.mycodemap/AI_MAP.md` — AI 可读的项目结构概览
- `.mycodemap/dependency-graph.md` — 依赖关系 Mermaid 图
- `.mycodemap/codemap.json` — 机器可读的完整代码地图
- `.mycodemap/context/` — 上下文文件（供 AI 代理使用）

### 规则引用

<!-- mycodemap-rules-bundle:start -->
- `@.mycodemap/rules/commit/default.md`
- `@.mycodemap/rules/test/default.md`
- `@.mycodemap/rules/lint/default.md`
- `@.mycodemap/rules/docs/default.md`
- `@.mycodemap/rules/validation/default.md`
<!-- mycodemap-rules-bundle:end -->

### 子代理检索

当需要项目环境契约时：

```bash
mycodemap env-contract --for default --json
```

使用 `--for explore`、`--for plan`、`--for worker` 或 `--for verify` 指定委托角色。

### CodeMap 上下文

> 详见 `.mycodemap/assistants/agents-context.md`
