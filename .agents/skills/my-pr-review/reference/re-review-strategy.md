# 复核 Review 策略

## 触发条件

当 developer 修复了 review 发现的问题后，请求二次 review。

## 决策树

```
复核请求
  │
  ├─ 首次 review 无 FAIL 项？ → 不需要复核，直接确认
  │
  ├─ 自上次 review 后无新 commit？ → 告知 developer 未检测到新提交
  │
  └─ 有新 commit → 运行 diff-since.sh
       │
       ├─ scope: "none" → 告知无变更
       │
       ├─ scope: "partial"（≤20 文件变更）
       │    └─ 只对变更文件执行 ce-code-review（报告模式）
       │       → 检查原 FAIL 项是否已修复
       │       → 检查变更是否引入新问题
       │
       └─ scope: "full"（>20 文件变更）
            └─ 执行完整 ce-code-review
```

## 范围裁剪原则

### 部分复核（partial）
- 只审查 `diff-since.sh` 返回的变更文件
- 重点关注：原 FAIL 项对应的文件/行号是否已修改
- 如果变更文件中包含非原 review 范围的文件，也要检查是否引入新问题

### 完整复核（full）
- 当变更文件过多（>20）或触及核心模块时，执行完整 ce-code-review
- 与首次 review 流程相同

## 输出格式

复核报告必须包含：
1. **原问题修复状态** — 每个原 FAIL 项：已修复 / 未修复 / 部分修复
2. **新发现** — 变更引入的新问题（如果有）
3. **结论** — 通过 / 仍有阻塞项

## 提交方式

与首次 review 相同：使用 COMMENT 事件提交到 PR。
