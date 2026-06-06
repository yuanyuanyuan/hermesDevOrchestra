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
- `docs/solutions/` — 已解决问题知识库（按 category 组织，frontmatter 包含 `module`、`tags`、`problem_type`），在实现、调试或对齐已记录方案时 relevant

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

### Worker Advancement Evidence Gate (Sprint 8)

`orch_gateway.submit_worker_output` 在 Sprint 8 中接入了 worker advancement
evidence gate，确保 stage advancement 之前必须有完整的 write scope / DAG /
review / commit evidence。

**Library**：`scripts/lib/worker_evidence_harden.py`

- `validate_worker_advancement(run, task, actual_changed_files) -> list[str]`：
  返回错误码列表；空列表表示通过。
- 错误码 schema：`<code>: <payload>`，如
  `write_scope_violation: files=[...]; expected_scope=[...]`。
- 错误码集合：`missing_write_scope`、`write_scope_violation`、
  `invalid_evidence_input`、`missing_dag_validation`、
  `dag_cycle_detected`、`dag_validation_failed`、
  `missing_review_evidence`、`missing_commit_evidence`、
  `unknown_stage`、`stage_order_violation`、
  `write_scope_unrestricted_engaged`。

**CLI**：`scripts/bin/orch-validate-worker-advancement`

- stdin 或 `--run` / `--task` / `--actual-changed-files` argv 输入 JSON。
- exit code：0 = valid / 1 = violations / 2 = usage error。
- 1MB JSON 大小限制（DoS 防护）。

**Stage 规范化**：所有 stage 字符串在 entry 处 `strip().lower()`。
Stage 元数据单一来源：`worker_evidence_harden.STAGE_REQUIREMENTS`。

**重要约束**：

- **不要**在 task 里设置 `write_scope_unrestricted: true` 来绕过 scope 校验；
  task-level 会被拒。run-level privilege grant 才会接受，但会 emit
  `write_scope_unrestricted_engaged: <stage>` 审计 warning。
- **不要**使用 `cycles`/`back_edges` 之外的 key 来传递 DAG 验证信息；当前
  validator 接受两种 schema（`valid`/`cycles` 与 `passed`/`back_edges`/
  `cycle_detected`）。

**已知 follow-up**：

- Sprint 8 e2e 集成测试目前只覆盖 block 路径；happy-path 计划在
  Sprint 8 follow-up issue 中实现。
- `worker_advancement_evidence_violations` 当前只接受 `dict` run/task；
  非 dict 入参返回 `invalid_evidence_input`。

详见：

- `docs/FULL-COVERAGE-MATRIX.md` — 工具条目
- `docs/solutions/security/worker-advancement-evidence-gate.md` — 完整背景
  与复用模式

### CodeMap 上下文

> 详见 `.mycodemap/assistants/agents-context.md`
