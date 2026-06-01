# PR Review Response Comment 格式规范

> 基于 GitHub Issue Comment API / Pull Request Review Comment API 文档设计。
> 目标：同时服务人类可读性和 Agent 可解析性。

## 双层格式设计

所有 response comment 采用**双层格式**：

- **外层（可视化层）**：Markdown — 供人类阅读，含 emoji、表格、折叠区域、代码块
- **内层（元数据层）**：HTML Comment — 供 Agent 解析，含结构化 JSON

```markdown
<!--AGENT_META:{"type":"review_fix","version":"1.0",...}-->

✅ **Fixed** — `src/file.py:23`
...
```

> **为什么用 HTML Comment？**
> - GitHub Markdown 渲染器会忽略 `<!-- -->` 内容，不在 UI 中显示
> - API 返回的原始 `body` 字段完整保留注释内容
> - Agent 可通过正则 `/<!--AGENT_(META|FINDING|RESPONSE):({.*?})-->/g` 提取

---

## 模板类型总览

| 模板 | 用途 | API |
|------|------|-----|
| `review_fix` | 单条修复结果 | `add_issue_comment` |
| `review_counter` | 单条反驳说明 | `add_issue_comment` |
| `review_response_summary` | 全部处理完毕后的汇总 | `add_issue_comment` |

---

## 模板 1: 修复 Comment（review_fix）

用于回复单条 AGREE 的 review 意见。

### AGENT_META Schema

```json
{
  "type": "review_fix",
  "version": "1.0",
  "pr_number": 42,
  "item_id": "f-1",
  "file": "src/pool.py",
  "line": 45,
  "status": "fixed | partially_fixed | wont_fix_justified",
  "commit": "def456abc...",
  "change_summary": "Added try/finally to ensure connection release"
}
```

### 完整模板

```markdown
<!--AGENT_META:{"type":"review_fix","version":"1.0","pr_number":${PR_NUMBER},"item_id":"${ITEM_ID}","file":"${FILE}","line":${LINE},"status":"fixed","commit":"${COMMIT}"}-->

✅ **Fixed** — \`${FILE}:${LINE}\`

> **Original Issue:** ${ISSUE_SUMMARY}

**Change Summary:** ${CHANGE_SUMMARY}

<details>
<summary>View Diff</summary>

\`\`\`diff
${DIFF_SNIPPET}
\`\`\`
</details>

**Verification:** ${VERIFICATION_RESULT}

Commit: \`${COMMIT}\`
```

### 变体：部分修复

```markdown
<!--AGENT_META:{"type":"review_fix","version":"1.0","pr_number":42,"item_id":"f-3","file":"src/api.py","line":78,"status":"partially_fixed","commit":"def456"}-->

🟡 **Partially Fixed** — `src/api.py:78`

> **Original Issue:** Add input validation to all endpoints

**Change Summary:** Added validation to 5/6 endpoints. The `/health` endpoint intentionally accepts any input (always returns 200).

**Rationale:** `/health` is a probe endpoint; validation would add latency without benefit.

Commit: `def456`
```

---

## 模板 2: 反驳 Comment（review_counter）

用于回复单条 DISAGREE 的 review 意见。必须满足反驳门槛。

### AGENT_META Schema

```json
{
  "type": "review_counter",
  "version": "1.0",
  "pr_number": 42,
  "item_id": "f-2",
  "file": "src/api.py",
  "line": 12,
  "status": "disagreed",
  "reason_type": "out_of_scope | not_a_bug | design_intention | insufficient_evidence | already_addressed | false_positive"
}
```

### 完整模板

```markdown
<!--AGENT_META:{"type":"review_counter","version":"1.0","pr_number":${PR_NUMBER},"item_id":"${ITEM_ID}","file":"${FILE}","line":${LINE},"status":"disagreed","reason_type":"${REASON_TYPE}"}-->

❌ **Disagreed** — \`${FILE}:${LINE}\`

> **Original Issue:** ${ISSUE_SUMMARY}

**Reason:** ${COUNTER_REASON}

<details>
<summary>Evidence & Context</summary>

${EVIDENCE_LIST}
</details>

**Alternative (if applicable):** ${ALTERNATIVE_SUGGESTION}

Please re-consider this feedback.
```

### 证据列表格式

```markdown
- **Code Evidence:** ${CODE_SNIPPET_OR_LINK}
- **Doc Reference:** [Link](...) — ${QUOTE}
- **Test Evidence:** ${TEST_RESULT}
- **Architecture Reason:** ${ARCH_EXPLANATION}
```

---

## 模板 3: 汇总 Comment（review_response_summary）

全部意见处理完毕后发送的最终汇总。

### AGENT_META Schema

```json
{
  "type": "review_response_summary",
  "version": "1.0",
  "pr_number": 42,
  "responder": "stark-007",
  "commit": "def456abc...",
  "agree_count": 5,
  "disagree_count": 1,
  "total_count": 6,
  "items": [
    {
      "id": "f-1",
      "decision": "agree | disagree",
      "status": "fixed | partially_fixed | disagreed",
      "file": "src/pool.py",
      "line": 45
    }
  ]
}
```

### 完整模板

```markdown
<!--AGENT_META:{"type":"review_response_summary","version":"1.0","pr_number":${PR_NUMBER},"responder":"stark-007","commit":"${COMMIT}","agree_count":${AGREE_COUNT},"disagree_count":${DISAGREE_COUNT},"total_count":${TOTAL_COUNT},"items":[${ITEMS_JSON_ARRAY}]}-->

## 📋 Review Response Summary — PR #${PR_NUMBER}

All review comments have been addressed. Latest commit: \`${COMMIT}\`

### ✅ Fixed (${AGREE_COUNT})

| # | Issue | File | Commit |
|---|-------|------|--------|
| 1 | ${ISSUE_1} | \`${FILE_1}:${LINE_1}\` | \`${COMMIT_1}\` |
| ... | ... | ... | ... |

### ❌ Disagreed (${DISAGREE_COUNT})

| # | Issue | File | Reason |
|---|-------|------|--------|
| 1 | ${ISSUE_1} | \`${FILE_1}:${LINE_1}\` | ${REASON_1} |
| ... | ... | ... | ... |

---

**Please re-review.** 🙏
```

### 变体：含部分修复

当存在 `partially_fixed` 时，增加一个独立分组：

```markdown
### 🟡 Partially Fixed (1)

| # | Issue | File | Status |
|---|-------|------|--------|
| 3 | Add input validation | `src/api.py:78` | 5/6 endpoints covered |
```

---

## Emoji 规范

| 场景 | Emoji | 说明 |
|------|-------|------|
| Fixed | ✅ | 已修复 |
| Partially Fixed | 🟡 | 部分修复 |
| Disagreed | ❌ | 不同意 |
| Summary | 📋 | 汇总 |
| Re-review Request | 🙏 | 请求重新 review |
| Commit Ref | 🔗 | 提交引用 |
| Diff | 📝 | 代码变更 |
| Evidence | 📎 | 证据 |

---

## Agent 解析规范

### 正则提取模式

```regex
<!--AGENT_META:({.*?})-->
```

### 解析步骤

1. 遍历 PR 的 issue comments，提取所有含 `AGENT_META` 的 comment
2. 按 `type` 分组：`review_fix` / `review_counter` / `review_response_summary`
3. 交叉验证：汇总 comment 的 `items` 应与所有单条 comment 的 `item_id` 一一对应
4. 复核流程可利用这些元数据自动识别哪些问题已修复、哪些被反驳

---

## GitHub API 兼容性

- `body` 字段最大长度：**65536 字符**
- 若修复 comment 含大量 diff 导致超出限制 → 截断 diff 或链接到 commit diff
- HTML `<details>` 和 `<summary>` 标签在 GitHub 渲染中完全支持
- HTML 注释 `<!-- -->` 在渲染中被完全忽略
- 引用原文使用 `>` blockquote 格式，在 GitHub UI 中清晰可辨
