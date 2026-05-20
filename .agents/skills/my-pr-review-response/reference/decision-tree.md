# Review 意见处理决策树

## 逐项审查流程

```
review 意见
  │
  ├─ 1. 理解：引用原文 + 读取上下文 + 判断类型
  │     类型: bug / style / architecture / doc / test
  │
  ├─ 2. 排查：/diagnose 逐项检查
  │     ├─ 检查代码是否确实存在问题
  │     ├─ 运行相关测试验证
  │     └─ 记录验证证据
  │
  └─ 3. 决策
        ├─ AGREE → 修复流水线（/tdd）
        └─ DISAGREE → 反驳流水线
```

## 反驳门槛（缺一不可）

- [ ] 有代码/文档证据
- [ ] 有架构理由
- [ ] 有替代方案（如适用）

## 止损条件

| 类型 | 触发条件 |
|------|---------|
| `out-of-scope` | 涉及文件不在当前 PR 中 |
| `test-env-conflict` | 修复后测试持续失败 3 次（与修复无关） |
| `contradictory-review` | reviewer 意见自相矛盾 |
| `tool-unavailable` | gh CLI 不可用 |
| `merge-conflict` | 存在未解决的合并冲突 |
| `unclear-review` | 无法解析出明确问题清单 |
