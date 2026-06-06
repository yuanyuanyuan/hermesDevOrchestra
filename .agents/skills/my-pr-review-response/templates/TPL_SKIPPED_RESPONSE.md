## Skipped: ${AUTO:finding_title} (${AUTO:finding_id})

**原始 finding**
> ${AUTO:reviewer} 在 ${AUTO:file_path}:${AUTO:line_num} 提出：
>
> ${AUTO:original_quote}

**严重度**: ${AUTO:severity}

### 跳过理由
${MANUAL:skip_reason}  <!-- e.g. "此 finding 已被本 PR 后续 commit 取代" -->

**取代 commit**: `${AUTO:replacement_commit_sha}`（如适用）
