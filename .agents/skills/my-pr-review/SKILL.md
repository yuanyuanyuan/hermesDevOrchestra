---
name: my-pr-review
description: >
  对指定 GitHub PR 执行完整的结构化 Code Review。
  收集情报、按维度逐项检查、以 PR Review Body 方式发送结构化 review 结果，
  提交 REQUEST_CHANGES 或 review approved comment，并基于证据做出合并/拒绝建议。
  Reviewer 身份：stark-008。
  注意：GitHub 不允许 PR 作者对自己的 PR 提交 APPROVE review，因此即使检查全部通过，也使用 COMMENT 事件附带 approved 说明，而非 APPROVE 事件。合并由用户手动执行。
---

# PR Review Skill

## 触发条件

当用户要求以下任一操作时激活本 Skill：
- "review this PR"
- "review PR #N"
- "对 PR 做 code review"
- 任何包含 PR number 的 review 请求

## 调用签名

```
my-pr-review <PR_NUMBER>
```

- `PR_NUMBER`: GitHub PR 编号（如 `8`）
- 当前目录必须是项目本地仓库，`gh` 会自动识别所属仓库

## 环境要求

- `gh` CLI 已安装且已认证（`gh auth status` 通过）
- 当前目录 `${REPO_DIR}` 为项目本地仓库
- 具有 `repo` 或 `pull_requests:write` 权限的 GitHub Token

## 变量定义（每次执行时解析）

执行前将以下占位符替换为实际值：

| 变量 | 来源 |
|------|------|
| `${PR_NUMBER}` | 调用参数 `<PR_NUMBER>` |
| `${OWNER}` | `gh repo view --json owner --jq '.owner.login'` |
| `${REPO}` | `gh repo view --json name --jq '.name'` |
| `${REPO_DIR}` | 当前工作目录（`$(pwd)`） |
| `${PR_URL}` | `gh pr view ${PR_NUMBER} --json url --jq '.url'` |
| `${REVIEW_DRAFT}` | `${REPO_DIR}/.tmp/pr-review-draft-${PR_NUMBER}.md` |

## 执行流程

### 阶段 1：情报收集（INTELLIGENCE GATHERING）

**步骤 A — 加载技能并读取 PR 元数据**

收集 PR 基本信息：
   ```bash
   cd ${REPO_DIR}
   OWNER=$(gh repo view --json owner --jq '.owner.login')
   REPO=$(gh repo view --json name --jq '.name')
   PR_URL=$(gh pr view ${PR_NUMBER} --json url --jq '.url')
   gh pr view ${PR_NUMBER} --json number,title,body,author,headRefName,baseRefName,createdAt,updatedAt,mergeable,mergeStateStatus,changedFiles,additions,deletions
   ```

**步骤 B — 读取 PR 完整 diff**

```bash
mkdir -p ${REPO_DIR}/.tmp
gh pr diff ${PR_NUMBER} > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-diff.patch
grep -E "^\+\+\+ b/" ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-diff.patch | sed 's/+++ b\///' > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-files.txt
```

**步骤 C — 读取已有 Review Comments（避免重复评论）**

```bash
gh api repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments \
  --jq '.[] | {id: .id, body: .body, user: .user.login, created_at: .created_at}' \
  > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-existing-comments.json

gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews \
  --jq '.[] | {id: .id, state: .state, body: .body, user: .user.login}' \
  > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-existing-reviews.json
```

**步骤 D — 读取相关上下文**

```bash
gh pr view ${PR_NUMBER} --json body | grep -oE '(docs/adr/[^ ]+|\.planning/specs/[^ ]+|#\d+)' | sort -u > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-refs.txt
```

---

### 阶段 2：REVIEW 执行标准（REVIEW CRITERIA）

遍历每个变更文件，逐项检查：

#### A. 代码质量（Code Quality）
- [ ] **命名规范**：函数/类/变量名符合项目约定
- [ ] **复杂度**：无过度嵌套，无超长函数（>50行）
- [ ] **重复代码**：DRY 原则，无 copy-paste 块
- [ ] **错误处理**：异常路径有处理，不裸 `except`
- [ ] **类型安全**：Python 有类型注解，JSON 有 schema 验证

#### B. 架构合规（Architecture Compliance）
- [ ] **ADR 引用**：实现与引用的 ADR 一致
- [ ] **边界遵守**：未修改 PR 范围外的文件
- [ ] **依赖控制**：未引入不必要的新依赖
- [ ] **接口契约**：新增 API 有明确输入/输出/异常定义

#### C. 测试覆盖（Test Coverage）
- [ ] **测试存在**：新增代码有对应测试
- [ ] **测试通过**：运行对应 `test-*.sh` exit 0
- [ ] **负向测试**：有错误路径/边界条件测试
- [ ] **无回归**：完整测试套件通过

#### D. 安全与合规（Security & Compliance）
- [ ] **无注入风险**：无 `shell=True`、无字符串拼接命令
- [ ] **无密钥硬编码**：无 API key/password 明文
- [ ] **权限正确**：文件权限 0600/0700，无过度授权
- [ ] **输入验证**：外部输入有校验/转义

#### E. 文档完整（Documentation）
- [ ] **代码注释**：复杂逻辑有注释，公共函数有 docstring
- [ ] **ADR 更新**：架构变更有对应 ADR 记录
- [ ] **PR Body**：需求来源、背景、测试证据齐全
- [ ] **配置文档**：新增配置项有说明和示例

---

### 阶段 3：发现项清单构建（FINDING LIST）

对每一个 **FAIL** 项，在 Review Draft 中构建一条结构化发现项。

**发现项 Markdown 格式：**
```markdown
### [维度-序号] 检查项名称 — FAIL

- **文件**: `文件相对路径` （行号范围或具体行）
- **问题描述**: 具体说明发现了什么问题
- **证据**:
  - 代码片段：[粘贴相关代码]
  - 命令输出：[如果有测试/lint失败，粘贴输出]
  - 规范引用：[引用 ADR/SPEC 相关段落]
- **建议修复**: 给出具体修改建议或替代方案
```

**示例：**
```markdown
### [D-03] Security — 命令注入风险

- **文件**: `scripts/lib/release_executor.py:120`
- **问题描述**: 此处使用 `subprocess.run(cmd, shell=True)`，存在命令注入风险。
- **证据**:
  - 代码：`subprocess.run(command_str, shell=True)`（line 120）
  - 规范：ADR-0013 要求 `arbitrary_shell_allowed: false`
- **建议修复**: 改用 `subprocess.run(command_list, shell=False)`，并将输入解析为列表。
```

**去重规则：**
- 如果已有 comments/reviews 中对相同问题有相似评论，跳过
- 同一问题跨多行，在发现项中标注核心行号，并在描述中引用行范围

---

### 阶段 4：REVIEW 提交（REVIEW SUBMISSION）

**步骤 A — 生成本地 Review Draft**

写入 `${REVIEW_DRAFT}`：
```markdown
# PR Review: ${PR_URL}
- Reviewer: stark-008
- Timestamp: $(date -Iseconds)
- Commit Reviewed: $(gh pr view ${PR_NUMBER} --json headRefOid --jq .headRefOid)

## 摘要
- 检查项总计: N | PASS: X | FAIL: Y | N/A: Z
- 发现项数量: Y（每个 FAIL 对应一条）
- 建议决策: [review approved / REQUEST_CHANGES]（均以 COMMENT 事件提交，见阶段 4）

## 发现项清单
[列出每个 FAIL 的文件:行号 + 问题摘要]
```

**步骤 B — 提交 Review**

如果有 FAIL 项（REQUEST_CHANGES）：
```bash
gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews \
  --method POST \
  --field event=REQUEST_CHANGES \
  --field body="$(cat ${REVIEW_DRAFT})"
```

如果全部 PASS（review approved comment）：
```bash
gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews \
  --method POST \
  --field event=COMMENT \
  --field body="✅ Review approved. All ${N} criteria checked, 0 blockers. Evidence verified. Ready for merge."
```

---

### 阶段 5：合并门控（MERGE GATE）

> ⚠️ 本 Skill 不执行实际合并操作。合并由用户手动完成。

**必要条件（缺一不可）：**
- [ ] 本次 review 所有检查项 PASS 或 N/A（无 FAIL）
- [ ] 测试套件全部通过（有命令输出证据）
- [ ] Security & Compliance 全 PASS
- [ ] PR `mergeable == true`
- [ ] 本次 review 的 commit 与 PR head 一致

**如果允许合并：**
在 review comment 中明确告知用户："✅ Review approved. 满足所有合并条件，请手动执行合并。"
用户自行执行：
```bash
gh pr merge ${PR_NUMBER} --squash --delete-branch=false
```

**如果拒绝合并：**
已通过 REQUEST_CHANGES + review body 中的发现项表达拒绝原因。
在 review body 中说明：阻塞问题数量、修复后重新请求 review 的方式。

---

### 阶段 6：约束与边界（CONSTRAINTS）

**硬性约束：**
- 不修改 PR 中的任何代码（纯 reviewer 角色）
- 每个 FAIL 必须在 review body 中明确列出文件、行号和问题描述，禁止泛泛而谈
- 不基于主观偏好提出阻塞意见（必须有规范或 ADR 支撑）
- 不跳过 Security & Compliance（即使其他项全 PASS）
- 如果已有其他 reviewer 的 unresolved review comments，在 review body 中引用并纳入评估

**只读边界：**
- PR diff 涉及的所有文件
- 项目测试脚本、配置、ADR 文档
- 已有 review comments（只读参考，不修改）

---

### 阶段 7：止损条件（BLOCKED STOP）

**立即停止并报告的情况：**
- `gh` CLI 无法读取 PR 或提交 review（权限不足、token 过期）
- PR diff 超过 5000 行（超出合理 review 范围）
- 测试脚本因环境问题持续失败 3 次
- 发现敏感信息泄露 → 立即提交 REJECT review（body 直接说明）

**报告格式：**
- Blocker 类型：`tool-unavailable` / `pr-too-large` / `env-failure` / `security-leak`
- 已收集的证据摘要
- 建议的人类介入方式
