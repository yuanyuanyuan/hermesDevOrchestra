---
title: "Agent SDK subagent hangs with non-Anthropic model via third-party proxy"
date: 2026-06-05
category: tooling-decisions
module: development-workflow
problem_type: tooling_decision
component: tooling
severity: medium
related_components:
  - development_workflow
tags:
  - claude-code
  - agent-sdk
  - multi-agent
  - model-compatibility
  - third-party-proxy
  - mimo-v25
  - subagent
---

# Agent SDK subagent hangs with non-Anthropic model via third-party proxy

## Context

使用 Claude Code 的 `Agent` 工具（如 `Explore` 子代理）调查项目脚本时，子代理进程挂起或被中断。项目环境使用非 Anthropic 原生模型（`mimo-v2.5[1m]`），通过第三方代理（`token-plan-sgp.xiaomimimo.com/anthropic`）访问 API。当主会话与子代理同时发起 API 请求时，`Agent` 工具创建的独立会话上下文会导致并发连接问题。

该问题并非每次必现——同一会话中多个并行子代理可能部分成功、部分挂起（参见 "Examples" 节的 Session 02af8cca 案例）。

## Guidance

### 诊断方法论

1. **检查 Hook 配置** — 排除 `SubagentStop`/`PreToolUse` hook 干扰的可能性。检查 `.harness-active`、`.claude/do-tasks/.current-task` 等状态文件是否存在；检查 `verify-loop.py` 是否只针对特定 agent type
2. **检查 agents 定义目录** — 确认 `~/.claude/agents/` 中是否有自定义代理定义。注意：系统提示中列出的 `Explore` 等内置 agent type 可能没有对应的 `.md` 定义文件
3. **检查模型与代理层** — 确认模型配置（`ANTHROPIC_MODEL`）和 API 端点（`ANTHROPIC_BASE_URL`）是否为第三方代理地址
4. **根因定位**：代理层可能存在并发连接限制或速率限制，多会话并发请求触发连接池耗尽

### 规避方案：直接使用 Bash 命令替代 Agent 工具

对于文件系统调查任务，直接使用 `grep`、`find`、`ls`、`cat` 等 Bash 命令，不依赖 API 调用：

```
# Agent 工具（可能挂起）
Agent(subagent_type="Explore", prompt="查找所有 resolve 相关脚本...")

# 替代方案（本地执行，即时返回）
rtk grep -rn "resolve" .claude/skills/my-pr-skill/scripts/
rtk find .claude/skills/my-pr-skill -name "*.sh" -type f
rtk cat .claude/skills/my-pr-skill/scripts/get-pr-reviews.sh
```

## Why This Matters

- **可靠性**：`Agent` 工具依赖完整 API 调用链（主会话 → 代理 → 模型 → 代理 → 主会话），任何环节异常都可能导致挂起；Bash 命令在本地执行，不受代理层并发限制影响
- **调试成本**：子代理挂起时缺乏明确的错误信息（`stop_reason: None`），排查困难；直接 Bash 命令失败时有即时反馈
- **Token 效率**：子代理启动需要额外的系统提示和上下文传递，直接 Bash 命令更轻量

## When to Apply

**Agent 工具可能正常工作的情况：**
- 使用 Anthropic 原生模型（claude-sonnet-4、claude-opus-4 等）直连 API
- 代理层无并发限制或速率限制较宽松
- 子代理任务较简单（不涉及大量工具调用）
- 会话中只有少量子代理并发运行

**应规避 Agent 工具的情况：**
- 使用非 Anthropic 模型通过第三方代理访问
- 已观察到子代理挂起或超时现象
- 任务主要是文件系统调查（grep/find/cat 即可完成）
- 需要快速响应的调试场景
- 会话中需要大量并行子代理（>5 个）

**诊断检查清单：**
- 检查 `~/.claude/agents/` 目录确认可用代理定义
- 检查模型配置（环境变量中的 `ANTHROPIC_MODEL`）
- 检查 `ANTHROPIC_BASE_URL` 是否为代理地址
- 检查 Hook 配置排除干扰（`~/.claude/settings.json`）
- 检查 `.harness-active`、`.claude/do-tasks/.current-task` 等状态文件

## Examples

### Before（Agent 工具挂起）

```
用户：调查 my-pr-skill 脚本是否支持 resolve conversation
→ Claude 调用 Agent 工具，spawn Explore 子代理
→ 子代理通过 ANTHROPIC_BASE_URL 发起 API 调用
→ 代理并发限制触发 → 子代理挂起无响应
→ 主会话等待超时或用户中断（"卡住了？"）
→ 耗时 ~5s+ 无任何输出
```

### After（Bash 命令直接调查）

```
用户：调查 my-pr-skill 脚本是否支持 resolve conversation
→ Claude 使用 Bash 命令直接调查：
  - rtk grep -rn "resolve" .claude/skills/my-pr-skill/scripts/
  - rtk cat .claude/skills/my-pr-skill/scripts/get-pr-reviews.sh
  - rtk cat .claude/skills/my-pr-skill/scripts/submit-review.sh
→ 本地文件系统操作，无 API 依赖，即时返回结果
→ 确认无 resolve 脚本，直接用 gh api 命令演示可行性
→ 总耗时 <30s，完整结论
```

### Session 02af8cca 案例（并行子代理部分失败）

```
Phase 1：5 个并行 Agent 子代理 → 全部成功
Phase 2：7 个并行 Agent 子代理 → 全部成功
Phase 3：3 个对抗验证器 Agent 子代理
  → V1（误报过滤）：成功
  → V2（契约验证）：成功
  → V3（维护者审查合成器，任务最复杂）：
      spawn 返回 ok，但子代理内部无输出
      ~12 分钟后用户放弃，用 V1+V2 结果直接生成报告
```

**关键观察**：V3 是三个验证器中任务最复杂的（需综合 18 个发现并分类 blocking/non-blocking）。这暗示**任务复杂度可能与挂起概率正相关**。

## Related

- `docs/solutions/integration-issues/gateway-fallback-contract-and-project-discovery-regressions.md` — 项目中唯一已有的 solution 文档，与本问题无交叉（Gateway HTTP 回退合约 vs. Claude Code Agent 工具）
