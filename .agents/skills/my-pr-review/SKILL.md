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
| `${PR_INFO_JSON}` | `${MY_PR_SKILL_SCRIPTS}/collect-pr-info.sh --json`（聚合 PR 元数据/已存 reviews/已存 comments）|
| `${MY_PR_SKILL_SCRIPTS}` | `my-pr-skill` 的 scripts 目录路径 |
| `${BASE_BRANCH}` | `${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=baseRefName` |
| `${IS_SELF_REVIEW}` | 阶段 3 步骤 A 检测：`reviewer == PR author` 时为 `true` |
| `${REVIEW_MODE}` | `first` / `delta` / `merge-blocked`，由阶段 1 步骤 D 自动判定 |
| `${LAST_REVIEWED_OID}` | 上次 review 提交时的 `headRefOid`（re-review 时从历史 review 中取最大）|
| `${PRIOR_REVIEWS}` | 历次 review 的 `[{id, state, user, body, submitted_at}]` 数组，驱动 Prior review trace 表 |

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
BASE_BRANCH=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=baseRefName)
MERGEABLE=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=mergeable)
PR_AUTHOR=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=author)
```

> 若需要完整 JSON 对象供后续解析，统一使用 `--json` 参数：
> ```bash
> ${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --json > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-metadata.json
> ```

**步骤 B — 获取已有 Review Comments（用于去重和 self-review 检测）**

```bash
${MY_PR_SKILL_SCRIPTS}/get-pr-reviews.sh --number=${PR_NUMBER} --json \
  > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-reviews.json

${MY_PR_SKILL_SCRIPTS}/get-pr-reviews.sh --number=${PR_NUMBER} --json \
  --comments-output=${REPO_DIR}/.tmp/pr-${PR_NUMBER}-review-comments.json

${MY_PR_SKILL_SCRIPTS}/get-pr-comments.sh --number=${PR_NUMBER} --json \
  > ${REPO_DIR}/.tmp/pr-${PR_NUMBER}-comments.json
```

**步骤 C — 检查 Reviewer 身份**

```bash
REVIEWER=$(gh api user --jq '.login')
```

> 注意：获取当前用户身份是 `my-pr-skill` 未封装的操作，可直接调用 `gh api user`。

如果 `REVIEWER == PR_AUTHOR`，设置 `${IS_SELF_REVIEW} = true`，否则为 `false`。

**步骤 D — 检测 Review 类型（决定 review mode）**

根据当前 PR 是否存在历史 review，决定 review 走哪条流水线：

```bash
# 取 HEAD SHA
HEAD_SHA=$(${MY_PR_SKILL_SCRIPTS}/get-pr-metadata.sh --number=${PR_NUMBER} --field=headRefOid)

# 取 PR 上已提交的 reviews（按 submittedAt 倒序）
REVIEWS_JSON=$(${MY_PR_SKILL_SCRIPTS}/get-pr-reviews.sh --number=${PR_NUMBER} --json)
REVIEW_COUNT=$(echo "$REVIEWS_JSON" | jq 'length')

if [[ "$REVIEW_COUNT" -eq 0 ]]; then
  REVIEW_MODE="first"
  LAST_REVIEWED_OID=""
else
  # 提取最近一次 review 的 commit SHA（取自 review body 的 footer 解析，或 fallback 到 headRefOid）
  # 推荐方式：使用本 skill 提交 review 时自动注入的 "Reviewed-commit: <sha>" 标记
  LAST_REVIEWED_OID=$(echo "$REVIEWS_JSON" | jq -r 'max_by(.submitted_at) | .body' \
    | grep -oP 'Reviewed-commit:\s*\K[a-f0-9]+' || echo "")

  if [[ -z "$LAST_REVIEWED_OID" ]]; then
    # Fallback：使用 PR 最早 open 时的 baseRefOid（无法做 delta review）
    REVIEW_MODE="merge-blocked"
  else
    # 调用 diff-since.sh 决定 review 范围
    DIFF_INFO=$(${MY_PR_SKILL_SCRIPTS}/diff-since.sh ${PR_NUMBER} ${LAST_REVIEWED_OID})
    SCOPE=$(echo "$DIFF_INFO" | jq -r '.scope')
    case "$SCOPE" in
      none)  REVIEW_MODE="merge-blocked" ;;   # 无新 commit 但 review 已发，说明阻塞
      full)  REVIEW_MODE="re-review-full" ;;  # >20 文件变更，退化为全量 review
      partial) REVIEW_MODE="delta" ;;         # 增量 review
    esac
  fi
fi

echo "REVIEW_MODE=$REVIEW_MODE  LAST_REVIEWED_OID=$LAST_REVIEWED_OID"
```

**Mode 决策表：**

| 触发条件 | `${REVIEW_MODE}` | 含义 | 模板 |
|----------|------------------|------|------|
| PR 上 0 个 review | `first` | 第一次 review | `TPL_FIRST_REVIEW` |
| 有 review + `diff-since` scope=partial | `delta` | 增量 review | `TPL_RE_REVIEW_DELTA` |
| 有 review + `diff-since` scope=full | `re-review-full` | 改动太大，退化为全量 | `TPL_RE_REVIEW_DELTA`（加大变更说明）|
| 有 review + `diff-since` scope=none | `merge-blocked` | 阻塞未解决 | `TPL_MERGE_BLOCKED` |
| 无 `Reviewed-commit` 标记 | `merge-blocked` | 无法定位上轮范围 | `TPL_MERGE_BLOCKED` |

> ⚠️ **必须**在本 skill 每次提交 review 时，把 `Reviewed-commit: ${HEAD_SHA}` 写进 review body footer（见阶段 3 步骤 B），否则 `LAST_REVIEWED_OID` 解析会失败。

> ⚠️ **`PRIOR_REVIEWS` 数组**：由 `${REVIEWS_JSON}` 直接提供，模板渲染时填入 "Prior review trace" 表。

---

### 阶段 2：代码审查（CODE REVIEW — 按 mode 走不同流水线）

> **核心设计**：本阶段不自行调度 reviewer agents，而是委托给 `ce-code-review` 技能。
> 该技能是 compound-engineering 插件提供的多 agent 编排器，负责：
> - 根据 diff 内容自动选择 reviewer personas（always-on + conditional）
> - 并行 spawn sub-agents 执行多维度审查
> - Merge/dedup findings + confidence gating
> - 生成结构化 review 报告

**Mode 决定流水线：**

| `${REVIEW_MODE}` | 是否调 `ce-code-review` | 审查范围 | 是否 verify 上轮 finding |
|------------------|------------------------|---------|---------------------------|
| `first` | ✅ Yes | 整个 PR diff | ❌ No（无上轮 finding）|
| `delta` | ❌ No（直接读 diff）| `diff-since` 输出的 files 列表 | ✅ **必须**：每条上轮 P0/P1 逐项核验 |
| `re-review-full` | ✅ Yes | 整个 PR diff | ✅ Yes（在 P0/P1 修复 trace 表中标注）|
| `merge-blocked` | ❌ No | N/A | ✅ Yes：报告阻塞项未解决 |

**步骤 A — checkout PR branch**

所有 mode 在调 `ce-code-review` 之前，先切换到 PR branch：

```bash
gh pr checkout ${PR_NUMBER}
```

**步骤 B — 按 mode 执行审查**

**B-1. `first` mode（首次 review）**

```
skill: "ce-code-review"
args: "mode:report-only base:${BASE_BRANCH}"
```

- `mode:report-only`：严格只读模式
- `base:${BASE_BRANCH}`：以 PR base branch 为 diff 基准

> `ce-code-review` 会自动完成 diff 分析 → reviewer 选型 → 并行审查 → 合并门控。

**B-2. `delta` mode（增量 review，推荐路径）**

不走 `ce-code-review`，**手动 diff 驱动的验证**：

```bash
# 1. 提取变更文件列表
CHANGED_FILES=$(echo "$DIFF_INFO" | jq -r '.files[]')

# 2. 对每个变更文件，git diff 出片段
for f in $CHANGED_FILES; do
  git diff ${LAST_REVIEWED_OID}..${HEAD_SHA} -- "$f"
done > .tmp/pr-${PR_NUMBER}-delta-patch.diff

# 3. 阅读 patch，按"原 finding 修复 trace"+"新 finding"两栏填表
```

**Delta mode 的核心交付物**（写入 `${REVIEW_DRAFT}`）：
- `Prior review trace` 表：每条上轮 P0/P1 标 `FIXED / NOT-FIXED / REGRESSED / N/A`
- `New findings` 表：`diff-since` 后才出现的问题
- 不需要重复列"P0/P1/P2 全部严重度"，只标 delta

**B-3. `re-review-full` mode（改动过大）**

与 `first` 模式相同，但额外：
- 在 review body 顶部加 `Prior review trace` 表
- 标 `Reviewed-commit: <上轮 OID>`，方便下次 `diff-since` 定位

**B-4. `merge-blocked` mode**

不走 `ce-code-review`。直接填 `TPL_MERGE_BLOCKED` 模板，列出：
- 上轮 P0/P1 列表 + 当前状态
- 阻塞项当前 `git log` / `git diff` 证据
- `@<author>` mention + 重新 review 请求

**降级策略：**

如果 `ce-code-review` 不可用或执行失败：
1. 在 review body 中注明："⚠️ ce-code-review 不可用，降级为手动审查"
2. 手动读取 diff 文件（阶段 1 已收集），按 A-E 维度逐项检查
3. 使用传统检查清单作为替代

---

### 阶段 3：REVIEW 提交（REVIEW SUBMISSION）

**步骤 A — 选择模板并填字段**

按 `${REVIEW_MODE}` 选择对应模板（见末尾"模板"章节）：

| `${REVIEW_MODE}` | 模板 | 必填字段 |
|------------------|------|----------|
| `first` | `TPL_FIRST_REVIEW` | metadata、Verdict、Findings 分组、Coverage、合并门控 |
| `delta` | `TPL_RE_REVIEW_DELTA` | metadata、Prior review trace、New findings、delta 范围 |
| `re-review-full` | `TPL_RE_REVIEW_DELTA` + 完整 findings 章节 | 同上 + 全量 findings |
| `merge-blocked` | `TPL_MERGE_BLOCKED` | 阻塞项当前证据、@author、Re-review 请求 |

**字段填充约定：**
- `${AUTO:` 开头：从脚本输出自动填（head_oid / reviewer / timestamp / prior reviews / scope）
- `${MANUAL:` 开头：人工判断后填（verdict / 修复状态 / 新 finding 描述）
- 模板**禁止**留 `${AUTO}` 字段未填就提交

> 注：`submit-review.sh` 原样传递 Draft 内容，不会追加额外 footer。

**步骤 B — Review Body Footer（强制）**

所有 review body 末尾必须**显式**追加 `Reviewed-commit` 标记，方便下次 `diff-since` 定位：

```markdown

---

## Review metadata
- Reviewed-commit: `${HEAD_SHA}` (auto)
- Reviewer: `${REVIEWER}` (auto)
- Timestamp: `${ISO8601}` (auto)
- Mode: `${REVIEW_MODE}` (auto)
- Last-reviewed-commit: `${LAST_REVIEWED_OID}` (auto, re-review 时填)
```

> ⚠️ 该 footer 是 `LAST_REVIEWED_OID` 自动解析的**唯一**来源，缺失会导致下次 review 退化为 `merge-blocked` mode。

**步骤 C — 事件类型选择**

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

**步骤 D — 提交 Review**

通过 `my-pr-skill` 的 `submit-review.sh` 提交：

```bash
${MY_PR_SKILL_SCRIPTS}/submit-review.sh \
  --number=${PR_NUMBER} \
  --event=${EVENT_TYPE} \
  --body-file=${REVIEW_DRAFT}
```

> 注：`submit-review.sh` 会自动在 body 末尾追加 `@codex review`，与 `Reviewed-commit` footer 共存，不冲突。

**步骤 E — 提交后校验**

提交完成后，必须回写 `${REVIEW_MODE}` 和 `${HEAD_SHA}` 到本地缓存，供下次 review 校验：

```bash
mkdir -p ${REPO_DIR}/.tmp/pr-review-state
cat > ${REPO_DIR}/.tmp/pr-review-state/${PR_NUMBER}.json <<EOF
{
  "pr_number": ${PR_NUMBER},
  "last_reviewed_oid": "${HEAD_SHA}",
  "review_mode": "${REVIEW_MODE}",
  "submitted_at": "${ISO8601}",
  "verdict": "${VERDICT}"
}
EOF
```

下次 review 时优先读此缓存，避免每次都解析 review body 里的 `Reviewed-commit`。

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
通过 `my-pr-skill` 的 `manage-pr.sh --checks --number=${PR_NUMBER} --json` 确认 PR 状态。合并由用户手动执行。

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

## 模板（按 mode 选择）

模板原文外置在 `templates/`，SKILL.md 只描述**字段约定**和**引用路径**。

### 模板清单

| `${REVIEW_MODE}` | 模板文件 | 用途 |
|------------------|----------|------|
| `first` | [`templates/TPL_FIRST_REVIEW.md`](templates/TPL_FIRST_REVIEW.md) | 首次 review（ce-code-review 驱动）|
| `delta` | [`templates/TPL_RE_REVIEW_DELTA.md`](templates/TPL_RE_REVIEW_DELTA.md) | 增量 review（Prior review trace 表）|
| `re-review-full` | [`templates/TPL_RE_REVIEW_DELTA.md`](templates/TPL_RE_REVIEW_DELTA.md) | 改动过大退化（同一模板，加大变更说明）|
| `merge-blocked` | [`templates/TPL_MERGE_BLOCKED.md`](templates/TPL_MERGE_BLOCKED.md) | 阻塞 / 无法定位上轮 |

### 字段命名约定

- `${AUTO:xxx}` = 从脚本输出自动填充
- `${MANUAL:xxx}` = 人工判断后填充
- `${TABLE_DATA:xxx}` = 表格行，由本 skill 在阶段 2/3 动态生成

### 模板使用流程

```bash
# 1. 选模板
TPL="${REPO_DIR}/.agents/skills/my-pr-review/templates/TPL_${REVIEW_MODE^^//-/_}.md"
# first → TPL_FIRST_REVIEW.md
# delta / re-review-full → TPL_RE_REVIEW_DELTA.md
# merge-blocked → TPL_MERGE_BLOCKED.md

# 2. envsubst 渲染
envsubst < "$TPL" > ${REVIEW_DRAFT}

# 3. 模板填充校验（提交前必跑）
bash ${REPO_DIR}/.agents/skills/my-pr-review/scripts/check-template.sh ${REVIEW_DRAFT}
```

`scripts/check-template.sh` 校验项：
1. 所有 `${AUTO:}` / `${MANUAL:}` / `${TABLE_DATA:}` 字段已替换
2. 必含 `Reviewed-commit:` footer（delta / merge-blocked 必需）
3. `Review Mode:` 标记必须合法

> ⚠️ 校验失败 → **禁止** 调 `submit-review.sh`；先修复 draft，再回到阶段 3 步骤 D。
