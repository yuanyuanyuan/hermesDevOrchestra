---
name: my-pr-review-response
description: >
  作为 PR 发起人处理所有 review threads：逐项审查、逐条修复或反驳、
  在原 thread 下回复、提交代码、生成响应汇总报告，并请求 reviewer 重新 review。
  发起人身份：stark-007。
---

# PR Review Response Skill

## 触发条件

当用户要求以下任一操作时激活本 Skill：
- "respond to review threads"
- "address review comments"
- "处理 review threads"
- "修复 PR review 意见"
- "回复 PR review"
- 任何涉及对已收到 review threads 进行响应的请求

## 调用签名

```
my-pr-review-response <PR_NUMBER>
```

- `PR_NUMBER`: GitHub PR 编号（如 `8`）
- 当前目录必须是项目本地仓库，`gh` 会自动识别所属仓库

## 环境要求

- `gh` CLI 已安装且已认证（`gh auth status` 通过）
- 当前目录 `${REPO_DIR}` 为项目本地仓库
- 本地仓库有 PR 分支的写权限
- 具有 `repo` 或 `pull_requests:write` 权限的 GitHub Token

## 变量定义（每次执行时解析）

执行前将以下占位符替换为实际值：

| 变量 | 来源 |
|------|------|
| `${PR_NUMBER}` | 调用参数 `<PR_NUMBER>` |
| `${OWNER}` | `gh repo view --json owner --jq '.owner.login'` |
| `${REPO}` | `gh repo view --json name --jq '.name'` |
| `${BRANCH}` | `gh pr view ${PR_NUMBER} --json headRefName --jq '.headRefName'` |
| `${REPO_DIR}` | 当前工作目录（`$(pwd)`） |
| `${REVIEW_LOG}` | `/tmp/pr-review-response-${PR_NUMBER}.md` |
| `${THREADS_JSON}` | `/tmp/pr-existing-threads-${PR_NUMBER}.json` |

---

## 执行流程

### 阶段 1：情报收集（INTELLIGENCE GATHERING）

**步骤 A — 读取 PR 元数据**

```bash
cd ${REPO_DIR}
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
BRANCH=$(gh pr view ${PR_NUMBER} --json headRefName --jq '.headRefName')
gh pr view ${PR_NUMBER} --json number,title,body,headRefName,baseRefName,reviewDecision,mergeable
```

**步骤 B — 读取所有 Review Threads**

```bash
gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments \
  --jq '.[] | {id: .id, path: .path, line: .line, body: .body, user: .user.login, in_reply_to_id: .in_reply_to_id, created_at: .created_at}' \
  > ${THREADS_JSON}

# 统计 thread 数量（in_reply_to_id 为 null 的是 thread 起点）
cat ${THREADS_JSON} | jq 'select(.in_reply_to_id == null) | .id' | wc -l
```

**步骤 C — 读取 PR reviews 整体状态**

```bash
gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews \
  --jq '.[] | {id: .id, state: .state, user: .user.login, body: .body}' \
  > /tmp/pr-reviews-${PR_NUMBER}.json
```

**步骤 D — 读取 PR diff 并 checkout 分支**

```bash
gh pr diff ${PR_NUMBER} > /tmp/pr-diff-${PR_NUMBER}.patch
git fetch origin ${BRANCH}
git checkout ${BRANCH}
```

---

### 阶段 2：逐项审查（REVIEW THREAD TRIAGE）

对每个 review thread（以 `in_reply_to_id == null` 的评论为起点），按以下决策树处理：

**1. 理解意见：**
- 引用 thread 原文（含 reviewer 用户名、行号、文件路径）
- 读取该 thread 下的所有回复（如果有后续讨论）
- 判断意见类型：`bug` / `style` / `architecture` / `doc` / `test`

**2. 验证意见：**
- 检查当前代码/文档是否确实存在所述问题
- 如果涉及行为，运行相关测试验证
- 记录验证证据（命令输出、文件片段）

**3. 决策：**
- **同意（AGREE）** → 进入阶段 3 修复流水线
- **不同意（DISAGREE）** → 进入阶段 4 反驳流水线

---

### 阶段 3：修复流水线（AGREE → FIX → REPLY TO THREAD）

对每条同意的 review thread：

**步骤 A — 修复代码**
- 修改对应文件，确保修复精确对应 thread 指出的问题
- 优先采用最小改动原则
- 修复后运行相关测试（对应模块）

**步骤 B — 验证修复**
- 重新读取修改后的代码，确认问题已消除
- 运行完整测试套件（如果涉及核心逻辑）
- 记录验证命令和输出到 `${REVIEW_LOG}`

**步骤 C — 在 Thread 下回复（关键：使用 reply API，不是普通 PR comment）**

```bash
# 获取该 thread 的起点 comment_id（in_reply_to_id == null 的那个）
THREAD_ROOT_ID=$(jq -r --arg path "${FILE_PATH}" --argjson line "${LINE_NUM}" 'select(.path==$path and .line==$line and .in_reply_to_id==null) | .id' ${THREADS_JSON})

# 在该 thread 下回复修复说明
gh api repos/${OWNER}/${REPO}/pulls/comments/${THREAD_ROOT_ID}/replies \
  --method POST \
  --field body="✅ 已修复。\n\n修改内容：${CHANGE_SUMMARY}\n\n验证：${VERIFY_COMMAND} 结果 exit 0。\n\nCommit: $(git rev-parse HEAD)"
```

**步骤 D — 提交代码**

```bash
git add .
git commit -m "fix(review): address review thread on ${FILE_PATH}:${LINE_NUM} — ${BRIEF_DESC}"
git push origin ${BRANCH}
```

**步骤 E — 标记响应**

在 `${REVIEW_LOG}` 中记录：
- Thread ID: `${THREAD_ROOT_ID}`
- 文件:行号: `${FILE_PATH}:${LINE_NUM}`
- 决策：AGREE
- 修复文件及 diff 摘要
- 验证结果
- Reply 链接: `https://github.com/${OWNER}/${REPO}/pull/${PR_NUMBER}#discussion_r${THREAD_ROOT_ID}`

---

### 阶段 4：反驳流水线（DISAGREE → COUNTER → REPLY TO THREAD）

对每条不同意的 review thread，必须满足反驳门槛（缺一不可）：

**反驳门槛检查清单：**
- [ ] 有代码/文档证据：引用现有代码、测试输出、ADR、SPEC 证明当前实现正确
- [ ] 有架构理由：说明为什么 review 建议会破坏设计约束或引入回归
- [ ] 有替代方案：如果 review 指出的问题存在但不是最佳修复方式，提供替代方案

**步骤 A — 撰写反驳**

在 `${REVIEW_LOG}` 中撰写结构化反驳：
```markdown
## Review Thread [ID] on ${FILE_PATH}:${LINE_NUM}
> [引用 reviewer 原文]

### 决策：DISAGREE

### 理由：
1. [证据 1：引用代码/文档/测试输出]
2. [证据 2：引用 ADR/SPEC/架构约束]
3. [如果适用] 替代方案：[描述更优的解决方式]

### 请求：
建议 reviewer 重新考虑，或针对 [具体点] 进一步讨论。
```

**步骤 B — 在 Thread 下回复反驳（关键：使用 reply API）**

```bash
THREAD_ROOT_ID=$(jq -r --arg path "${FILE_PATH}" --argjson line "${LINE_NUM}" 'select(.path==$path and .line==$line and .in_reply_to_id==null) | .id' ${THREADS_JSON})

gh api repos/${OWNER}/${REPO}/pulls/comments/${THREAD_ROOT_ID}/replies \
  --method POST \
  --field body="❌ 不同意此 review 意见。\n\n理由：${COUNTER_REASON}\n\n证据：${EVIDENCE}\n\n请 reviewer 重新考虑。"
```

**步骤 C — 标记响应**

在 `${REVIEW_LOG}` 中记录：
- Thread ID: `${THREAD_ROOT_ID}`
- 文件:行号: `${FILE_PATH}:${LINE_NUM}`
- 决策：DISAGREE
- 反驳证据摘要
- Reply 链接

---

### 阶段 5：最终交付（DELIVERY）

全部 review threads 处理完毕后：

**步骤 A — 生成 Review Response 汇总报告**

将 `${REVIEW_LOG}` 整理，发一条 PR 通用评论（非 thread reply）：

```markdown
## Review Response Summary — PR #${PR_NUMBER}

所有 review threads 已处理完毕：

| Thread | 文件:行号 | 决策 | 状态 |
|--------|-----------|------|------|
| #id1 | path:line | AGREE | 已修复，已回复 thread |
| #id2 | path:line | AGREE | 已修复，已回复 thread |
| #id3 | path:line | DISAGREE | 已反驳，已回复 thread |

- 同意项：N 项，已修复并提交，Commit range: [first-hash..last-hash]
- 不同意项：M 项，理由已回复到对应 thread，请 reviewer 查看
- 待讨论项：K 项，需要 reviewer 进一步澄清

请 reviewer 重新 review。如有需要，可点击 "Re-request review" 按钮。
```

**步骤 B — 请求重新 Review（PR 通用评论 + 标签）**

```bash
gh pr comment ${PR_NUMBER} --body-file /tmp/pr-response-summary-${PR_NUMBER}.md
gh pr edit ${PR_NUMBER} --add-label "awaiting-review"
```

注意：PR 作者无法通过 API 触发 "Re-request review" 按钮（这是 GitHub UI 功能），但可以在评论中 @ 原 reviewer。

**步骤 C — 验证 PR 可合并状态**
- 运行完整测试套件确认无回归
- 确认无未解决的合并冲突
- 确认 CI 状态（如果有）

---

### 阶段 6：约束与边界（CONSTRAINTS）

**硬性约束：**
- 不修改 PR 范围外的文件（仅修复 review thread 涉及的文件）
- 不引入新依赖（除非 review 明确要求且已论证）
- 不重构未 review 的代码（最小改动原则）
- 不自动合并 PR（仅处理 review threads，等待 reviewer 确认）
- 反驳必须有证据，禁止主观感受式反驳
- 必须在原 thread 下回复（使用 reply API），禁止只发普通 PR comment 而不回复 thread

**写权限边界（可修改）：**
- PR diff 中涉及的所有文件
- `${REVIEW_LOG}`
- `/tmp/counter-*.md`
- `/tmp/pr-response-summary-*.md`

**只读边界（禁止写入）：**
- `scripts/lib/orch_gateway.py`（除非 review thread 明确要求修改）
- `config/schemas/orchestra.full.schema.json`（除非 review thread 明确要求修改）
- 其他 Sprint 的配置和测试脚本

---

### 阶段 7：止损条件（BLOCKED STOP）

**立即停止并报告 blocker 的情况：**
- review thread 涉及文件不在当前 PR 中，且无法定位
- 修复后测试持续失败 3 次，且失败与 review 修复无关
- reviewer 意见自相矛盾，无法同时满足
- `gh` CLI 不可用，无法回复 thread 或推送代码
- PR 存在未解决的合并冲突，无法推送修复
- 无法获取 thread 的起点 comment_id（`in_reply_to_id == null` 的评论）

**报告格式（必须包含）：**
- Blocker 类型：`out-of-scope` / `test-env-conflict` / `contradictory-review` / `tool-unavailable` / `merge-conflict` / `thread-lost`
- 涉及的 thread ID / 文件路径 / 行号
- 已尝试的处理方式
- 解锁所需的人类输入
