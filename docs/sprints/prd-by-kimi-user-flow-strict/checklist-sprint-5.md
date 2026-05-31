# Sprint 5 验收清单

## 验收条件（可独立验证子项）

### AC-1: 辩论工单 7 字段完整性
- **可执行断言**: `python scripts/lib/debate_ticket_generator.py --validate test-ticket.json` 返回 exit 0 且输出包含 7 个字段 `project_background`、`goal`、`non_goal`、`constraints`、`acceptance_criteria`、`risk_boundary`、`failure_strategy`；缺失任一字段返回 exit 1
- **测试脚本**: `scripts/tests/test-debate-ticket-schema.sh`
- **负向用例**: 工单缺失 `failure_strategy` 仍返回 exit 0，则阻塞
- **状态**: ⬜

### AC-2: 硬约束不可覆盖
- **可执行断言**: 辩论结论试图覆盖标记为 `hard` 的约束时，`debate_assembly.py` 返回 `verdict: blocked` 与 `reason: "hard_constraint_violation"`
- **测试脚本**: `scripts/tests/test-debate-assembly.sh`
- **负向用例**: 系统允许覆盖硬约束且未记录 `override_reason`，则阻塞
- **状态**: ⬜

### AC-3: 团队选择策略覆盖 16+canonical+扩展+别名
- **可执行断言**: `team_selector.select(task_type="refactor", project_profile={...})` 返回的 `TeamList` 包含 canonical 团队 ID、扩展团队 ID，且旧别名被正确解析为 canonical 团队
- **测试脚本**: `scripts/tests/test-team-selector.sh`
- **负向用例**: 旧别名未被解析或扩展团队被错误归类为 canonical，则阻塞
- **状态**: ⬜

### AC-4: alias-mapping.json 存在且有效
- **可执行断言**: `cat config/debate/full/alias-mapping.json | jq '.mappings | length'` ≥ 3；`python scripts/tests/test-debate-alias-mapping.sh` 通过 JSON Schema 校验
- **测试脚本**: `scripts/tests/test-debate-alias-mapping.sh`
- **负向用例**: `alias-mapping.json` 不存在或映射条目 < 3，则阻塞
- **状态**: ⬜

### AC-5: 自定义团队 prompt_injection 安全扫描
- **可执行断言**: 自定义团队配置 `prompt_injection: "eval(request.body)"`，`security_scanner.scan()` 返回 `status: blocked` 与 `blocked_keywords: ["eval("]`；`team_selector` 将该团队标记 `security_blocked: true`
- **测试脚本**: `scripts/tests/test-debate-custom-team-guards.sh`
- **负向用例**: 包含 `eval(` 的 prompt_injection 未被检测为 blocked，则阻塞
- **状态**: ⬜

### AC-6: max_teams 动态上限可配置
- **可执行断言**: `project-profile.yaml` 设置 `max_teams: 32`，`team_selector.select()` 成功返回 32 个团队；设置 `max_teams: 100`，返回 `config_error: max_teams exceeds hard limit 64`
- **测试脚本**: `scripts/tests/test-gateway-config-registries.sh`
- **负向用例**: `max_teams: 100` 被静默截断为 16 或 64 且无错误提示，则阻塞
- **状态**: ⬜

### AC-7: 安全红线扫描日志
- **可执行断言**: `logs/security-scan.jsonl` 存在条目包含 `team_id`、`prompt_hash`、`scan_result`、`blocked_keywords`、`timestamp`（ISO 8601）
- **测试脚本**: `scripts/tests/test-security-scanner.sh`
- **负向用例**: 安全扫描未产生日志或日志缺少 `blocked_keywords`，则阻塞
- **状态**: ⬜

### AC-8: 方向结论自动晋级二阶条件
- **可执行断言**: 辩论输出 `confidence=0.85`、`risk_level="low"`、`conflicts=[]` 时，`direction_gate.verdict()` 返回 `next_phase: "phase_2"`；任一条件不满足则返回 `next_phase: "phase_1_review"`
- **测试脚本**: `scripts/tests/test-debate-assembly.sh`
- **负向用例**: `confidence=0.6` 仍自动进入二阶，则阻塞
- **状态**: ⬜

## 架构红线合规
- [ ] Gateway 新增逻辑 100% 落在 helper modules（seam extraction 检查）
- [ ] `orch_gateway.py` 行数净增长 ≤ 50 行（基线 6109 行）
- [ ] 安全扫描器作为独立 helper module（可被 S4b 复用）
- [ ] alias-mapping.json 通过 JSON Schema 校验且版本受控

## 文档交付物
- [ ] `docs/adr/0001-full-debate-package-team-registry.md` 更新：安全红线清单 + 别名映射 schema
- [ ] `docs/adr/0009-dynamic-debate-assembly-policy.md` 更新：maxItems 动态配置决策
- [ ] `docs/CONFIGURATION.md` 更新：`max_teams` 配置 + 安全红线关键词列表
- [ ] `docs/user-flow-guide_by_kimi.md` 更新：1 阶方向辩论流程

## 任务完成状态
- [ ] U5a — 辩论工单契约与团队策略引擎
- [ ] U5b — 安全红线、别名映射与 Schema 扩展

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
