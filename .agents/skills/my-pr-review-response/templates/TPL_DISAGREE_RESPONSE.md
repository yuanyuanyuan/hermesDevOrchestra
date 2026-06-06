## Counter: ${AUTO:finding_title} (${AUTO:finding_id})

**原始 finding**
> ${AUTO:reviewer} 在 ${AUTO:file_path}:${AUTO:line_num} 提出：
>
> ${AUTO:original_quote}

**严重度**: ${AUTO:severity}

### 决策：DISAGREE

### 反驳理由（反驳门槛 3 项必须全部填写）

**1. 代码/文档证据**
${MANUAL:evidence_code}  <!-- 引用代码片段 / 测试输出 / ADR -->

**2. 架构理由**
${MANUAL:evidence_arch}  <!-- 说明 review 建议为何违反现有约束 -->

**3. 替代方案（如适用）**
${MANUAL:alternative}  <!-- 不填则写 "N/A — 沿用现有设计" -->

### 请求
建议 @${AUTO:reviewer} 重新考虑此点，或针对上述证据进一步讨论。
