# GitHub PR Review API 格式要求

## Review 事件类型

| 事件 | 用途 | 限制 |
|------|------|------|
| `COMMENT` | 提交评论（不改变 PR 状态） | **必须用此事件** — GitHub 不允许 approve 自己的 PR |
| `APPROVE` | 标记为 approved | ❌ 不能用于自己的 PR |
| `REQUEST_CHANGES` | 标记为 changes requested | ❌ 不能用于自己的 PR |

## POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews

### 请求体字段

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `event` | string | 是 | `"COMMENT"` |
| `body` | string | 是 | Review 摘要文本 |
| `comments` | array | 否 | 行内评论数组 |

### 行内评论格式（comments 数组元素）

```json
{
  "path": "src/file.py",
  "position": 5,
  "body": "comment text"
}
```

**关键字段说明：**
- `path` — 文件相对于仓库根目录的路径
- `position` — diff 中的位置（0-indexed，从 diff hunk header 后的第一行开始计数）
- `body` — 评论内容（Markdown）

### 常见错误

```
"Invalid request.\n\nNo subschema in \"oneOf\" matched.\n\"positioning\" wasn't supplied.\n\"path\", \"position\" weren't supplied."
```

**原因：** comments 数组元素缺少 `path` 或 `position` 字段。
**修复：** 确保每个 comment 都有 `path` 和 `position`。

### 替代方案：Issue Comments（无行内定位）

如果不需要行内评论，使用 Issue Comments API 更简单：

```bash
gh pr comment <PR_NUMBER> --body "review body"
```

或 API：

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  --method POST \
  --field body="comment text"
```

## 推荐策略

1. **Review Body** — 使用 PR Review API 的 `COMMENT` 事件提交
2. **行内评论** — 如果需要精确定位，用 `comments` 数组
3. **降级方案** — 如果行内评论 API 报错，回退到 Issue Comment
