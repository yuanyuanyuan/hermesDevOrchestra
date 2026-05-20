# GitHub Review Comment 数据源

## 三种评论来源

| 来源 | API | 含义 | 典型内容 |
|------|-----|------|---------|
| Review Body | `GET /pulls/{n}/reviews` | reviewer 的整体评审意见 | REQUEST_CHANGES 的问题清单 |
| Review Comment | `GET /pulls/{n}/comments` | 代码行级 inline 评论 | 具体某行的修改建议 |
| Issue Comment | `GET /issues/{n}/comments` | PR 通用评论区 | 补充说明、讨论 |

## 读取优先级

1. **Review Body** — 重点关注 `state == "CHANGES_REQUESTED"` 的 body，提取问题清单
2. **Review Comments** — reviewer 在代码行上的 inline 评论，通常包含具体修改建议
3. **Issue Comments** — 补充讨论，可能包含 reviewer 的追加说明

## 注意事项

- Review Body 和 Review Comments 由 reviewer 通过 Review API 提交
- Issue Comments 是通用评论，任何人都可以发
- 处理响应时，三种来源都需要检查，避免遗漏
- Inline comments 的 `diff_hunk` 字段提供上下文代码片段
