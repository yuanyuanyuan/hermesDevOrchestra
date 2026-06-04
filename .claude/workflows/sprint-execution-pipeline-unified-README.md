# Sprint Execution Pipeline - 统一版

## 🎯 概述

统一版 Sprint 执行流水线，严格通过三个核心 Skill 驱动开发和 PR 生命周期：

| Skill | 职责 | 调用位置 |
|-------|------|---------|
| `/my-sprint-execute` | Sprint 开发（Git 分支 + 代码 + 测试 + PR） | 步骤 1 |
| `/my-pr-skill` | PR 管理（manage-pr.sh, get-repo-info.sh） | 底层依赖 |
| `/my-pr-review-response` | Review 反馈处理（读评论 + 修复 + 回复） | 步骤 3 轮询中 |

**核心优势**：
- ✅ **Skill 驱动**：严格使用三个已定义的 Skill，不重复造轮子
- ✅ **高效轮询**：单 agent 内部循环，非每轮 spawn 新 agent
- ✅ **正确 review 检测**：基于 `reviewDecision` 字段，非 `state`
- ✅ **失败即停**：Sprint 失败时立即中止后续 Phase

## 🚀 快速启动

```bash
# 通过 slash command
/sprint-execution-pipeline-unified

# 通过 Workflow 工具
Workflow({ name: "sprint-execution-pipeline-unified" })

# 自定义 plan 和 checklist 路径
Workflow({
  name: "sprint-execution-pipeline-unified",
  args: {
    planPath: "/home/stark/.claude/plans/plan-sprint-*.md",
    checklistPath: "/data/hermes/docs/execution-checklist.md"
  }
})
```

## ⚙️ 配置参数

### 脚本内常量

| 常量 | 默认值 | 说明 |
|------|--------|------|
| `REPO` | `yuanyuanyuan/hermesDevOrchestra` | 目标仓库 |
| `POLL_INTERVAL_SECONDS` | `60` | 轮询间隔（秒） |
| `MAX_POLL_MINUTES` | `240` | 最大等待时间（分钟） |

### Reviewer 配置

```javascript
const REVIEWER_CONFIG = {
  enabled: true,            // 是否启用独立审查
  maxAttempts: 3,           // 最多审查尝试次数
  reviewCriteria: [         // 8 项审查标准
    '代码质量和可维护性',
    '架构设计合理性',
    '测试覆盖率充分性',
    '安全性考虑',
    '性能影响评估',
    '文档完整性',
    '错误处理健壮性',
    '向后兼容性'
  ],
  passThreshold: 0.8,       // 通过阈值（80%）
  softPassThreshold: 0.70,  // 无 critical 时的最低通过分
  autoFixEnabled: true      // 是否启用自动修复
}
```

### 调用参数（args）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `planPath` | `plan-sprint-*.md` | Sprint Plan 路径模板（`*` 替换为 Sprint 号） |
| `checklistPath` | `execution-checklist.md` | 验收清单路径 |

## 📊 执行流程

### 完整流程图

```
Phase: Sprint-1
│
├─ 步骤 0: findExistingPR(sprintNum)
│  └─ 有已有 PR → 跳过开发
│
├─ 步骤 1: /my-sprint-execute (callSprintExecute)
│  ├─ Git 分支工作流 (feat/sprintN, origin/main)
│  ├─ 顺序执行 Plan 中的任务
│  ├─ 验证验收 (test + checklist)
│  └─ PR 创建 (/my-pr-skill → manage-pr.sh --create)
│
├─ 步骤 2: executeReviewerReview (独立质量门禁)
│  ├─ 评分 ≥ 0.80 → ✅ 通过
│  ├─ 评分 ≥ 0.70 且无 critical → ⚠️ 勉强通过
│  ├─ 有 critical → 🔧 自动修复 → 重审（最多 3 轮）
│  └─ 仍失败 → ❌ 中止
│
└─ 步骤 3: waitForPRMerge (单 agent 内部轮询)
   ├─ 每 60s 检查 gh pr view --json state,mergedAt,reviewDecision,reviews
   ├─ mergedAt 非空 → ✅ 完成
   ├─ reviewDecision=CHANGES_REQUESTED 或有 review comments
   │  └─ /my-pr-review-response
   │     ├─ decomposer agent → review_plan.md
   │     ├─ code agent → 修复 + git commit --amend + push -f
   │     └─ gh pr comment → 回复每条 review comment
   └─ 超时 240 分钟 → ⏰ TIMEOUT

Phase: Sprint-2 (依赖 Sprint-1 merged)
...
Phase: Sprint-13 (依赖 Sprint-12 merged)
```

### Sprint 依赖关系

```
Sprint-1 ──→ Sprint-2 ──→ Sprint-3  ──→ Sprint-5  ──→ Sprint-9  ──→ Sprint-12 ──→ Sprint-13
                          ├→ Sprint-4  ──→ Sprint-6  ──┘
                          ├→ Sprint-7                  ──→ Sprint-9
                          ├→ Sprint-8                  ──┘
                          └→ Sprint-10 ──→ Sprint-11 ──→ Sprint-12
```

| Phase | Sprints | 执行方式 |
|-------|---------|---------|
| Sprint-1 | [1] | 串行 |
| Sprint-2 | [2] | 串行 |
| Sprint-3-4-7-8-10 | [3, 4, 7, 8, 10] | 并行 |
| Sprint-5-6-11 | [5, 6, 11] | 并行 |
| Sprint-9 | [9] | 串行 |
| Sprint-12 | [12] | 串行 |
| Sprint-13 | [13] | 串行 |

## 🔍 Review 检测机制

### GitHub PR Review 三层状态模型

| 层级 | 字段 | 值 | 说明 |
|------|------|-----|------|
| PR 生命周期 | `state` | OPEN / CLOSED / MERGED | PR 本身状态 |
| 聚合决策 | `reviewDecision` | APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / 空 | GitHub 计算的总决策 |
| 单个 Review | `reviews[].state` | APPROVED / CHANGES_REQUESTED / COMMENTED / DISMISSED | 每个 reviewer 的状态 |

### 检测逻辑

```javascript
// ✅ 正确：检查 reviewDecision
const hasChangeRequests = reviewDecision === 'CHANGES_REQUESTED'
  || reviews.some(r => r.state === 'CHANGES_REQUESTED')

// ❌ 错误：state 永远不会是 CHANGES_REQUESTED
// state 只有 OPEN / CLOSED / MERGED
```

### 处理策略

| 状态 | 处理方式 |
|------|---------|
| `reviewDecision = APPROVED` | 等待合并 |
| `reviewDecision = CHANGES_REQUESTED` | 调用 `/my-pr-review-response` |
| `reviews` 有 COMMENTED | 首次检测时处理，之后跳过 |
| 无 reviews | 正常轮询等待 |

## 🎨 自定义配置

### 修改仓库

在脚本中修改常量：
```javascript
const REPO = 'your-org/your-repo'
```

### 禁用独立审查

```javascript
REVIEWER_CONFIG.enabled = false
```

### 提高质量要求

```javascript
REVIEWER_CONFIG.passThreshold = 0.9
REVIEWER_CONFIG.maxAttempts = 5
REVIEWER_CONFIG.autoFixEnabled = false
```

### 添加审查标准

```javascript
REVIEWER_CONFIG.reviewCriteria.push('国际化支持')
REVIEWER_CONFIG.reviewCriteria.push('可访问性')
```

## 🛠️ 故障排除

### PR 创建失败

**原因**：`/my-sprint-execute` 依赖 `/my-pr-skill` 的 `manage-pr.sh`

**排查**：
```bash
# 检查 my-pr-skill 脚本是否存在
ls /data/hermes/.agents/skills/my-pr-skill/scripts/

# 检查 gh CLI 认证
gh auth status

# 检查仓库权限
gh repo view yuanyuanyuan/hermesDevOrchestra
```

### Review 反馈处理失败

**原因**：`/my-pr-review-response` 需要能读取 PR 评论并推送修复

**排查**：
```bash
# 检查 PR 评论
gh pr view <PR_NUMBER> --repo yuanyuanyuan/hermesDevOrchestra --comments

# 检查分支是否可推送
git push --dry-run origin feat/sprintN
```

### 轮询超时

**原因**：PR 需要手动合并，或 reviewer 未响应

**处理**：
```bash
# 手动合并 PR
gh pr merge <PR_NUMBER> --repo yuanyuanyuan/hermesDevOrchestra

# 或通过 resume 恢复
Workflow({ scriptPath: "<script-path>", resumeFromRunId: "<run-id>" })
```

### 依赖未满足

**原因**：前序 Sprint 的 PR 未合并

**处理**：确保所有依赖 Sprint 的 PR 已合并后重新运行。

## 📁 文件结构

```
.claude/workflows/
├── sprint-execution-pipeline-unified.js              # 主 workflow 脚本
├── sprint-execution-pipeline-unified-README.md       # 本文档
├── sprint-execution-pipeline-unified-QUICKSTART.md   # 快速参考
├── sprint-execution-pipeline-SUMMARY.md              # 项目总结
├── sprint-execution-pipeline-test.js                 # 测试版（调试用）
└── prd-compliance-audit.js                           # PRD 合规审计

.agents/skills/
├── my-sprint-execute/    # Sprint 开发 Skill
├── my-pr-skill/          # PR 管理 Skill
└── my-pr-review-response/ # Review 反馈处理 Skill
```

## 📚 相关文档

- **快速参考**：`sprint-execution-pipeline-unified-QUICKSTART.md`
- **项目总结**：`sprint-execution-pipeline-SUMMARY.md`
- **Skill 文档**：
  - `/data/hermes/.agents/skills/my-sprint-execute/SKILL.md`
  - `/data/hermes/.agents/skills/my-pr-skill/SKILL.md`
  - `/data/hermes/.agents/skills/my-pr-review-response/SKILL.md`
