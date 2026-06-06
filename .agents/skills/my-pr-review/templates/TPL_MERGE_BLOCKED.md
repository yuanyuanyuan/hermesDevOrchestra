# PR Review (merge-blocked): ${AUTO:pr_url}
- Reviewer: ${AUTO:reviewer}
- Timestamp: ${AUTO:iso8601}
- Review Mode: merge-blocked
- Reason: ${MANUAL:block_reason}  <!-- e.g. "HEAD 未推进 / 无法定位 Reviewed-commit" -->

## 阻塞项（沿用上轮 review 结论）
| # | 上轮 finding | 严重度 | 当前状态 | 证据 |
|---|--------------|--------|----------|------|
${TABLE_DATA:blocked_items}

## 解除阻塞所需
${MANUAL:unblock_actions}  <!-- 列表: 1) 作者 push 修复 commit 2) 重新跑 rebase ... -->

@${AUTO:pr_author} 请处理上述阻塞项后，重新 request review。

---

## Review metadata
- Reviewed-commit: ${AUTO:head_sha}
- Reviewer: ${AUTO:reviewer}
- Timestamp: ${AUTO:iso8601}
- Mode: merge-blocked
- Last-reviewed-commit: ${AUTO:last_reviewed_oid}
