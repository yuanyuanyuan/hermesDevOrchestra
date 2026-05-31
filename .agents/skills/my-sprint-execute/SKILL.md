---
name: my-sprint-execute
description: >
  按 Plan 完成指定 Sprint 的开发、验证、提交与 PR 交付。
  包含前置依赖确认、Git 分支工作流、架构红线门控、顺序执行任务（含四级 Checklist 验收）、
  负向测试执行、Schema 同步验证、交付流水线、迭代修复与止损处理。
  需要由 /my-sprint-plan（Codex: $my-sprint-plan）先生成 Plan 和 Checklist 文件。
  触发词：execute sprint N、完成 sprint N、run sprint N、开发 sprint N、sprint N 交付。
  开发者身份：stark-007（PR Owner）。
---

# Sprint Execute Skill（增强版 v2）

> v2 核心改进（与 /my-sprint-plan v2 对应）：
> 1. **阶段 0 前置依赖确认**：检查上游 Sprint 完成状态和接口契约就绪性
> 2. **架构红线门控**：执行前检查是否向单一大文件堆叠，helper module 是否到位
> 3. **四级 Checklist 验收**：按"架构红线→功能验收→测试覆盖→文档同步"顺序执行，每级阻断
> 4. **模糊词处理**：遇到 ⚠️ 标记的验收项，必须先补充量化定义才能验收
> 5. **负向测试执行**：必须实现并运行负向测试/边界条件
> 6. **Schema 同步验证**：验收时验证 schema.md ↔ schema.json ↔ 实现 三重一致
> 7. **风险降级策略**：修复失败时执行 Plan 中定义的降级方案，而非无限重试

## 调用签名

```
my-sprint-execute <PLAN_PATH> <CHECKLIST_PATH> <SPRINT>
```

- `PLAN_PATH`: Sprint Plan 文件绝对路径（由 /my-sprint-plan 生成）
- `CHECKLIST_PATH`: 验收清单文件绝对路径（由 /my-sprint-plan 生成）
- `SPRINT`: Sprint 编号（如 `8`）

## 环境要求

- `git` 已安装且配置好用户身份
- `gh` CLI 已安装且已认证（`gh auth status` 通过）
- 当前目录 `${REPO_DIR}` 为项目本地仓库
- 具有 `repo` 权限的 GitHub Token（用于发起 PR）
- `jq` 已安装（用于解析 Plan/Checklist 结构）

## 变量定义（每次执行时解析）

| 变量 | 来源 |
|------|------|
| `${PLAN_PATH}` | 调用参数 `<PLAN_PATH>` |
| `${CHECKLIST_PATH}` | 调用参数 `<CHECKLIST_PATH>` |
| `${SPRINT}` | 调用参数 `<SPRINT>` |
| `${PREV_SPRINT}` | `${SPRINT} - 1` |
| `${SKILL}` | 固定为 `/tdd`（Codex: `$tdd`，开发方法论 Skill） |
| `${MAX_FIX_ATTEMPTS}` | `3` |
| `${MAX_REGRESS_ATTEMPTS}` | `3`（对应规划端四阶回归上限） |
| `${REPO_DIR}` | 当前工作目录（`$(pwd)`） |
| `${BRANCH}` | `feat/sprint${SPRINT}`（可覆盖） |
| `${BASE_BRANCH}` | `main`（可覆盖） |
| `${PR_TITLE}` | 根据 Sprint 工作内容动态生成 |
| `${SPEC_REF}` | 查找本项目相关 spec 文档 |
| `${ADR_REF}` | 查找本项目相关 ADR 文档 |
| `${PR_BODY_FILE}` | `/tmp/pr-body-sprint${SPRINT}.md` |
| `${DEBUG_LOG}` | `/tmp/sprint${SPRINT}-debug.log` |
| `${WORKTREE_DIR}` | `/tmp/wt-sprint${SPRINT}` |
| `${OWNER}` | `gh repo view --json owner --jq '.owner.login'` |
| `${REPO}` | `gh repo view --json name --jq '.name'` |

---

## 阶段 0：前置依赖与契约确认（PREREQUISITE CHECK）

> **本阶段为 v2 新增。任何一项不通过，立即 BLOCKED STOP。**

**步骤 A — 读取 Plan 中的前置依赖**

```bash
# 从 plan-sprint-N.md 中提取前置依赖状态
DEPS=$(grep "前置依赖状态" "${PLAN_PATH}" | sed 's/.*://')
echo "前置依赖: ${DEPS}"
```

**步骤 B — 确认上游 Sprint 已完成**

1. 读取 `${PLAN_PATH}` 中"前置依赖状态"段落
2. 如果存在上游 Sprint 依赖（如 U5 依赖 U4）：
   - 检查上游 Sprint 的 checklist 是否已签核（所有 checkbox 已勾选）
   - 检查上游 Sprint 的 PR 是否已合并到 `${BASE_BRANCH}`
   - 检查上游 Sprint 输出的 helper modules / schema 是否已就绪并可导入
3. 如果上游 Sprint 未完成 → **BLOCKED STOP**（类型：`missing-prereq`）

**步骤 C — 确认接口契约就绪**

1. 读取 `${PLAN_PATH}` 中"接口契约变更"段落
2. 如果本 Sprint 需要消费上游契约：
   - 验证契约定义的数据格式、schema 版本、关键字段是否已文档化
   - 验证契约对应的 artifact / 配置文件是否存在于仓库中
3. 如果契约未就绪 → **BLOCKED STOP**（类型：`contract-not-ready`）

**步骤 D — 确认模糊词已量化**

1. 读取 `${CHECKLIST_PATH}` 中"功能验收"段落
2. 扫描是否存在 ⚠️ 标记（`[需量化]` / `包含不可量化词汇`）
3. 如果存在未量化的验收项：
   - **不立即阻断**，但必须在实现前补充量化定义
   - 将量化定义写入 `${PLAN_PATH}` 的对应验收标准中
   - 补充后移除 ⚠️ 标记

---

## 阶段 1：GIT 分支工作流（GIT WORKFLOW）

**工作流选择策略（v2 增强）：**

**默认使用 worktree 模式**（强制隔离，避免污染当前工作区）：
```bash
git worktree add ${WORKTREE_DIR} -b ${BRANCH} 2>/dev/null || git worktree add ${WORKTREE_DIR} ${BRANCH}
cd ${WORKTREE_DIR}
```

仅在以下情况退化为 feature branch 模式：
- worktree 创建失败（磁盘空间不足、文件系统不支持）
- 当前工作区无任何未提交改动且分支切换无副作用

**使用完毕后必须清理：**
```bash
cd ${REPO_DIR}
git worktree remove ${WORKTREE_DIR}
git worktree prune
```

**步骤 A — 环境准备**

```bash
cd ${REPO_DIR}
git fetch origin
git checkout ${BASE_BRANCH}
git pull origin ${BASE_BRANCH}
```

**步骤 B — 创建/切换分支（在 worktree 中）**

```bash
cd ${WORKTREE_DIR}
git rebase ${BASE_BRANCH} || (git rebase --abort && echo "Rebase failed, manual merge needed")
```

**步骤 C — 提交规范（Conventional Commits）**

每完成一个子任务提交一次，格式：
- 功能提交：`feat(sprint-${SPRINT}): [子任务名] — [一句话描述]`
- 修复提交：`fix(sprint-${SPRINT}): [修复描述]`
- 文档提交：`docs(sprint-${SPRINT}): [文档描述]`
- **架构重构提交**：`refactor(sprint-${SPRINT}): 抽取 [module] 到 [path]`
- **测试提交**：`test(sprint-${SPRINT}): [正向/负向]测试 [场景名]`

**步骤 D — 推送与 PR**

```bash
cd ${WORKTREE_DIR}
git push -u origin ${BRANCH}
gh pr create \
  --title "feat(sprint-${SPRINT}): ${PR_TITLE}" \
  --body-file ${PR_BODY_FILE} \
  --base ${BASE_BRANCH} \
  --head ${BRANCH} \
  --repo ${OWNER}/${REPO} 2>/dev/null || echo "PR may already exist"
```

**步骤 E — 冲突处理**

1. 停止执行，报告冲突文件列表
2. 不允许自动解决冲突（需人类判断）
3. 记录冲突上下文到 `${DEBUG_LOG}`

---

## 阶段 2：执行顺序（SEQUENTIAL）

**加载开发方法论 Skill：** `/tdd`（Codex: `$tdd`）

读取 `${PLAN_PATH}`，按任务清单顺序逐个完成。每个 Task 的执行流程：

### 2A — 架构红线检查（v2 新增，执行代码前必须完成）

```markdown
- [ ] 本 Task 是否涉及向单一大文件（>3000 行）新增逻辑？
  - 是 → 必须先抽取 helper module，禁止直接堆叠
  - 否 → 继续
- [ ] 是否需要新增 helper module？
  - 是 → 先创建 helper module + 单元测试，再修改原文件
  - 否 → 继续
- [ ] 新增代码在原文件中的占比是否 < 20%？
  - 否 → 重新拆分 Task 或抽取更多 helper
```

**如果架构红线检查不通过 → 停止当前 Task，先完成 seam extraction。**

### 2B — 读取 Approach 和测试矩阵

1. 读取 `${PLAN_PATH}` 中当前 Task 的 Approach 段落
2. 读取测试矩阵（Test Scenario → 验证方式 → 预期结果 → 测试脚本）
3. 读取风险与降级策略

### 2C — 实现代码/配置

根据 Plan 的 Approach 和当前子任务描述进行开发：
1. 按 TDD 红-绿-重构循环开发
2. 优先实现 helper module，再在原文件中调用
3. 同步更新 schema.md / schema.json（如有数据模型变更）

### 2D — 实现测试（含负向测试）

1. **正向测试**：实现测试矩阵中每个 Test Scenario 对应的测试脚本
2. **负向测试**：实现 `${PLAN_PATH}` 中"负向测试/边界条件"列出的用例（≥2 条）
3. **回归测试**：运行本 Sprint 相关的全部测试，确认通过

### 2E — 验证与提交

1. 运行对应验证脚本 → 确认 exit 0
2. `git add + git commit` → 遵循阶段 1 的提交规范
3. **更新 Checklist** — 在 `${CHECKLIST_PATH}` 中勾选对应项
4. **进入下一个子任务**

---

## 阶段 3：验证与验收（VERIFICATION — 四级结构）

> v2 核心增强：按 Checklist 的四级结构顺序验收，**任何一级不通过则整体不通过**。

### 3A — 一级验收：架构红线合规

```bash
# 检查清单（全部通过才能进入下一级）
```

- [ ] 新增逻辑优先落入 helper modules，非直接堆叠单一大文件
  - 验证方法：统计本 Sprint 新增代码行在各文件中的分布
  - 通过标准：单文件新增占比 < 20%，或已抽取独立 helper
- [ ] 若修改了单一大文件，已抽取独立 helper 并附带单元测试
- [ ] 接口契约变更已同步到 schema.md / schema.json
- [ ] 自动化 schema↔实现一致性校验通过（如有 schema 变更）

**任何一项不通过 → 回到阶段 2 重新实现，或 BLOCKED STOP（类型：`architecture-guardrail-violation`）**

### 3B — 二级验收：功能验收

读取 `${CHECKLIST_PATH}` 中"功能验收"段落，**逐条独立执行**：

```bash
# 对每条验收标准：
for item in $(grep "^\- \[ \]" "${CHECKLIST_PATH}" | grep -A1 "功能验收"); do
  # 1. 读取验证方式
  # 2. 执行验证命令
  # 3. 对比通过标准
  # 4. 通过则勾选，不通过则记录失败原因
done
```

**模糊词处理规则：**
- 如果验收项包含 ⚠️ 标记（`[需量化]`）：
  1. 检查开发者是否已在实现过程中补充了量化定义
  2. 如果已补充 → 移除 ⚠️ 标记，执行验证
  3. 如果未补充 → **BLOCKED STOP**（类型：`unquantified-acceptance-criteria`）

**任何一项功能验收不通过 → 进入阶段 6 迭代修复**

### 3C — 三级验收：测试覆盖

#### 3C.1 正向测试（Test Scenarios）

读取 `${CHECKLIST_PATH}` 中"正向测试"表格，逐行执行：
- 运行每个 Test Scenario 对应的测试脚本
- 确认 exit 0 且输出包含 "PASS"
- 在 Checklist 中勾选对应项

#### 3C.2 负向测试 / 边界条件

读取 `${PLAN_PATH}` 中"负向测试/边界条件"段落，逐条执行：
- 运行负向测试脚本
- 确认系统在异常/越界/降级场景下的行为符合预期
- **关键原则**：负向测试的"通过"不一定是 exit 0，而是"系统正确阻塞/失败/降级"

#### 3C.3 回归测试

- 运行本 Sprint 相关测试套件，全部 exit 0
- 运行上游依赖 Sprint 的核心测试，确认仍通过
- 非本 Sprint 测试失败不阻塞交付，但需确认不影响 main 稳定性

**任何一项测试不通过 → 进入阶段 6 迭代修复**

### 3D — 四级验收：文档 / Schema / 配置同步

- [ ] 所有涉及文件变更已逐项确认（Create/Modify → Verify）
  - 验证：对比 Plan 中的"涉及文件"列表与实际 git diff
- [ ] schema.md 与 schema.json 字段名/类型/约束一致（差异 0 项）
  - 验证：运行 schema 一致性校验脚本（如 `test-schema-doc-sync.sh`）
- [ ] 用户流程文档已同步更新
  - 验证：检查文档中是否提及本 Sprint 的新功能/变更
- [ ] ADR / 架构文档已同步更新（如有架构变更）
- [ ] 配置变更已验证向后兼容
  - 验证：旧配置在新代码中仍能正常加载
- [ ] 向下游 Sprint 的接口契约已文档化
  - 验证：在 Plan 中已填写"向下游输出契约"

**任何一项不通过 → 回到阶段 2 补充文档/配置，或 BLOCKED STOP**

### 3E — 标记完成

四级验收全部通过后，在 `${CHECKLIST_PATH}` 中 Sprint `${SPRINT}` 段落下追加：
```
[YYYY-MM-DD] Verified by Codex — 四级验收全部通过
  - 架构红线合规: ✅
  - 功能验收: ✅ (N/N 条)
  - 测试覆盖: ✅ (正向 N/N, 负向 N/N, 回归通过)
  - 文档/Schema/配置同步: ✅
```

---

## 阶段 4：交付流水线（DELIVERY PIPELINE）

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
- **架构红线合规说明**：[helper module 抽取情况 / 单文件新增占比]

### 测试证据
#### 正向测试
| # | Scenario | 脚本 | 结果 |
|---|----------|------|------|
| 1 | ... | ... | PASS |

#### 负向测试
| # | 场景 | 预期行为 | 结果 |
|---|------|----------|------|
| 1 | ... | 阻塞/失败/降级 | PASS |

#### 回归测试
```
[粘贴回归测试完整通过输出]
```

### 四级验收状态
- [x] **一级：架构红线合规** — helper module 优先，新增代码单文件占比 < 20%
- [x] **二级：功能验收** — N/N 条全部通过
- [x] **三级：测试覆盖** — 正向 N/N, 负向 N/N, 回归通过
- [x] **四级：文档/Schema/配置同步** — schema 一致性校验通过

### 接口契约
- 向下游 Sprint 输出：[契约名称/格式/版本]
- 前置依赖状态：[上游 Sprint 已完成并合并]
```

**PR 发起后：**
- 推送最新 commit 到 `origin/${BRANCH}`
- 确保 PR 关联到正确的 milestone/label（如果有）
- **不自动合并**，等待 review

---

## 阶段 5：约束与边界（CONSTRAINTS & BOUNDARIES）

**硬性约束：**
- 不实现 Sprint `${SPRINT}` 范围外的任何内容
- 不修改现有 MVP 代码（除非 Plan 明确要求）
- 不修改其他 Sprint 的配置或测试脚本
- 不自动合并 PR（仅发起，等待 review）
- 不删除 `${BASE_BRANCH}` 或任何现有 release tags
- **不违反架构红线**（禁止向单一大文件直接堆叠逻辑，必须先抽取 helper）

**写权限边界（可修改）：**
- Sprint `${SPRINT}` Plan 中明确指定的文件
- 新增文件（测试、配置、文档、helper modules 等）
- `${PR_BODY_FILE}`、`${DEBUG_LOG}`

**只读边界（仅参考，禁止写入）：**
- 其他 Sprint 的配置和测试脚本
- `${BASE_BRANCH}` 上的已有代码（除非通过 rebase/merge）
- 现有 release tags

---

## 阶段 6：迭代策略（ITERATION POLICY）

> v2 增强：增加降级/回滚路径，对应规划端的"风险与降级策略"。

每轮失败后的下一步：

1. **记录失败**：记录失败测试名和错误输出摘要（写入 `${DEBUG_LOG}`）
2. **检查回归**：检查最近 3 次 diff 是否引入回归
3. **尝试修复**（限制在 `${MAX_FIX_ATTEMPTS}` 次内）：
   - 分析失败根因
   - 修改代码/测试
   - 重新运行完整验证套件
4. **修复成功**：`git commit --amend` 或新增 fix 提交
5. **修复失败（达到 `${MAX_FIX_ATTEMPTS}`）**：
   - 读取 `${PLAN_PATH}` 中当前 Task 的"风险与降级策略"
   - **执行降级方案**（如：回滚到上一个稳定 commit、使用 mock 替代真实实现、跳过非核心功能）
   - 如果降级方案也无法执行 → **BLOCKED STOP**（类型：`fix-failed-after-max-attempts`）

**回归循环上限（对应规划端四阶改进）：**
- 同一问题最多修复 `${MAX_REGRESS_ATTEMPTS}`（3）次
- 第 3 次仍失败 → 不再自动重试，必须执行降级方案或上报审批

---

## 阶段 7：止损条件（BLOCKED STOP）

**立即停止并报告 blocker 的情况：**

| Blocker 类型 | 触发条件 |
|--------------|----------|
| `missing-prereq` | 前置 Sprint 未完成或上游接口契约未就绪 |
| `contract-not-ready` | 消费的接口契约数据格式/schema未定义 |
| `unquantified-acceptance-criteria` | 验收标准含 ⚠️ 模糊词标记且未补充量化定义 |
| `architecture-guardrail-violation` | 违反架构红线（向单一大文件堆叠、未抽取 helper） |
| `schema-sync-failed` | schema.md ↔ schema.json ↔ 实现 三方不一致 |
| `test-failure` | 任一验证脚本运行 `${MAX_FIX_ATTEMPTS}` 次仍失败且降级方案无效 |
| `fix-failed-after-max-attempts` | 同一问题修复 `${MAX_FIX_ATTEMPTS}` 次仍失败 |
| `regress-limit-exceeded` | 同一问题回归超过 `${MAX_REGRESS_ATTEMPTS}`（3）次 |
| `missing-prereq-file` | Sprint `${SPRINT}` 前置依赖文件缺失 |
| `tool-unavailable` | `gh` CLI 不可用且无法生成手动 PR 指令 |
| `git-conflict` | `git rebase` 冲突无法自动解决 |
| `worktree-failure` | worktree 创建失败或清理失败 |
| `unknown` | 未预期错误 |

**报告格式（必须包含）：**
- Blocker 类型（见上表）
- 最后执行的命令及输出（前 50 行）
- 已尝试的修复次数和方式
- 当前所在的四级验收级别（如：三级验收-负向测试失败）
- 解锁所需的人类输入

**BLOCKED STOP POLICY：**
- 一旦命中 blocker，立即退出执行流程，并停止 goal
- 不得继续任何后续步骤
- 不得再次运行相同验证命令
- 不得重复输出同一 blocker 报告
- 只允许在用户提供新的解除信息后恢复执行

---

## 与 /my-sprint-plan 的衔接

```
/my-sprint-plan <PRD_PATH> --output <SPRINTS_DIR>
  ↓
生成 plan-sprint-N.md + checklist-sprint-N.md
  ↓
/my-sprint-execute <SPRINTS_DIR>/plan-sprint-N.md <SPRINTS_DIR>/checklist-sprint-N.md N
  ↓
按四级 Checklist 执行 → PR
```
