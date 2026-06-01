---
name: my-pr-review-response
description: >
  作为 PR 发起人处理所有 review 意见：逐项审查、逐条修复或反驳、
  以 PR Comment 方式发送修复结果和反驳说明，提交代码、生成响应汇总报告，并请求 reviewer 重新 review。
  发起人身份：stark-007。
---

# PR Review Response Skill

## 触发条件

当用户要求以下任一操作时激活本 Skill：
- "respond to review"
- "address review comments"
- "处理 review 意见"
- "修复 PR review 问题"
- "回复 PR review"
- 任何涉及对已收到 review 意见进行响应的请求

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
| `${REVIEW_LOG}` | `${REPO_DIR}/.tmp/pr-review-response-${PR_NUMBER}.md` |

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

**步骤 B — 读取 Review 意见**

获取该 PR 上最新的 REQUEST_CHANGES review（提取问题列表）以及所有 PR comments：

```bash
mkdir -p ${REPO_DIR}/.tmp
gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews \
  --jq '.[] | {id: .id, state: .state, body: .body, user: .user.login, submitted_at: .submitted_at}' \
  > ${REPO_DIR}/.tmp/pr-reviews-${PR_NUMBER}.json

gh api repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments \
  --jq '.[] | {id: .id, body: .body, user: .user.login, created_at: .created_at}' \
  > ${REPO_DIR}/.tmp/pr-comments-${PR_NUMBER}.json
```

重点关注 `state == "CHANGES_REQUESTED"` 的 review body 中的发现项清单。

**步骤 C — 读取 PR reviews 整体状态**

```bash
gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews \
  --jq '.[] | {id: .id, state: .state, user: .user.login, body: .body}' \
  > ${REPO_DIR}/.tmp/pr-reviews-${PR_NUMBER}.json
```

**步骤 D — 读取 PR diff 并 checkout 分支**

```bash
gh pr diff ${PR_NUMBER} > ${REPO_DIR}/.tmp/pr-diff-${PR_NUMBER}.patch
git fetch origin ${BRANCH}
git checkout ${BRANCH}
```

---

### 阶段 2：逐项审查（REVIEW FINDING TRIAGE）

对 review body 中提取的每个发现项（问题），按以下决策树处理：

**1. 理解意见：**
- 引用 reviewer 原文（含 reviewer 用户名、文件路径、行号）
- 读取该问题相关的上下文和讨论（PR comments 中的补充说明）
- 判断意见类型：`bug` / `style` / `architecture` / `doc` / `test`

**2. 验证意见：**
- 检查当前代码/文档是否确实存在所述问题
- 如果涉及行为，运行相关测试验证
- 记录验证证据（命令输出、文件片段）

**3. 决策：**
- **同意（AGREE）** → 进入阶段 3 修复流水线
- **不同意（DISAGREE）** → 进入阶段 4 反驳流水线

---

### 阶段 3：修复流水线（AGREE → FIX → COMMENT）

对每条同意的 review 意见：

**步骤 A — 修复代码**
- 修改对应文件，确保修复精确对应 review 意见指出的问题
- 优先采用最小改动原则
- 修复后运行相关测试（对应模块）

**步骤 B — 验证修复**
- 重新读取修改后的代码，确认问题已消除
- 运行完整测试套件（如果涉及核心逻辑）
- 记录验证命令和输出到 `${REVIEW_LOG}`

**步骤 C — 在 PR 下回复修复结果（发 Comment）**

修复提交后，针对该问题发一条 PR comment 说明：

```bash
gh pr comment ${PR_NUMBER} --body "✅ 已修复 review 意见。

**文件**: ${FILE_PATH}:${LINE_NUM}
**问题**: ${ISSUE_SUMMARY}

**修改内容**: ${CHANGE_SUMMARY}
**验证**: ${VERIFY_COMMAND} 结果 exit 0。
**Commit**: $(git rev-parse HEAD)"
```

**步骤 D — 提交代码**

```bash
git add .
git commit -m "fix(review): address review finding on ${FILE_PATH}:${LINE_NUM} — ${BRIEF_DESC}"
git push origin ${BRANCH}
```

**步骤 E — 标记响应**

在 `${REVIEW_LOG}` 中记录：
- 问题摘要: ${ISSUE_SUMMARY}
- 文件:行号: `${FILE_PATH}:${LINE_NUM}`
- 决策：AGREE
- 修复文件及 diff 摘要
- 验证结果
- PR Comment 时间戳（发完后记录）

---

### 阶段 4：反驳流水线（DISAGREE → COUNTER → COMMENT）

对每条不同意的 review 意见，必须满足反驳门槛（缺一不可）：

**反驳门槛检查清单：**
- [ ] 有代码/文档证据：引用现有代码、测试输出、ADR、SPEC 证明当前实现正确
- [ ] 有架构理由：说明为什么 review 建议会破坏设计约束或引入回归
- [ ] 有替代方案：如果 review 指出的问题存在但不是最佳修复方式，提供替代方案

**步骤 A — 撰写反驳**

在 `${REVIEW_LOG}` 中撰写结构化反驳：
```markdown
## Review Finding on ${FILE_PATH}:${LINE_NUM}
> [引用 reviewer 原文]

### 决策：DISAGREE

### 理由：
1. [证据 1：引用代码/文档/测试输出]
2. [证据 2：引用 ADR/SPEC/架构约束]
3. [如果适用] 替代方案：[描述更优的解决方式]

### 请求：
建议 reviewer 重新考虑，或针对 [具体点] 进一步讨论。
```

**步骤 B — 发 PR Comment 进行反驳**

```bash
gh pr comment ${PR_NUMBER} --body "❌ 不同意此 review 意见。

**文件**: ${FILE_PATH}:${LINE_NUM}
**问题**: ${ISSUE_SUMMARY}

**理由**: ${COUNTER_REASON}
**证据**: ${EVIDENCE}

请 reviewer 重新考虑。"
```

**步骤 C — 标记响应**

在 `${REVIEW_LOG}` 中记录：
- 问题摘要: ${ISSUE_SUMMARY}
- 文件:行号: `${FILE_PATH}:${LINE_NUM}`
- 决策：DISAGREE
- 反驳证据摘要
- PR Comment 时间戳（发完后记录）

---

### 阶段 5：最终交付（DELIVERY）

全部 review 意见处理完毕后：

**步骤 A — 生成 Review Response 汇总报告**

将 `${REVIEW_LOG}` 整理，发一条 PR 通用评论：

```markdown
## Review Response Summary — PR #${PR_NUMBER}

所有 review 意见已处理完毕：

| 问题 | 文件:行号 | 决策 | 状态 |
|--------|-----------|------|------|
| #id1 | path:line | AGREE | 已修复，已发 comment |
| #id2 | path:line | AGREE | 已修复，已发 comment |
| #id3 | path:line | DISAGREE | 已反驳，已发 comment |

- 同意项：N 项，已修复并提交，Commit range: [first-hash..last-hash]
- 不同意项：M 项，理由已发 comment 说明，请 reviewer 查看
- 待讨论项：K 项，需要 reviewer 进一步澄清

请 reviewer 重新 review。如有需要，可点击 "Re-request review" 按钮。
```

**步骤 B — 发送 Review Response 汇总报告（PR Comment）**

```bash
gh pr comment ${PR_NUMBER} --body-file ${REPO_DIR}/.tmp/pr-response-summary-${PR_NUMBER}.md
gh pr edit ${PR_NUMBER} --add-label "awaiting-review"
```

注意：PR 作者无法通过 API 触发 "Re-request review" 按钮（这是 GitHub UI 功能），但可以在汇总评论中 @ 原 reviewer。

**步骤 C — 验证 PR 可合并状态**
- 运行完整测试套件确认无回归
- 确认无未解决的合并冲突
- 确认 CI 状态（如果有）

---

### 阶段 6：约束与边界（CONSTRAINTS）

**硬性约束：**
- 不修改 PR 范围外的文件（仅修复 review 涉及的文件）
- 不引入新依赖（除非 review 明确要求且已论证）
- 不重构未 review 的代码（最小改动原则）
- 不自动合并 PR（仅处理 review 意见，等待 reviewer 确认）
- 反驳必须有证据，禁止主观感受式反驳
- 必须以 PR Comment 方式回复每条修复或反驳结果，禁止只修改代码而不发评论说明

**写权限边界（可修改）：**
- PR diff 中涉及的所有文件
- `${REVIEW_LOG}`
- `${REPO_DIR}/.tmp/counter-*.md`
- `${REPO_DIR}/.tmp/pr-response-summary-*.md`

**只读边界（禁止写入）：**
- `scripts/lib/orch_gateway.py`（除非 review 意见明确要求修改）
- `config/schemas/orchestra.full.schema.json`（除非 review 意见明确要求修改）
- 其他 Sprint 的配置和测试脚本

---

### 阶段 7：止损条件（BLOCKED STOP）

**立即停止并报告 blocker 的情况：**
- review 意见涉及文件不在当前 PR 中，且无法定位
- 修复后测试持续失败 3 次，且失败与 review 修复无关
- reviewer 意见自相矛盾，无法同时满足
- `gh` CLI 不可用，无法发 comment 或推送代码
- PR 存在未解决的合并冲突，无法推送修复
- 无法从 review body 中解析出明确的问题清单

**报告格式（必须包含）：**
- Blocker 类型：`out-of-scope` / `test-env-conflict` / `contradictory-review` / `tool-unavailable` / `merge-conflict` / `unclear-review`
- 涉及的问题摘要 / 文件路径 / 行号
- 已尝试的处理方式
- 解锁所需的人类输入
