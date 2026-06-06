# PR Review: ${AUTO:pr_url}
- Reviewer: ${AUTO:reviewer}
- Timestamp: ${AUTO:iso8601}
- Commit Reviewed: ${AUTO:head_sha}
- Self-Review: ${AUTO:is_self_review}
- Review Engine: ce-code-review (compound-engineering)
- Review Mode: first

## 摘要
- Verdict: ${MANUAL:verdict}    <!-- Ready to merge / Ready with fixes / Not ready -->
- Findings: P0: ${AUTO:p0_count} | P1: ${AUTO:p1_count} | P2: ${AUTO:p2_count} | P3: ${AUTO:p3_count}
- 建议决策: ${MANUAL:decision}  <!-- review approved / REQUEST_CHANGES -->

## Findings

### P0 — Critical
${TABLE_DATA:p0_findings}
<!-- 列: # | File | Issue | Reviewer | Confidence -->

### P1 — High
${TABLE_DATA:p1_findings}

### P2 — Moderate
${TABLE_DATA:p2_findings}

### P3 — Low
${TABLE_DATA:p3_findings}

## Coverage
- Suppressed: ${AUTO:suppressed_count} findings below confidence threshold
- Failed reviewers: ${AUTO:failed_reviewers}

## 合并门控
- ${MANUAL:merge_gate_notes}  <!-- ✅/🚫 合并条件逐项评估 -->

---

## Review metadata
- Reviewed-commit: ${AUTO:head_sha}
- Reviewer: ${AUTO:reviewer}
- Timestamp: ${AUTO:iso8601}
- Mode: first
- Last-reviewed-commit: (none)
