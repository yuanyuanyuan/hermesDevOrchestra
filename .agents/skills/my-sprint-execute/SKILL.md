---
name: my-sprint-execute
description: >
  加载指定 Skill（如 TDD），按 Plan 完成指定 Sprint 的开发、验证、提交与 PR 交付。
  包含 Git 分支工作流、顺序执行任务、验证验收、交付流水线、迭代修复与止损处理。
  开发者身份：stark-007（PR Owner）。
---

# Sprint Execute Skill

## 触发条件

当用户要求以下任一操作时激活本 Skill：
- "execute sprint N"
- "完成 sprint N"
- "run sprint N"
- "开发 sprint N"
- "sprint N 交付"
- 任何包含 Sprint 编号和 Plan 路径的开发执行请求

## 调用签名

```
my-sprint-execute <PLAN_PATH> <CHECKLIST_PATH> <SPRINT>
```

- `PLAN_PATH`: Sprint Plan 文件绝对路径（如 `/home/stark/.claude/plans/plan-sprint-8.md`）
- `CHECKLIST_PATH`: 验收清单文件绝对路径（如 `/data/hermes/docs/execution-checklist.md`）
- `SPRINT`: Sprint 编号（如 `8`）

## 环境要求

- `git` 已安装且配置好用户身份
- `my-pr-skill` 已加载（所有 GitHub 操作由其 scripts/ 目录下的脚本完成）
- `gh` CLI 已安装且已认证（由 `my-pr-skill` 底层脚本使用）
- 当前目录 `${REPO_DIR}` 为项目本地仓库
- 具有 `repo` 权限的 GitHub Token（用于发起 PR）

## 变量定义（每次执行时解析）

执行前将以下占位符替换为实际值：

| 变量 | 来源 |
|------|------|
| `${PLAN_PATH}` | 调用参数 `<PLAN_PATH>` |
| `${CHECKLIST_PATH}` | 调用参数 `<CHECKLIST_PATH>` |
| `${SPRINT}` | 调用参数 `<SPRINT>` |
| `${PREV_SPRINT}` | `${SPRINT} - 1` |
| `${SKILL}` | 固定为 `$tdd`（开发方法论 Skill） |
| `${MAX_FIX_ATTEMPTS}` | `3` |
| `${REPO_DIR}` | 当前工作目录（`$(pwd)`） |
| `${BRANCH}` | `feat/sprint${SPRINT}`（可覆盖） |
| `${BASE_BRANCH}` | `main`（可覆盖） |
| `${PR_TITLE}` | 根据 Sprint 工作内容动态生成 |
| `${SPEC_REF}` | 查找本项目相关 spec 文档 |
| `${ADR_REF}` | 查找本项目相关 ADR 文档 |
| `${PR_BODY_FILE}` | `/tmp/pr-body-sprint${SPRINT}.md` |
| `${DEBUG_LOG}` | `/tmp/sprint${SPRINT}-debug.log` |
| `${WORKTREE_DIR}` | `/tmp/wt-sprint${SPRINT}` |
| `${OWNER}` | `my-pr-skill` 脚本 `get-repo-info.sh --owner` |
| `${REPO}` | `my-pr-skill` 脚本 `get-repo-info.sh --repo` |
| `${MY_PR_SKILL_SCRIPTS}` | `my-pr-skill` 的 scripts 目录路径 |
| `${PR_TYPE}` | `feat` / `fix` / `docs` / `infra` / `chore`，决定 PR body 模板 |
| `${COMMITS_JSON}` | `git log origin/${BASE_BRANCH}..HEAD --pretty=format:'{"sha":"%h","subject":"%s","type":"%s"},'` 解析为 JSON |
| `${VERIFICATION_REPORT}` | `/tmp/sprint${SPRINT}-verification.md`（独立 verification 报告，可附在 PR body 内）|

---

## 执行流程

### 阶段 1：GIT 分支工作流（GIT WORKFLOW）

**工作流选择策略：**

**步骤 A — 环境准备**

拉取远程更新并确保 `${BASE_BRANCH}` 为最新：
```bash
git fetch origin ${BASE_BRANCH}
git checkout ${BASE_BRANCH}
git reset --hard origin/${BASE_BRANCH}
```

**步骤 B — 创建/切换分支**

必须从**远端最新的 `origin/${BASE_BRANCH}`** 创建 `${BRANCH}`，禁止从本地可能过期的 `${BASE_BRANCH}` 直接切出：
```bash
git checkout -b ${BRANCH} origin/${BASE_BRANCH}
```
如分支已存在，先删除本地分支再从远端最新 `${BASE_BRANCH}` 重建，或执行 rebase 到 `origin/${BASE_BRANCH}`。

**步骤 C — 提交规范（Conventional Commits）**

每完成一个子任务提交一次，**必须使用 `TPL_COMMIT_MSG` 模板**（见末尾"模板"章节）：

```bash
# 1. 选择 commit type
case "${SUBTASK_KIND}" in
  feature)        COMMIT_TYPE="feat" ;;
  bugfix)         COMMIT_TYPE="fix" ;;
  doc)            COMMIT_TYPE="docs" ;;
  test)           COMMIT_TYPE="test" ;;
  refactor)       COMMIT_TYPE="refactor" ;;
  perf)           COMMIT_TYPE="perf" ;;
  build|ci|infra) COMMIT_TYPE="chore" ;;
  *)              COMMIT_TYPE="feat" ;;  # 兜底
esac

# 2. 用模板生成 commit message
export COMMIT_TYPE SUBTASK_NAME SUBTASK_DESC
envsubst < ${REPO_DIR}/.agents/skills/my-sprint-execute/templates/TPL_COMMIT_MSG.md

# 3. commit
git commit -F - <<EOF
$(envsubst < ${REPO_DIR}/.agents/skills/my-sprint-execute/templates/TPL_COMMIT_MSG.md)
EOF
```

格式参考：
- 功能提交：`feat(sprint-${SPRINT}): [子任务名] — [一句话描述]`
- 修复提交：`fix(sprint-${SPRINT}): [修复描述]`
- 文档提交：`docs(sprint-${SPRINT}): [文档描述]`

**步骤 E — 推送与 PR**

推送代码后，通过 `my-pr-skill` 的 `manage-pr.sh` 发起 PR。

**步骤 F — 冲突处理（如果 rebase/push 遇到冲突）**

1. 停止执行，报告冲突文件列表
2. 不允许自动解决冲突（需人类判断）
3. 记录冲突上下文到 `${DEBUG_LOG}`

---

### 阶段 2：执行顺序（SEQUENTIAL）

**加载开发方法论 Skill：**
```
$tdd
```

按 Sprint `${SPRINT}` 内部任务顺序逐个完成，每完成一个子任务：
1. **实现代码/配置** — 根据 Plan 和当前子任务描述进行开发
2. **运行对应验证脚本** — 确认 exit 0
3. **git add + git commit** — 遵循阶段 1 的提交规范
4. **进入下一个子任务**

---

### 阶段 3：验证与验收（VERIFICATION）

**步骤 A — 读取验收清单**

```bash
cat ${CHECKLIST_PATH} | grep -A 50 "Sprint ${SPRINT}"
```

**步骤 B — 逐项执行验证（必须全部 exit 0）**

```bash
bash scripts/tests/test-runtime-knowledge.sh
python -m jsonschema -i config/knowledge/runtime-kb.json config/schemas/orchestra.full.schema.json
# 如果 gbrain 可用，额外验证：
which gbrain && gbrain --version || echo "gbrain not available, using degraded path"
```

注意：以上验证命令为示例，实际执行时应根据 `${PLAN_PATH}` 和项目结构确定具体验证脚本。

**步骤 B.5 — 生成 Verification Report（用 `TPL_VERIFICATION_REPORT` 模板）**

每条验证命令执行后，将结果追加到 `${VERIFICATION_REPORT}`，最后在 PR body 中引用：

```bash
touch ${VERIFICATION_REPORT}

# 对每条验证命令
for cmd in "${VERIFICATION_CMDS[@]}"; do
  echo "## \$ $cmd" >> ${VERIFICATION_REPORT}
  echo '```' >> ${VERIFICATION_REPORT}
  eval "$cmd" >> ${VERIFICATION_REPORT} 2>&1
  echo '```' >> ${VERIFICATION_REPORT}
  echo "" >> ${VERIFICATION_REPORT}
done
```

报告结构（见末尾模板）：

- 测试套件（按 spec / 单元 / 集成分组）
- Schema 验证
- Lint / Type check
- 性能基准（如适用）
- 边界用例覆盖

**步骤 C — 标记完成**

在 `${CHECKLIST_PATH}` 中 Sprint `${SPRINT}` 段落下追加：
```
[YYYY-MM-DD] Verified by Codex — all tests passed
```

---

### 阶段 4：交付流水线（DELIVERY PIPELINE）

**步骤 A — 自动检测 `${PR_TYPE}`**

```bash
# 根据 ${COMMITS_JSON} 中 commit type 决定 PR 类型
PR_TYPE=$(echo "${COMMITS_JSON}" | jq -r '
  group_by(.type)
  | map({type: .[0].type, count: length})
  | sort_by(-.count)
  | .[0].type
')
# e.g. feat / fix / docs / chore
```

**步骤 B — 选择 PR body 模板并填充**

按 `${PR_TYPE}` 选择对应模板（见末尾"模板"章节）：

| `${PR_TYPE}` | 模板 | 用途 |
|--------------|------|------|
| `feat` | `TPL_PR_BODY_FEAT` | 新功能 / 增强 |
| `fix` | `TPL_PR_BODY_FIX` | Bug 修复（需含 regression test）|
| `docs` | `TPL_PR_BODY_DOCS` | 纯文档（无代码变更）|
| `infra` / `chore` | `TPL_PR_BODY_INFRA` | 构建 / CI / 依赖 |
| `mixed`（默认）| `TPL_PR_BODY_FEAT` | 含多种 commit type，按主类型走 |

**生成流程：**

```bash
# 1. 选模板
TPL="${REPO_DIR}/.agents/skills/my-sprint-execute/templates/TPL_PR_BODY_${PR_TYPE^^}.md"
[[ -f "$TPL" ]] || TPL="${REPO_DIR}/.agents/skills/my-sprint-execute/templates/TPL_PR_BODY_FEAT.md"

# 2. 用 envsubst 渲染
export SPRINT PR_TITLE PLAN_PATH SPEC_REF ADR_REF COMMITS_JSON
envsubst < "$TPL" > ${PR_BODY_FILE}

# 3. 嵌入 verification report（如模板含占位符 ${VERIFICATION_REPORT_INLINE}）
if grep -q '\${VERIFICATION_REPORT_INLINE}' ${PR_BODY_FILE}; then
  sed -i "/\${VERIFICATION_REPORT_INLINE}/r ${VERIFICATION_REPORT}" ${PR_BODY_FILE}
  sed -i '/\${VERIFICATION_REPORT_INLINE}/d' ${PR_BODY_FILE}
fi

# 4. 模板填充校验（提交前必跑）
bash ${REPO_DIR}/.agents/skills/my-sprint-execute/scripts/check-pr-body.sh \
  --file=${PR_BODY_FILE} --type=${PR_TYPE}
```

> 注：`manage-pr.sh --create` 原样传递 PR body 内容，不会追加额外 footer。

**步骤 C — 发起 PR**

```bash
# 推送代码
git push -u origin ${BRANCH}

# 发起 PR（manage-pr.sh 会自动追加 @codex review footer）
${MY_PR_SKILL_SCRIPTS}/manage-pr.sh --create \
  --title="${PR_TITLE}" \
  --head=${BRANCH} \
  --base=${BASE_BRANCH} \
  --body-file=${PR_BODY_FILE}
```

**PR 发起后：**
- 推送最新 commit 到 `origin/${BRANCH}`
- 确保 PR 关联到正确的 milestone/label（如果有）
- **不自动合并**，等待 review

> 注：4 个 PR body 模板的渲染示例见末尾"模板"章节，覆盖 90% 的 sprint 场景。

---

### 阶段 5：约束与边界（CONSTRAINTS & BOUNDARIES）

**硬性约束：**
- 不实现 Sprint `${SPRINT}` 范围外的任何内容
- 不修改现有 MVP 代码（如 `scripts/lib/orch_gateway.py` 等核心模块，除非 Plan 明确要求）
- 不修改其他 Sprint 的配置或测试脚本
- 不自动合并 PR（仅发起，等待 review）
- 不删除 `${BASE_BRANCH}` 或任何现有 release tags

**写权限边界（可修改）：**
- Sprint `${SPRINT}` Plan 中明确指定的文件
- 新增文件（测试、配置、文档等）
- `${PR_BODY_FILE}`、`${DEBUG_LOG}`

**只读边界（仅参考，禁止写入）：**
- 其他 Sprint 的配置和测试脚本
- `${BASE_BRANCH}` 上的已有代码（除非通过 rebase/merge）
- 现有 release tags

---

### 阶段 6：迭代策略（ITERATION POLICY）

每轮失败后的下一步：
1. 记录失败测试名和错误输出摘要（写入 `${DEBUG_LOG}`）
2. 检查最近 3 次 diff 是否引入回归
3. 尝试修复（限制在 `${MAX_FIX_ATTEMPTS}` 次内）
4. 修复后重新运行完整验证套件，不跳过任何步骤
5. 如果修复成功，`git commit --amend` 或新增 fix 提交

---

### 阶段 7：止损条件（BLOCKED STOP）

**立即停止并报告 blocker 的情况：**
- 任一验证脚本运行 `${MAX_FIX_ATTEMPTS}` 次仍失败
- Sprint `${SPRINT}` 前置依赖文件缺失（如 Sprint `${PREV_SPRINT}` 交付物不存在）
- `config/knowledge/runtime-kb.json` 缺失或 schema 验证失败（项目特定，根据实际调整）
- `gbrain` 不可用且降级路径也无法实现（如 Sprint 有特殊依赖）
- `my-pr-skill` 脚本不可用且无法生成手动 PR 指令
- `git rebase` 冲突无法自动解决

**报告格式（必须包含）：**
- Blocker 类型：`test-failure` / `missing-prereq` / `tool-unavailable` / `git-conflict` / `unknown`
- 最后执行的命令及输出（前 50 行）
- 已尝试的修复次数和方式
- 解锁所需的人类输入

**BLOCKER STOP POLICY：**
- 一旦命中 blocker，立即退出执行流程，并停止 goal
- 不得继续任何后续步骤
- 不得再次运行相同验证命令
- 不得重复输出同一 blocker 报告
- 只允许在用户提供新的解除信息后恢复执行

---

## 模板（Templates）

模板原文外置在 `templates/`，SKILL.md 只描述**字段约定**和**引用路径**。

### 模板清单

| 用途 | 模板文件 | 校验 type |
|------|----------|----------|
| Commit 消息 | [`templates/TPL_COMMIT_MSG.md`](templates/TPL_COMMIT_MSG.md) | — |
| 新功能 PR | [`templates/TPL_PR_BODY_FEAT.md`](templates/TPL_PR_BODY_FEAT.md) | `feat` |
| Bug 修复 PR | [`templates/TPL_PR_BODY_FIX.md`](templates/TPL_PR_BODY_FIX.md) | `fix` |
| 纯文档 PR | [`templates/TPL_PR_BODY_DOCS.md`](templates/TPL_PR_BODY_DOCS.md) | `docs` |
| 构建/CI PR | [`templates/TPL_PR_BODY_INFRA.md`](templates/TPL_PR_BODY_INFRA.md) | `infra` |
| 验证报告 | [`templates/TPL_VERIFICATION_REPORT.md`](templates/TPL_VERIFICATION_REPORT.md) | — |

### 字段命名约定

- `${AUTO:xxx}` = 从脚本输出自动填充
- `${MANUAL:xxx}` = 人工判断后填充
- `${VERIFICATION_REPORT_INLINE}` = 嵌入 `${VERIFICATION_REPORT}` 全文
- `${COMMITS_TABLE}` = 自动生成 commit 列表（由 `render-commits.sh` 渲染）

### 模板使用流程

```bash
# 1. 选模板（按 ${PR_TYPE}）
TPL="${REPO_DIR}/.agents/skills/my-sprint-execute/templates/TPL_PR_BODY_${PR_TYPE^^}.md"
# feat / fix / docs / infra

# 2. envsubst 渲染
envsubst < "$TPL" > ${PR_BODY_FILE}

# 3. 嵌入 ${COMMITS_TABLE}（如有占位符）
if grep -q '\${COMMITS_TABLE}' ${PR_BODY_FILE}; then
  COMMITS_JSON=$(git log origin/${BASE_BRANCH}..HEAD --pretty=format:'{"sha":"%h","type":"%s","subject":"%s","files":[]},' | jq -s '.')
  COMMITS_TABLE=$(COMMITS_JSON="$COMMITS_JSON" bash ${REPO_DIR}/.agents/skills/my-sprint-execute/scripts/render-commits.sh)
  envsubst < ${PR_BODY_FILE} > ${PR_BODY_FILE}.tmp && mv ${PR_BODY_FILE}.tmp ${PR_BODY_FILE}
fi

# 4. 嵌入 ${VERIFICATION_REPORT_INLINE}（如有占位符）
if grep -q '\${VERIFICATION_REPORT_INLINE}' ${PR_BODY_FILE}; then
  sed -i "/\${VERIFICATION_REPORT_INLINE}/r ${VERIFICATION_REPORT}" ${PR_BODY_FILE}
  sed -i '/\${VERIFICATION_REPORT_INLINE}/d' ${PR_BODY_FILE}
fi

# 5. 模板填充校验（发起 PR 前必跑）
bash ${REPO_DIR}/.agents/skills/my-sprint-execute/scripts/check-pr-body.sh \
  --file=${PR_BODY_FILE} --type=${PR_TYPE}
```

`scripts/check-pr-body.sh` 校验项（`--type` 决定）：
1. 通用：所有 `${AUTO:}` / `${MANUAL:}` / `${VERIFICATION_REPORT_INLINE}` / `${COMMITS_TABLE}` 全部已替换
2. `feat` 模式：5 个强制章节（需求来源/实现摘要/测试覆盖/验收状态/Reviewer 重点关注）
3. `fix` 模式：必须含 `### Regression Test` + `修复前 FAIL` 证据
4. `docs` 模式：3 个强制章节（文档变更/影响范围/验收状态）
5. `infra` 模式：必须含 `### 兼容性 / 风险评估` + `### 回滚方案`
6. 通用：所有验收 checkbox 必须全部勾选

> ⚠️ 校验失败 → **禁止** 调 `manage-pr.sh --create`；回到阶段 4 修复。
