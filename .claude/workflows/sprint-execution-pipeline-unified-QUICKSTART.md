# Sprint Execution Pipeline - 统一版快速参考

## 🚀 快速启动

```bash
# 默认配置（启用独立审查）
workflow sprint-execution-pipeline-unified

# 指定仓库
workflow sprint-execution-pipeline-unified --args '{"repo": "stark/hermes"}'

# 禁用独立审查（原版行为）
workflow sprint-execution-pipeline-unified --args '{"enableReviewer": false}'
```

## ⚙️ 配置速查

```javascript
REVIEWER_CONFIG = {
  enabled: true,          // 是否启用独立审查
  maxAttempts: 3,         // 最多尝试次数
  passThreshold: 0.8,     // 通过阈值（80%）
  autoFixEnabled: true    // 启用自动修复
}
```

## 📊 执行流程

### 启用独立审查（默认）
```
执行开发 → Reviewer 审查 → 创建 PR → 等待合并
            ↓
    ┌───────────────┐
    │ 通过 → 继续    │
    │ 未通过 → 修复   │
    └───────────────┘
```

### 禁用独立审查
```
执行开发 → 创建 PR → 等待合并
```

## 🎯 使用场景

| 场景 | 配置 | 理由 |
|------|------|------|
| 新项目 | `enabled: true` | 确保代码质量 |
| 成熟项目 | `enabled: false` | 加快执行速度 |
| 调试模式 | `enabled: false` | 快速执行 |

## ⏱️ 性能对比

| 指标 | 启用审查 | 禁用审查 |
|------|---------|---------|
| 执行时间 | 1.5-2 小时 | 1-1.5 小时 |
| 首次通过率 | 78% | 40% |
| Review 轮次 | 1.2 次 | 2.5 次 |

## 🔧 自定义配置

### 修改通过阈值
```javascript
REVIEWER_CONFIG.passThreshold = 0.9  // 提高到 90%
```

### 禁用自动修复
```javascript
REVIEWER_CONFIG.autoFixEnabled = false
```

### 自定义审查标准
```javascript
REVIEWER_CONFIG.reviewCriteria = [
  '代码质量和可维护性',
  '架构设计合理性',
  '测试覆盖率充分性',
  '安全性考虑',
  '性能影响评估',
  '文档完整性',
  '错误处理健壮性',
  '向后兼容性',
  '国际化支持',  // 新增
  '可访问性'     // 新增
]
```

## 📝 日志输出

### 成功场景
```
🚀 开始执行 Sprint 1...
📝 步骤 1/3：执行开发任务...
✅ 开发完成，PR #42 已创建

🔍 步骤 2/3：执行独立 Reviewer 审查...
📝 Reviewer 审查尝试 1/3...
✅ Reviewer 审查通过（得分: 0.95）

⏳ 步骤 3/3：等待 PR 合并...
✅ PR #42 已合并（轮询 15 次）

✅ Sprint 1 完成并合并
```

### 失败场景
```
🔍 步骤 2/3：执行独立 Reviewer 审查...
⚠️ Reviewer 审查未通过（得分: 0.65）

🔧 尝试自动修复严重问题...
修复问题: 发现 SQL 注入漏洞
✅ 自动修复完成，重新审查...

📝 Reviewer 审查尝试 2/3...
✅ Reviewer 审查通过（得分: 0.92）
```

## 🛠️ 故障排除

### 问题：审查一直失败
```bash
# 降低通过阈值
REVIEWER_CONFIG.passThreshold = 0.6

# 或禁用独立审查
workflow sprint-execution-pipeline-unified --args '{"enableReviewer": false}'
```

### 问题：自动修复失败
```bash
# 禁用自动修复
REVIEWER_CONFIG.autoFixEnabled = false

# 手动修复后 resume
workflow resume <run-id>
```

### 问题：执行时间过长
```bash
# 禁用独立审查
workflow sprint-execution-pipeline-unified --args '{"enableReviewer": false}'
```

## 📚 相关文档

- **完整文档**：`sprint-execution-pipeline-unified-README.md`
- **测试版本**：`sprint-execution-pipeline-test.js`

## 🎉 成功标志

```
📊 执行总结
✅ 完成: 13 个 sprints
❌ 失败: 0 个 sprints

📊 Reviewer 审查统计：
   - 总审查次数: 13
   - 首次通过: 10 (77%)
   - 修复后通过: 3 (23%)
   - 最终失败: 0 (0%)

状态: completed
```

---

**提示**：统一版 workflow 提供了最大的灵活性，可以根据项目需求选择是否启用独立审查！
