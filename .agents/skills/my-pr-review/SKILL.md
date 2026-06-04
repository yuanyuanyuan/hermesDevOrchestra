---
name: my-pr-review
description: >
  对指定 GitHub PR 执行完整的结构化 Code Review。
  使用 compound-engineering review agents 并行多维度审查，
  聚合发现项后以 PR Review Body 方式发送结构化 review 结果，
  提交 REQUEST_CHANGES 或 review approved comment，并基于证据做出合并/拒绝建议。
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
| `${IS_SELF_REVIEW}` | 阶段 4 步骤 A 检测：`reviewer == PR author` 时为 `true` |
| `${DIFF_CONTEXT}` | PR diff + 变更文件列表（阶段 1 收集，供 agent 使用） |

---

## 执行流程

### 阶段 1：情报收集（INTELLIGENCE GATHERING）

**步骤 A — 读取 PR 元数据**

通过 `my-pr-skill` 获取仓库信息和 PR 元数据：

```bash
OWNER=$(${MY_PR_SKILL_SCRIPTS}/get-repo-info.sh --owner)
REPO=$(${MY_PR_SKILL_SCRIPTS}/get-repo-info.sh --repo)
PR_URL=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=url)

# 完整元数据 JSON 写入本地缓存
${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-metadata.json
```

**步骤 B — 读取 PR 完整 diff**

```bash
${MY_PR_SKILL_SCRIPTS}/get-pr-diff.sh --number=${PR_NUMBER} --output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}.diff
```

提取变更文件列表，统计 diff 行数。若 diff 超过 5000 行，进入止损条件（阶段 7）。

**步骤 C — 读取已有 Review Comments（避免重复评论）**

```bash
${MY_PR_SKILL_SCRIPTS}/get-pr-reviews.sh --number=${PR_NUMBER} \
  --output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-reviews.json \
  --comments-output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-review-comments.json

${MY_PR_SKILL_SCRIPTS}/get-pr-comments.sh --number=${PR_NUMBER} \
  --output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-comments.json
```

**步骤 D — 读取相关上下文**

从 PR body 中提取引用的文档路径和关联 issue，读取到本地作为上下文。

**步骤 E — 构建 Agent 共享上下文**

将以下内容组装为 `${DIFF_CONTEXT}` 字符串，作为后续 agent 的输入：
- 变更文件列表（相对路径）
- 完整 diff
- PR body（需求描述）
- 已有 review comments 摘要（用于去重）

---

### 阶段 2：多维度并行审查（MULTI-DIMENSIONAL REVIEW ENGINE）

> **核心变更**：替代手动逐项检查，调度 compound-engineering review agents 并行审查。
> 每个 agent 独立读取代码、分析 diff、产出结构化 findings。

#### Agent 调度矩阵

| Agent | `subagent_type` | 触发条件 | 审查维度 |
|-------|-----------------|---------|---------|
| Correctness | `compound-engineering:ce-correctness-reviewer` | **Always-on** | 逻辑错误、边界条件、状态管理、错误传播、意图-实现不匹配 |
| Security | `compound-engineering:ce-security-reviewer` | diff 触及 auth/输入处理/权限/公共端点 | 可利用漏洞、注入风险、密钥泄露、权限检查 |
| Maintainability | `compound-engineering:ce-maintainability-reviewer` | **Always-on** | 结构质量、复杂度、耦合、命名、死代码、类型泄漏、抽象债 |
| Testing | `compound-engineering:ce-testing-reviewer` | **Always-on** | 测试覆盖缺口、弱断言、实现耦合测试、边界条件缺失 |
| Project Standards | `compound-engineering:ce-project-standards-reviewer` | **Always-on** | 对齐 CLAUDE.md / AGENTS.md 标准、命名约定、frontmatter 规则 |
| Performance | `compound-engineering:ce-performance-reviewer` | diff 触及 DB 查询/循环/缓存/IO 密集路径 | 性能瓶颈、算法复杂度、内存使用、可扩展性 |
| Adversarial | `compound-engineering:ce-adversarial-reviewer` | diff >= 50 行或触及高风险域（auth/payments/数据变更/外部 API） | 主动构造失败场景、破坏性测试 |
| Architecture | `compound-engineering:ce-architecture-strategist` | diff 涉及新增服务/结构重构/模式变更 | 模式合规、设计完整性 |

#### 调度逻辑

```
changed_files = extract_file_paths(diff)
diff_line_count = count_lines(diff)

# Always-on agents（必跑）
agents = [Correctness, Maintainability, Testing, Project Standards]

# Conditional agents（条件触发）
if touches_auth_or_input(changed_files):
    agents.append(Security)
if touches_db_or_io(changed_files):
    agents.append(Performance)
if diff_line_count >= 50 or touches_high_risk(changed_files):
    agents.append(Adversarial)
if touches_structure(changed_files):
    agents.append(Architecture)
```

#### Agent 调用模式

使用 `Agent` tool 并行 spawn 所有 agent，每个 agent 获得：

```
subagent_type: "compound-engineering:ce-{reviewer-name}"
prompt: |
  Review the following PR diff for {dimension} issues.

  ## PR Context
  - Title: ${PR_TITLE}
  - Description: ${PR_BODY}
  - Changed files: ${CHANGED_FILES}

  ## Diff
  ${DIFF}

  ## Review Focus
  {dimension-specific instructions from the matrix above}

  ## Output Format
  For each finding, return:
  - file: relative path
  - line: line number or range
  - severity: BLOCKER | WARNING | SUGGESTION
  - category: one of [correctness, security, maintainability, testing, performance, architecture, standards]
  - title: one-line summary
  - description: detailed explanation with evidence
  - suggestion: concrete fix recommendation

  If no issues found, return an empty findings list.
  Do NOT modify any files. Read-only review.
mode: "default"  # read-only, no edits
```

> **重要**：所有 agent 使用 `mode: "default"` 或不指定 mode（默认只读），
> 因为 review 是纯读操作，不应修改任何文件。

#### 并行执行

所有 agent 调用放在**同一个** `Agent` tool block 中并行发出，
等待全部返回后进入阶段 3。

---

### 阶段 3：发现项聚合与结构化（FINDING AGGREGATION）

**步骤 A — 收集 Agent Findings**

从每个 agent 的返回结果中提取 findings 列表。

**步骤 B — 去重**

- 同一文件 + 同一行号 + 相似描述 → 合并为一条，保留最高 severity
- 已有 review comments 中的相同问题 → 跳过（阶段 1 已收集）
- 同一根本原因的不同表现 → 合并为一条，描述中列出所有位置

**步骤 C — 分类与排序**

按 severity 排序：BLOCKER > WARNING > SUGGESTION
同 severity 内按 category 排序：security > correctness > testing > performance > maintainability > architecture > standards

**步骤 D — 映射到 Review 检查项**

将 agent findings 映射到传统检查项维度（A-E），生成检查项汇总表：

| 维度 | 检查项 | 结果 |
|------|--------|------|
| A. Code Quality | 命名/复杂度/DRY/错误处理/类型安全 | PASS / FAIL (引用 finding) |
| B. Architecture | ADR/边界/依赖/接口契约 | PASS / FAIL / N/A |
| C. Test Coverage | 存在/通过/负向/回归 | PASS / FAIL |
| D. Security | 注入/密钥/权限/输入验证 | PASS / FAIL |
| E. Documentation | 注释/ADR/PR Body/配置文档 | PASS / FAIL |

**步骤 E — 生成 Review Draft**

写入 `${REVIEW_DRAFT}`，包含：
1. 元数据（reviewer, timestamp, commit SHA, self-review 标记）
2. 检查项汇总表（PASS/FAIL 计数）
3. 发现项清单（每个 FAIL 的结构化描述）
4. 合并门控判断

> 注：`submit-review.sh` 会在发送时自动在 body 末尾追加 `@codex review`，无需在 Draft 中手动写入。

---

### 阶段 4：REVIEW 提交（REVIEW SUBMISSION）

**步骤 A — 检查 Reviewer 身份**

```bash
PR_AUTHOR=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=author)
```

通过 `gh api user --jq '.login'` 获取当前认证用户（reviewer）。
> 注意：获取当前用户身份是 `my-pr-skill` 未封装的操作，可直接调用 `gh api user`。

如果 `REVIEWER == PR_AUTHOR`，设置 `${IS_SELF_REVIEW} = true`，否则为 `false`。

> ⚠️ **GitHub 限制**：PR 作者不能对自己的 PR 提交 `REQUEST_CHANGES` 或 APPROVE review。
> 当 `IS_SELF_REVIEW == true` 时，所有 review 事件必须降级为 `COMMENT`。

**步骤 B — 提交 Review**

通过 `my-pr-skill` 的 `submit-review.sh` 提交 review：

```bash
${MY_PR_SKILL_SCRIPTS}/submit-review.sh \
  --number=${PR_NUMBER} \
  --event=${EVENT_TYPE} \
  --body-file=${REVIEW_DRAFT}
```

事件类型选择逻辑：
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

> 注：底层 `submit-review.sh` 会自动追加 `@codex review` footer，触发 Codex 外部视觉 review。

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
通过 `my-pr-skill` 的 `manage-pr.sh --checks` 确认 PR 状态。合并由用户手动执行。

**如果拒绝合并：**
- 正常 review：通过 `REQUEST_CHANGES` 事件 + review body 中的发现项表达拒绝原因，GitHub 会自动阻塞合并。
- Self-review：通过 `COMMENT` 事件 + review body 中的发现项表达拒绝原因。由于 GitHub 不会自动阻塞合并，需在 body 中明确标注 "🚫 合并阻塞：发现 N 个问题需修复"。

---

### 阶段 6：约束与边界（CONSTRAINTS）

**硬性约束：**
- 不修改 PR 中的任何代码（纯 reviewer 角色）
- 每个 FAIL 必须在 review body 中明确列出文件、行号和问题描述，禁止泛泛而谈
- 不基于主观偏好提出阻塞意见（必须有规范或 ADR 支撑）
- 不跳过 Security & Compliance（即使其他项全 PASS）
- 如果已有其他 reviewer 的 unresolved review comments，在 review body 中引用并纳入评估
- 所有 compound-engineering agents 必须以只读模式运行（不修改文件）
- **所有 GitHub 操作必须通过 `my-pr-skill` 脚本完成，禁止直接调用 `gh`**（获取当前用户身份除外）

**只读边界：**
- PR diff 涉及的所有文件
- 项目测试脚本、配置、ADR 文档
- 已有 review comments（只读参考，不修改）

---

### 阶段 7：止损条件（BLOCKED STOP）

**立即停止并报告的情况：**
- `my-pr-skill` 脚本无法读取 PR 或提交 review（权限不足、token 过期）
- PR diff 超过 5000 行（超出合理 review 范围）
- 测试脚本因环境问题持续失败 3 次
- 发现敏感信息泄露 → 立即提交 REJECT review（body 直接说明）
- compound-engineering agents 全部超时或失败 → 降级为手动逐项检查（阶段 2 fallback）

**报告格式：**
- Blocker 类型：`tool-unavailable` / `pr-too-large` / `env-failure` / `security-leak` / `agents-failed`
- 已收集的证据摘要
- 建议的人类介入方式

---

## 降级策略（FALLBACK）

当 compound-engineering agents 不可用或全部失败时，降级为手动审查：

1. 按阶段 2 的 Agent 调度矩阵中的审查维度，手动逐项检查
2. 使用传统检查清单（A-E 维度）作为替代
3. 在 review body 中注明："⚠️ 本次 review 降级为手动模式（agents 不可用）"

---

## Review Draft 模板

```markdown
# PR Review: ${PR_URL}
- Reviewer: ${REVIEWER}
- Timestamp: ${ISO8601}
- Commit Reviewed: ${HEAD_SHA}
- Self-Review: ${IS_SELF_REVIEW}
- Review Engine: compound-engineering agents (${AGENT_COUNT} agents dispatched)

## 摘要
- 检查项总计: N | PASS: X | FAIL: Y | N/A: Z
- 发现项数量: Y（其中 BLOCKER: B, WARNING: W, SUGGESTION: S）
- 建议决策: [review approved / REQUEST_CHANGES]

## Agent Review 覆盖
| Agent | Status | Findings |
|-------|--------|----------|
| ce-correctness-reviewer | completed | N findings |
| ce-security-reviewer | completed/skipped | N findings |
| ... | ... | ... |

## 检查项汇总
| 维度 | 检查项 | 结果 |
|------|--------|------|
| A. Code Quality | ... | PASS / FAIL |
| ... | ... | ... |

## 发现项清单
### [BLOCKER-01] category — title
- **文件**: `path:line`
- **问题描述**: ...
- **证据**: ...
- **建议修复**: ...

### [WARNING-01] ...
...

## 合并门控
- ✅/🚫 合并条件评估...
```
