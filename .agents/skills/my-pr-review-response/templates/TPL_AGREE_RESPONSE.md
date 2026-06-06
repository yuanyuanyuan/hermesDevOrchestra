## Fix: ${AUTO:finding_title} (${AUTO:finding_id})

**原始 finding**
> ${AUTO:reviewer} 在 ${AUTO:file_path}:${AUTO:line_num} 提出：
>
> ${AUTO:original_quote}

**严重度**: ${AUTO:severity}  <!-- P0 | P1 | P2 | P3 -->

### 修复内容
${MANUAL:fix_description}

**修改文件:**
- ${AUTO:file_path}:${AUTO:line_range}（${MANUAL:change_summary}）

**修复 commit**: `${AUTO:fix_commit_sha}`

### 验证证据
\`\`\`
${MANUAL:verification_output}
\`\`\`

### 验证命令
\`\`\`bash
${MANUAL:verification_command}
\`\`\`
