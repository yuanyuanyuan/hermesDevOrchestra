# Sprint Execution Pipeline - 项目总结

## 📁 文件结构

```
.claude/workflows/
├── sprint-execution-pipeline-unified.js              # 主 workflow（推荐）
├── sprint-execution-pipeline-unified-README.md       # 完整文档
├── sprint-execution-pipeline-unified-QUICKSTART.md   # 快速参考
├── sprint-execution-pipeline-SUMMARY.md              # 本文件
├── sprint-execution-pipeline-test.js                 # 测试版（调试用）
└── prd-compliance-audit.js                           # PRD 合规审计
```

## 🎯 核心设计

### Skill 驱动架构

workflow 严格通过三个 Skill 执行所有操作，不重复实现已有能力：

```
workflow script
│
├─ callSprintExecute()     → /my-sprint-execute
│   └─ Git + 代码 + 测试 + PR（via /my-pr-skill）
│
├─ executeReviewerReview() → workflow 内置质量门禁
│   └─ 评分 + 自动修复
│
└─ waitForPRMerge()        → 单 agent 内部轮询
    ├─ gh pr view（状态检查）
    └─ /my-pr-review-response（review 反馈处理）
```

### 性能优化

| 优化点 | 旧方案 | 新方案 | 收益 |
|--------|--------|--------|------|
| PR 轮询 | 每轮 spawn 2 agent（sleep + check） | 单 agent 内部循环 | ~480 → 1 agent 调用 |
| PR 查找 | 硬编码分支名 `branch-sprint-N` | agent 智能匹配 PR 列表 | 适配任意分支命名 |
| Review 检测 | 检查 `state === 'CHANGES_REQUESTED'` | 检查 `reviewDecision` + `reviews` | 正确识别 review 状态 |
| 失败处理 | 继续执行后续 Phase | 立即停止 | 避免无效执行 |

### Review 检测修复

**问题**：GitHub PR 的 `state` 字段只有 `OPEN`/`CLOSED`/`MERGED`，永远不会有 `CHANGES_REQUESTED`。

**修复**：
```javascript
// 查询时包含 reviewDecision 和 reviews
gh pr view --json state,mergedAt,reviewDecision,reviews

// 检测逻辑
hasChangeRequests = reviewDecision === 'CHANGES_REQUESTED'
  || reviews.some(r => r.state === 'CHANGES_REQUESTED')
```

## ⚙️ 配置参考

### 脚本常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `REPO` | `yuanyuanyuan/hermesDevOrchestra` | 目标仓库 |
| `POLL_INTERVAL_SECONDS` | `60` | 轮询间隔 |
| `MAX_POLL_MINUTES` | `240` | 最大等待时间 |

### Reviewer 配置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `enabled` | `true` | 启用独立审查 |
| `maxAttempts` | `3` | 最大审查尝试 |
| `passThreshold` | `0.8` | 通过阈值 |
| `softPassThreshold` | `0.70` | 无 critical 时最低分 |
| `autoFixEnabled` | `true` | 启用自动修复 |

### 调用参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `args.planPath` | `plan-sprint-*.md` | Plan 路径模板 |
| `args.checklistPath` | `execution-checklist.md` | 验收清单路径 |

## 📊 Sprint 依赖图

```
1 → 2 → 3 ──→ 5 ──→ 9 ──→ 12 → 13
        ├──→ 4 ──→ 6 ──┘
        ├──→ 7 ──────────┘
        ├──→ 8 ──────────┘
        └──→ 10 → 11 ───┘
```

| Phase | Sprints | 执行方式 |
|-------|---------|---------|
| Sprint-1 | 1 | 串行 |
| Sprint-2 | 2 | 串行 |
| Sprint-3-4-7-8-10 | 3, 4, 7, 8, 10 | 并行 |
| Sprint-5-6-11 | 5, 6, 11 | 并行 |
| Sprint-9 | 9 | 串行 |
| Sprint-12 | 12 | 串行 |
| Sprint-13 | 13 | 串行 |

## 🔧 维护指南

### 修改仓库

```javascript
// sprint-execution-pipeline-unified.js 第 ~30 行
const REPO = 'your-org/your-repo'
```

### 禁用独立审查

```javascript
REVIEWER_CONFIG.enabled = false
```

### 调整通过阈值

```javascript
REVIEWER_CONFIG.passThreshold = 0.9     // 更严格
REVIEWER_CONFIG.softPassThreshold = 0.80 // 提高软阈值
```

### 添加审查标准

```javascript
REVIEWER_CONFIG.reviewCriteria.push('国际化支持')
```

## 🚨 已知限制

1. **Plan 路径通配符**：`planPath` 中的 `*` 会被替换为 Sprint 号，需确保文件存在
2. **并行 Sprint 共享仓库**：并行执行的 Sprint 会各自创建分支，但 PR 创建可能冲突
3. **轮询 agent 时长**：单个轮询 agent 最长运行 4 小时，受 agent 超时限制
4. **Review 评论处理**：`COMMENTED` 状态首次处理后标记跳过，不会重复处理

## 📚 文档导航

| 文档 | 用途 |
|------|------|
| `sprint-execution-pipeline-unified-QUICKSTART.md` | 快速上手 |
| `sprint-execution-pipeline-unified-README.md` | 完整文档 |
| `sprint-execution-pipeline-SUMMARY.md` | 本文件（项目总结） |
| `sprint-execution-pipeline-test.js` | 测试版（调试用） |

## 🎉 成功标志

```
📊 执行总结
✅ 完成: 13 — 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
❌ 失败: 无

状态: completed
```
