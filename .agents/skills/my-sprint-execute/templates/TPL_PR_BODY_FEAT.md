## Sprint ${AUTO:sprint}: ${AUTO:pr_title}

### 需求来源
- Plan: `${AUTO:plan_path}` Sprint ${AUTO:sprint}
- Spec: ${AUTO:spec_ref}
- ADR: ${AUTO:adr_ref}

### 改动摘要（Conventional Commits）
${COMMITS_TABLE}
<!-- 列: SHA | Type | Subject | Files -->

### 实现摘要
${MANUAL:implementation_summary}  <!-- 3-5 句话说清核心逻辑 / 设计决策 -->

### 新增/修改文件（按模块分组）
${MANUAL:file_changes}  <!-- 列表 -->

### 测试覆盖
- 新增单元测试: ${AUTO:new_unit_test_count} 个
- 新增集成测试: ${AUTO:new_integration_test_count} 个
- 回归测试: ${AUTO:regression_test_count} 个

### Verification Report
${VERIFICATION_REPORT_INLINE}

### 验收状态
- [x] checklist Sprint ${AUTO:sprint} 所有项已勾选
- [x] 全部验证 exit 0
- [x] 无新增 lint warning
- [x] 无未解决合并冲突

### Reviewer 重点关注
${MANUAL:reviewer_focus}  <!-- 列表: 关键设计决策 / 风险点 -->
