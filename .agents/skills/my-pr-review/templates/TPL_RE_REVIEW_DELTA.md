# PR Review (delta): ${AUTO:pr_url}
- Reviewer: ${AUTO:reviewer}
- Timestamp: ${AUTO:iso8601}
- Commit Reviewed: ${AUTO:head_sha}
- Self-Review: ${AUTO:is_self_review}
- Review Engine: manual diff-driven (delta mode)
- Review Mode: ${AUTO:review_mode}  <!-- delta | re-review-full -->
- Delta Range: ${AUTO:last_reviewed_oid}..${AUTO:head_sha}
- Changed Files: ${AUTO:delta_file_count} (scope: ${AUTO:diff_scope})

## Prior review trace
<!-- 每行 = 上轮 review 的一个 finding -->
| # | 上轮 ID | 严重度 | 文件:行号 | 原 issue | 状态 | 证据 |
|---|---------|--------|-----------|----------|------|------|
${TABLE_DATA:prior_review_trace}
<!-- 状态枚举: FIXED | NOT-FIXED | REGRESSED | N/A -->
<!-- 证据列: 引用 commit SHA / diff 行号 / 测试输出 -->

## New findings（自上轮 review 之后才出现的问题）
### P0
${TABLE_DATA:new_p0}
### P1
${TABLE_DATA:new_p1}
### P2
${TABLE_DATA:new_p2}

## 摘要
- Verdict: ${MANUAL:verdict}    <!-- Ready to merge / Ready with fixes / Not ready -->
- 上轮 P0/P1 状态: ${AUTO:prior_p0_fixed}/${AUTO:prior_p0_total} P0 fixed; ${AUTO:prior_p1_fixed}/${AUTO:prior_p1_total} P1 fixed
- 新增 P0/P1: ${AUTO:new_p0_count} P0, ${AUTO:new_p1_count} P1

## 合并门控
- ${MANUAL:merge_gate_notes}

---

## Review metadata
- Reviewed-commit: ${AUTO:head_sha}
- Reviewer: ${AUTO:reviewer}
- Timestamp: ${AUTO:iso8601}
- Mode: ${AUTO:review_mode}
- Last-reviewed-commit: ${AUTO:last_reviewed_oid}
