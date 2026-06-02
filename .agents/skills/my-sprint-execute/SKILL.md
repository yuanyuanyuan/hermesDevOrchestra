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

每完成一个子任务提交一次，格式：
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

**步骤 C — 标记完成**

在 `${CHECKLIST_PATH}` 中 Sprint `${SPRINT}` 段落下追加：
```
[YYYY-MM-DD] Verified by Codex — all tests passed
```

---

### 阶段 4：交付流水线（DELIVERY PIPELINE）

**PR Body 生成（自动写入 `${PR_BODY_FILE}`）**

```markdown
## Sprint ${SPRINT}: ${PR_TITLE}

### 需求来源
- ${PLAN_PATH} Sprint ${SPRINT}
- ${SPEC_REF}
- ${ADR_REF}

### 实现摘要
- 新增/修改文件：[列出]
- 核心逻辑说明：[描述]

### 测试证据
```
[粘贴验证脚本完整通过输出]
```

### 验收状态
- [x] checklist Sprint ${SPRINT} 所有项已勾选
- [x] 全部测试 exit 0
```

**PR 发起后：**
- 推送最新 commit 到 `origin/${BRANCH}`
- 确保 PR 关联到正确的 milestone/label（如果有）
- **不自动合并**，等待 review

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
