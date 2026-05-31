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

## 环境要求
- `gh` CLI 已认证，当前目录为项目本地仓库

## 核心约束
- 只 review 不修复，COMMENT 事件提交，每次 review 有 PR comment 记录

---

## 执行流程

### Phase 1: 情报收集

```bash
PR_INFO=$(bash scripts/collect-pr-info.sh ${PR_NUMBER})
```

脚本输出 JSON，包含：PR 元数据、变更文件列表、已有 review/comments。

**判断是否为复核：**
- 用户显式说"复核/re-review/二次review"或带 `--re-review` → Phase 1b
- 用户说"review PR #N"且该 PR 已有 stark-008 的 review → 提示用户"首次review或复核?"
- 否则 → Phase 2

### Phase 1b: 复核范围检测

**获取上次 review commit：**
```bash
LAST_REVIEWED_OID=$(gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
  --jq '[.[] | select(.user.login == "stark-008")] | max_by(.submitted_at).commit_id')
```
- 无记录 → 视为首次 review
- `LAST_REVIEWED_OID == HEAD_OID` → 止损（无新提交）

**获取变更文件：**
```bash
bash scripts/diff-since.sh ${PR_NUMBER} ${LAST_REVIEWED_OID}
```

### ⏸ 检查点 1: PR 信息确认

Phase 1 完成后展示摘要并请求确认：

```
PR #${PR_NUMBER}: ${TITLE} by ${AUTHOR}
变更: ${CHANGED_FILES} 文件 (+${ADDITIONS}/-${DELETIONS})  类型: [首次/复核]
是否继续? [确认/取消/调整范围]
```

- **取消** → 终止，记录原因
- **调整范围** → 回到 Phase 1，按用户指定文件重收集
- **确认** → 进入 Phase 2

---

### Phase 2: 执行 Code Review

```
/compound-engineering:ce-code-review ${PR_NUMBER}
```

**引擎行为：** 自动选择 reviewer personas，并行多维度审查，输出结构化 JSON（含 `level`(P0-P3)、`file`、`line`、`title`、`description`、`evidence`、`suggestion`）。

**前置检查：**
- `gh` CLI 未认证 → 止损流程
- ce-code-review 返回非 0 或格式异常 → 降级为手动 checklist review

### Phase 3: 复核策略决策（仅复核时）

综合变更文件数 + 原 FAIL 项覆盖度决定范围：

| 文件数 | FAIL 覆盖度 | 决策 | 执行 |
|--------|------------|------|------|
| 0 | — | none | 已在 1b 拦截 |
| ≤20 | 完全/部分 | partial | `ce-code-review ${PR_NUMBER} --files ${DIFF_FILES}` |
| >20 | 任意 | full | `ce-code-review ${PR_NUMBER}` |

**覆盖度判定：** 变更文件列表 ∩ 原 FAIL 项文件列表

### ⏸ 检查点 2: 复核范围确认（仅复核）

Phase 1b/3 后展示计划：
```
复核: ${SCOPE}  文件: ${DIFF_FILE_COUNT}  原FAIL覆盖: [是/否/部分]
执行? [确认/改完整review/取消]
```

---

### Phase 4: 生成 Review 报告

将 ce-code-review 的 JSON 输出映射到报告模板：
- `level` → `[P0/P1/P2/P3]` 前缀
- `file`+`line` → `文件:行号`
- `title`+`description`+`evidence`+`suggestion` → 对应段落
- 统计 PASS/FAIL/N/A 生成摘要

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

### ⏸ 检查点 3: 提交前确认

调用 submit-review.sh 前展示摘要：

```
PR #${PR_NUMBER}: 检查项 N | PASS X | FAIL Y | 结论 [PASS/HAS_BLOCKERS]
提交方式: COMMENT (stark-008)
是否提交? [提交/修改/取消]
```

- **修改** → 展示完整报告，按反馈调整后重新确认
- **取消** → 保存到本地，不提交
- **确认** → 进入 Phase 5

---

### Phase 5: 提交到 PR

```bash
bash scripts/submit-review.sh ${PR_NUMBER} /tmp/pr-review-${PR_NUMBER}.md
```

脚本处理：
1. 用 `COMMENT` 事件提交 review body
2. 如果有行内评论需求，通过 `comments` 数组提交（自动处理 API 格式要求）
3. 如果行内评论 API 报错，降级为纯 body 评论
4. 添加 `reviewed` 标签到 PR

**提交失败 fallback：**
- API 权限不足 → 提示用户检查 `gh` 认证状态，保存报告到本地
- 网络超时 → 重试 1 次，仍失败则保存报告并告知用户手动提交
- PR 已关闭/合并 → 报告状态变化，不提交

---

## 止损与异常处理

触发时**不自主停止**，报告用户并请求决策：

| 场景 | 用户提示 | 操作选项 |
|------|---------|---------|
| gh CLI 不可用/未认证 | CLI 状态异常，无法获取 PR 信息 | 修复后重试 / 取消 |
| PR 404/无权限 | PR #N 不存在或无权限访问 | 修正编号 / 取消 |
| PR diff > 5000 行 | 变更 ${TOTAL_LINES} 行，超出建议范围 | 继续 / 指定文件 / 取消 |
| API 超时 | 请求超时 (${RETRY}/3) | 重试 / 稍后手动 / 取消 |
| ce-code-review 失败 | 深度审查工具异常 | 降级 checklist / 重试 / 取消 |
| 敏感信息泄露 | ⚠️ 检测到疑似敏感信息 | 继续(标注风险) / 停止 / 通知作者 |
| 提交失败 | Review 提交失败: ${ERROR} | 保存本地 / 重试 / 取消 |

---

## 参考文档

- `reference/github-review-api.md` — GitHub Review API 格式要求和常见错误
- `reference/re-review-strategy.md` — 复核策略决策树
- `scripts/collect-pr-info.sh` — PR 信息收集
- `scripts/diff-since.sh` — 变更范围检测
- `scripts/submit-review.sh` — Review 提交（COMMENT 事件）
