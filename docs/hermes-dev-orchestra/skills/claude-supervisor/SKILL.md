---
name: claude-supervisor
description: 作为Claude Code CLI的监督者技能：审查Codex输出、做架构决策、处理技术疑问、标记危险操作
version: 2.0.0
metadata:
  hermes:
    tags: [claude-code, supervisor, code-review, decision-maker]
    category: autonomous-ai-agents
    requires_version: ">=0.10.0"
---

# Claude Supervisor Skill

## When to Use

当需要以 Claude Code CLI 作为监督代理时，用于：
- 审查 Codex 的代码输出
- 做技术架构决策
- 回答 Codex 执行中遇到的疑问
- 标记需要升级到 Hermes/用户的高风险操作
- 确保代码质量和项目规范

## Role Definition

你在本技能中的角色是 **"技术主管 / Senior Architect"**：
- 你有权批准或拒绝 Codex 的技术方案
- 你的决策基于代码质量、安全性和项目规范
- 你无权批准：系统级危险操作、产品需求变更、涉及密钥/凭证的操作
- 遇到上述无权批准的事项，必须写入 escalation 文件

## Procedure

### 1. 启动监督会话

Claude Code 以 Print 模式或 tmux 持久会话运行，接收审查任务：

**Print 模式（快速审查）：**
```bash
terminal(command="cat /tmp/hermes-orchestra/{project}/codex-result.md | claude -p '审查这段代码，检查：1.安全性 2.代码规范 3.性能问题。给出明确的批准/修改/拒绝意见。' --output-format json")
```

**tmux 持久会话（复杂决策链）：**
```bash
terminal(command="tmux new-session -d -s hermes-{project}-claude -x 180 -y 40 'cd {project_dir} && claude --permission-mode auto'")
```

### 2. 审查 Codex 输出

读取 Codex 的执行结果：

```bash
read_file(file_path="/tmp/hermes-orchestra/{project}/codex-result.md")
```

审查 checklist（必须逐项确认）：

- [ ] 是否有 SQL 注入、XSS、路径遍历等安全漏洞？
- [ ] 是否引入了新的依赖？依赖是否可信？
- [ ] 是否修改了配置文件或环境变量？
- [ ] 是否符合项目的代码规范（ESLint/Prettier/Black 等）？
- [ ] 是否有足够的错误处理？
- [ ] 是否包含测试用例？
- [ ] 性能是否可接受？（是否有 N+1 查询、内存泄漏等）

### 3. 处理技术疑问

读取 Codex 的疑问：

```bash
read_file(file_path="/tmp/hermes-orchestra/{project}/codex-question.md")
```

决策并写入 `claude-decision.md`：

```bash
terminal(command="cat > /tmp/hermes-orchestra/{project}/claude-decision.md << 'EOF'
## Decision from Claude Supervisor
### Question: {question_summary}

### Decision: [APPROVED / REJECTED / NEEDS_MODIFICATION]

### Rationale:
{detailed_reasoning}

### Implementation Guidance:
{specific_instructions}

### Risk Assessment: [LOW / MEDIUM / HIGH]

### Escalation Required: [YES / NO]
- If YES: {escalation_reason}
EOF")
```

### 4. 升级标记（Escalation）

当遇到以下情况，必须写入 `escalation.md`：

```bash
# 危险操作检查清单
dangerous_patterns = [
    "rm -rf /", "chmod 777", "DROP TABLE", "ALTER TABLE DROP",
    "sudo", "docker system prune", "kubectl delete",
    "修改 package.json 中 scripts 的 preinstall",
    "修改 .env 或密钥文件", "修改 CI/CD 配置文件",
    "破坏性数据库迁移", "API 兼容性变更"
]
```

写入 escalation：

```bash
terminal(command="cat > /tmp/hermes-orchestra/{project}/escalation.md << 'EOF'
## Escalation Request
### Level: [HIGH / CRITICAL]
### Type: [SECURITY / ARCHITECTURE / PRODUCT_IMPACT / DATA_LOSS]

### Description:
{detailed_description_of_the_issue}

### Proposed Action:
{what_codex_wants_to_do}

### Potential Impact:
{impact_analysis}

### Reversible: [YES / NO / WITH_DIFFICULTY]

### Recommended User Action:
{what_you_recommend_user_to_do}

### Timestamp: $(date -Iseconds)
EOF")
```

### 5. 与 Codex 的通信协议

Claude Code 监督者与 Codex 执行者通过文件通信：

**文件格式规范：**
- 所有文件使用 UTF-8 编码
- Markdown 格式，YAML frontmatter 可选
- 状态字段：`PENDING`, `APPROVED`, `REJECTED`, `NEEDS_CLARIFICATION`

**通信时序：**

```
1. Hermes → task.md (写入任务)
2. Codex → codex-question.md (疑问)
3. Claude → claude-decision.md (决策)
4. Codex → codex-result.md (结果)
5. Claude → review-result.md (审查意见)
6. (如有) Claude → escalation.md (升级)
7. Hermes → 读取所有文件并决定下一步
```

## Pitfalls

- **不要**使用 `--dangerously-skip-permissions` 运行监督者 Claude，这会绕过所有安全检查
- **不要**让 Claude Code 直接操作生产环境数据库，必须通过 escalation 升级
- Claude Code 的 Print 模式 (`-p`) 每次启动都是新会话，没有上下文记忆。复杂监督应使用 tmux 持久会话
- Claude Code 的 Agent Teams 是实验性功能（v2.1.32+），不建议生产环境使用
- 如果 Codex 的疑问涉及多个文件的选择，Claude 应该给出明确的优先顺序

## Verification

确认监督流程正常：

```bash
# 1. 检查 Claude Code 进程运行中
terminal(command="tmux ls | grep hermes-{project}-claude")

# 2. 检查决策文件已写入
terminal(command="ls -lt /tmp/hermes-orchestra/{project}/")

# 3. 验证决策格式正确
terminal(command="head -20 /tmp/hermes-orchestra/{project}/claude-decision.md | grep -E 'Decision:|Risk Assessment:|Escalation Required:'")
```
