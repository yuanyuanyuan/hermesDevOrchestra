# Sprint ${AUTO:sprint} Verification Report

**生成时间**: ${AUTO:iso8601}
**执行者**: ${AUTO:executor}  <!-- stark-007 -->
**总耗时**: ${AUTO:total_duration}

## 1. 测试套件
### 单元测试
\`\`\`bash
$ bash scripts/tests/test-unit.sh
${AUTO:unit_test_output}
\`\`\`
**结果**: ${AUTO:unit_test_status}  <!-- ✅ PASS (N/N) -->

### 集成测试
\`\`\`bash
$ bash scripts/tests/test-integration.sh
${AUTO:integration_test_output}
\`\`\`
**结果**: ${AUTO:integration_test_status}

### E2E / 端到端（如适用）
\`\`\`bash
$ bash scripts/tests/test-e2e.sh
${AUTO:e2e_test_output}
\`\`\`
**结果**: ${AUTO:e2e_test_status}

## 2. Schema / Lint / Type
### Schema 验证
\`\`\`bash
$ python -m jsonschema -i config/knowledge/runtime-kb.json config/schemas/orchestra.full.schema.json
${AUTO:schema_output}
\`\`\`
**结果**: ${AUTO:schema_status}

### Lint
\`\`\`bash
$ ruff check .  # 或项目实际 lint 命令
${AUTO:lint_output}
\`\`\`
**结果**: ${AUTO:lint_status}

## 3. 性能基准（如适用）
\`\`\`
${AUTO:benchmark_output}
\`\`\`

## 4. 边界用例
${MANUAL:edge_case_results}  <!-- 表格: 用例 | 期望 | 实际 -->

## 5. 已知遗留
${MANUAL:known_issues}  <!-- 列表; 留空写 "无" -->

## 6. 总结
- 全部验证: ${AUTO:overall_status}  <!-- ✅ ALL PASS / ⚠️ PARTIAL / ❌ FAIL -->
- 可发起 PR: ${AUTO:ready_for_pr}  <!-- Yes / No (需要回退) -->
