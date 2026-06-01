---
name: my-sprint-execute
description: >
  按 Plan 完成指定 Sprint 的开发、验证、提交与 PR 交付。
  流程：前置依赖确认 → Git 分支工作流 → Team Topology 多 Agent 协作执行
  → 四级 Checklist 验收（含团队交叉 Review 门控） → 负向测试 → Schema 同步验证 → PR 交付。
  支持 solo / pair / trio 自动推断，Batch 内无依赖 Task 并行 dispatch。
  触发词：execute sprint N、完成 sprint N、run sprint N、开发 sprint N、sprint N 交付。
  开发者身份：stark-007（PR Owner）。
---

# Sprint Execute Skill

> 多 Agent 协作执行 Sprint。自动推断团队拓扑（solo/pair/trio），Batch 内并行 dispatch，四级验收 + 交叉 Review 门控。
> 需先由 /my-sprint-plan 生成 Plan 和 Checklist。

## TL;DR

```
读取 Plan + Checklist
  → 阶段0 前置依赖确认（不通过则 BLOCKED）
  → 阶段1 Git 工作流（切 feature branch）
  → 阶段2 Team 协作执行（拓扑推断 → Batch 调度 → dispatch → 交叉 Review → 合并）
  → 阶段3 四级验收（架构红线 → 功能 → 测试 → 文档同步）
  → 阶段4 PR 交付
```

## 调用签名

```
my-sprint-execute <PLAN_PATH> <CHECKLIST_PATH> <SPRINT> [--team-topology <auto|solo|pair|trio>] [--max-parallel-teams <N>]
```

| 参数 | 说明 |
|------|------|
| `PLAN_PATH` | Sprint Plan 绝对路径（由 /my-sprint-plan 生成） |
| `CHECKLIST_PATH` | 验收清单绝对路径 |
| `SPRINT` | Sprint 编号（如 `8`） |
| `--team-topology` | 强制拓扑模式（默认 `auto`） |
| `--max-parallel-teams` | 最大并行 Team 数（默认 `3`） |

## 环境要求

- `git` 可用，支持 `checkout -b`、`merge`、`branch -d`
- `gh` CLI 已认证（`gh auth status` 通过）
- 当前目录 `${REPO_DIR}` 为项目本地仓库
- 具有 `repo` 权限的 GitHub Token
- `jq` 已安装

## 变量速查

| 变量 | 来源 |
|------|------|
| `${PLAN_PATH}` `${CHECKLIST_PATH}` `${SPRINT}` | 调用参数 |
| `${SKILL}` | 固定 `/tdd`（开发方法论 Skill） |
| `${MAX_FIX_ATTEMPTS}` `${MAX_REGRESS_ATTEMPTS}` | `3` / `3` |
| `${REPO_DIR}` | `$(pwd)` |
| `${BRANCH}` | `feat/sprint${SPRINT}` |
| `${BASE_BRANCH}` | `main` |
| `${PR_BODY_FILE}` `${DEBUG_LOG}` | `/tmp/pr-body-sprint${SPRINT}.md` / `/tmp/sprint${SPRINT}-debug.log` |
| `${OWNER}` `${REPO}` | `gh repo view --json owner,name` |
| `${TEAM_TOPOLOGY}` `${MAX_PARALLEL_TEAMS}` | 参数或 Plan 字段，默认 `auto` / `3` |
| `${TEAM_ARTIFACT_BASE}` `${CROSS_REVIEW_LOG_BASE}` | `/tmp/sprint${SPRINT}-team` / `/tmp/sprint${SPRINT}-cross-review` |

---

## 阶段 0：前置依赖确认

> 任一项不通过 → **BLOCKED STOP**

1. **读取前置依赖**：从 `${PLAN_PATH}` 提取"前置依赖状态"
2. **确认上游 Sprint 已完成**：检查上游 checklist 已签核、PR 已合并、helper modules 可导入。未完成 → `missing-prereq`
3. **确认接口契约就绪**：验证数据格式、schema 版本、关键字段已文档化，artifact 存在。未就绪 → `contract-not-ready`
4. **模糊词量化检查**：扫描 `${CHECKLIST_PATH}` 中 ⚠️ 标记（`[需量化]`）。存在未量化项 → 先补充量化定义再移除标记，**不立即阻断**

---

## 阶段 1：Git 工作流

### 主分支创建

```bash
cd ${REPO_DIR}
git fetch origin
git checkout ${BASE_BRANCH}
git pull origin ${BASE_BRANCH}
git checkout -b ${BRANCH}
```

### Team 分支（每个 Task 独立）

```bash
TASK_BRANCH="feat/sprint${SPRINT}-${TASK_ID}"
git checkout ${BASE_BRANCH}
git pull origin ${BASE_BRANCH}
git checkout -b "${TASK_BRANCH}"
# subagent 在 ${TASK_BRANCH} 上工作，完成后合并到 ${BRANCH}
```

### 合并与清理

```bash
git merge "${TASK_BRANCH}" --no-edit || {
  git merge --abort
  echo "Merge conflict on ${TASK_ID}, manual resolution needed"
}
git branch -d "${TASK_BRANCH}" 2>/dev/null || true
```

### 提交规范（Conventional Commits）

| 类型 | 格式 |
|------|------|
| 功能 | `feat(sprint-${SPRINT}): [子任务名] — [描述]` |
| 修复 | `fix(sprint-${SPRINT}): [描述]` |
| 文档 | `docs(sprint-${SPRINT}): [描述]` |
| 重构 | `refactor(sprint-${SPRINT}): 抽取 [module] 到 [path]` |
| 测试 | `test(sprint-${SPRINT}): [正向/负向]测试 [场景名]` |

### PR 创建

```bash
git push -u origin ${BRANCH}
gh pr create \
  --title "feat(sprint-${SPRINT}): ${PR_TITLE}" \
  --body-file ${PR_BODY_FILE} \
  --base ${BASE_BRANCH} \
  --head ${BRANCH} \
  --repo ${OWNER}/${REPO} 2>/dev/null || echo "PR may already exist"
```

### 冲突处理

冲突时停止执行，报告文件列表，**不允许自动解决**，记录到 `${DEBUG_LOG}`。

---

## 阶段 2：Team 协作执行

> 加载开发方法论 Skill：`/tdd`（Codex: `$tdd`）。读取 Plan，解析 Task 依赖构建 DAG，按 Batch 调度。

### 2.0 — 拓扑推断

```bash
# 优先读取 Plan 中显式 team_topology 字段
EXPLICIT_TOPO=$(grep -A5 "${TASK_ID}" "${PLAN_PATH}" | grep "team_topology" | sed 's/.*: *//')
if [ -n "${EXPLICIT_TOPO}" ]; then
  TOPOLOGY="${EXPLICIT_TOPO}"
else
  # 自动推断
  SP=$(grep -A10 "${TASK_ID}" "${PLAN_PATH}" | grep -i "sp" | head -1 | grep -oE '[0-9]+' || echo "3")
  FILE_COUNT=$(grep -A20 "${TASK_ID}" "${PLAN_PATH}" | grep -c "^- \`\`")
  HAS_ARCH_DEBT=$(grep -A20 "${TASK_ID}" "${PLAN_PATH}" | grep -ci "architecture_debt\|架构债务" || echo "0")
  HAS_SECURITY=$(grep -A20 "${TASK_ID}" "${PLAN_PATH}" | grep -ciE "auth|permission|security|授权|权限|安全" || echo "0")

  if [ "$SP" -le 3 ] && [ "$HAS_ARCH_DEBT" -eq 0 ] && [ "$FILE_COUNT" -le 3 ]; then
    TOPOLOGY="solo"
  elif [ "$SP" -le 5 ] || [ "$HAS_ARCH_DEBT" -gt 0 ] || [ "$FILE_COUNT" -le 7 ]; then
    TOPOLOGY="pair"
  else
    TOPOLOGY="trio"
  fi
  # 安全/权限强制提级
  [ "$HAS_SECURITY" -gt 0 ] && [ "$TOPOLOGY" = "solo" ] && TOPOLOGY="pair"
fi
```

| 拓扑 | 角色 | 触发条件 |
|------|------|----------|
| `solo` | Developer | SP ≤ 3，无架构债务，文件 ≤ 3 |
| `pair` | Driver + Navigator | SP = 5，或有架构债务，或文件 4–7 |
| `trio` | Driver + Navigator + Guardian | SP = 8，或文件 > 7，或高风险 |

### 2.1 — 依赖排序与批次划分

1. 读取所有 Task 的 `dependencies`，构建 DAG
2. 拓扑排序，无依赖（或依赖已完成）的 Task 归入同一 **Batch**
3. Batch 内 Task 按拓扑组建 Team 并行 dispatch（受 `${MAX_PARALLEL_TEAMS}` 限制）

```
Batch 1: [Task-A: pair, Task-B: solo, Task-C: trio]  → 并行 dispatch
Batch 2: [Task-D: pair]                               → 依赖 Task-A 完成
Batch 3: [Task-E: solo]                               → 依赖 Task-B + Task-D
```

### 2.2 — Team 组建与 Dispatch

**Slot 计算**：每 Team 占用 slots = 角色数（solo=1, pair=2, trio=3）。总 slots = `${MAX_PARALLEL_TEAMS}`。平台默认上限详见 `references/ai-cli-compatibility.md`。

**调度**：按 Task 优先级排序，dispatch 直到 slots 耗尽；Team 完成释放 slots，继续 dispatch 队列中的下一个。

**Subagent 参数**（不写死工具名/模型名，按当前 runtime 适配）：
- 每个 subagent 传入 `${REPO_DIR}`、分支名 `${TASK_BRANCH}`、协作目录 `${TEAM_ARTIFACT_DIR}`
- 支持显式 spawn 的 runtime 用 `Agent` 工具 + `run_in_background: true`
- 不支持显式 spawn 的 runtime 回退为 solo 或自然语言委托

| 角色 | 核心职责 | 四级验收主导项 |
|------|----------|---------------|
| Driver | 核心编码、TDD 红-绿-重构、接口实现 | 二级：功能验收 |
| Navigator | 架构红线守护、代码结构审查、schema 监督 | 一级：架构红线合规 |
| Guardian | 测试矩阵设计、边界验证、回归执行 | 三级：测试覆盖、四级：文档同步 |

各角色完整 Prompt 模板见 `references/team-topology.md`。

### 2.3 — 协作循环

**Artifact 协议**（`${TEAM_ARTIFACT_DIR} = /tmp/sprint${SPRINT}-team-${TASK_ID}`）：

```
driver-progress.md      → Driver 实时写入进度
navigator-review.md     → Navigator 审查意见 / 批准状态
guardian-test-plan.md   → Guardian 测试矩阵与验证结果
team-consensus.md       → 全体成员确认的最终共识
```

**同步循环**：
```
Driver 编码 → driver-progress.md
  → Navigator 审查 → navigator-review.md (APPROVED/REJECTED)
  → Guardian 审查 → guardian-test-plan.md (APPROVED/REJECTED)
  → 任一 REJECTED → Driver 修正 → 重新循环
  → 全部 APPROVED → team-consensus.md → 进入 2.4 交叉 Review
```

**超时降级**：

| 场景 | 超时 | 降级 |
|------|------|------|
| Navigator 未响应 | 10 分钟 | SKIP，Orchestrator 自检架构红线 |
| Guardian 未响应 | 10 分钟 | SKIP，Orchestrator 自检测试覆盖 |
| Driver 无 progress | 15 分钟 | 检查分支状态，无进展 → BLOCKED STOP |

### 2.4 — 团队交叉 Review（前置门控）

Pair 模式：Navigator 对 Driver 最终代码完整 Review → `${CROSS_REVIEW_LOG}-${TASK_ID}.json`。通过标准：无 P1+ 发现，无架构红线违规。

Trio 模式：Navigator 审架构 + Guardian 审测试 → Orchestrator 合并去重取最高严重级别。通过标准：合并后无 P1+ 发现。

Solo 模式：跳过本门控。

Review 发现格式（轻量版，兼容 ce-code-review）：

```json
{
  "reviewer": "navigator",
  "task_id": "U3",
  "findings": [{
    "title": "向单一大文件新增逻辑超过 20%",
    "severity": "P1",
    "file": "src/core/engine.ts",
    "line": 120,
    "category": "architecture-guardrail",
    "resolution": "抽取 helper module 到 src/core/engine-utils.ts"
  }]
}
```

不通过 → 回到 2.3 修正，或 BLOCKED STOP（`cross-review-p1-found`）。

### 2.5 — Post-Batch 合并

Batch 内所有 Team 完成后：

1. 按 Task 依赖顺序合并各分支到 `${BRANCH}`
2. 冲突 → `git merge --abort` → 降级为 solo 串行重试
3. 每次合并后运行回归测试，失败则诊断修复后再合并下一个
4. 合并完成清理临时分支

### 2.6 — 回退矩阵

| 场景 | 回退行为 |
|------|----------|
| Harness 不支持 subagent | 降级为 solo 顺序执行 |
| Feature branch 创建失败 | 降级为共享目录 serial 执行 |
| 仅 1 个 Task | 自动降级为 solo |
| `--team-topology solo` | 完全等价于串行 v2 流程 |
| Navigator/Guardian subagent 失败 | 降级为 solo + Orchestrator 自检 |

---

## 阶段 3：四级验收

> 角色分工：一级 Navigator 主导，二级 Driver 主导，三/四级 Guardian 主导。
> 任一级不通过 → 进入阶段 6 迭代修复，或 BLOCKED STOP。

### 3.0 — 团队交叉 Review 通过确认

1. 读取 `${CROSS_REVIEW_LOG}-${TASK_ID}.json`（pair/trio 模式）
2. 确认 navigator-review.md 为 APPROVED，无 P1+ 发现
3. 确认 team-consensus.md 已签署

通过标准：Pair（Navigator 通过）/ Trio（Navigator + Guardian 均通过，合并后无 P1+）/ Solo（跳过）。

### 3A — 架构红线合规

- [ ] 新增逻辑优先落入 helper modules，非直接堆叠单一大文件
  - 通过标准：单文件新增占比 < 20%，或已抽取独立 helper
- [ ] 接口契约变更已同步到 schema.md / schema.json
- [ ] schema↔实现一致性校验通过（如有 schema 变更）

### 3B — 功能验收

读取 `${CHECKLIST_PATH}`"功能验收"段落，逐条独立执行：读取验证方式 → 执行命令 → 对比通过标准 → 勾选或记录失败。

⚠️ 模糊词处理：含 `[需量化]` 标记的项，检查是否已补充量化定义。已补充 → 移除标记并验证；未补充 → BLOCKED STOP（`unquantified-acceptance-criteria`）。

### 3C — 测试覆盖

**3C.1 正向测试**：运行 `${CHECKLIST_PATH}` 中每个 Test Scenario 对应脚本，确认 exit 0 且含 "PASS"。

**3C.2 负向测试 / 边界条件**：运行 `${PLAN_PATH}` 中负向测试脚本。通过标准不一定是 exit 0，而是"系统正确阻塞/失败/降级"。

**3C.3 回归测试**：本 Sprint 相关测试套件全部 exit 0；上游依赖 Sprint 核心测试仍通过。非本 Sprint 测试失败不阻塞但需确认不影响 main 稳定性。

### 3D — 文档 / Schema / 配置同步

- [ ] 所有涉及文件变更已逐项确认（Create/Modify → Verify）
  - 验证：对比 Plan "涉及文件"列表与 git diff
- [ ] schema.md 与 schema.json 字段名/类型/约束一致（差异 0 项）
- [ ] 用户流程文档已同步更新
- [ ] ADR / 架构文档已同步（如有架构变更）
- [ ] 配置变更向后兼容（旧配置在新代码中正常加载）
- [ ] 向下游 Sprint 的接口契约已文档化

### 3E — 标记完成

四级验收全部通过后，在 `${CHECKLIST_PATH}` 追加：

```
[YYYY-MM-DD] Verified — 四级验收全部通过
  - 架构红线合规: ✅
  - 功能验收: ✅ (N/N 条)
  - 测试覆盖: ✅ (正向 N/N, 负向 N/N, 回归通过)
  - 文档/Schema/配置同步: ✅
```

---

## 阶段 4：交付流水线

**PR Body 写入 `${PR_BODY_FILE}`**：

```markdown
## Sprint ${SPRINT}: ${PR_TITLE}

### 需求来源
- ${PLAN_PATH} Sprint ${SPRINT}
- ${SPEC_REF}
- ${ADR_REF}

### 实现摘要
- 新增/修改文件：[列出]
- 团队拓扑：solo N 个 / pair N 个 / trio N 个
- 架构红线合规说明：[helper module 抽取 / 单文件新增占比]

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
```[完整通过输出]```

### 四级验收状态
- [x] 一级：架构红线合规
- [x] 二级：功能验收 — N/N 条
- [x] 三级：测试覆盖 — 正向 N/N, 负向 N/N, 回归通过
- [x] 四级：文档/Schema/配置同步

### 接口契约
- 向下游 Sprint 输出：[契约名称/格式/版本]
- 前置依赖状态：[上游 Sprint 已完成并合并]
```

**PR 发起后**：推送最新 commit，确保关联 milestone/label，**不自动合并**。

---

## 阶段 5：约束与边界

**硬性约束**：
- 不实现 Sprint 范围外内容
- 不修改现有 MVP 代码（除非 Plan 明确要求）
- 不修改其他 Sprint 的配置或测试脚本
- 不自动合并 PR（仅发起，等待 review）
- 不违反架构红线（禁止向单一大文件堆叠逻辑）

**写权限边界**：Plan 指定的文件、新增文件（测试/配置/文档/helper modules）、`${PR_BODY_FILE}`、`${DEBUG_LOG}`

**只读边界**：其他 Sprint 配置和测试脚本、`${BASE_BRANCH}` 已有代码（除非 rebase/merge）、release tags

---

## 阶段 6：迭代策略

每轮失败后的处理：

1. **记录**：失败测试名和错误摘要 → `${DEBUG_LOG}`
2. **回归检查**：最近 3 次 diff 是否引入回归
3. **尝试修复**（≤ `${MAX_FIX_ATTEMPTS}` 次）：分析根因 → 修改 → 重跑完整验证
4. **修复成功**：`git commit --amend` 或新增 fix 提交
5. **修复失败（达到上限）**：
   - 读取 Plan 中当前 Task 的"风险与降级策略"
   - 执行降级（回滚稳定 commit / mock 替代 / 跳过非核心功能）
   - 降级也无法执行 → BLOCKED STOP（`fix-failed-after-max-attempts`）

**回归循环上限**：同一问题最多修复 `${MAX_REGRESS_ATTEMPTS}`（3）次，第 3 次仍失败 → 执行降级或上报。

---

## 阶段 7：止损条件（BLOCKED STOP）

立即停止并报告 blocker。报告必须包含：blocker 类型、最后命令及输出（前 50 行）、已尝试修复次数和方式、当前验收级别、解锁所需的人类输入。

| Blocker 类型 | 触发条件 |
|--------------|----------|
| `missing-prereq` | 前置 Sprint 未完成或上游契约未就绪 |
| `contract-not-ready` | 消费的接口契约未定义 |
| `unquantified-acceptance-criteria` | 验收标准含模糊词标记且未量化 |
| `architecture-guardrail-violation` | 违反架构红线 |
| `schema-sync-failed` | schema.md ↔ schema.json ↔ 实现 三方不一致 |
| `fix-failed-after-max-attempts` | 修复 `${MAX_FIX_ATTEMPTS}` 次仍失败 |
| `regress-limit-exceeded` | 同一问题回归超过 `${MAX_REGRESS_ATTEMPTS}` 次 |
| `cross-review-p1-found` | 交叉 Review 发现 P1+ 且修复失败 |
| `parallel-merge-conflict` | Batch 合并冲突且串行重试失败 |
| `team-consensus-failed` | Team 内部无法达成一致 |
| `subagent-timeout` | Team 内角色超时且无降级方案 |
| `git-conflict` | rebase 冲突无法自动解决 |
| `tool-unavailable` | `gh` CLI 不可用 |
| `unknown` | 未预期错误 |

**BLOCKED STOP POLICY**：
- 命中 blocker → 立即停止，停止 goal
- 不得继续后续步骤，不得重复运行验证命令，不得重复输出 blocker 报告
- 仅在用户提供解除信息后恢复执行

---

## 与 /my-sprint-plan 的衔接

```
/my-sprint-plan <PRD_PATH> --output <SPRINTS_DIR>
  → 生成 plan-sprint-N.md + checklist-sprint-N.md
/my-sprint-execute <SPRINTS_DIR>/plan-sprint-N.md <SPRINTS_DIR>/checklist-sprint-N.md N
  → Team 拓扑推断 → Batch 调度 → dispatch → 协作循环 → 交叉 Review → 四级验收 → PR
```

### Plan 中的 team_topology 字段（可选）

建议 Plan 为每个 Task 增加可选字段以精确控制拓扑：

```markdown
### U3: 用户权限校验模块
- **team_topology**: pair  # 可选：solo | pair | trio
- **sp**: 5
- **architecture_debt**: true
```

未提供时 execute 端按自动推断规则处理，保持向后兼容。
