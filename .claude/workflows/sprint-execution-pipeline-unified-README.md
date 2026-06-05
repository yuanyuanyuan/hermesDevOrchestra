# Sprint Execution Pipeline - 统一版

## 🎯 概述

统一版 Sprint 执行流水线，从目录动态发现 Sprint、自动解析依赖图、拓扑排序生成执行阶段。

| Skill | 职责 | 调用位置 |
|-------|------|---------|
| `/my-sprint-execute` | Sprint 开发（Git 分支 + 代码 + 测试 + PR） | 步骤 1 |
| `/my-pr-skill` | PR 管理（manage-pr.sh, get-repo-info.sh） | 底层依赖 |
| `/my-pr-review-response` | Review 反馈处理（读评论 + 修复 + 回复） | 步骤 3 轮询中 |

**核心优势**：
- ✅ **动态发现**：从目录自动扫描 `plan-sprint-N.md` + `checklist-sprint-N.md`
- ✅ **自动依赖解析**：从 `sprint-overview.md` 表格提取依赖关系
- ✅ **拓扑排序**：自动计算可并行的执行阶段
- ✅ **恢复支持**：检测已合并 PR，自动跳过已完成 Sprint
- ✅ **Skill 驱动**：严格使用三个已定义的 Skill，不重复造轮子

## 🚀 快速启动

```bash
# 通过 slash command
/sprint-execution-pipeline-unified

# 通过 Workflow 工具（必须指定 sprintsDir）
Workflow({
  name: "sprint-execution-pipeline-unified",
  args: {
    sprintsDir: "/data/hermes/docs/sprints/prd-compliance-audit-remediation-full"
  }
})
```

## ⚙️ 配置参数

### 调用参数（args）

| 参数 | 必需 | 说明 |
|------|------|------|
| `sprintsDir` | ✅ | Sprint 文件目录路径，包含 plan 和 checklist |

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

## 📊 执行流程

### 完整流程图

```
main()
│
├─ 1. discoverSprints(sprintsDir)
│     扫描目录 → { 1: {planPath, checklistPath}, 2: {...}, ... }
│
├─ 2. parseDependencyGraph(sprintsDir, sprintNums)
│     解析 sprint-overview.md 表格 → { 1: [], 2: [1], 9: [6,8], ... }
│
├─ 3. buildExecutionPhases(sprintNums, depGraph)
│     拓扑排序 → [{phase:'Sprint-1', sprints:[1]}, {phase:'Sprint-2-3', sprints:[2,3]}, ...]
│
└─ 4. 逐 Phase 执行
     │
     ├─ Phase: Sprint-1
     │  └─ executeSprint(1, planPath, checklistPath)
     │     ├─ 步骤 0a: findMergedPR → 已合并? 跳过
     │     ├─ 步骤 0b: findExistingPR → 有 open PR? 跳过开发
     │     ├─ 步骤 1: /my-sprint-execute → 开发 + PR
     │     ├─ 步骤 2: executeReviewerReview → 质量门禁
     │     └─ 步骤 3: waitForPRMerge → 等待合并
     │
     ├─ Phase: Sprint-2-3 (并行)
     │  └─ parallel([executeSprint(2, ...), executeSprint(3, ...)])
     │
     └─ ...
```

### Sprint 目录结构

```
sprints-dir/
├── plan-sprint-1.md          # Sprint 1 开发计划（必需）
├── checklist-sprint-1.md     # Sprint 1 验收清单（必需）
├── plan-sprint-2.md
├── checklist-sprint-2.md
├── ...
├── sprint-overview.md        # 依赖关系表（解析依赖图）
└── schema.md                 # Schema 说明（可选）
```

### 依赖图解析

从 `sprint-overview.md` 的表格中自动提取：

```markdown
| Sprint | ... | Depends On |
|--------|-----|------------|
| 1      | ... | Prior ...  |     → 1: []
| 2      | ... | Sprint 1   |     → 2: [1]
| 9      | ... | Sprints 6, 8 |   → 9: [6, 8]
| 12     | ... | Sprints 1-11 |   → 12: [1,2,3,4,5,6,7,8,9,10,11]
```

### 拓扑排序

自动计算可并行执行的 Sprint 分组：

```
Sprint-1          → 阶段 1（无依赖）
Sprint-2          → 阶段 2（依赖 1）
Sprint-3, 4, 7, 8, 10 → 阶段 3（都只依赖 2，可并行）
Sprint-5, 6, 11   → 阶段 4（依赖阶段 3 的产出）
Sprint-9          → 阶段 5（依赖 6, 8）
Sprint-12         → 阶段 6（依赖 1-11 全部）
Sprint-13         → 阶段 7（依赖 12）
```

## 🔄 恢复机制

workflow 支持中断后恢复：

1. **已合并 Sprint** → `findMergedPR()` 检测到 → 自动跳过，日志显示 `⏭️`
2. **已有 open PR** → `findExistingPR()` 检测到 → 跳过开发，直接进入审查
3. **全新 Sprint** → 正常执行完整流程

```
🚀 开始执行 Sprint 1...
⏭️ Sprint 1 已完成（PR #34 已合并 @ 2026-06-03T10:30:00Z），跳过
🚀 开始执行 Sprint 2...
📝 步骤 1/3：调用 /my-sprint-execute 执行开发任务...
```

## 🔍 Review 检测机制

### GitHub PR Review 三层状态模型

| 层级 | 字段 | 值 | 说明 |
|------|------|-----|------|
| PR 生命周期 | `state` | OPEN / CLOSED / MERGED | PR 本身状态 |
| 聚合决策 | `reviewDecision` | APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / 空 | GitHub 计算的总决策 |
| 单个 Review | `reviews[].state` | APPROVED / CHANGES_REQUESTED / COMMENTED / DISMISSED | 每个 reviewer 的状态 |

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

## 🛠️ 故障排除

### sprintsDir 参数缺失

**错误**：`缺少必需参数 sprintsDir`

**解决**：
```javascript
Workflow({
  name: "sprint-execution-pipeline-unified",
  args: { sprintsDir: "/path/to/sprints/dir" }
})
```

### Sprint 文件缺失

**错误**：`Sprint N 缺少 plan 文件` 或 `Sprint N 缺少 checklist 文件`

**解决**：确保目录中有 `plan-sprint-N.md` 和 `checklist-sprint-N.md`

### PR 创建失败

**排查**：
```bash
# 检查 my-pr-skill 脚本是否存在
ls /data/hermes/.agents/skills/my-pr-skill/scripts/

# 检查 gh CLI 认证
gh auth status
```

### 轮询超时

**处理**：
```bash
# 手动合并 PR
gh pr merge <PR_NUMBER> --repo yuanyuanyuan/hermesDevOrchestra
```

## 📁 文件结构

```
.claude/workflows/
├── sprint-execution-pipeline-unified.js              # 主 workflow 脚本
├── sprint-execution-pipeline-unified-README.md       # 本文档
├── sprint-execution-pipeline-unified-QUICKSTART.md   # 快速参考
├── sprint-execution-pipeline-SUMMARY.md              # 项目总结
├── sprint-execution-pipeline-test.js                 # 测试版（调试用）
└── prd-compliance-audit.js                           # PRD 合规审计
```

## 📚 相关文档

- **快速参考**：`sprint-execution-pipeline-unified-QUICKSTART.md`
- **项目总结**：`sprint-execution-pipeline-SUMMARY.md`
- **Skill 文档**：
  - `/data/hermes/.agents/skills/my-sprint-execute/SKILL.md`
  - `/data/hermes/.agents/skills/my-pr-skill/SKILL.md`
  - `/data/hermes/.agents/skills/my-pr-review-response/SKILL.md`
