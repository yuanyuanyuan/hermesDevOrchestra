## Verified: ${AUTO:finding_title} (${AUTO:finding_id})

**原始 finding**
> ${AUTO:reviewer} 在 ${AUTO:file_path}:${AUTO:line_num} 提出：
>
> ${AUTO:original_quote}

**严重度**: ${AUTO:severity}

### 复核结论
${MANUAL:verify_conclusion}  <!-- e.g. "上一轮已在 commit xyz 中修复，确认无需再次处理" -->

**已存在的修复 commit**: `${AUTO:fix_commit_sha}`
**本次复核 commit**: `${AUTO:current_head_sha}`（无新变更）
