# GitHub PR Review API 格式要求

> 基于 [GitHub REST API — Pulls/Reviews](https://docs.github.com/en/rest/pulls/reviews) 和 [Pulls/Comments](https://docs.github.com/en/rest/pulls/comments) 文档。

## Review 事件类型

| 事件 | 用途 | 限制 |
|------|------|------|
| `COMMENT` | 提交评论（不改变 PR 状态） | **必须用此事件** — stark-008 只做 review 不 approve |
| `APPROVE` | 标记为 approved | ❌ 不能用于自己的 PR |
| `REQUEST_CHANGES` | 标记为 changes requested | ❌ 不能用于自己的 PR |

## POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews

### 请求体字段

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `commit_id` | string | 是 | 被 review 的 commit SHA |
| `event` | string | 是 | `"COMMENT"` |
| `body` | string | 是 | Review 摘要文本（Markdown） |
| `comments` | array | 否 | 行内评论数组 |

### body 字段规范

- **支持 Markdown** — 标题、列表、表格、代码块、引用均可用
- **支持 HTML 标签** — `<details>`、`<summary>` 折叠区域在 GitHub UI 中完全支持
- **支持 HTML 注释** — `<!-- -->` 在渲染中被忽略，但保留在原始文本中（用于 agent 元数据）
- **最大长度：65536 字符** — 超出需截断

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
- `body` — 评论内容（Markdown），最大长度 65536 字符

**body 内也可嵌套 HTML 注释元数据**，用于 agent 解析 inline comment 的级别和 ID：

```markdown
<!--AGENT_INLINE:{"id":"f-1","level":"P0","file":"src/file.py","line":23}-->

❌ **[P0] Memory leak**

See review body for full details.
```

### 多行评论（Line Range）

GitHub 支持对多行代码块发表评论：

```json
{
  "path": "src/file.py",
  "commit_id": "abc123...",
  "body": "...",
  "start_line": 10,
  "start_side": "RIGHT",
  "line": 15,
  "side": "RIGHT"
}
```

- `start_line` + `start_side` + `line` + `side` → 指定多行范围
- `side` / `start_side`: `"LEFT"` (base) 或 `"RIGHT"` (head)
- 当评论针对新增代码时，使用 `"RIGHT"`

### 常见错误

```
"Invalid request.\n\nNo subschema in \"oneOf\" matched.\n\"positioning\" wasn't supplied.\n\"path\", \"position\" weren't supplied."
```

**原因：** comments 数组元素缺少 `path` 或 `position` 字段。
**修复：** 确保每个 comment 都有 `path` 和 `position`。

---

## 双层格式最佳实践

Review body 采用**双层格式**：Markdown 可视化层 + HTML Comment 元数据层。

### 为什么这样做？

1. **人类可读** — Markdown 渲染出清晰的视觉层次（emoji、表格、折叠区域）
2. **Agent 可解析** — HTML 注释中的 JSON 元数据可被后续 agent 通过 API 提取解析
3. **GitHub 原生支持** — 注释在 UI 中不可见，API 原始 body 中完整保留

### 结构示例

```markdown
<!--AGENT_META:{"type":"pr_review","version":"1.0","pr_number":42,...}-->

# 🔍 PR Review Report — PR #42
...

<!--AGENT_FINDING:{"id":"f-1","level":"P0","file":"src/pool.py","line":45}-->
```

详见 `comment-format-guide.md` 中的完整模板规范。

---

## 替代方案

### Issue Comments（无行内定位）

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

### Review Comment Reply（回复已有行内评论）

```bash
POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies
```

Body 参数仅需要 `body`。`comment_id` 必须是**顶层行内评论**的 ID，不支持回复的回复。

---

## 推荐策略

1. **Review Body** — 使用 PR Review API 的 `COMMENT` 事件提交整体报告（双层格式）
2. **行内评论** — 通过 `comments[]` 数组创建，每条含精简内容和 AGENT_INLINE 元数据
3. **降级方案** — 如果 `comments[]` API 报错，降级为 body-only（完整 findings 展开在 body 中）
4. **Reply** — 如需回复 reviewer 的已有 inline comment，使用 replies API
