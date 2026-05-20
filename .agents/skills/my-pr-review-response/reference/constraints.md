# 约束与边界

## 硬性约束

- 不修改 PR 范围外的文件
- 不引入新依赖（除非 review 明确要求且已论证）
- 不重构未 review 的代码（最小改动原则）
- 不自动合并 PR
- 反驳必须有证据，禁止主观感受式反驳
- 必须以 PR Comment 方式回复每条修复或反驳结果

## 写权限边界

- PR diff 中涉及的所有文件
- `/tmp/pr-review-response-*.md`

## 只读边界

- `scripts/lib/orch_gateway.py`（除非 review 意见明确要求修改）
- `config/schemas/orchestra.full.schema.json`（除非 review 意见明确要求修改）
- 其他 Sprint 的配置和测试脚本
