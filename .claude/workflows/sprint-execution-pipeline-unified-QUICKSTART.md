# Sprint Execution Pipeline - 统一版快速参考

## 🚀 快速启动

```bash
# 通过 slash command（需传入 sprintsDir）
/sprint-execution-pipeline-unified

# 通过 Workflow 工具调用（必须指定 sprintsDir）
Workflow({
  name: "sprint-execution-pipeline-unified",
  args: {
    sprintsDir: "/data/hermes/docs/sprints/prd-compliance-audit-remediation-full"
  }
})
```

## 📂 Sprint 目录结构要求

目录中需包含以下文件（自动发现）：

```
sprints-dir/
├── plan-sprint-1.md          # Sprint 1 的开发计划（必需）
├── checklist-sprint-1.md     # Sprint 1 的验收清单（必需）
├── plan-sprint-2.md
├── checklist-sprint-2.md
├── ...
├── sprint-overview.md        # 依赖关系表（用于自动解析依赖图）
└── schema.md                 # Schema 说明（可选）
```

## ⚙️ 配置速查

```javascript
REPO = 'yuanyuanyuan/hermesDevOrchestra'   // 目标仓库（脚本内常量）

REVIEWER_CONFIG = {
  enabled: true,            // 是否启用独立审查
  maxAttempts: 3,           // 最多尝试次数
  passThreshold: 0.8,       // 通过阈值（80%）
  softPassThreshold: 0.70,  // 无 critical 时的最低通过分
  autoFixEnabled: true      // 启用自动修复
}
```

## 📊 Skill 调用链

```
Sprint 执行流程
│
├─ 步骤 0a: findMergedPR（恢复模式 — 已合并则跳过）
├─ 步骤 0b: findExistingPR（已有 open PR 则跳过开发）
│
├─ 步骤 1: /my-sprint-execute
│  ├─ Git 分支 (feat/sprintN)
│  ├─ 顺序执行 Plan 任务
│  ├─ 验证验收 (test + checklist)
│  └─ PR 创建 (/my-pr-skill → manage-pr.sh)
│
├─ 步骤 2: 独立 Reviewer (质量门禁)
│  └─ 评分 → 通过 / 勉强通过 / 自动修复 / 失败
│
└─ 步骤 3: 等待 PR 合并
   ├─ 单 agent 内部轮询（高效）
   └─ 检测到 review → /my-pr-review-response
      ├─ 读评论 + 修复代码 + 推送
      └─ 回复 review comments
```

## 🎯 审查通过规则

| 条件 | 结果 |
|------|------|
| 得分 ≥ 0.80 且 passed | ✅ 通过 |
| 得分 ≥ 0.70 且无 critical issues | ⚠️ 勉强通过 |
| 得分 < 0.70 或有 critical issues | 🔧 尝试自动修复 → 重审 |
| 自动修复 3 次仍失败 | ❌ 中止 Sprint |

## 📝 日志输出

### 成功场景
```
🚀 开始执行 Sprint 1...
📝 步骤 1/3：调用 /my-sprint-execute 执行开发任务...
✅ PR #34 已确认

🔍 步骤 2/3：执行独立 Reviewer 审查...
✅ Reviewer 审查通过（得分: 0.85）

⏳ 步骤 3/3：等待 PR 合并...
✅ PR #34 已合并

✅ Sprint 1 完成
```

### 恢复场景（Sprint 已完成）
```
🚀 开始执行 Sprint 1...
⏭️ Sprint 1 已完成（PR #34 已合并 @ 2026-06-03T10:30:00Z），跳过
```

## 🛠️ 故障排除

| 问题 | 解决方案 |
|------|---------|
| `缺少必需参数 sprintsDir` | 传入 `args: { sprintsDir: "/path/to/sprints" }` |
| `Sprint N 缺少 plan 文件` | 确保目录中有 `plan-sprint-N.md` |
| `Sprint N 缺少 checklist 文件` | 确保目录中有 `checklist-sprint-N.md` |
| Reviewer 一直失败 | 降低 `passThreshold` 或禁用 `enabled: false` |
| PR 轮询超时 | 检查 PR 是否需要手动合并 |
| 依赖未满足 | 确保前序 Sprint 已合并 |

## 📚 相关文档

- **完整文档**：`sprint-execution-pipeline-unified-README.md`
- **项目总结**：`sprint-execution-pipeline-SUMMARY.md`
- **Skill 定义**：
  - `/data/hermes/.agents/skills/my-sprint-execute/`
  - `/data/hermes/.agents/skills/my-pr-skill/`
  - `/data/hermes/.agents/skills/my-pr-review-response/`
