---
name: my-pr-review-response
description: >
  作为 PR 发起人处理所有 review 意见：逐项审查、逐条修复或反驳、
  以 PR Comment 方式发送修复结果和反驳说明，提交代码、生成响应汇总报告，并请求 reviewer 重新 review。
  发起人身份：stark-007。
---

# PR Review Response Skill

## 触发条件

- "respond to review" / "address review comments"
- "处理 review 意见" / "修复 PR review 问题" / "回复 PR review"
- 任何涉及对已收到 review 意见进行响应的请求

## 调用签名

```
my-pr-review-response <PR_NUMBER>
```

## 环境要求

- `gh` CLI 已认证
- 当前目录为项目本地仓库
- 具有 `pull_requests:write` 权限的 GitHub Token

---

## 执行流程

### Phase 1: 情报收集

```bash
CONTEXT=$(bash scripts/collect-review-context.sh ${PR_NUMBER})
```

脚本输出 JSON，包含：PR 元数据、reviews（含 REQUEST_CHANGES body）、review inline comments（代码行级评论）、PR issue comments、变更文件列表。

**读取 review 意见的三个来源**（见 `reference/review-comment-sources.md`）：
1. Review Body — `state == "CHANGES_REQUESTED"` 的 body，提取问题清单
2. Review Comments — reviewer 在 diff 上的 inline 评论
3. Issue Comments — PR 评论区的补充讨论

**从三个来源合并提取问题清单**，去重后进入 Phase 2。

```bash
bash scripts/checkout-branch.sh ${PR_NUMBER}
```

### Phase 2: 逐项审查（需要智力判断）

对合并后的问题清单中的每个发现项：

**1. 理解意见：**
- 引用 reviewer 原文（含来源、文件路径、行号）
- 读取相关上下文（diff hunk、PR 讨论）
- 判断类型：`bug` / `style` / `architecture` / `doc` / `test`

**2. 排查验证：**
```
/diagnose
```
使用 /diagnose 命令逐项检查当前代码是否确实存在所述问题，运行相关测试验证，记录证据。

**3. 决策**（见 `reference/decision-tree.md`）：
- **AGREE** → Phase 3
- **DISAGREE** → Phase 4

> 🔴 **CHECKPOINT**：处理完所有 review 意见后，生成 AGREE/DISAGREE 决策清单，**向用户展示并确认**后再进入修复/反驳流水线。
> 🛑 **STOP**：如有任何意见你无法判断，暂停并询问用户，不要自主猜测。

### Phase 3: 修复流水线（需要智力判断）

对每条 AGREE 的意见：

**步骤 A — TDD 修复：**
```
/tdd
```
使用 /tdd 命令进行测试驱动修复：先写失败测试复现问题，再修复代码使测试通过。确保修复精确对应 review 意见，遵循最小改动原则。

**步骤 B — 验证：**
- 运行完整测试套件确认无回归
- 读取修改后的代码确认问题已消除

**步骤 C — 发 PR Comment：**
```bash
cat > /tmp/pr-fix-${PR_NUMBER}-${ITEM_ID}.md << 'EOF'
✅ 已修复 review 意见。

**文件**: ${FILE_PATH}:${LINE_NUM}
**问题**: ${ISSUE_SUMMARY}
**修改内容**: ${CHANGE_SUMMARY}
**验证**: 测试通过
**Commit**: $(git rev-parse HEAD)
EOF

bash scripts/post-comment.sh ${PR_NUMBER} /tmp/pr-fix-${PR_NUMBER}-${ITEM_ID}.md
```

**步骤 D — 提交：**
```bash
git add . && git commit -m "fix(review): ${BRIEF_DESC}" && git push origin ${BRANCH}
```

> 🔴 **CHECKPOINT**：**提交并 push 前，向用户展示修改摘要**（修改了哪些文件、核心变更点），确认后再执行。

### Phase 4: 反驳流水线（需要智力判断）

对每条 DISAGREE 的意见，必须满足反驳门槛（见 `reference/decision-tree.md`）：

**撰写并发送反驳：**
```bash
cat > /tmp/pr-counter-${PR_NUMBER}-${ITEM_ID}.md << 'EOF'
❌ 不同意此 review 意见。

**文件**: ${FILE_PATH}:${LINE_NUM}
**问题**: ${ISSUE_SUMMARY}

**理由**: ${COUNTER_REASON}
**证据**: ${EVIDENCE}

请 reviewer 重新考虑。
EOF

bash scripts/post-comment.sh ${PR_NUMBER} /tmp/pr-counter-${PR_NUMBER}-${ITEM_ID}.md
```

### Phase 5: 最终交付

全部意见处理完毕后：

**步骤 A — 生成汇总报告：**
先向用户展示报告内容。

🔴 **CHECKPOINT**：**发送 PR Comment 前，向用户展示完整响应清单**（每条意见的决策+状态），确认无误后再执行步骤 B。

**步骤 B — 发送 PR Comment：**

```bash
cat > /tmp/pr-summary-${PR_NUMBER}.md << 'EOF'
## Review Response Summary — PR #${PR_NUMBER}

所有 review 意见已处理完毕：

| 问题 | 文件:行号 | 决策 | 状态 |
|------|-----------|------|------|
| ... | ... | AGREE/DISAGREE | 已修复/已反驳 |

请 reviewer 重新 review。
EOF

bash scripts/post-comment.sh ${PR_NUMBER} /tmp/pr-summary-${PR_NUMBER}.md
```

---

## 约束与止损

硬性约束和边界见 `reference/constraints.md`。

**止损条件：**
- `gh` CLI 不可用 → 报告 blocker
- 修复后测试持续失败 3 次 → 报告 blocker
- reviewer 意见自相矛盾 → 报告 blocker
- 无法解析出明确问题清单 → 报告 blocker

---

## 参考文档

- `scripts/collect-review-context.sh` — 情报收集（reviews + inline comments + issue comments）
- `scripts/post-comment.sh` — 发送 PR 评论
- `scripts/checkout-branch.sh` — checkout PR 分支
- `reference/review-comment-sources.md` — 三种评论来源说明
- `reference/decision-tree.md` — 处理决策树和反驳门槛
- `reference/constraints.md` — 约束与边界
