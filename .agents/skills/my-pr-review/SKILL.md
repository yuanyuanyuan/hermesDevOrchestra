---
name: my-pr-review
description: >
  对指定 GitHub PR 执行完整的结构化 Code Review。
  情报收集通过 my-pr-skill 完成，代码审查委托给 ce-code-review 技能，
  最终以 PR Review Body 方式提交结构化 review 结果。
  所有 GitHub 操作通过 my-pr-skill 脚本完成，不直接调用 gh。
  Reviewer 身份：stark-008。
  注意：GitHub 不允许 PR 作者对自己的 PR 提交 REQUEST_CHANGES 或 APPROVE review，
  因此 self-review 场景下所有事件降级为 COMMENT。合并由用户手动执行。
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
- 当前目录必须是项目本地仓库

## 环境要求

- `my-pr-skill` 已加载（所有 GitHub 操作由其 scripts/ 目录下的脚本完成）
- `ce-code-review` 技能可用（compound-engineering 插件提供）
- `gh` CLI 已安装且已认证（由 `my-pr-skill` 底层脚本使用）
- 当前目录 `${REPO_DIR}` 为项目本地仓库
- 具有 `repo` 或 `pull_requests:write` 权限的 GitHub Token

## 变量定义（每次执行时解析）

执行前将以下占位符替换为实际值：

| 变量 | 来源 |
|------|------|
| `${PR_NUMBER}` | 调用参数 `<PR_NUMBER>` |
| `${OWNER}` | `${MY_PR_SKILL_SCRIPTS}/get-repo-info.sh --owner` |
| `${REPO}` | `${MY_PR_SKILL_SCRIPTS}/get-repo-info.sh --repo` |
| `${REPO_DIR}` | 当前工作目录（`$(pwd)`） |
| `${PR_URL}` | `${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=url` |
| `${REVIEW_DRAFT}` | `${REPO_DIR}/.tmp/pr-review-draft-${PR_NUMBER}.md` |
| `${MY_PR_SKILL_SCRIPTS}` | `my-pr-skill` 的 scripts 目录路径 |
| `${IS_SELF_REVIEW}` | 阶段 3 步骤 A 检测：`reviewer == PR author` 时为 `true` |

---

## 执行流程

### 阶段 1：情报收集（INTELLIGENCE GATHERING）

通过 `my-pr-skill` 获取 PR 元数据和已有 review 信息。

**步骤 A — 获取仓库信息和 PR 元数据**

```bash
OWNER=$(${MY_PR_SKILL_SCRIPTS}/get-repo-info.sh --owner)
REPO=$(${MY_PR_SKILL_SCRIPTS}/get-repo-info.sh --repo)
PR_URL=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=url)
HEAD_SHA=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=headRefOid)
MERGEABLE=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=mergeable)
PR_AUTHOR=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=author)
```

**步骤 B — 获取已有 Review Comments（用于去重和 self-review 检测）**

```bash
${MY_PR_SKILL_SCRIPTS}/get-pr-reviews.sh --number=${PR_NUMBER} \
  --output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-reviews.json \
  --comments-output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-review-comments.json

${MY_PR_SKILL_SCRIPTS}/get-pr-comments.sh --number=${PR_NUMBER} \
  --output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-comments.json
```

**步骤 C — 检查 Reviewer 身份**

```bash
REVIEWER=$(gh api user --jq '.login')
```

> 注意：获取当前用户身份是 `my-pr-skill` 未封装的操作，可直接调用 `gh api user`。

如果 `REVIEWER == PR_AUTHOR`，设置 `${IS_SELF_REVIEW} = true`，否则为 `false`。

---

### 阶段 2：代码审查（CODE REVIEW — 委托 ce-code-review）

> **核心设计**：本阶段不自行调度 reviewer agents，而是委托给 `ce-code-review` 技能。
> 该技能是 compound-engineering 插件提供的多 agent 编排器，负责：
> - 根据 diff 内容自动选择 reviewer personas（always-on + conditional）
> - 并行 spawn sub-agents 执行多维度审查
> - Merge/dedup findings + confidence gating
> - 生成结构化 review 报告

**调用方式：**

使用 `Skill` tool 调用 `ce-code-review`：

```
skill: "ce-code-review"
args: "${PR_NUMBER} mode:headless"
```

- `${PR_NUMBER}`：告诉 `ce-code-review` review 哪个 PR
- `mode:headless`：程序化模式，返回结构化 findings，不交互、不修改文件

> `ce-code-review` 会自动：
> 1. checkout PR branch
> 2. 计算 diff（against PR base branch）
> 3. 分析 diff 内容选择 reviewer agents
> 4. 并行 spawn agents 审查
> 5. Merge findings + confidence gating
> 6. 返回结构化报告

**降级策略：**

如果 `ce-code-review` 不可用或执行失败：
1. 在 review body 中注明："⚠️ ce-code-review 不可用，降级为手动审查"
2. 手动读取 diff 文件（阶段 1 已收集），按 A-E 维度逐项检查
3. 使用传统检查清单作为替代

---

### 阶段 3：REVIEW 提交（REVIEW SUBMISSION）

**步骤 A — 映射 Findings 到 Review 格式**

将 `ce-code-review` 返回的结构化 findings 映射到 GitHub PR Review 格式：

1. 从 `ce-code-review` 的输出中提取：
   - Findings 列表（含 severity, file, line, title, description, suggestion）
   - Verdict（Ready to merge / Ready with fixes / Not ready）
   - Coverage 数据

2. 生成 Review Draft（`${REVIEW_DRAFT}`），包含：
   - 元数据（reviewer, timestamp, commit SHA, self-review 标记）
   - Findings 按 severity 分组（P0 → P3）
   - 合并门控判断

> 注：`submit-review.sh` 原样传递 Draft 内容，不会追加额外 footer。

**步骤 B — 事件类型选择**

```
if IS_SELF_REVIEW:
    event = "COMMENT"  # GitHub 限制，无论 PASS/FAIL 都只能用 COMMENT
elif has_FAIL:
    event = "REQUEST_CHANGES"
else:
    event = "COMMENT"  # approved 说明
```

在 review body 末尾追加说明（仅 self-review 时）：
```
> ⚠️ **Self-Review 说明**：由于 reviewer 与 PR 作者为同一人，GitHub 不允许 REQUEST_CHANGES/APPROVE 事件。
> 本次 review 以 COMMENT 事件提交，发现项仍需修复后才能合并。
```

**步骤 C — 提交 Review**

通过 `my-pr-skill` 的 `submit-review.sh` 提交：

```bash
${MY_PR_SKILL_SCRIPTS}/submit-review.sh \
  --number=${PR_NUMBER} \
  --event=${EVENT_TYPE} \
  --body-file=${REVIEW_DRAFT}
```

---

### 阶段 4：合并门控（MERGE GATE）

> ⚠️ 本 Skill 不执行实际合并操作。合并由用户手动完成。

**必要条件（缺一不可）：**
- [ ] `ce-code-review` verdict 为 "Ready to merge"（无 P0/P1 findings）
- [ ] 测试套件全部通过（`ce-code-review` 的 testing reviewer 已验证）
- [ ] Security reviewer 无 P0/P1 findings
- [ ] PR `mergeable == true`
- [ ] 本次 review 的 commit 与 PR head 一致

**如果允许合并：**
在 review comment 中明确告知用户："✅ Review approved. 满足所有合并条件，请手动执行合并。"
通过 `my-pr-skill` 的 `manage-pr.sh --checks` 确认 PR 状态。合并由用户手动执行。

**如果拒绝合并：**
- 正常 review：通过 `REQUEST_CHANGES` 事件 + review body 中的发现项表达拒绝原因，GitHub 会自动阻塞合并。
- Self-review：通过 `COMMENT` 事件 + review body 中的发现项表达拒绝原因。由于 GitHub 不会自动阻塞合并，需在 body 中明确标注 "🚫 合并阻塞：发现 N 个问题需修复"。

---

### 阶段 5：约束与边界（CONSTRAINTS）

**硬性约束：**
- 不修改 PR 中的任何代码（纯 reviewer 角色）
- 每个 FAIL 必须在 review body 中明确列出文件、行号和问题描述，禁止泛泛而谈
- 不基于主观偏好提出阻塞意见（必须有规范或 ADR 支撑）
- 不跳过 Security & Compliance（即使其他项全 PASS）
- 如果已有其他 reviewer 的 unresolved review comments，在 review body 中引用并纳入评估
- **所有 GitHub 操作必须通过 `my-pr-skill` 脚本完成，禁止直接调用 `gh`**（获取当前用户身份除外）
- **代码审查必须委托给 `ce-code-review` 技能，禁止自行调度 reviewer agents**

**只读边界：**
- PR diff 涉及的所有文件
- 项目测试脚本、配置、ADR 文档
- 已有 review comments（只读参考，不修改）

---

### 阶段 6：止损条件（BLOCKED STOP）

**立即停止并报告的情况：**
- `my-pr-skill` 脚本无法读取 PR 或提交 review（权限不足、token 过期）
- `ce-code-review` 执行失败且降级审查也失败
- 发现敏感信息泄露 → 立即提交 REJECT review（body 直接说明）

**报告格式：**
- Blocker 类型：`tool-unavailable` / `review-engine-failed` / `security-leak`
- 已收集的证据摘要
- 建议的人类介入方式

---

## Review Draft 模板

```markdown
# PR Review: ${PR_URL}
- Reviewer: ${REVIEWER}
- Timestamp: ${ISO8601}
- Commit Reviewed: ${HEAD_SHA}
- Self-Review: ${IS_SELF_REVIEW}
- Review Engine: ce-code-review (compound-engineering)

## 摘要
- Verdict: ${VERDICT}
- Findings: P0: ${P0_COUNT} | P1: ${P1_COUNT} | P2: ${P2_COUNT} | P3: ${P3_COUNT}
- 建议决策: [review approved / REQUEST_CHANGES]

## Findings

### P0 — Critical
| # | File | Issue | Reviewer | Confidence |
|---|------|-------|----------|------------|
| ... | ... | ... | ... | ... |

### P1 — High
| # | File | Issue | Reviewer | Confidence |
|---|------|-------|----------|------------|
| ... | ... | ... | ... | ... |

### P2 — Moderate
...

### P3 — Low
...

## Coverage
- Suppressed: ${SUPPRESSED_COUNT} findings below confidence threshold
- Failed reviewers: ${FAILED_REVIEWERS}

## 合并门控
- ✅/🚫 合并条件评估...
```
