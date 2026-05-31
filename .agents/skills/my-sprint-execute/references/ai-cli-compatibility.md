# AI CLI 工具兼容性参考

> 本文件定义 my-sprint-execute v3 在 Claude Code、Codex、Kimi 三大 AI CLI 平台上的 subagent 调用差异与兼容策略。
> **所有技术声明均标注来源**。未标注来源的数字或参数名视为"未验证"，Skill 实现中不得依赖。

---

## 0. 执行摘要（关键差异）

| 维度 | Claude Code | Codex | Kimi |
|------|-------------|-------|------|
| **Subagent 机制** | 显式 `Agent` 工具调用 | **自然语言委托**（主 agent 自动协调，无显式 spawn 工具） | 显式 `Agent` 工具调用 |
| **Orchestrator 可控性** | ✅ 直接 spawn / resume / 后台运行 | ❌ 不可控，主 agent 自行决定何时 spawn | ✅ 直接 spawn / resume / 后台运行 |
| **并发上限（文档化）** | 未文档化 | `agents.max_threads` 默认 **6** | 未文档化 |
| **后台运行参数** | `run_in_background: bool` | 不适用（无显式工具） | `run_in_background: bool` |
| **Subagent 模型覆盖** | 参数存在但对内置 types **无效** | 通过自定义 agent TOML 的 `model` 字段 | 参数存在，具体值未文档化 |
| **隔离机制** | Feature branch（推荐） | Feature branch（推荐） | Feature branch（推荐） |

> **核心结论**：Codex 的 subagent 架构与 Claude Code/Kimi **根本不同**。my-sprint-execute v3 的"Orchestrator 显式 dispatch 多 agent"模式在 Codex 上无法直接复现。详见第 5 节 Codex 适配策略。

---

## 1. 平台机制分类

### 1.1 显式 Agent 工具平台（Claude Code、Kimi）

这两个平台提供同名的 `Agent` 内置工具，允许 orchestrator（主 agent）**显式地**创建、控制、恢复 subagent。

**工作流程**：
1. Orchestrator 调用 `Agent` 工具，传入 `description` + `prompt` + `subagent_type`
2. 平台创建独立上下文窗口的 subagent 实例
3. Subagent 执行完毕后返回单一文本结果给 orchestrator
4. Orchestrator 可通过 `resume` 参数恢复已有实例

**对 my-sprint-execute 的意义**：
- 支持 **Bounded Dispatch**：orchestrator 可以精确控制同时运行的 subagent 数量
- 支持 **Team Topology**：orchestrator 可以按任务分配 Driver/Navigator/Guardian 角色
- 支持 **Artifact 协作**：orchestrator 指定共享文件路径，subagent 按约定读写

### 1.2 自然语言委托平台（Codex）

Codex **没有显式的 subagent spawn 工具**。Subagent workflow 由主 agent 在阅读用户 prompt 后**自行决定**是否 spawn、何时 spawn、spawn 多少个。

**官方文档原文**：
> "Codex only spawns subagents when you explicitly ask it to. Because each subagent does its own model and tool work, subagent workflows consume more tokens than comparable single-agent runs."
> — [OpenAI Codex Subagents 文档](https://developers.openai.com/codex/subagents)

> "Codex handles orchestration across agents, including spawning new subagents, routing follow-up instructions, waiting for results, and closing agent threads."
> — [OpenAI Codex Subagents 文档](https://developers.openai.com/codex/subagents)

**对 my-sprint-execute 的意义**：
- Orchestrator **无法直接控制** subagent 的创建和调度
- Team Topology（pair/trio）无法由 orchestrator 强制执行
- Bounded Dispatch 无法在 orchestrator 层实现（只能依赖 Codex 内部的 `max_threads` 配置）
- 只能采用**自然语言委托**策略：在 prompt 中描述"请按以下方式分配多个 subagent"，由 Codex 自行决定是否执行

---

## 2. 各平台详细规格

### 2.1 Claude Code

**官方文档**：https://code.claude.com/docs/en/tools-reference

#### Agent 工具参数（官方 schema）

| 参数 | 类型 | 必需 | 说明 | 来源 |
|------|------|------|------|------|
| `description` | string | ✅ | 简短描述（3-5 词） | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |
| `prompt` | string | ✅ | 任务详细描述 | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |
| `subagent_type` | string | ✅ | 内置 subagent 类型 | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |
| `model` | string | — | `"sonnet"` / `"opus"` / `"haiku"` | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |
| `resume` | string | — | 恢复已有 agent ID | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |
| `run_in_background` | boolean | — | 后台运行 | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |

#### 内置 subagent_type 值

- `general-purpose`: 通用任务（工具: `*`）
- `Explore`: 只读代码库探索
- `Plan`: 实现规划与架构设计
- `statusline-setup`: 配置状态栏
- `claude-code-guide`: 回答 Claude Code 使用问题

来源：[Tools Reference](https://code.claude.com/docs/en/tools-reference)

#### 已知限制（有 issue 佐证）

| 限制 | 说明 | 来源 |
|------|------|------|
| `model` 参数对内置 types 无效 | Subagent 始终继承 parent model，无论指定什么 model | [anthropics/claude-code#20167](https://github.com/anthropics/claude-code/issues/20167) |
| Background agent 写文件失败 | `run_in_background=true` 时 subagent 可能无法写入文件 | [anthropics/claude-code#14521](https://github.com/anthropics/claude-code/issues/14521) |
| Subagent 不继承 CWD | `cd` 变化不会带到 subagent session | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |
| Background agent 自动拒绝权限 | 不显示权限提示，自动 deny 需要提示的工具调用 | [Tools Reference](https://code.claude.com/docs/en/tools-reference) |

#### 并发上限

**官方未文档化**。无 `max_threads` 等配置项公开。实测中通常可并行运行多个 subagent，但无保证上限。

> **Skill 策略**：不假设具体上限。通过试错检测：若 spawn 失败则排队等待。

---

### 2.2 Codex

**官方文档**：https://developers.openai.com/codex/subagents

#### 关键事实

Codex **不提供 orchestrator 直接调用的 subagent spawn 工具**。以下列出的是官方文档中确认的 subagent **配置与行为**，而非 orchestrator 可调用的工具参数。

| 配置项 | 类型 | 默认值 | 说明 | 来源 |
|--------|------|--------|------|------|
| `agents.max_threads` | number | **6** | 并发 open agent thread 上限 | [Codex Subagents](https://developers.openai.com/codex/subagents) |
| `agents.max_depth` | number | **1** | Subagent 嵌套深度（root=0） | [Codex Subagents](https://developers.openai.com/codex/subagents) |
| `agents.job_max_runtime_seconds` | number | — | CSV batch 任务的默认超时 | [Codex Subagents](https://developers.openai.com/codex/subagents) |

#### 内置 Agent 角色

- `default`: 通用 fallback
- `worker`: 执行聚焦（implementation & fixes）
- `explorer`: 只读代码库探索

来源：[Codex Subagents](https://developers.openai.com/codex/subagents)

#### 自定义 Agent 定义

通过 TOML 文件定义，路径：`~/.codex/agents/`（个人）或 `.codex/agents/`（项目）。

必需字段：`name`, `description`, `developer_instructions`
可选字段：`nickname_candidates`, `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`

来源：[Codex Subagents](https://developers.openai.com/codex/subagents)

#### 已知限制

| 限制 | 说明 | 来源 |
|------|------|------|
| 无显式 spawn 工具 | Orchestrator 无法直接创建 subagent | [Codex Subagents](https://developers.openai.com/codex/subagents) |
| Subagent 继承 sandbox policy | 无法为单个 subagent 单独设置 sandbox | [Codex Subagents](https://developers.openai.com/codex/subagents) |
| 本地 provider subagent 可能失败 | 非 OpenAI provider 时 subagent 可能不可用 | [openai/codex#24069](https://github.com/openai/codex/issues/24069) |
| 自定义 provider 的 subagent 回退到 openai | 使用 custom provider 时 subagent 可能回退到 openai 端点 | [openai/codex#13204](https://github.com/openai/codex/issues/13204) |

---

### 2.3 Kimi

**官方文档**：https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html

#### Agent 工具参数（官方 schema）

| 参数 | 类型 | 必需 | 说明 | 来源 |
|------|------|------|------|------|
| `description` | string | — | 简短描述（3-5 词） | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |
| `prompt` | string | — | 任务详细描述 | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |
| `subagent_type` | string | — | 内置类型，默认 `coder` | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |
| `model` | string | — | 可选模型覆盖 | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |
| `resume` | string | — | 恢复已有实例 ID | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |
| `run_in_background` | boolean | — | 后台运行，默认 false | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |

#### 内置 subagent_type 值

- `coder`: 通用软件工程（可用工具：Shell, ReadFile, Glob, Grep, WriteFile, StrReplaceFile, SearchWeb, FetchURL）
- `explore`: 只读代码探索（无写工具）
- `plan`: 实现规划（无 Shell，无写工具）

来源：[Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html)

#### 已知限制

| 限制 | 说明 | 来源 |
|------|------|------|
| Subagent 不能嵌套 Agent | Subagent 无法创建自己的 subagent | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |
| Subagent 不继承 CWD | `cd` 变化不传递到 subagent，影响 worktree 工作流 | [MoonshotAI/kimi-cli#1931](https://github.com/MoonshotAI/kimi-cli/issues/1931) |
| `model` 参数具体值未文档化 | 文档仅说"可选模型覆盖"，无可用值列表 | [Kimi Subagents](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html) |

#### 并发上限

**官方未文档化**。无 `max_threads` 等配置项。

---

## 3. 跨平台 Subagent 能力矩阵

| 能力 | Claude Code | Codex | Kimi |
|------|:-----------:|:-----:|:----:|
| Orchestrator 显式 spawn subagent | ✅ `Agent` 工具 | ❌ 无工具 | ✅ `Agent` 工具 |
| Orchestrator 指定 subagent 类型 | ✅ `subagent_type` | ❌ 不可控 | ✅ `subagent_type` |
| Orchestrator 后台运行 subagent | ✅ `run_in_background` | ❌ 不可控 | ✅ `run_in_background` |
| Orchestrator 恢复 subagent | ✅ `resume` | ❌ 不可控 | ✅ `resume` |
| Orchestrator 设置并发上限 | ❌ 未暴露 | ❌ 仅用户配置 `max_threads` | ❌ 未暴露 |
| Subagent 嵌套（孙子 agent） | ⚠️ 可能，但未文档化推荐 | ⚠️ `max_depth` 默认 1 | ❌ 明确禁止 |
| Subagent 模型覆盖 | ❌ 对内置 types 无效 | ⚠️ 通过自定义 agent TOML | ⚠️ 参数存在但值未文档 |
| Subagent 文件写入（后台） | ⚠️ 已知有 bug | — | ✅ 正常 |

---

## 4. Feature Branch 隔离（跨平台统一）

所有三个平台都支持通过 **git feature branch** 实现工作隔离。这是 v3 唯一采用的隔离机制。

```
# 创建并切换到任务分支
git checkout -b feat/sprint${SPRINT}-${TASK_ID}

# Subagent 在此分支上工作
# 完成后 orchestrator 合并回 base branch
git checkout ${BASE_BRANCH}
git merge feat/sprint${SPRINT}-${TASK_ID}
```

**为什么不用 worktree？**
- Claude Code 虽有 `EnterWorktree` / `ExitWorktree` 工具，但 subagent 不继承 CWD 变化
- Kimi subagent 不继承 parent CWD，worktree 切换后 subagent 可能仍在原目录
- Codex 无 worktree 相关工具
- Feature branch 是所有平台都支持的通用 git 操作

---

## 5. my-sprint-execute v3 跨平台适配策略

### 5.1 Claude Code — 完全支持

Team Topology（solo/pair/trio）+ Bounded Dispatch + Cross-Review Gate 均可实现。

**实现要点**：
- 使用 `Agent` 工具显式 spawn Driver/Navigator/Guardian
- 使用 `run_in_background: true` 实现并行
- `subagent_type` 建议：Driver=`general-purpose`, Navigator=`Explore`/`Plan`, Guardian=`general-purpose`
- **不要依赖 `model` 参数控制成本**（对内置 types 无效）
- **需要写文件的 subagent 建议前台运行**（规避 issue #14521）
- 通过 `resume` 恢复长任务 subagent

**Bounded Dispatch 实现**：
```
# 无平台配置的上限，采用保守值
MAX_PARALLEL_TEAMS = 4  # 经验值，可根据实测调整

# spawn 失败时（容量不足），排队等待
# 使用 TaskList / TaskOutput 监控后台 subagent
```

### 5.2 Kimi — 完全支持

与 Claude Code 类似的显式 `Agent` 工具，参数兼容。

**实现要点**：
- 使用 `Agent` 工具显式 spawn
- 内置 `subagent_type` 值与 v3 角色天然对应：
  - Driver → `coder`
  - Navigator → `explore`（只读审查）或 `plan`（架构审查）
  - Guardian → `coder`（需要运行测试）
- Subagent 不能嵌套 Agent → **确保 prompt 中不要求 subagent 再 spawn 子 agent**
- `model` 参数存在但值未文档 → **省略该参数，使用默认模型**

**Bounded Dispatch 实现**：
```
# 同 Claude Code，无官方上限
MAX_PARALLEL_TEAMS = 4  # 保守值
```

### 5.3 Codex — 受限支持（重要）

由于 Codex 没有显式 spawn 工具，my-sprint-execute v3 的 orchestrator 驱动多 agent 模式**无法直接实现**。

#### 推荐策略 A：降级为 Solo（最可靠）

在 Codex 上，my-sprint-execute 回退到 v2 的**顺序 solo 执行**模式：
- 每个 implementation unit 由主 agent 顺序完成
- 无 Team Topology、无并行 dispatch
- 保留 4-level checklist 和 feature branch 隔离

**何时使用**：生产环境、关键路径、需要可预测性的场景。

#### 推荐策略 B：自然语言委托（实验性）

在 prompt 中明确请求 Codex 使用 subagent workflow，但不控制具体调度：

```
这是一个需要多角色协作的 Sprint 任务。

请使用 Codex 的 subagent workflow，按以下方式分配：
1. 创建一个 Driver subagent 负责实现代码
2. 创建一个 Navigator subagent 负责审查架构
3. 创建一个 Guardian subagent 负责测试验证

每个 subagent 在 feature branch feat/sprint${SPRINT}-${TASK_ID} 上工作。
完成后合并结果并输出到 ${TEAM_ARTIFACT_DIR}/team-consensus.md。
```

**风险**：
- Codex 可能不 spawn 任何 subagent，自己完成所有工作
- 无法控制并发数（受用户 `max_threads` 配置约束，orchestrator 不知情）
- 无法获取单个 subagent 的完成状态进行 cross-review
- 无法精确实现 Bounded Dispatch

**何时使用**：探索性任务、非关键路径、用户明确接受不可控性的场景。

#### Codex 配置建议（提供给用户）

若用户希望在 Codex 上尝试多 agent 模式，建议在 `~/.codex/config.toml` 中配置：

```toml
[agents]
max_threads = 6
max_depth = 1
```

并创建自定义 agent 定义（`.codex/agents/`）：

```toml
# driver.toml
name = "driver"
description = "Implementation-focused agent for coding tasks."
developer_instructions = "You are the Driver. Write code, run tests, and report progress."

# navigator.toml
name = "navigator"
description = "Review-focused agent for architecture and design review."
sandbox_mode = "read-only"
developer_instructions = "You are the Navigator. Review code for design correctness and architectural alignment. Do not write code."

# guardian.toml
name = "guardian"
description = "Testing-focused agent for test validation."
developer_instructions = "You are the Guardian. Write and run tests, verify coverage, and report test results."
```

> 注意：即使定义了自定义 agent，orchestrator 仍然**无法显式 spawn 它们**。Codex 主 agent 自行决定何时使用这些定义。

---

## 6. 保守默认值矩阵

以下默认值仅用于 my-sprint-execute v3 的跨平台实现。**所有数字均为保守估计**，因为仅 Codex 有文档化默认值。

| 平台 | 默认 `MAX_PARALLEL_TEAMS` | 依据 |
|------|--------------------------|------|
| Claude Code | 4 | 未文档化；经验保守值 |
| Codex | 1（Solo）| 无显式 spawn 工具，多 agent 不可控 |
| Kimi | 4 | 未文档化；经验保守值 |
| 未知平台 | 1 | 安全回退 |

**Slot 计算**：
- Solo = 1 slot
- Pair = 2 slots
- Trio = 3 slots

**超过上限时的行为**：
- Claude Code / Kimi：spawn 失败时捕获错误，排队重试
- Codex：不适用（无显式 spawn）

---

## 7. Prompt 中的跨平台兼容写法

### 7.1 必须避免的写法

❌ **不要写死工具名**：
```
# 错误 — Codex 没有 Agent 工具
请调用 Agent 工具 spawn 一个 subagent。

# 错误 — Codex 没有 spawn_agent
请调用 spawn_agent 创建 worker。
```

❌ **不要写死模型名**：
```
# 错误 — Claude Code 内置 subagent types 忽略 model 参数
请使用 model="sonnet" 创建 subagent。

# 错误 — 无官方依据的模型名
请使用 gpt-5.4-mini 创建 subagent。
```

❌ **不要写死参数名**：
```
# 错误 — Codex 没有这些参数
请设置 run_in_background=true。
```

❌ **不要假设 worktree**：
```
# 错误 — 不是跨平台通用机制
请在 worktree 中工作。
```

### 7.2 推荐的兼容写法

✅ **使用平台无关的指令**：
```
你是 Sprint ${SPRINT} Task ${TASK_ID} 的 ${ROLE}。

## 工作上下文
- 仓库路径：${REPO_DIR}
- 你的工作分支：feat/sprint${SPRINT}-${TASK_ID}
- 基础分支：${BASE_BRANCH}

## 操作规范
1. 开始前执行：cd ${REPO_DIR} && git checkout feat/sprint${SPRINT}-${TASK_ID}
2. 所有代码修改只在此分支上进行
3. 完成后执行 git add + git commit（不要 push，由主会话负责集成）
4. 将进度写入 ${TEAM_ARTIFACT_DIR}/${ROLE}-progress.md
```

✅ **对 Codex 使用自然语言委托**：
```
请使用你的 subagent 能力完成以下任务分配：
- 一个 subagent 作为 Driver 实现代码
- 一个 subagent 作为 Navigator 审查设计
- 一个 subagent 作为 Guardian 验证测试

每个 subagent 在分支 feat/sprint${SPRINT}-${TASK_ID} 上工作。
```

---

## 8. 平台检测（务实方案）

**官方未提供任何标准化的平台检测环境变量**。以下方案基于**间接推断**，非官方 API，可能在版本更新后失效。

| 检测方式 | Claude Code | Codex | Kimi |
|---------|:-----------:|:-----:|:----:|
| 检查 `CLAUDE_CODE` 环境变量 | 有时存在 | ❌ | ❌ |
| 检查 `.claude/` 目录存在 | ✅ 项目级 | ❌ | ❌ |
| 检查 `.codex/` 目录存在 | ❌ | ✅ 项目级 | ❌ |
| 检查 `.kimi/` 目录存在 | ❌ | ❌ | ✅ 项目级 |
| 询问用户 | ✅ 最可靠 | ✅ 最可靠 | ✅ 最可靠 |

**推荐策略**：
1. 优先通过 `--platform` 参数或环境变量由用户显式声明
2. 次选通过项目目录中的配置文件推断（`.claude/` → Claude Code, `.codex/` → Codex, `.kimi/` → Kimi）
3. 无法推断时，默认 Solo 模式（最安全）

```bash
# 推荐：用户显式声明
my-sprint-execute plan.md checklist.md 3 --platform claude

# 或环境变量
export MY_SPRINT_PLATFORM=claude
```

---

## 9. 参考资料

### 官方文档

| 平台 | 文档 | URL |
|------|------|-----|
| Claude Code | Tools Reference | https://code.claude.com/docs/en/tools-reference |
| Claude Code | Environment Variables | https://code.claude.com/docs/en/env-vars |
| Codex | Subagents | https://developers.openai.com/codex/subagents |
| Kimi | Agents and Subagents | https://www.kimi.com/code/docs/en/kimi-code-cli/customization/sub-agents.html |

### GitHub Issues（已验证的限制）

| Issue | 平台 | 说明 |
|-------|------|------|
| [anthropics/claude-code#20167](https://github.com/anthropics/claude-code/issues/20167) | Claude Code | `model` 参数对内置 subagent types 无效 |
| [anthropics/claude-code#14521](https://github.com/anthropics/claude-code/issues/14521) | Claude Code | Background agent 无法写文件 |
| [openai/codex#24069](https://github.com/openai/codex/issues/24069) | Codex | 本地 provider 的 subagent 在 0.133.0 中失效 |
| [openai/codex#13204](https://github.com/openai/codex/issues/13204) | Codex | 自定义 provider 的 subagent 回退到 openai |
| [MoonshotAI/kimi-cli#1931](https://github.com/MoonshotAI/kimi-cli/issues/1931) | Kimi | Subagent 不继承 parent CWD |

---

## 10. 版本兼容性

| my-sprint-execute 版本 | Claude Code | Codex | Kimi |
|------------------------|:-----------:|:-----:|:----:|
| v3.0+ | ✅ Team Topology 完全支持 | ⚠️ Solo 推荐；多 agent 实验性 | ✅ Team Topology 完全支持 |
| v2.x | ✅ Solo 顺序执行 | ✅ Solo 顺序执行 | ✅ Solo 顺序执行 |

> **v3 在 Codex 上的降级说明**：由于 Codex 没有显式 subagent spawn 工具，v3 的 Team Topology 和 Bounded Dispatch 无法在 orchestrator 层强制执行。Codex 用户应预期回退到 Solo 模式，或接受自然语言委托的不可控性。
