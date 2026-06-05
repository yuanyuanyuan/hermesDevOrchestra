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

### 动态发现架构

workflow 不再硬编码 Sprint 列表，而是从目录动态发现：

```
main(sprintsDir)
│
├─ discoverSprints(dir)
│   扫描 plan-sprint-N.md + checklist-sprint-N.md
│   → { 1: {planPath, checklistPath}, 2: {...}, ... }
│
├─ parseDependencyGraph(dir, sprintNums)
│   解析 sprint-overview.md 表格
│   → { 1: [], 2: [1], 9: [6,8], ... }
│
├─ buildExecutionPhases(sprintNums, depGraph)
│   拓扑排序 → 可并行的执行阶段
│   → [{phase, sprints}, ...]
│
└─ 逐 Phase 执行（支持并行 + 恢复）
```

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

### 恢复机制

支持中断后恢复，不重复执行已完成的 Sprint：

| 状态 | 检测方式 | 行为 |
|------|---------|------|
| PR 已合并 | `findMergedPR()` 查 `gh pr list --state merged` | 跳过，日志 `⏭️` |
| PR 已创建（open） | `findExistingPR()` 查 `gh pr list --state open` | 跳过开发，直接审查 |
| 全新 | 无匹配 PR | 执行完整流程 |

### 性能优化

| 优化点 | 旧方案 | 新方案 | 收益 |
|--------|--------|--------|------|
| Sprint 发现 | 硬编码 13 个 Sprint | 目录扫描 + 自动解析 | 适配任意 Sprint 集合 |
| 依赖图 | 硬编码 `DEPENDENCY_GRAPH` | 从 `sprint-overview.md` 解析 | 依赖变更无需改代码 |
| 执行阶段 | 固定 7 个 Phase | 拓扑排序动态生成 | 自动最大化并行度 |
| PR 轮询 | 每轮 spawn 2 agent | 单 agent 内部循环 | ~480 → 1 agent 调用 |
| 恢复 | 无 | 检测已合并 PR 跳过 | 中断后无缝继续 |

## ⚙️ 配置参考

### 调用参数

| 参数 | 必需 | 说明 |
|------|------|------|
| `sprintsDir` | ✅ | Sprint 文件目录路径 |

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

## 📊 Sprint 目录示例

```
docs/sprints/prd-compliance-audit-remediation-full/
├── plan-sprint-1.md          # Sprint 1 开发计划
├── checklist-sprint-1.md     # Sprint 1 验收清单
├── plan-sprint-2.md
├── checklist-sprint-2.md
├── ...                       # Sprint 3-13 同理
├── sprint-overview.md        # 依赖关系表（自动解析）
├── schema.md                 # Schema 说明
└── spec.md                   # 规格说明
```

## 🔧 维护指南

### 修改仓库

```javascript
// sprint-execution-pipeline-unified.js
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

## 🚨 已知限制

1. **并行 Sprint 共享仓库**：并行执行的 Sprint 会各自创建分支，但 PR 创建可能冲突
2. **轮询 agent 时长**：单个轮询 agent 最长运行 4 小时，受 agent 超时限制
3. **依赖图解析**：依赖 `sprint-overview.md` 表格格式，非标准格式会降级为无依赖模式
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
