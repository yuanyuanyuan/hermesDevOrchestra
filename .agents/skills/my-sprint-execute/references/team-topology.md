# Team Topology Reference

> 本文件定义 my-sprint-execute v3 中多 Agent 协作执行的团队拓扑规则、角色职责、Prompt 模板与协作协议。

---

## 1. Topology 判定规则

### 自动推断逻辑（`--team-topology auto`）

对每个 Task 读取以下元数据（来自 Plan 文件或解析后的 JSON）：

| 判定因子 | 来源字段 | 影响 |
|----------|----------|------|
| SP（故事点） | `implementation_units[].sp` | SP ≤ 3 → 倾向 solo；SP = 5 → 倾向 pair；SP = 8 → 倾向 trio |
| 架构债务 | `implementation_units[].architecture_debt` | `true` 时至少 pair |
| 涉及文件数 | `implementation_units[].files` 长度 | ≤ 3 → solo；4–7 → pair；> 7 → trio |
| 风险等级 | `implementation_units[].risk_level` | `high` 时至少 pair |

### 判定算法

```bash
# 伪代码
def infer_topology(task):
    sp = task.sp
    arch_debt = task.architecture_debt or false
    file_count = len(task.files)
    risk = task.risk_level or "low"
    
    # 基础判定
    if sp <= 3 and not arch_debt and file_count <= 3:
        topo = "solo"
    elif sp <= 5 or arch_debt or file_count <= 7:
        topo = "pair"
    else:
        topo = "trio"
    
    # 安全/权限强制提级
    if task_has_security_keyword(task) and topo == "solo":
        topo = "pair"
    
    return topo
```

### 安全关键词检测

扫描 Task 的以下字段：`name`, `goal`, `approach`, `requirements`。若包含以下关键词，触发提级：
- `auth`, `authentication`, `授权`, `认证`
- `permission`, `权限`
- `security`, `安全`, `加密`, `签名`
- `payment`, `支付`, `交易`

---

## 2. 角色定义与 Prompt 模板

### 2.1 Driver（主攻手）

**身份**：Task 的核心实现者，负责将 Plan 转化为可运行的代码和测试。

**Prompt 模板**：

```
你是 Sprint ${SPRINT} Task ${TASK_ID} 的 Driver（主攻手）。

## 任务上下文
- Task 名称：${TASK_NAME}
- Goal：${TASK_GOAL}
- Approach：${TASK_APPROACH}
- Files：${TASK_FILES}
- Patterns to follow：${TASK_PATTERNS}
- Test Scenarios：${TASK_TEST_SCENARIOS}
- 风险与降级策略：${TASK_RISK_FALLBACK}

## 你的职责
1. 按 TDD 红-绿-重构循环实现代码
2. 优先实现 helper module，再在原文件中调用
3. 同步更新 schema.md / schema.json（如有数据模型变更）
4. 每完成一个子模块，将进度写入 ${TEAM_ARTIFACT_DIR}/driver-progress.md
5. 运行测试并确保通过

## 协作规则
- 你的实现会被 Navigator 实时审查。若 navigator-review.md 中出现 REJECTED 标记，你必须暂停当前工作，根据审查意见修正后重新写入 progress 文件。
- 若 Guardian 存在（trio 模式），完成测试后需等待 guardian-test-plan.md 的 APPROVED 标记。
- 最终提交前，必须在 team-consensus.md 中确认全体成员已 APPROVED。

## Feature Branch 隔离
你在独立的 feature branch 上工作：`feat/sprint${SPRINT}-${TASK_ID}`
- 从 `${BASE_BRANCH}` 切出，所有修改只提交到本分支
- 请勿操作 orchestrator 当前所在的分支或其他 Team 的分支
- 完成后将分支推送到 origin，由 Orchestrator 负责 merge
```

### 2.2 Navigator（领航员）

**身份**：架构红线守护者，实时审查 Driver 的实现是否符合架构约束。

**Prompt 模板**：

```
你是 Sprint ${SPRINT} Task ${TASK_ID} 的 Navigator（领航员）。

## 任务上下文
- Task 名称：${TASK_NAME}
- Goal：${TASK_GOAL}
- Approach：${TASK_APPROACH}
- Files：${TASK_FILES}

## 你的职责
1. 轮询读取 ${TEAM_ARTIFACT_DIR}/driver-progress.md
2. 对 Driver 的实现进行实时架构审查，重点检查：
   - 是否向单一大文件（>3000 行）直接堆叠逻辑？
   - 新增代码在单文件中的占比是否 < 20%？
   - 是否需要抽取 helper module 但未抽取？
   - 接口契约变更是否已同步到 schema.md / schema.json？
   - 代码结构是否符合项目现有模式？
3. 将审查意见写入 ${TEAM_ARTIFACT_DIR}/navigator-review.md

## 输出格式（navigator-review.md）

```markdown
## Navigator Review — Task ${TASK_ID} — $(date -Iseconds)

### 状态：APPROVED | REJECTED | PENDING

### 发现（如有）
| # | 类别 | 文件 | 行 | 严重级别 | 描述 | 建议修正 |
|---|------|------|----|----------|------|----------|
| 1 | architecture-guardrail | ... | ... | P1 | ... | ... |

### 审查意见
- ...
```

## 约束
- 你是只读审查者，**不直接修改代码**
- 你的目标是帮助 Driver 在实现阶段就发现并修正架构问题，而非事后验收
- REJECTED 状态必须有至少一条具体的、可执行的修正建议
```

### 2.3 Guardian（守护者）

**身份**：测试与边界条件守护者，确保测试覆盖完整、边界条件充分。

**Prompt 模板**：

```
你是 Sprint ${SPRINT} Task ${TASK_ID} 的 Guardian（守护者）。

## 任务上下文
- Task 名称：${TASK_NAME}
- Goal：${TASK_GOAL}
- Test Scenarios：${TASK_TEST_SCENARIOS}
- 负向测试要求：${TASK_NEGATIVE_TESTS}
- 验证标准：${TASK_VERIFICATION}

## 你的职责
1. 轮询读取 ${TEAM_ARTIFACT_DIR}/driver-progress.md
2. 审查 Driver 实现的测试覆盖：
   - 正向测试是否覆盖所有 Test Scenario？
   - 负向测试是否 ≥ 2 条？边界条件是否充分？
   - 回归测试范围是否合适？
3. 补充 Guardian 认为遗漏的测试场景（如有）
4. 将测试审查结果写入 ${TEAM_ARTIFACT_DIR}/guardian-test-plan.md

## 输出格式（guardian-test-plan.md）

```markdown
## Guardian Test Review — Task ${TASK_ID} — $(date -Iseconds)

### 状态：APPROVED | REJECTED | PENDING

### 测试覆盖评估
| 类别 | 要求 | 实际 | 缺口 |
|------|------|------|------|
| 正向测试 | N 条 | M 条 | ... |
| 负向测试 | ≥2 条 | K 条 | ... |
| 回归测试 | ... | ... | ... |

### 补充建议（如有）
- ...

### 发现（如有）
| # | 类别 | 文件 | 行 | 严重级别 | 描述 |
|---|------|------|----|----------|------|
| 1 | testing-gap | ... | ... | P1 | ... |
```

## 约束
- 你是只读审查者，**不直接修改代码或测试**
- 若发现测试缺口，在 test-plan 中给出具体的补充测试场景描述
- REJECTED 状态必须有具体的测试覆盖缺口说明
```

---

## 3. 协作协议（Collaboration Protocol）

### 3.1 Artifact 目录结构

每个 Task 的 Team 拥有独立的 artifact 目录：

```
${TEAM_ARTIFACT_DIR} = /tmp/sprint${SPRINT}-team-${TASK_ID}
```

| 文件 | 写入者 | 读取者 | 用途 |
|------|--------|--------|------|
| `driver-progress.md` | Driver | Navigator, Guardian | 实现进度、代码变更摘要 |
| `navigator-review.md` | Navigator | Driver, Orchestrator | 架构审查意见、APPROVED/REJECTED |
| `guardian-test-plan.md` | Guardian | Driver, Orchestrator | 测试覆盖审查、APPROVED/REJECTED |
| `team-consensus.md` | 全体成员 | Orchestrator | 最终共识确认 |

### 3.2 同步循环

```
Driver 编码 → 写入 driver-progress.md
                ↓
Navigator 轮询读取 → 审查 → 写入 navigator-review.md
                ↓ (APPROVED / REJECTED)
Guardian 轮询读取 → 测试审查 → 写入 guardian-test-plan.md
                ↓ (APPROVED / REJECTED)
若任一 REJECTED → Driver 修正 → 重新写入 driver-progress.md
                ↓
循环直到 Navigator 和 Guardian 均为 APPROVED
                ↓
全体成员签署 team-consensus.md
                ↓
Orchestrator 确认 → 进入交叉 Review 门控
```

### 3.3 超时与降级

| 场景 | 超时阈值 | 降级行为 |
|------|----------|----------|
| Navigator 未响应 | 10 分钟 | 标记为 SKIP，Orchestrator 自行执行架构红线检查 |
| Guardian 未响应 | 10 分钟 | 标记为 SKIP，Orchestrator 自行执行测试覆盖检查 |
| Driver 未更新 progress | 15 分钟 | Orchestrator 检查分支状态（`git log feat/sprint${SPRINT}-${TASK_ID}`），若无进展则上报 BLOCKED STOP |

### 3.4 team-consensus.md 格式

```markdown
# Team Consensus — Sprint ${SPRINT} Task ${TASK_ID}

## 签署状态
- [x] Driver APPROVED — $(date -Iseconds)
- [x] Navigator APPROVED — $(date -Iseconds)
- [x] Guardian APPROVED — $(date -Iseconds)

## 共识摘要
- 架构红线：无违规（单文件新增占比 X%）
- 测试覆盖：正向 N/N，负向 K/K，回归通过
- 接口契约：已同步到 schema.md / schema.json
- 已知限制：...

## 提交建议
- 提交信息：feat(sprint-${SPRINT}): [Task 名称] — [一句话描述]
```

---

## 4. Batch Parallelism 调度规则

### 4.1 DAG 构建

读取 Plan 中所有 Task 的 `dependencies` 字段，构建有向无环图（DAG）。

### 4.2 批次划分

```
Batch 0 = 所有入度为 0 的 Task（无依赖）
Batch N = 所有前置依赖已全部完成的 Task
```

### 4.3 Bounded Dispatch

```
总 slots = ${MAX_PARALLEL_TEAMS}（默认 3，每 Team 占用 slot 数 = topology 对应的 agent 数）

调度策略：
1. 按 Task 在 Plan 中的顺序排序
2. 尽可能 dispatch 多个 Team，直到 slots 耗尽
3. Team 完成后释放 slots，dispatch 队列中下一个 Team
4. 同一 Batch 内所有 Team 完成后，进入下一个 Batch
```

### 4.4 Post-Batch 合并（Feature Branch 模式）

```bash
cd ${REPO_DIR}
git checkout ${BRANCH}

for task_id in ${MERGE_ORDER}; do
  TASK_BRANCH="feat/sprint${SPRINT}-${task_id}"
  git merge "${TASK_BRANCH}" --no-edit || {
    git merge --abort
    echo "Merge conflict on ${task_id}, falling back to solo execution"
    execute_task_solo "${task_id}"
    continue
  }
  run_regression_tests
  git branch -d "${TASK_BRANCH}" 2>/dev/null || true
done
```

**要点**：
- 所有 Team 在独立 feature branch 上工作，分支名为 `feat/sprint${SPRINT}-${TASK_ID}`
- 合并前确保 orchestrator 已 checkout 到主分支 `${BRANCH}`
- 冲突时 abort merge，将该 Task 降级为 solo 在当前 `${BRANCH}` 上重新实现
- 合并成功后删除本地临时分支（远程分支保留，供 PR 阶段使用）

---

## 5. 回退策略矩阵

| 场景 | 回退行为 |
|------|----------|
| Harness 不支持 subagent | 降级为 solo 顺序执行 |
| Feature branch 创建失败 | 降级为共享目录 serial subagents（在当前分支上顺序执行各 Task） |
| 仅 1 个 Task 的 Sprint | 自动降级为 solo |
| `--team-topology solo` | 完全等价于现有 v2 流程 |
| Navigator subagent 失败 | 降级为 solo + Orchestrator 自检架构红线 |
| Guardian subagent 失败 | 降级为 pair（Driver + Navigator） |
| Batch 合并冲突且重试失败 | 降级为 solo 串行执行冲突 Task |
| Topology 推断缺少元数据 | 默认 pair，记录警告到 DEBUG_LOG |
