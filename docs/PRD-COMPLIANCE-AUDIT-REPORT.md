# PRD 合规审计报告 — Hermes Dev Orchestra

**审计日期**: 2026-06-04
**审计依据**: `docs/prd_by_kimi.md` (v1.3) + `docs/user-flow-guide_by_kimi.md`
**审计范围**: 全部代码实现（scripts/lib/、config/schemas/、config/debate/、scripts/bin/、scripts/tests/）
**审计方法**: 37 项结构化 checklist，逐条对照源代码验证

---

## 📊 总体评估

| 指标 | 值 |
|------|-----|
| **总体得分** | **5.3 / 10** |
| 审计项数 | 36 / 37（1项子代理输出异常） |
| ✅ 完全实现 | 8 项 (22%) |
| ⚠️ 部分实现 | 22 项 (61%) |
| ❌ 未实现 | 6 项 (17%) |

**结论**: 项目在辩论系统配置、信息溯源、成功指标管道等维度实现较好，但在状态机完整性、冲突管理、通道分级集成、回滚策略等核心编排逻辑上存在显著缺口。

---

## 📈 维度得分概览

```
维度              得分        状态分布
──────────────────────────────────────────────
工具开发         ██████████ 10.0  (1✅ 0⚠️ 0❌)
成功指标         █████████░  8.5  (1✅ 1⚠️ 0❌)
辩论系统         ███████░░░  7.3  (3✅ 0⚠️ 1❌)
需求补全         ███████░░░  6.7  (1✅ 2⚠️ 0❌)
持续改进         ███████░░░  6.7  (1✅ 2⚠️ 0❌)
Worker 执行     ███████░░░  6.5  (0✅ 2⚠️ 0❌)
状态机           ██████░░░░  6.0  (0✅ 2⚠️ 0❌)
改进闭环         ██████░░░░  5.7  (1✅ 2⚠️ 0❌)
执行心跳         █████░░░░░  5.0  (0✅ 1⚠️ 0❌)
全局评估         █████░░░░░  4.7  (0✅ 2⚠️ 1❌)
DAG 管理         ████░░░░░░  4.0  (0✅ 2⚠️ 0❌)
Schema           ████░░░░░░  4.0  (0✅ 1⚠️ 0❌)
用户纠正         ███░░░░░░░  3.0  (0✅ 2⚠️ 0❌)
通道分级         ███░░░░░░░  2.6  (0✅ 3⚠️ 2❌)
冲突管理         █░░░░░░░░░  1.0  (0✅ 0⚠️ 1❌)
回滚策略         █░░░░░░░░░  1.0  (0✅ 0⚠️ 1❌)
```

---

## 🔴 高危缺口（得分 < 5，需优先修复）

### 1. 冲突管理 (1.0/10) — CON-02

**PRD 要求**: Conflict Ledger 数据结构 + Gateway 推进前查询 open 冲突 + high severity 阻塞推进

**现状**: 完全未实现。

**关键证据**:
- `orch_gateway.py:4875-4894` — `advance_run_stage_projection()` 直接推进，无冲突查询
- `orch_gateway.py:4436-4437` — `build_parallel_worker_artifacts()` 返回 None
- `orchestra.full.schema.json:497-510` — severity 枚举为 `blocking/warning/info`，与 PRD 的 `high/medium/low` 不一致
- 全文无 `conflict_ledger`、`conflict_id`、`resolution=open` 等字段

**风险**: 阶段推进可在高严重性冲突存在时不受阻拦地执行，六阶审计无法读取冲突记录。

**建议**: 新增 Conflict Ledger 数据结构（PRD §3.5 完整字段），在 `advance_run_stage_projection()` 前增加冲突门控。

---

### 2. 回滚策略 (1.0/10) — RB-01

**PRD 要求**: 按阶段实现不同回滚范围（丢弃补全包、丢弃辩论报告、git revert、回滚到基线）

**现状**: 完全未实现。仅有 `rollback_checkpoints` 字段引用，无实际回滚执行逻辑。

**建议**: 至少实现 implementation 和 improvement 阶段的 git revert 回滚能力。

---

### 3. 通道分级 (2.6/10) — 5 项审计

**最大缺口**:

| ID | 问题 | 得分 |
|----|------|------|
| CH-01 | channel_router 分类结果未传递给 run 创建和阶段推进逻辑，快速/轻量通道实际走全量六阶段 | 4 |
| CH-02 | 快速通道缺少 PRD §7.2 要求的极简辩论确认（1-2 支团队，1 轮，30 秒） | 2 |
| CH-03 | 安全逃逸规则完全缺失（敏感词强制升级标准通道） | 1 |
| CH-04 | 自动合并功能部分实现 | 5 |
| CH-05 | Rollout Gate 部分实现 | 5 |

**关键发现**:
- `slo-policy.json` 中 `quick.debate_rounds` 配置为 0，与 PRD 要求的 1 轮辩论直接矛盾
- `channel_router.py` 的 `classify()` 方法完全缺少 diff 内容感知能力
- `evidence_scanner.py` 的敏感词列表仅 3 个（password=, secret=, api_key），PRD 要求 6+ 个

---

### 4. 同源隔离检测 (1.0/10) — DEB-04

**PRD 要求**: review/audit/cross_check worker 的 model_source 不得与上层裁决者同源

**现状**: 完全未实现。现有的 `check_source_isolation()` 检测的是任务指纹碰撞，与 model provider 隔离是完全不同的机制。

**关键证据**:
- `worker_session.py` 的 `create_session()` 无 `model_source` 参数
- `orchestra.full.schema.json` 的 `worker_session_record` 无 `model_source` 字段
- 全文搜索 `source_isolation_violation` — 无此错误码

---

### 5. 用户纠正 (3.0/10) — 2 项审计

| ID | 问题 | 得分 |
|----|------|------|
| COR-01 | `correction_gate.py` 实现了两轮纠正框架，但缺少渐进式 UX（折叠/展开）、30秒超时、L3/L4 审批触发 | 3 |
| COR-02 | Override 记录格式部分实现，缺少 `correction_rounds` 详情和 `approver_ref` | 3 |

---

### 6. 全局评估 (4.7/10) — 3 项审计

| ID | 问题 | 得分 |
|----|------|------|
| EVAL-01 | 8 维评估框架存在，但维度名称与 PRD 不一致，缺少"一票否决"逻辑 | 5 |
| EVAL-02 | 残余风险阈值逻辑完全缺失 | 1 |
| EVAL-03 | 通知级别配置部分实现 | 8 |

---

## 🟡 中等缺口（得分 5-7，需改进）

### 7. 状态机 (6.0/10)

**已实现**: 六阶段枚举完整 (`direction_debate` → `continuous_improvement`)

**缺失**:
- 缺少 `created`、`intake_complete`、`closed` 生命周期状态
- 缺少 `paused`、`cancelled`、`rollback_requested` 异常状态
- `advance_run_stage_projection()` 仅做线性推进，未校验 PRD §3.6 条件表
- `stop_run()` 使用 `stopped` 而非 `cancelled`，无 resume 能力

### 8. 需求补全 (6.7/10)

**已实现**: `project_discovery.py` 技术栈探测、`gateway_projection.py` 补全包构建、信息溯源字段

**缺失**:
- CI/CD 配置检测完全缺失
- `prompt_envelope` 仅含 4 项（PRD 要求 8 项）
- 缺少独立的"已验证事实"和"未验证假设"分节

### 9. Worker 执行 (6.5/10)

**已实现**: Worker 生命周期管理、心跳处理、僵尸检测

**缺失**:
- write_scope 两阶段校验未实现
- DAG 循环依赖检测返回 None

### 10. 改进闭环 (5.7/10)

**已实现**: A-E 分类框架、D 类回归循环计数

**缺失**:
- E 类 mini-debate 未集成真实辩论引擎
- 回归预算（3 次上限）的边界测试不足

### 11. 执行心跳 (5.0/10)

**已实现**: SSE 推送、30 秒间隔心跳

**缺失**:
- 断线重连恢复（5 秒内获取最近 3 条历史心跳）未实现
- 快照查询接口未实现

---

## 🟢 良好实现（得分 ≥ 7）

### 12. 辩论系统 (7.3/10)

| ID | 项目 | 得分 |
|----|------|------|
| DEB-01 | 16 支 canonical 团队注册 | **10** ✅ |
| DEB-02 | 8 种 canonical 模式 | **9** ✅ |
| DEB-03 | dynamic_assembly + adversarial_debate | **9** ✅ |

`config/debate/full/teams.json` 和 `config/debate/full/modes.json` 与 PRD §6.1/§6.3 完全对齐。

### 13. 成功指标 (8.5/10)

- `success_metrics.py` 实现了完整的 NDJSON 事件管道
- `orch-audit` 和 `orch-verify` 脚本存在且功能正确

### 14. 信息溯源 (9.0/10) — INT-03

- `gateway_projection.py` 为所有顶层区块注入 `source_input_hash` 和 `projection_timestamp`
- 关键结论附带 `source/confidence/verification_method` 三元组

---

## 📋 完整审计结果明细

| ID | 维度 | 需求 | 状态 | 得分 |
|----|------|------|------|------|
| SM-01 | 状态机 | 六阶段状态机 + 生命周期状态 | ⚠️ 部分实现 | 5 |
| SM-02 | 状态机 | 证据完整性校验 | ⚠️ 部分实现 | 7 |
| INT-01 | 需求补全 | 新项目接入探测 | ⚠️ 部分实现 | 6 |
| INT-02 | 需求补全 | 0阶输出完整性 | ⚠️ 部分实现 | 5 |
| INT-03 | 需求补全 | 信息溯源字段 | ✅ 完全实现 | 9 |
| DEB-01 | 辩论系统 | 16 支 canonical 团队 | ✅ 完全实现 | 10 |
| DEB-02 | 辩论系统 | 8 种 canonical 模式 | ✅ 完全实现 | 9 |
| DEB-03 | 辩论系统 | dynamic_assembly + adversarial_debate | ✅ 完全实现 | 9 |
| DEB-04 | 辩论系统 | 同源隔离检测 | ❌ 未实现 | 1 |
| CON-02 | 冲突管理 | Conflict Ledger + 推进门控 | ❌ 未实现 | 1 |
| CH-01 | 通道分级 | 三层通道 + 阶段跳过 | ⚠️ 部分实现 | 4 |
| CH-02 | 通道分级 | 快速通道辩论确认 | ❌ 未实现 | 2 |
| CH-03 | 通道分级 | 安全逃逸规则 | ❌ 未实现 | 1 |
| CH-04 | 通道分级 | 自动合并 + 降级 | ⚠️ 部分实现 | 5 |
| CH-05 | 通道分级 | Rollout Gate | ⚠️ 部分实现 | 5 |
| WRK-01 | Worker | 生命周期管理 | ⚠️ 部分实现 | 6 |
| WRK-02 | Worker | 写入范围校验 | ⚠️ 部分实现 | 7 |
| HB-01 | 执行心跳 | SSE + 断线恢复 | ⚠️ 部分实现 | 5 |
| IMP-01 | 改进闭环 | A-E 分类 | ⚠️ 部分实现 | 6 |
| IMP-02 | 改进闭环 | D 类回归循环 | ✅ 完全实现 | 7 |
| IMP-03 | 改进闭环 | E 类 mini-debate | ⚠️ 部分实现 | 4 |
| EVAL-01 | 全局评估 | 8 维评估 | ⚠️ 部分实现 | 5 |
| EVAL-02 | 全局评估 | 残余风险阈值 | ❌ 未实现 | 1 |
| EVAL-03 | 全局评估 | 通知级别配置 | ✅ 完全实现 | 8 |
| CI-01 | 持续改进 | 审计输入完整性校验 | ⚠️ 部分实现 | 6 |
| CI-02 | 持续改进 | Self-evolution Queue | ✅ 完全实现 | 7 |
| CI-03 | 持续改进 | Protected Target 审批 | ⚠️ 部分实现 | 7 |
| COR-01 | 用户纠正 | 两轮渐进式纠正 | ⚠️ 部分实现 | 3 |
| COR-02 | 用户纠正 | Override 记录格式 | ⚠️ 部分实现 | 3 |
| MET-01 | 成功指标 | 事件采集管道 | ⚠️ 部分实现 | 7 |
| MET-02 | 成功指标 | orch-audit / orch-verify | ✅ 完全实现 | 10 |
| SCH-01 | Schema | schema.json 完整性 | ⚠️ 部分实现 | 4 |
| DAG-01 | DAG 管理 | DAG 数据格式 | ⚠️ 部分实现 | 5 |
| DAG-02 | DAG 管理 | 循环依赖检测 | ⚠️ 部分实现 | 3 |
| RB-01 | 回滚策略 | 多级回滚策略 | ❌ 未实现 | 1 |

---

## 🎯 优先修复建议

### P0 — 阻塞级（影响系统核心正确性）

1. **Conflict Ledger 实现** — 新增数据结构 + 推进门控 + severity 统一
2. **回滚策略实现** — 至少覆盖 implementation/improvement 阶段的 git revert
3. **通道分级集成** — 将 channel_router 分类结果传递给 run 创建和阶段推进
4. **安全逃逸规则** — 在 channel_router 中增加敏感词检测和强制升级

### P1 — 高优（影响功能完整性）

5. **状态机补全** — 增加 created/intake_complete/paused/cancelled/rollback_requested 状态
6. **同源隔离检测** — 实现 model_source 校验和 source_isolation_violation
7. **快速通道辩论确认** — 连接 channel_router 与 debate_engine
8. **全局评估残余风险阈值** — 实现高/中/低风险量化判定

### P2 — 中优（影响质量保障）

9. **证据校验统一** — worker_response 路径补齐 review_evidence/commit_evidence 校验
10. **CI/CD 配置检测** — 在 project_discovery.py 中新增 detect_ci_config()
11. **prompt_envelope 扩展** — 补齐 PRD §5.4 要求的 8 项子内容
12. **E 类 mini-debate 集成** — 连接真实辩论引擎

---

## 📎 附录

### 审计脚本

审计 workflow 脚本位于: `.claude/workflows/prd-compliance-audit.js`

### 数据来源

- PRD: `docs/prd_by_kimi.md` (v1.3, 2026-06-03)
- 用户流程: `docs/user-flow-guide_by_kimi.md`
- 代码: `scripts/lib/orch_gateway.py` (303KB 核心)、`config/schemas/orchestra.full.schema.json` (95KB)
- 配置: `config/debate/full/teams.json`、`config/debate/full/modes.json`、`config/performance/slo-policy.json`
