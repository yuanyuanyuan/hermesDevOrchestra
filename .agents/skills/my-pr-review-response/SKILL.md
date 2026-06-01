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

- **优先：GitHub MCP 工具可用** — 当前环境已注册 `mcp__github__*` 系列工具（`get_pull_request`、`get_pull_request_reviews`、`get_pull_request_comments`、`get_pull_request_files`、`add_issue_comment` 等）
- **降级：`gh` CLI 已认证** — 当 MCP 不可用时降级使用
- 当前目录为项目本地仓库
- 具有 `pull_requests:write` 权限的 GitHub Token（gh CLI 降级路径需要）
- **隔离机制：Feature Branch 模式** — 在当前仓库内通过分支切换完成工作，不创建 git worktree

---

## 执行流程

### Phase 1: 情报收集

**优先路径 — GitHub MCP（推荐）：**

1. 获取 PR 元数据：
   ```
   mcp__github__get_pull_request(owner, repo, pull_number)
   ```
   提取：`number`, `title`, `user.login`, `head.ref`, `head.sha`, `changed_files`, `additions`, `deletions`

2. 获取 reviews（含 REQUEST_CHANGES body）：
   ```
   mcp__github__get_pull_request_reviews(owner, repo, pull_number)
   ```
   提取：`id`, `state`, `user.login`, `body`, `submitted_at`

3. 获取 review inline comments（代码行级）：
   ```
   mcp__github__get_pull_request_comments(owner, repo, pull_number)
   ```
   提取：`id`, `user.login`, `path`, `line`, `body`, `diff_hunk`

4. 获取变更文件列表：
   ```
   mcp__github__get_pull_request_files(owner, repo, pull_number)
   ```
   提取：`filename`, `status`, `additions`, `deletions`

5. PR issue comments（通用评论区）：
   > MCP 暂无直接获取 issue comments 的工具，使用 gh CLI 降级：
   > ```bash
   > OWNER=$(gh repo view --json owner --jq '.owner.login')
   > REPO=$(gh repo view --json name --jq '.name')
   > ISSUE_COMMENTS=$(gh api "repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments" \
   >   --jq '[.[] | {id: .id, user: .user.login, body: .body, created_at: .created_at}]')
   > ```

> **MCP 降级判断：** 如果 MCP 调用返回错误、超时或环境未注册 MCP 工具，整体降级到 gh CLI 路径。

**降级路径 — gh CLI：**
```bash
CONTEXT=$(bash scripts/collect-review-context.sh ${PR_NUMBER})
```
脚本输出 JSON，包含：PR 元数据、reviews、review inline comments、PR issue comments、变更文件列表。

**读取 review 意见的三个来源**（见 `reference/review-comment-sources.md`）：
1. Review Body — `state == "CHANGES_REQUESTED"` 的 body，提取问题清单
2. Review Comments — reviewer 在 diff 上的 inline 评论
3. Issue Comments — PR 评论区的补充讨论

**从三个来源合并提取问题清单**，去重后进入 Phase 2。

### Step 0 — 保存当前工作上下文（Feature Branch 安全模式）

**获取 PR 分支名（优先 MCP）：**
若 Phase 1 使用 MCP 路径，从 PR 结果中提取：
```bash
BRANCH=$(echo "$PR" | jq -r '.head.ref')
```
> MCP 不可用时：`BRANCH=$(gh pr view "$PR_NUMBER" --json headRefName --jq '.headRefName')`

**执行 checkout：**
```bash
bash scripts/checkout-branch.sh ${PR_NUMBER} "${BRANCH}"
```

`checkout-branch.sh` 内部自动完成：
1. 记录原分支名
2. 如有未提交更改则自动 `git stash push`
3. `git fetch origin` 并 `git checkout` PR 分支
4. 输出 JSON：`{branch, original_branch, stashed}`

> **如果 Phase 1 MCP/脚本 失败** → 报告 `tool-unavailable` blocker。
> **如果 `checkout-branch.sh` 失败** → 报告 blocker（脚本内部已处理 stash，无需手动重试）。

### Phase 2: 逐项审查

对合并后的问题清单中的每个发现项：

**1. 理解意见：**
- 引用 reviewer 原文（含来源、文件路径、行号）
- 读取相关上下文（diff hunk、PR 讨论）
- 判断类型：`bug` / `style` / `architecture` / `doc` / `test`

**2. 排查验证：**
```
/diagnose ${FILE_PATH}:${LINE_NUM} "${ISSUE_DESCRIPTION}"
```
传入文件路径、行号和问题描述，逐项检查代码是否确实存在所述问题，运行测试验证，记录证据。

**3. 决策**（见 `reference/decision-tree.md`）：
- **AGREE** → Phase 3
- **DISAGREE** → Phase 4

> 🔴 **CHECKPOINT**：处理完所有 review 意见后，生成 AGREE/DISAGREE 决策清单，**向用户展示并确认**后再进入修复/反驳流水线。
> 🛑 **STOP**：如有任何意见你无法判断，暂停并询问用户，不要自主猜测。

> **如果 `/diagnose` 命令不可用** → 手动读取相关代码和测试文件，人工验证问题是否存在 → 仍无法判断则暂停询问用户。

### Phase 3: 修复流水线

对每条 AGREE 的意见：

**步骤 A — TDD 修复：**
```
/tdd --file ${FILE_PATH} --issue "${ISSUE_SUMMARY}"
```
指定目标文件和问题摘要，先写失败测试复现问题，再修复代码使测试通过。确保精确对应 review 意见，遵循最小改动原则。

**步骤 B — 验证：**
- 运行完整测试套件确认无回归
- 读取修改后的代码确认问题已消除

**步骤 C — 发 PR Comment（优先 MCP）：**

使用**双层格式**撰写修复 comment（外层 Markdown + 内层 `AGENT_META` JSON）：

```bash
cat > /tmp/pr-fix-${PR_NUMBER}-${ITEM_ID}.md << 'EOF'
<!--AGENT_META:{"type":"review_fix","version":"1.0","pr_number":${PR_NUMBER},"item_id":"${ITEM_ID}","file":"${FILE_PATH}","line":${LINE_NUM},"status":"fixed","commit":"$(git rev-parse HEAD)"}-->

✅ **Fixed** — \`${FILE_PATH}:${LINE_NUM}\`

> **Original Issue:** ${ISSUE_SUMMARY}

**Change Summary:** ${CHANGE_SUMMARY}

<details>
<summary>View Diff</summary>

\`\`\`diff
${DIFF_SNIPPET}
\`\`\`
</details>

**Verification:** ${VERIFICATION_RESULT}

Commit: \`$(git rev-parse HEAD)\`
EOF

# 优先使用 MCP
mcp__github__add_issue_comment(
  owner=${OWNER},
  repo=${REPO},
  issue_number=${PR_NUMBER},
  body=$(cat /tmp/pr-fix-${PR_NUMBER}-${ITEM_ID}.md)
)
```

> **降级路径（gh CLI）：**
> ```bash
> bash scripts/post-comment.sh ${PR_NUMBER} /tmp/pr-fix-${PR_NUMBER}-${ITEM_ID}.md
> ```

> **部分修复变体：** 若无法完全修复，将 `status` 改为 `"partially_fixed"`，标题 emoji 改为 🟡，在正文中说明未覆盖部分的原因。

**步骤 D — 提交：**
```bash
git add . && git commit -m "fix(review): ${BRIEF_DESC}" && git push origin ${BRANCH}
```

> 🔴 **CHECKPOINT**：**提交并 push 前，向用户展示修改摘要**（修改了哪些文件、核心变更点），确认后再执行。

> **如果 `/tdd` 修复后测试仍失败** → 检查失败是否与 review 意见相关 → 若无关则触发 `test-env-conflict` 止损。

### Phase 4: 反驳流水线

对每条 DISAGREE 的意见，必须满足反驳门槛（见 `reference/decision-tree.md`）：

**撰写并发送反驳（优先 MCP）：**

使用**双层格式**撰写反驳 comment（外层 Markdown + 内层 `AGENT_META` JSON）：

```bash
cat > /tmp/pr-counter-${PR_NUMBER}-${ITEM_ID}.md << 'EOF'
<!--AGENT_META:{"type":"review_counter","version":"1.0","pr_number":${PR_NUMBER},"item_id":"${ITEM_ID}","file":"${FILE_PATH}","line":${LINE_NUM},"status":"disagreed","reason_type":"${REASON_TYPE}"}-->

❌ **Disagreed** — \`${FILE_PATH}:${LINE_NUM}\`

> **Original Issue:** ${ISSUE_SUMMARY}

**Reason:** ${COUNTER_REASON}

<details>
<summary>Evidence & Context</summary>

${EVIDENCE_LIST}
</details>

**Alternative (if applicable):** ${ALTERNATIVE_SUGGESTION}

Please re-consider this feedback.
EOF

# 优先使用 MCP
mcp__github__add_issue_comment(
  owner=${OWNER},
  repo=${REPO},
  issue_number=${PR_NUMBER},
  body=$(cat /tmp/pr-counter-${PR_NUMBER}-${ITEM_ID}.md)
)
```

> **降级路径（gh CLI）：**
> ```bash
> bash scripts/post-comment.sh ${PR_NUMBER} /tmp/pr-counter-${PR_NUMBER}-${ITEM_ID}.md
> ```

> **证据列表格式：**
> ```markdown
> - **Code Evidence:** ${CODE_SNIPPET_OR_LINK}
> - **Doc Reference:** [Link](...) — ${QUOTE}
> - **Test Evidence:** ${TEST_RESULT}
> - **Architecture Reason:** ${ARCH_EXPLANATION}
> ```

> **如果反驳证据不足**（不满足门槛任一条）→ 转 AGREE 处理，不可强行反驳。

### Phase 5: 最终交付

全部意见处理完毕后：

**步骤 A — 生成汇总报告：**
先向用户展示报告内容。

🔴 **CHECKPOINT**：**发送 PR Comment 前，向用户展示完整响应清单**（每条意见的决策+状态），确认无误后再执行步骤 B。

**步骤 B — 发送 PR Comment（优先 MCP）：**

使用**双层格式**撰写汇总 comment：

```bash
cat > /tmp/pr-summary-${PR_NUMBER}.md << 'EOF'
<!--AGENT_META:{"type":"review_response_summary","version":"1.0","pr_number":${PR_NUMBER},"responder":"stark-007","commit":"$(git rev-parse HEAD)","agree_count":${AGREE_COUNT},"disagree_count":${DISAGREE_COUNT},"total_count":${TOTAL_COUNT},"items":[${ITEMS_JSON_ARRAY}]}-->

## 📋 Review Response Summary — PR #${PR_NUMBER}

All review comments have been addressed. Latest commit: \`$(git rev-parse HEAD)\`

### ✅ Fixed (${AGREE_COUNT})

| # | Issue | File | Commit |
|---|-------|------|--------|
| 1 | ${ISSUE_1} | \`${FILE_1}:${LINE_1}\` | \`${COMMIT_1}\` |
| ... | ... | ... | ... |

### ❌ Disagreed (${DISAGREE_COUNT})

| # | Issue | File | Reason |
|---|-------|------|--------|
| 1 | ${ISSUE_1} | \`${FILE_1}:${LINE_1}\` | ${REASON_1} |
| ... | ... | ... | ... |

---

**Please re-review.** 🙏
EOF

# 优先使用 MCP
mcp__github__add_issue_comment(
  owner=${OWNER},
  repo=${REPO},
  issue_number=${PR_NUMBER},
  body=$(cat /tmp/pr-summary-${PR_NUMBER}.md)
)
```

> **降级路径（gh CLI）：**
> ```bash
> bash scripts/post-comment.sh ${PR_NUMBER} /tmp/pr-summary-${PR_NUMBER}.md
> ```

> **部分修复变体：** 若存在 `partially_fixed` 项，在 ✅ Fixed 和 ❌ Disagreed 之间增加独立分组：
> ```markdown
> ### 🟡 Partially Fixed (1)
>
> | # | Issue | File | Status |
> |---|-------|------|--------|
> | 3 | Add input validation | `src/api.py:78` | 5/6 endpoints covered |
> ```

> **如果 MCP/gh 提交失败** → 重试一次 → 仍失败则提示用户手动发送汇总评论。

**步骤 C — 恢复工作上下文：**

```bash
bash scripts/return-to-original-branch.sh ${PR_NUMBER}
```

`return-to-original-branch.sh` 内部自动完成：
1. 读取 Step 0 保存的原分支名
2. `git checkout` 回原分支
3. 如有自动 stash 则 `git stash pop`
4. 清理临时标记文件

> 🔴 **CHECKPOINT**：**恢复分支前确认所有 commit 已 push**，避免丢失修改。

---

## 约束与止损

硬性约束和边界见 `reference/constraints.md`。

**止损条件（触发条件 / 一线修复 / 仍失败兜底）：**

| 触发条件 | 一线修复 | 仍失败兜底 |
|---------|---------|-----------|
| GitHub MCP 不可用且 `gh` CLI 未认证 | 检查 MCP 注册状态 / `gh auth status` | 报告 `tool-unavailable` blocker，停止执行 |
| 修复后测试持续失败 3 次 | 检查失败是否与 review 意见相关 | 报告 `test-env-conflict` blocker |
| reviewer 意见自相矛盾 | 在 PR Comment 中请求澄清 | 报告 `contradictory-review` blocker |
| 无法解析出明确问题清单 | 尝试手动读取 review body 和 comments | 报告 `unclear-review` blocker |

---

## 反例与黑名单

| 不要做 | 正确做法 |
|--------|---------|
| 未验证直接改代码 | 先用 `/diagnose` 验证问题确实存在 |
| 强行反驳无证据 | 证据不足时转 AGREE 处理 |
| 修改 PR 范围外文件 | 严格只修改 PR diff 中的文件 |
| 跳过测试直接 push | 必须运行测试验证后再提交 |
| 自动合并 PR | 只请求 reviewer 重新 review |
| 主观感受式反驳 | 反驳必须有代码/文档/架构证据 |

---

## 参考文档

- `reference/comment-format-guide.md` — Response Comment 双层格式模板规范（Fix / Counter / Summary）
- `reference/review-comment-sources.md` — 三种评论来源说明
- `reference/decision-tree.md` — 处理决策树和反驳门槛
- `reference/constraints.md` — 约束与边界
- `scripts/collect-review-context.sh` — 情报收集（reviews + inline comments + issue comments）
- `scripts/post-comment.sh` — 发送 PR 评论
- `scripts/checkout-branch.sh` — checkout PR 分支（含自动 stash / 保存原分支）
- `scripts/return-to-original-branch.sh` — 恢复原始分支与 stash
