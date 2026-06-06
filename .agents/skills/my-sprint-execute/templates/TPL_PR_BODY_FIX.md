## Fix: ${AUTO:pr_title}

### 关联 Sprint
Sprint ${AUTO:sprint}

### 缺陷描述
${MANUAL:bug_description}  <!-- 触发条件 / 复现步骤 / 影响范围 -->

### 根因
${MANUAL:root_cause}

### 修复方案
${MANUAL:fix_approach}

### Regression Test
- 新增测试: `${AUTO:regression_test_file}` 测试 ${MANUAL:regression_test_name}
- 触发条件: ${MANUAL:trigger_condition}
- 验证结果: 修复前 FAIL → 修复后 PASS

### Verification Report
${VERIFICATION_REPORT_INLINE}

### 验收状态
- [x] Regression test 失败 → 修复 → 通过
- [x] 全部现有测试不退化
- [x] 无新增 lint warning
