# Phase 19 增量能力可行性验证报告

**日期**: 2026-05-10  
**验证依据**: Hermes Agent v0.13.0 官方文档（Plugin Hooks、Kanban Worker、Build a Plugin、Git Worktrees、Architecture）  
**验证方法**: 索引检索 → FetchURL 获取官方原文 → 交叉核对 R3-R24 每项需求的官方支持度

---

## 1. 官方 Hook 系统确认（R19 基础设施）

Hermes 官方提供三类 hook 系统：

| 系统 | 注册方式 | 运行范围 | 阻塞能力 |
|------|---------|---------|---------|
| **Gateway hooks** | `HOOK.yaml` + `handler.py` in `~/.hermes/hooks/` | Gateway only | 否 |
| **Plugin hooks** | `ctx.register_hook()` in plugin | **CLI + Gateway** | `pre_tool_call` 可 block |
| **Shell hooks** | `hooks:` block in `config.yaml` | **CLI + Gateway** | `pre_tool_call` 可 block |

### 1.1 官方支持的 Plugin Hooks（完整列表）

| Hook | 触发时机 | 回调签名 | 返回值影响行为？ |
|------|---------|---------|---------------|
| `pre_tool_call` | 每个工具执行前 | `tool_name, args, task_id, **kwargs` | ✅ 可返回 `{"action":"block","message":"..."}` |
| `post_tool_call` | 每个工具返回后 | `tool_name, args, result, task_id, duration_ms, **kwargs` | ❌ 纯观察 |
| `pre_llm_call` | 每轮工具循环前 | `session_id, user_message, conversation_history, is_first_turn, model, platform, **kwargs` | ✅ 可注入 context |
| `post_llm_call` | 每轮成功完成后 | `session_id, user_message, assistant_response, conversation_history, model, platform, **kwargs` | ❌ 纯观察 |
| `on_session_start` | 新会话首次 turn | `session_id, model, platform, **kwargs` | ❌ 纯观察 |
| `on_session_end` | 每次 `run_conversation()` 结束 + CLI exit | `session_id, completed, interrupted, model, platform, **kwargs` | ❌ 纯观察 |
| `on_session_finalize` | CLI/Gateway teardown | `session_id, platform, **kwargs` | ❌ 纯观察 |
| `on_session_reset` | Gateway 换 session key | `session_id, platform, **kwargs` | ❌ 纯观察 |
| `subagent_stop` | `delegate_task` 子代理退出后 | `parent_session_id, child_role, child_summary, child_status, duration_ms, **kwargs` | ❌ 纯观察 |
| `pre_gateway_dispatch` | Gateway 收到消息，auth/dispatch 前 | `event, gateway, session_store, **kwargs` | ✅ 可 skip/rewrite/allow |
| `pre_approval_request` | 危险命令审批请求发送前 | `command, description, pattern_key, pattern_keys, session_key, surface, **kwargs` | ❌ 纯观察 |
| `post_approval_response` | 用户响应审批后 | 同上 + `choice, **kwargs` | ❌ 纯观察 |
| `transform_tool_result` | 工具返回后，加入对话前 | `tool_name, arguments, result, task_id, **kwargs` | ✅ 可替换 result |
| `transform_terminal_output` | terminal 工具内，truncation 前 | `command, output, exit_code, cwd, task_id, **kwargs` | ✅ 可替换 output |
| `transform_llm_output` | 最终响应交付前 | `response_text, session_id, model, platform, **kwargs` | ✅ 可替换 text |

**关键结论**：
- ✅ `post_tool_call` 和 `on_session_end` **官方确实存在**，R19 的基础假设成立
- ⚠️ `task_id` 参数文档说明："Empty string if not set" — 在 Kanban Worker 场景中需验证 `HERMES_KANBAN_TASK` env var 是否会自动映射到 `task_id`
- ⚠️ `on_session_end` 在 **SIGKILL / 未捕获异常崩溃时不会触发**（仅在 `run_conversation()` 正常结束或 CLI exit handler 时触发）

### 1.2 Plugin 在 Kanban Worker 中的加载

Plugin 通过 `PluginManager.discover_and_load()` 在 Hermes **启动时**加载。加载来源：
1. `~/.hermes/plugins/`（用户级）
2. `.hermes/plugins/`（项目级）
3. pip entry points

**关键问题**：Kanban Worker 是 Dispatcher 生成的 **独立 OS 进程**。如果 Worker 通过标准 Hermes CLI/Gateway 入口启动，则 plugins 会被加载，hooks 会生效。如果 Worker 是裸 `AIAgent.run_conversation()` 调用（不经过 CLI/Gateway 初始化），则 plugins 可能不加载。

**官方 Architecture 文档说明**：Worker 由 Dispatcher spawn，但具体 spawn 方式未在获取的文档中详细说明。需要 Phase 0 代码验证确认。

---

## 2. 逐项可行性评估

### R3: 项目级 Profile Override

| 维度 | 评估 |
|------|------|
| **官方支持** | Profile 有 `HERMES_HOME` 完全隔离，但无"全局 base + 项目 override"合并机制 |
| **可行路径** | ① `.hermes/plugins/`（项目级插件目录）可注册 `pre_llm_call` hook 注入项目级上下文；② 项目级 `AGENTS.md` 已原生支持 |
| **可行性** | 🟡 **部分可行** — 无官方"合并"机制，需通过 Plugin 模拟；项目级上下文覆盖可用 `AGENTS.md` + `pre_llm_call` 实现 |
| **风险** | 若 override 涉及 model/provider 等核心配置，Plugin hook 无法覆盖（`pre_llm_call` 只能注入上下文，不能修改配置） |

### R4: Worktree 回收

| 维度 | 评估 |
|------|------|
| **官方支持** | `workspace: worktree` 原生支持；`git worktree add/remove` 标准 Git 功能 |
| **可行路径** | ① Worker SOUL.md 写死"结束前清理"；② `on_session_end` hook 执行 `git worktree remove`；③ 外部 cron 扫描孤儿 worktree |
| **可行性** | 🟡 **部分可行** — 正常退出时可清理；**SIGKILL/crash 时 `on_session_end` 不触发**，必须依赖外部兜底机制 |
| **风险** | Dirty-state 回滚（git stash / reset）在 crash 场景下可能损坏；需要文件系统快照或 git 初始 clean commit 作为基准 |

### R5: 背压（Backpressure）

| 维度 | 评估 |
|------|------|
| **官方支持** | Dispatcher 有原生 60s tick 循环，但无"按 profile 分类的 ready 队列深度感知"机制 |
| **可行路径** | ① Cron job 定期调用 `hermes kanban list` 计算队列深度比，动态调整；② Plugin 无法直接控制 Dispatcher spawn 频率（无 hook 接入点） |
| **可行性** | 🟡 **部分可行** — 需要外部监控进程（cron 或独立 daemon）而非 Plugin hook |
| **风险** | 与 Dispatcher 内部状态竞争；调整 spawn 频率的接口未官方暴露 |

### R6: 声明式 Risk Policy YAML

| 维度 | 评估 |
|------|------|
| **官方支持** | `pre_tool_call` hook 可拦截任何工具调用；`transform_terminal_output` 可重写终端输出 |
| **可行路径** | Plugin 注册 `pre_tool_call`，读取 YAML 策略文件，匹配 `tool_name` + `args` 模式，返回 `{"action":"block","message":"..."}` |
| **可行性** | 🟢 **高度可行** — 这是 `pre_tool_call` 的官方设计目标场景 |
| **风险** | 无；模式匹配精度需 careful 设计，避免误拦/漏拦 |

### R7: Memory 命名空间隔离

| 维度 | 评估 |
|------|------|
| **官方支持** | Memory Provider 插件支持自定义存储后端；官方 Memory 有 `MEMORY.md` / `USER.md` |
| **可行路径** | 自定义 Memory Provider 插件，实现 `sync_turn()` / `prefetch()` / `on_session_end()`，在存储 key 中嵌入项目/全局命名空间前缀 |
| **可行性** | 🟡 **部分可行** — Memory Provider 是 **single-select**（一次只能激活一个），替换官方 provider 意味着失去内置 MEMORY.md 功能，或需在自定义 provider 中复现 |
| **风险** | 高侵入性；Single Provider Rule 意味着不能"叠加"多个 provider |

### R8: Reviewer Terminal 写操作拦截

| 维度 | 评估 |
|------|------|
| **官方支持** | `pre_tool_call` 可 block；`transform_tool_result` 可重写结果 |
| **可行路径** | Plugin 注册 `pre_tool_call`，检测当前 profile（通过 env 或 context），若为 reviewer 且 tool_name 为 `terminal`/`file_write`/`patch` 等，解析 args 中的命令，匹配写操作 pattern，返回 block |
| **可行性** | 🟢 **高度可行** — 与 R6 同理，是 `pre_tool_call` 的典型应用场景 |
| **风险** | Terminal 命令解析复杂（如 `echo x > file` 是写操作但 `echo x` 不是）；需要命令级 AST 解析或 allowlist 策略 |

### R9-R18: SOUL.md / Worker Skill 行为契约

| 维度 | 评估 |
|------|------|
| **官方支持** | SOUL.md 是官方配置；Skill 是官方机制；`kanban_*` 工具官方存在 |
| **可行路径** | 纯配置层面：编写 SOUL.md 规则、定义 Skill 行为契约、配置 toolsets 白名单 |
| **可行性** | 🟢 **完全可行** — 无技术障碍，纯文本契约 |
| **风险** | LLM 不 100% 遵守 prompt 规则；需要 R6/R8 的 hook 兜底 |

### R19: Observability Plugin（`post_tool_call` / `on_session_end`）

| 维度 | 评估 |
|------|------|
| **官方支持** | `post_tool_call` 和 `on_session_end` hooks 官方存在 |
| **可行路径** | Plugin 注册这两个 hook，将数据写入 SQLite / JSONL trace 存储 |
| **可行性** | 🟢 **高度可行** — 但有一个关键约束： |
| **风险** | ① `task_id` 可能为空，需通过 `HERMES_KANBAN_TASK` env var 关联；② Worker crash 时 `on_session_end` 不触发，缺失数据需由 Dispatcher 侧补充；③ 大量 tool call 产生高频写入，需 batch 或异步化 |

### R20: SRE-Observer 自动触发

| 维度 | 评估 |
|------|------|
| **官方支持** | 无原生"任务失败自动创建分析任务"机制 |
| **可行路径** | ① `on_session_end` 检测 `completed=False` 后... 但 hook **不能调用工具**（`kanban_create`），只能写入外部队列；② **Cron job** 定期扫描 board，检测 crashed/timed_out/gave_up 状态，自动创建 sre-observer 任务；③ Gateway hook 监控（仅限 Gateway 场景） |
| **可行性** | 🟡 **部分可行** — 最佳路径是 **cron job** 或独立监控进程，不是 Plugin hook 直接触发 |
| **风险** | Cron 间隔决定响应延迟；需要持久化"已触发"状态避免重复创建分析任务 |

### R21: RCA Metadata Schema

| 维度 | 评估 |
|------|------|
| **官方支持** | `kanban_complete` 的 `metadata` 参数是自由 dict |
| **可行路径** | 纯数据契约：SRE-Observer SOUL.md 中定义输出 schema，Plugin 可选做 schema 校验 |
| **可行性** | 🟢 **完全可行** — 无技术障碍 |
| **风险** | LLM 输出结构化数据的可靠性；建议用 JSON schema 约束 + 后处理校验 |

### R22: 环境快照

| 维度 | 评估 |
|------|------|
| **官方支持** | `on_session_start` hook 官方存在；`terminal` 工具可执行 shell 命令 |
| **可行路径** | `on_session_start` hook 中调用 `subprocess` 采集 `git status`、`df -h`、`hermes status`；绑定到 `task_run` metadata 需通过 `HERMES_KANBAN_TASK` env var |
| **可行性** | 🟢 **可行** — 但 snapshot 采集与 task_run 的关联需要自定义映射层 |
| **风险** | `on_session_start` 在 worker crash 后重启时也会触发，可能产生重复 snapshot |

### R23/R24: QA/DevOps 故障自动触发 SRE

| 维度 | 评估 |
|------|------|
| **官方支持** | `post_tool_call` 可观察 `kanban_block` 调用 |
| **可行路径** | Plugin `post_tool_call` 监听 `kanban_block`，解析 `reason` 字段，匹配关键词（`regression`、`critical_bug`、`security_flaw`），将事件写入外部队列；由 cron job 消费并创建 sre-observer 任务 |
| **可行性** | 🟢 **可行** — 但同样需要 cron/外部进程做实际的任务创建 |
| **风险** | `reason` 是自由文本，关键词匹配有漏报/误报风险 |

---

## 3. 可行性矩阵汇总

| R-ID | 增量需求 | 可行性 | 实现路径 | 关键约束/风险 |
|------|---------|--------|---------|--------------|
| R3 | 项目级 profile override | 🟡 | 项目级 plugin + `pre_llm_call` 注入 / `AGENTS.md` | 无法覆盖 model/provider 核心配置 |
| R4 | Worktree 回收 | 🟡 | `on_session_end` + 外部 cron 兜底 | SIGKILL 时 hook 不触发 |
| R5 | 背压 | 🟡 | Cron job 监控队列深度 | 无官方 Dispatcher 控制接口 |
| R6 | Risk Policy YAML | 🟢 | `pre_tool_call` hook 拦截 | 无 |
| R7 | Memory 命名空间 | 🟡 | 自定义 Memory Provider | Single Provider Rule，高侵入 |
| R8 | Reviewer read-only 拦截 | 🟢 | `pre_tool_call` hook 拦截 | Terminal 命令解析复杂度 |
| R9-R18 | 行为契约 | 🟢 | SOUL.md + Skill 配置 | LLM 遵守率非 100% |
| R19 | Observability hooks | 🟢 | `post_tool_call` + `on_session_end` | task_id 可能为空；crash 无数据 |
| R20 | SRE 自动触发 | 🟡 | Cron job 扫描 board | Hook 无法直接创建 kanban 任务 |
| R21 | RCA schema | 🟢 | 纯数据契约 | 无 |
| R22 | 环境快照 | 🟢 | `on_session_start` hook | 需自定义 task_run 关联 |
| R23/R24 | QA/DevOps 故障触发 | 🟢 | `post_tool_call` + cron 消费 | 关键词匹配精度 |

---

## 4. 对 WORKFLOW-EXPLAINED.md 的影响

### 4.1 叙事中必须标注的能力来源

| 叙事内容 | 实际来源 | 标注 |
|---------|---------|------|
| Kanban Board、Dispatcher tick、Worker spawn | Hermes 官方原生 | `[Hermes 官方]` |
| `kanban_*` 工具调用（非 CLI） | Hermes 官方原生 | `[Hermes 官方]` |
| Profile 切换、SOUL.md、Skill 注入 | Hermes 官方原生 | `[Hermes 官方]` |
| Risk Policy 拦截 L3 命令 | Phase 19 增量（Plugin `pre_tool_call`） | `[Phase 19 增量]` |
| Observability trace 采集 | Phase 19 增量（Plugin `post_tool_call`/`on_session_end`） | `[Phase 19 增量]` |
| SRE-Observer 自动创建分析任务 | Phase 19 增量（Cron job + Plugin 观察） | `[Phase 19 增量]` |
| 背压暂停 spawn | Phase 19 增量（外部监控） | `[Phase 19 增量]` |
| Worktree 自动回收 | Phase 19 增量（`on_session_end` + cron 兜底） | `[Phase 19 增量]` |
| Reviewer terminal 写拦截 | Phase 19 增量（Plugin `pre_tool_call`） | `[Phase 19 增量]` |
| Memory 项目/全局命名空间 | Phase 19 增量（自定义 Memory Provider） | `[Phase 19 增量]` |
| 环境快照自动采集 | Phase 19 增量（Plugin `on_session_start`） | `[Phase 19 增量]` |
| 根因报告包含 CI/CD 日志摘要 | 设计假设（需外部 CI 集成） | `[设计假设]` |
| 1 分钟内输出根因报告 | 设计假设（依赖 cron 间隔 + SRE 模型速度） | `[设计假设]` |
| 背压 ratio 阈值（>4 暂停） | 设计假设（参数未官方定义） | `[设计假设]` |
| "审核日志记录决策轨迹" | 设计假设（需自定义审计存储） | `[设计假设]` |

### 4.2 叙事中必须修正的技术错误

1. **Worker 调用方式**: 叙事中任何 `hermes kanban` CLI 命令必须改为 `kanban_show()` / `kanban_complete()` / `kanban_block()` 工具调用
2. **SOUL.md 位置**: 叙事中任何"项目根目录 SOUL.md"必须改为"全局 `~/.hermes/SOUL.md` 或 per-profile `~/.hermes/profiles/<name>/SOUL.md`"；项目特定指令应指向 `AGENTS.md`
3. **SIGSTOP/SIGCONT 休眠**: 叙事中不得呈现为活跃功能（已 deprecated）
4. **Tmux Warm Pool**: 叙事中不得呈现为活跃功能（已 deprecated）
5. **Plugin hook 触发范围**: 需注明在 Worker crash 时 `on_session_end` 不触发，数据可能缺失

### 4.3 叙事中必须增加的 AI 失败模式

每个角色至少展示 1-2 种错误行为：
- **Implementer**: 未发现问题（如 RS256/PSS 问题）、过度自信地自行决定架构选型（未调用 `kanban_block`）
- **Tech-Reviewer**: 遗漏安全问题、产生误报（如认为安全的 random 生成器不安全）
- **Orchestrator**: 任务拆分过细/过粗、依赖关系设错
- **QA-Tester**: 测试覆盖不全、未测试边界条件
- **DevOps-Engineer**: 部署脚本环境变量遗漏、未验证回滚路径
- **SRE-Observer**: 根因归因错误（如将环境问题归因于代码）、confidence 过高但实际错误

### 4.4 叙事中必须增加的人的真实反应

- **延迟响应**: Jacky 在开会/睡觉时收到 block 通知，2 小时后才处理
- **信息过载**: 面对 8 个审查 findings 直接跳过某些项
- **情绪/疲劳**: 第 10 个 block 通知时感到烦躁，草率做决策
- **盲区**: 技术细节看不懂，凭直觉选 A 而非最优解
- **通知疲劳**: 关闭 Gateway 通知，导致重要 block 被忽略

---

## 5. 实施建议

### 5.1 高优先级（🟢 可行且高价值）

1. **R6 Risk Policy Plugin** — 利用 `pre_tool_call` 实现，官方设计目标场景
2. **R8 Reviewer 读保护 Plugin** — 同上，技术风险低
3. **R19 Observability Plugin** — `post_tool_call` + `on_session_end` 官方支持，只需解决 task_id 关联和 crash 场景数据缺失
4. **R9-R18 行为契约** — 纯配置工作，无技术风险

### 5.2 中优先级（🟡 可行但有约束）

5. **R20 SRE 自动触发** — 需要 cron job 架构，非纯 Plugin 可解决
6. **R4 Worktree 回收** — 需要 cron 兜底，正常路径可用 `on_session_end`
7. **R22 环境快照** — 可用 `on_session_start`，但 task_run 关联需自定义
8. **R23/R24 故障关键词触发** — 可用 `post_tool_call` + cron 消费

### 5.3 低优先级/需进一步验证

9. **R3 Profile Override** — 若仅需上下文覆盖，`AGENTS.md` + `pre_llm_call` 足够；若需 model/provider 覆盖，需官方支持或走其他路径
10. **R5 背压** — 需要外部监控进程，架构复杂度较高，建议延后或简化
11. **R7 Memory 命名空间** — Single Provider Rule 限制高，建议评估是否真的需要替换官方 Memory 系统，或仅在 `AGENTS.md` / SOUL.md 层面做命名空间约定

### 5.4 Phase 0 验证建议

在 ce-plan 前必须验证：
- [ ] Plugin 在 Kanban Worker 进程中是否被加载（spawn 方式决定）
- [ ] `HERMES_KANBAN_TASK` env var 在 `post_tool_call` 中是否可通过 `task_id` 获取
- [ ] `on_session_end` 在 Worker 正常完成时是否触发（预期：是）
- [ ] `on_session_end` 在 Worker 被 SIGTERM 时是否触发（预期：可能否）
- [ ] `pre_tool_call` 的 block 行为在 Worker 中是否生效（预期：是）
