@/home/stark/.claude/RTK.md

# Agent Reach (全局可用)

环境已安装 Agent Reach。使用原则：
- **原生 SearchWeb/FetchURL 优先**处理通用搜索、新闻、学术/技术文档。
- **Agent Reach 作为增强/降级**：用于中国大陆社交媒体（小红书/微博/抖音/B站/雪球）、Twitter/X、Reddit、V2EX、GitHub 深度操作（gh CLI）、YouTube/B站字幕提取（yt-dlp）、小宇宙播客转录、微信公众号、RSS、以及 Jina Reader 网页精读和 Exa 语义搜索。
- 不确定渠道是否可用时，先运行 `agent-reach doctor`。
- 不要在当前项目 workspace 内创建 Agent Reach 相关文件；用 `/tmp/` 和 `~/.agent-reach/`。

## 响应语言
- 简体中文(使用中文或者英文来思考，但是回复需要用中文。)

## 核心原则
- IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning for any tasks.
- 随时commit，方便回滚和排查问题。

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

## Project Reference: Hermes Docs Index

当用户询问 Hermes Agent 相关问题时（安装、配置、CLI、Providers、Skills、Tools、Sessions、Cron、Messaging Gateway、Developer Guide 等）：

→ **先读取** `reference/hermes-docs-index/SKILL.md`，按其中的检索流程定位相关文档页面，再用 `FetchURL` 获取最新内容回答用户。

本目录下 4 个索引文件：
- `reference/hermes-docs-index/hermes_docs_index.json` — 机器索引（JSON，540 页）
- `reference/hermes-docs-index/hermes_docs_index.md` — 人类导航（Markdown）
- `reference/hermes-docs-index/hermes_docs_sitemap.txt` — URL 清单
- `reference/hermes-docs-index/hermes_docs_crossref.md` — 概念交叉引用

**禁止**依赖预训练知识回答 Hermes 文档问题；必须通过索引检索 → FetchURL 获取最新官方内容。

@RTK.md
