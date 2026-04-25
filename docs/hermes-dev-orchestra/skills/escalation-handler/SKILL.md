---
name: escalation-handler
description: 处理从Claude Supervisor升级的危险决策请求：评估风险等级、向用户请求最终决策、执行用户指令并记录审计日志
version: 2.0.0
metadata:
  hermes:
    tags: [escalation, risk-management, user-approval, audit]
    category: autonomous-ai-agents
    requires_version: ">=0.10.0"
---

# Escalation Handler Skill

## When to Use

当 `escalation.md` 文件被创建时触发，用于：
- 评估升级请求的风险等级
- 向用户（通过 Remote Decision Channel 或 SSH/local fallback）请求最终决策
- 记录所有升级和决策的审计日志
- 执行用户批准后的操作
- 拒绝执行用户未批准的危险操作

## Role Definition

你在本技能中的角色是 **"风险守门员 / Risk Gatekeeper"**：
- 你是 Claude Code 和 Codex 与用户之间的最后防线
- 你的职责是确保用户完全理解风险后再做决策
- 你无权自行批准任何危险操作
- 所有决策必须有明确记录，支持事后审计

## Escalation Risk Levels

| 等级 | 标识 | 示例 | 响应时间 |
|------|------|------|---------|
| L1 | 注意 (Notice) | 引入新依赖、修改构建脚本 | 异步通知 |
| L2 | 警告 (Warning) | 修改数据库 schema、删除旧 API | 5 分钟内响应 |
| L3 | 危险 (Danger) | 系统级命令、修改认证逻辑 | 立即响应 |
| L4 | 紧急 (Critical) | 删除生产数据、修改密钥 | 阻塞直到用户确认 |

## Procedure

### 1. 检测升级请求

监控 `escalation.md` 文件：

```bash
# 通过 inotify 或轮询检测
timeout 30 inotifywait -q -e create,modify /tmp/hermes-orchestra/{project}/escalation.md 2>/dev/null || true

# 读取升级内容
read_file(file_path="/tmp/hermes-orchestra/{project}/escalation.md")
```

### 2. 风险分析

自动分析升级内容，确定风险等级：

```python
# execute_code 中运行风险分析
risk_keywords = {
    "CRITICAL": ["rm -rf /", "DROP TABLE", "DELETE FROM", "TRUNCATE", "sudo", "chmod 777"],
    "DANGER": ["docker system prune", "kubectl delete", "ALTER TABLE DROP", "修改 .env"],
    "WARNING": ["npm install", "pip install", "添加依赖", "修改 package.json"],
    "NOTICE": ["修改 README", "更新文档", "格式化代码"]
}
```

### 3. 用户决策请求

根据风险等级选择通知方式；具体远程传输保持抽象，未配置时使用本地 `orch-decisions` / `orch-approve` / `orch-reject`：

**L1-L2（异步）：**

```bash
send_message(action="send", target="{remote-channel}", message="【项目 {project}】操作通知\n\n{escalation_summary}\n\n风险等级：{level}")
```

**L3-L4（阻塞，必须立即确认）：**

```
clarify(
    question="【紧急】项目 {project} 需要您的立即决策\n\n{escalation_content}\n\n⚠️ 此操作可能：{potential_impact}\n\n请确认：",
    choices=[
        "🔴 批准执行 - 我已了解风险并确认执行",
        "🟡 需要修改 - 我想调整执行范围",
        "🟢 拒绝 - 取消此操作，保持现状"
    ]
)
```

可同时发送紧急通知：

```bash
send_message(
    action="send",
    target="{remote-channel}",
    message="🚨【紧急决策请求】🚨\n\n项目：{project}\n类型：{escalation_type}\n\n{summary}\n\n请立即通过远程通道或 SSH/local fallback 回复确认。"
)
```

### 4. 决策执行与审计

用户决策后：

**批准执行：**

```bash
# 1. 记录审计 JSONL
terminal(command="orch-approve {approval_id} '{user_decision}'")

# 2. 将批准结果写入 claude-decision.md
terminal(command="cat > /tmp/hermes-orchestra/{project}/claude-decision.md << 'EOF'
## Decision: APPROVED (by User via Hermes)
### Authority: User Final Approval
### Escalation Level: {level}
### Condition: {any_conditions}

Proceed with execution.
EOF")

# 3. 通知 Claude 和 Codex 继续执行
terminal(command="tmux send-keys -t hermes-{project}-claude '用户已批准，继续执行' Enter")
terminal(command="tmux send-keys -t hermes-{project}-codex '用户已批准，继续执行' Enter")
```

**拒绝执行：**

```bash
# 1. 记录审计 JSONL
terminal(command="orch-reject {approval_id} '{user_decision}'")

# 2. 写入拒绝决策
terminal(command="cat > /tmp/hermes-orchestra/{project}/claude-decision.md << 'EOF'
## Decision: REJECTED (by User via Hermes)
### Authority: User Final Denial
### Reason: {user_reason}

Stop execution immediately. Revert any partial changes if possible.
EOF")

# 3. 通知停止
terminal(command="tmux send-keys -t hermes-{project}-codex '/exit' Enter")
terminal(command="tmux send-keys -t hermes-{project}-claude '/exit' Enter")
```

### 5. 超时处理

如果用户在指定时间内未响应：

```bash
# L1: 30 分钟后默认批准
# L2: 15 分钟后提醒一次，30 分钟后默认拒绝
# L3-L4: 阻塞直到响应，不自动处理

# 超时默认拒绝（仅 L2）
terminal(command="cat > /tmp/hermes-orchestra/{project}/claude-decision.md << 'EOF'
## Decision: REJECTED (Timeout - No user response)
### Authority: Hermes Auto-Reject (L2 timeout policy)
### Reason: User did not respond within 30 minutes.

Execution cancelled for safety.
EOF")
```

## Pitfalls

- **不要**在消息平台中使用 `clarify` 的 5th "Other" 选项处理危险操作——用户可能输入模糊的指令
- **必须**区分 "Claude 的决策" 和 "用户的最终决策"——Claude 无权批准 L3-L4 操作
- 审计日志位于 `~/.local/share/hermes-orchestra/{project}/audit.jsonl`，字段包括 `timestamp`, `level`, `project`, `type`, `decision`, `user_decision`, `details`, `approval_id`, `ttl`, `task_id`, `escalation_id`, `agent_source`, `session_id`
- Remote Decision Channel 消息可能有长度限制，长内容需要分段发送
- 如果用户通过远程通道回复但 Hermes 处于 SSH CLI 模式，需要确保消息路由正确
- 绝不要在没有明确用户确认的情况下，自动批准任何标记为 DANGER 或 CRITICAL 的操作

## Verification

确认升级处理流程：

```bash
# 1. 检查审计日志存在
terminal(command="ls -la ~/.local/share/hermes-orchestra/{project}/audit.jsonl")

# 2. 测试写入权限
terminal(command="orch-audit {project} --limit 1")

# 3. 验证 Remote Decision Channel 连接（如已配置）
send_message(action="list")
```

## Appendix: 审计日志格式

```
2026-04-24T10:30:00+08:00 | APPROVED | project-a | SECURITY | User: 批准执行
Details: 需要修改 JWT 密钥轮换策略
---
2026-04-24T10:35:00+08:00 | REJECTED | project-b | DATA_LOSS | User: 拒绝
Details: 删除用户数据表请求过于危险
---
```
