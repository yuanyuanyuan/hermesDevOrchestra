---
name: codex-executor
description: 作为Codex CLI的执行者技能：接收编码任务、执行开发工作、遇到疑问时暂停并写入问题文件、完成后输出结果
version: 2.0.0
metadata:
  hermes:
    tags: [codex, executor, coding, full-auto]
    category: autonomous-ai-agents
    requires_version: ">=0.10.0"
---

# Codex Executor Skill

## When to Use

当需要以 Codex CLI 作为实际编码执行者时，用于：
- 实现具体功能代码
- 编写测试用例
- 执行重构任务
- 修复 Bug
- 生成文档

## Role Definition

你在本技能中的角色是 **"全栈开发工程师"**：
- 你的职责是高效、准确地实现给定的编码任务
- 你必须遵循项目的技术栈和规范
- 遇到不确定的问题时，必须暂停并向上级（Claude Supervisor）提问
- 你无权自行决定：架构变更、安全策略、API 设计方向、依赖引入

## Procedure

### 1. 启动执行环境

Codex 在 tmux 会话中以 `exec --full-auto` 模式运行：

```bash
# 方式一：直接 codex exec（推荐用于明确任务）
terminal(
    command="cat \"$RUNTIME_DIR/task.md\" | codex exec --full-auto --json --output-last-message \"$RUNTIME_DIR/codex-result.md\" -",
    background=true,
    pty=true,
    notify_on_complete=true,
)
```

```bash
# 方式二：tmux 持久会话（推荐用于多轮交互任务）
terminal(
    command="tmux new-session -d -s hermes-{project}-codex -x 180 -y 40 'cd {project_dir} && codex exec --full-auto --json'",
    background=true,
    pty=true,
    notify_on_complete=false,
)
```

**关键参数说明：**
- `--full-auto`：自动批准文件编辑和命令执行（在 workspace-write sandbox 内）
- `--json`：输出 JSON Lines，便于后续解析
- `--output-last-message "$RUNTIME_DIR/codex-result.md"`：将最终 JSON envelope 写入 Runtime bus
- `-C {project_dir}`：设置工作目录
- `--ephemeral`：不保存会话文件（可选）
- `--model gpt-5.3-codex`：指定 Codex 专用模型（更快更便宜）
- `--model gpt-5.4`：对于复杂任务使用更强的模型

### 2. 接收任务并执行

任务通过 `task.md` 文件传递：

```bash
# 读取任务文件
read_file(file_path="/tmp/hermes-orchestra/{project}/task.md")
```

任务执行 checklist：

- [ ] 读取并理解 `task.md` 中的所有需求
- [ ] 检查项目技术栈（package.json, requirements.txt, Cargo.toml 等）
- [ ] 运行现有测试，确认基线状态
- [ ] 实现功能代码
- [ ] 编写/更新测试用例
- [ ] 运行测试验证
- [ ] 检查代码规范和类型检查
- [ ] 写入结果到 `codex-result.md`

### 3. 遇到疑问时的暂停协议

当 Codex 遇到以下情况时，**必须暂停执行并写入 `codex-question.md`**：

- 任务需求存在歧义或冲突
- 需要选择技术方案但不确定最佳选项
- 发现现有代码与任务需求存在矛盾
- 需要修改非代码文件（配置、文档、CI/CD）
- 发现潜在的安全问题或性能瓶颈
- 预估工作量超出任务描述范围

写入疑问文件：

```bash
terminal(command="cat > /tmp/hermes-orchestra/{project}/codex-question.md << 'EOF'
{
  \"schema_version\": \"1.0\",
  \"message_id\": \"msg-{uuid}\",
  \"project_id\": \"{project}\",
  \"task_id\": \"{task_id}\",
  \"correlation_id\": \"{correlation_id}\",
  \"status\": \"question\",
  \"author\": \"codex\",
  \"authority\": \"executor\",
  \"timestamp\": \"{iso8601}\",
  \"body\": {
    \"question\": \"{clear_question_description}\",
    \"options\": [\"{option_1}\", \"{option_2}\", \"{option_3}\"],
    \"context\": {
      \"current_file\": \"{file_being_edited}\",
      \"related_files\": [\"{related_file}\"]
    },
    \"urgency\": \"BLOCKING\"
  }
}
EOF")

# 暂停 Codex 执行（等待决策）
# 在 tmux 模式下，Codex 会等待新的输入
# 在 background 模式下，通知 Hermes 处理
```

### 4. 写入执行结果

任务完成或部分完成后，写入 `codex-result.md`：

```bash
terminal(command="cat > /tmp/hermes-orchestra/{project}/codex-result.md << 'EOF'
{
  \"schema_version\": \"1.0\",
  \"message_id\": \"msg-{uuid}\",
  \"project_id\": \"{project}\",
  \"task_id\": \"{task_id}\",
  \"correlation_id\": \"{correlation_id}\",
  \"status\": \"completed\",
  \"author\": \"codex\",
  \"authority\": \"executor\",
  \"timestamp\": \"{iso8601}\",
  \"body\": {
    \"summary\": \"{what_was_done}\",
    \"files_modified\": [{\"path\": \"{file_path}\", \"change\": \"{change_description}\"}],
    \"tests\": {\"status\": \"PASSED\", \"commands\": [\"{test_command}\"]},
    \"known_issues\": [],
    \"next_steps\": [\"{suggested_next_task}\"]
  }
}
EOF")
```

### 5. 从 Claude Supervisor 接收决策

当 `claude-decision.md` 更新后，读取并继续执行：

```bash
# 监控决策文件
terminal(command="inotifywait -q -e modify /tmp/hermes-orchestra/{project}/claude-decision.md 2>/dev/null || sleep 5")

# 读取决策
read_file(file_path="/tmp/hermes-orchestra/{project}/claude-decision.md")
```

如果决策是 `APPROVED`，继续执行。
如果决策是 `REJECTED`，回滚已做的修改（如果有），写入失败原因。
如果决策是 `NEEDS_MODIFICATION`，按修改意见调整后重新执行。

## Pitfalls

- Codex CLI **必须在 git 仓库内运行**，非 git 目录会被拒绝。确保执行前 `git init`
- `--full-auto` 默认在受限 sandbox 中运行；如果任务需要网络或更宽权限，先写入 `codex-question.md` 请求 Claude/Hermes 决策，不要在执行技能里自行扩大权限。
- 不要对生产数据库使用 Codex，sandbox 不保护数据库连接
- JSON 输出模式下，`stderr` 是进度流，`stdout` 是最终结果。不要混淆
- Codex 的 `--dangerously-bypass-approvals-and-sandbox` 仅用于完全隔离的 CI 环境，**绝不要**在开发环境使用
- 如果任务涉及多轮对话，tmux 模式比 background 模式更可靠

## Verification

确认执行环境就绪：

```bash
# 1. 验证 Codex CLI 安装
codex --version

# 2. 验证在 git 仓库内
git rev-parse --git-dir

# 3. 验证有 API Key
echo $OPENAI_API_KEY | head -c 10

# 4. 测试简单任务
echo 'print("Hello from Codex")' | codex exec --full-auto "运行这段代码"
```

## Appendix: Codex 模型选择指南

| 模型 | 适用场景 | 速度 | 成本 |
|------|---------|------|------|
| `gpt-5.3-codex` | 日常编码、小功能、重构 | 快 | 低 |
| `gpt-5.3-codex-spark` | 快速原型、探索性编码 | 最快 | 最低 |
| `gpt-5.4` | 复杂算法、架构设计 | 中等 | 中 |
| `gpt-5.4-mini` | 小改动、文档生成 | 快 | 低 |
| `gpt-5.5` | 高难度任务、深度调试 | 慢 | 高 |

默认推荐：`gpt-5.3-codex`（均衡性价比）
