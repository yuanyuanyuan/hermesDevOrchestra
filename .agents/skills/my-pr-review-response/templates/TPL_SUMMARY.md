## Review Response Summary — PR #${AUTO:pr_number}

**全量统计**
- 收到 finding 总数: ${AUTO:total_count}
- AGREE / FIXED: ${AUTO:agree_count}
- DISAGREE / COUNTERED: ${AUTO:disagree_count}
- VERIFIED: ${AUTO:verified_count}
- SKIPPED: ${AUTO:skipped_count}
- PENDING: ${AUTO:pending_count}  <!-- 必须为 0 才能提交 -->

### P0 — Critical（${AUTO:p0_count} 项）
| # | 文件:行号 | 标题 | 决策 | 状态 | 证据 |
|---|-----------|------|------|------|------|
${TABLE_DATA:p0_rows}

### P1 — High（${AUTO:p1_count} 项）
${TABLE_DATA:p1_rows}

### P2 — Moderate（${AUTO:p2_count} 项）
${TABLE_DATA:p2_rows}

### P3 — Low（${AUTO:p3_count} 项）
${TABLE_DATA:p3_rows}

### 修复 Commit Range
${AUTO:commit_range}  <!-- e.g. `abc1234..def5678` -->

@${AUTO:reviewer_login} 请重新 review。
