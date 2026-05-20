---
name: my-pr-review
description: >
  对指定 GitHub PR 执行结构化 Code Review。
  使用 ce-code-review 执行审查，以 COMMENT 事件提交结果到 PR。
  支持首次 review 和智能复核（仅审查变更范围）。
  Reviewer 身份：stark-008。只做 review，不做修复。
---

# PR Review Skill

## 触发条件

- "review PR #N" / "对 PR 做 code review" / "review this PR"
- "复核 PR #N" / "re-review" / "二次 review"（触发复核流程）

## 调用签名

```
my-pr-review <PR_NUMBER> [--re-review]
```

## 环境要求

- `gh` CLI 已认证
- 当前目录为项目本地仓库

## 核心约束

1. **不修复代码** — 只提交 review 结果，不做任何代码修改
2. **不自我 approve** — 用 `COMMENT` 事件提交（GitHub 不允许 approve 自己的 PR）
3. **所有结果提交到 PR** — 每次 review 都必须有 PR comment 记录
4. **复核范围裁剪** — 二次 review 只审查变更文件，避免资源浪费

---

## 执行流程

### Phase 1: 情报收集

```bash
PR_INFO=$(bash scripts/collect-pr-info.sh ${PR_NUMBER})
```

脚本输出 JSON，包含：PR 元数据、变更文件列表、已有 review/comments。

**判断是否为复核：**
- 如果 `--re-review` 标记或用户明确要求复核 → 进入 Phase 1b
- 否则 → 进入 Phase 2

### Phase 1b: 复核范围检测

读取上次 review 记录的 commit OID（从 PR comments 中查找 reviewer stark-008 的最近 review）。

```bash
bash scripts/diff-since.sh ${PR_NUMBER} ${LAST_REVIEWED_OID}
```

根据 `scope` 决定：
- `none` → 无新提交，告知用户
- `partial`（≤20 文件）→ 只对变更文件做 ce-code-review
- `full`（>20 文件）→ 完整 ce-code-review

### Phase 2: 执行 Code Review

使用 ce-code-review 执行深度审查：

```
/compound-engineering:ce-code-review ${PR_NUMBER}
```

ce-code-review 会自动选择 reviewer personas、并行审查、合并结果。

### Phase 3: 智能判断（仅复核时）

复核场景下，在调用 ce-code-review 前，先读取原 review 的 FAIL 项清单：
- 如果变更文件完全覆盖原 FAIL 项涉及的文件 → 可以只做 partial review
- 如果变更文件不相关或范围过大 → 执行 full review

**判断依据：**
- 变更文件列表 vs 原 FAIL 项文件列表的交集
- 变更行数（小改动可只做针对性检查，大改动需完整 review）

### Phase 4: 生成 Review 报告

将 ce-code-review 的发现整理为结构化报告：

```markdown
# PR Review Report — PR #${PR_NUMBER}

**Reviewer:** stark-008
**Commit:** ${HEAD_OID}
**Timestamp:** $(date -Iseconds)
**Review Type:** [首次 review / 复核]

## 摘要
- 检查项: N | PASS: X | FAIL: Y | N/A: Z
- 发现项数量: Y
- 结论: [PASS / HAS_BLOCKERS]

## 发现项清单

### [P0/P1/P2/P3] 标题 — 文件:行号
- **问题描述:** ...
- **证据:** ...
- **建议修复:** ...

（每个 FAIL 项一条）

## 复核场景额外内容（如有）
### 原问题修复状态
| 原问题 | 文件 | 状态 |
|--------|------|------|
| #1 | path:line | ✅ 已修复 / ❌ 未修复 |

### 新发现
（变更引入的新问题）
```

### Phase 5: 提交到 PR

```bash
bash scripts/submit-review.sh ${PR_NUMBER} /tmp/pr-review-${PR_NUMBER}.md
```

脚本处理：
1. 用 `COMMENT` 事件提交 review body
2. 如果有行内评论需求，通过 `comments` 数组提交（自动处理 API 格式要求）
3. 如果行内评论 API 报错，降级为纯 body 评论
4. 添加 `reviewed` 标签到 PR

---

## 止损条件

- `gh` CLI 不可用 → 报告 blocker，停止
- PR diff > 5000 行 → 报告超出范围，建议人工介入
- ce-code-review 执行失败 → 报告错误，降级为手动 checklist review
- 敏感信息泄露 → 立即报告，不继续 review

---

## 参考文档

- `reference/github-review-api.md` — GitHub Review API 格式要求和常见错误
- `reference/re-review-strategy.md` — 复核策略决策树
- `scripts/collect-pr-info.sh` — PR 信息收集
- `scripts/diff-since.sh` — 变更范围检测
- `scripts/submit-review.sh` — Review 提交（COMMENT 事件）
