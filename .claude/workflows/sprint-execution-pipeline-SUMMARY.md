# Sprint Execution Pipeline - 文件结构总结

## 📁 最终文件结构

```
.claude/workflows/
├── sprint-execution-pipeline-unified.js          # 统一版 workflow（推荐）
├── sprint-execution-pipeline-unified-README.md   # 完整文档
├── sprint-execution-pipeline-unified-QUICKSTART.md  # 快速参考
└── sprint-execution-pipeline-test.js             # 测试版（调试用）
```

## 🎯 文件说明

### 1. `sprint-execution-pipeline-unified.js` (19.2K)
**统一版 workflow** - 推荐使用

**功能**：
- ✅ 执行 13 个 Sprint
- ✅ 可配置的独立 Reviewer 审查
- ✅ 自动修复严重问题
- ✅ PR 轮询等待合并
- ✅ 处理 GitHub Review 反馈
- ✅ 超时暂停和 Resume 恢复

**配置**：
```javascript
const REVIEWER_CONFIG = {
  enabled: true,          // 是否启用独立审查
  maxAttempts: 3,         // 最多尝试次数
  passThreshold: 0.8,     // 通过阈值
  autoFixEnabled: true    // 启用自动修复
}
```

**使用**：
```bash
# 默认配置（启用独立审查）
workflow sprint-execution-pipeline-unified

# 禁用独立审查
workflow sprint-execution-pipeline-unified --args '{"enableReviewer": false}'
```

### 2. `sprint-execution-pipeline-unified-README.md` (8.4K)
**完整文档** - 详细说明

**内容**：
- 功能概述
- 配置参数详解
- 执行流程说明
- 使用场景示例
- 性能对比
- 自定义配置
- 故障排除
- 最佳实践

### 3. `sprint-execution-pipeline-unified-QUICKSTART.md` (3.7K)
**快速参考** - 快速上手

**内容**：
- 快速启动命令
- 配置速查
- 执行流程图
- 使用场景表
- 性能对比表
- 自定义配置示例
- 日志输出示例
- 故障排除速查

### 4. `sprint-execution-pipeline-test.js` (4.8K)
**测试版** - 调试用

**功能**：
- ✅ 执行前 2 个 Sprint
- ✅ 10 秒轮询间隔
- ✅ 最多 10 次轮询
- ✅ 简化的 Reviewer 逻辑

**使用**：
```bash
# 测试版本（快速验证）
workflow sprint-execution-pipeline-test
```

**适用场景**：
- 验证 workflow 逻辑
- 测试轮询机制
- 调试 Reviewer 审查
- 快速验证配置

## 🚀 使用建议

### 首次使用
```bash
# 1. 先运行测试版本验证
workflow sprint-execution-pipeline-test

# 2. 确认逻辑正确后，使用统一版
workflow sprint-execution-pipeline-unified
```

### 生产环境
```bash
# 启用独立审查（推荐）
workflow sprint-execution-pipeline-unified --args '{"repo": "stark/hermes"}'

# 或禁用独立审查（加快速度）
workflow sprint-execution-pipeline-unified --args '{"repo": "stark/hermes", "enableReviewer": false}'
```

### 调试模式
```bash
# 使用测试版本快速验证
workflow sprint-execution-pipeline-test

# 或禁用独立审查
workflow sprint-execution-pipeline-unified --args '{"enableReviewer": false}'
```

## 📊 功能对比

| 功能 | 统一版 | 测试版 |
|------|--------|--------|
| Sprint 数量 | 13 | 2 |
| 轮询间隔 | 60 秒 | 10 秒 |
| 最大轮询 | 240 次 | 10 次 |
| 独立审查 | 可配置 | 简化版 |
| 自动修复 | 支持 | 不支持 |
| Resume 支持 | 支持 | 不支持 |

## 🎨 配置示例

### 示例 1：新项目（推荐）
```javascript
// 启用独立审查，确保代码质量
const REVIEWER_CONFIG = {
  enabled: true,
  maxAttempts: 3,
  passThreshold: 0.8,
  autoFixEnabled: true
}
```

### 示例 2：成熟项目
```javascript
// 禁用独立审查，加快执行速度
const REVIEWER_CONFIG = {
  enabled: false
}
```

### 示例 3：严格质量要求
```javascript
// 提高通过阈值，禁用自动修复
const REVIEWER_CONFIG = {
  enabled: true,
  maxAttempts: 5,
  passThreshold: 0.9,
  autoFixEnabled: false
}
```

### 示例 4：宽松质量要求
```javascript
// 降低通过阈值，启用自动修复
const REVIEWER_CONFIG = {
  enabled: true,
  maxAttempts: 3,
  passThreshold: 0.6,
  autoFixEnabled: true
}
```

## 🔧 维护说明

### 更新 workflow
1. 编辑 `sprint-execution-pipeline-unified.js`
2. 测试修改：`workflow sprint-execution-pipeline-test`
3. 验证无误后使用统一版

### 添加新功能
1. 在 `REVIEWER_CONFIG` 中添加配置项
2. 在 `executeReviewerReview` 中实现逻辑
3. 更新文档说明

### 修复问题
1. 使用测试版本复现问题
2. 修复 `sprint-execution-pipeline-unified.js`
3. 验证修复：`workflow sprint-execution-pipeline-test`
4. 更新文档说明

## 📚 文档导航

### 快速上手
- **快速参考**：`sprint-execution-pipeline-unified-QUICKSTART.md`
- **测试版本**：`sprint-execution-pipeline-test.js`

### 详细文档
- **完整文档**：`sprint-execution-pipeline-unified-README.md`
- **配置说明**：查看 `REVIEWER_CONFIG` 部分

### 故障排除
- **常见问题**：查看快速参考的"故障排除"部分
- **详细排查**：查看完整文档的"故障排除"部分

## 🎉 成功标志

当看到以下输出时，表示执行成功：

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
