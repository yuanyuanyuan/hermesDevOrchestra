# PRD 合规 DRIFT 审计 — Hermes Dev Orchestra

**审计日期**: 2026-06-15
**基线报告**: `docs/PRD-COMPLIANCE-AUDIT-REPORT.md` (2026-06-05)
**跨度**: 10 天 / 9 个 sprint (sprint-2 ~ sprint-13)
**审计方法**: 以基线 35 项 checklist 为标准，按 8 个维度并行重审当前 HEAD，比较分数变化

---

## 🎯 一句话结论

**净分 +2.21**（5.51 → 7.73）；25 项改善 / 0 项回退 / 8 项未变；0 项未实现；仅 IMP-03 仍处高危区。

所有 sprint 声称触达的 18 项中有 **16 项实际改善**（89%），但多数改善项存在 **"库就绪、未集成"** 的二阶缺口 —— sprint 模型在创建 library + tests 层面高效，但在 wire-up 到 orch_gateway 主调用链层面系统性遗漏。

---

## 📊 总体分数变化

| 指标 | 基线 (2026-06-05) | 当前 (2026-06-15) | Δ |
|------|-------------------|-------------------|---|
| **总均分** | 5.51 / 10 | **7.73 / 10** | **+2.21** |
| ✅ 完全实现 | 9 / 35 (26%) | 19 / 33 (58%) | +32pp |
| ⚠️ 部分实现 | 22 / 35 (63%) | 14 / 33 (42%) | -21pp |
| ❌ 未实现 | 4 / 35 (11%) | 0 / 33 (0%) | -11pp |

> 当前审计覆盖 33 项（基线 35 项中 RB-01 与 IMP-02 在重审时被合入相邻检查，agent 自主重平衡）。逐项核对基线仍为 35 项有效。

---

## 🏆 改进项 Top-10（按分数提升幅度）

| ID | 维度 | 基线 → 当前 | Δ | 关键证据 |
|----|------|-------------|---|----------|
| **CH-03** | 通道分级 | 1 → 7 | +6 | `scripts/lib/security_escape.py:14-27` 6 类敏感词；`:69-101` 强制升级；`:104-140` 三重校验；14 测试 |
| **DAG-02** | Worker+DAG | 3 → 9 | +6 | `dag_validator.py:166-184` DFS 双集检测；`worker_evidence_harden.py:240-264` 阻断 advancement |
| **EVAL-02** | 全局评估 | 1 → 7 | +6 | `global_evaluation_veto.py:23-27` 残余风险 high/medium/low；`:84-105` 双审批链路 |
| **COR-02** | 用户纠正 | 3 → 8 | +5 | `correction_override.py:101-142` 9 字段完整；11 个测试覆盖 |
| **INT-02** | 需求补全 | 5 → 9 | +4 | `intake_completeness.py:21-30` 8 项 envelope；`:171-193` CI 检测；`:206-216` 事实/假设分离；14 测试 |
| **DEB-04** | 辩论系统 | 1 → 5 | +4 | `worker_source_isolation.py:50-60` 错误码；`:111-137` 同源比对；264 行测试 |
| **CH-02** | 通道分级 | 2 → 6 | +4 | `mini_debate_orchestration.py:19-37` quick/light 极简辩论映射 |
| **DAG-01** | Worker+DAG | 5 → 9 | +4 | `dag_validator.py:29-73` 双格式兼容；`:199-210` Kahn 拓扑 |
| **WRK-01** | Worker | 6 → 9 | +3 | `worker_session.py:30-46` 双状态机；`:125-192` UUIDv4 dispatch_token |
| **CI-01** | 持续改进 | 6 → 9 | +3 | 六阶审计输入完整性校验 |

完整 25 项改进明细见附 JSON 文件 `prd-compliance-drift-audit-2026-06-15.json`。

### 改进项明细（基线 → 当前）

| ID | 维度 | 基线 → 当前 | 状态 |
|----|------|-------------|------|
| CH-03 | 通道分级 | 1 → 7 | partially_implemented |
| DAG-02 | Worker+DAG | 3 → 9 | fully_implemented |
| EVAL-02 | 全局评估 | 1 → 7 | partially_implemented |
| COR-02 | 用户纠正 | 3 → 8 | fully_implemented |
| INT-02 | 需求补全 | 5 → 9 | fully_implemented |
| DEB-04 | 辩论系统 | 1 → 5 | partially_implemented |
| CH-02 | 通道分级 | 2 → 6 | partially_implemented |
| DAG-01 | Worker+DAG | 5 → 9 | fully_implemented |
| WRK-01 | Worker | 6 → 9 | fully_implemented |
| CI-01 | 持续改进 | 6 → 9 | fully_implemented |
| COR-01 | 用户纠正 | 3 → 6 | partially_implemented |
| SCH-01 | Schema | 4 → 7 | partially_implemented |
| SM-02 | 状态机 | 7 → 9 | fully_implemented |
| CH-01 | 通道分级 | 4 → 6 | partially_implemented |
| CH-04 | 通道分级 | 5 → 7 | partially_implemented |
| WRK-02 | Worker | 7 → 9 | fully_implemented |
| IMP-01 | 改进闭环 | 6 → 8 | fully_implemented |
| IMP-02 | 改进闭环 | 7 → 9 | fully_implemented |
| CI-02 | 持续改进 | 7 → 9 | fully_implemented |
| MET-01 | 成功指标 | 7 → 9 | fully_implemented |
| SM-01 | 状态机 | 5 → 6 | partially_implemented |
| CH-05 | 通道分级 | 5 → 6 | partially_implemented |
| CI-03 | 持续改进 | 7 → 8 | fully_implemented |
| EVAL-01 | 全局评估 | 5 → 6 | partially_implemented |
| EVAL-03 | 全局评估 | 8 → 9 | fully_implemented |

---

## 🚨 仍未消化的关键缺口 (current < 5)

仅 1 项：

### IMP-03 — E 类 mini-debate 真实引擎集成 (4/10)

**PRD 要求**: E 类争议 mini-debate：最多 2 轮，每轮 60 秒，总时长 3 分钟，需接入真实辩论引擎。

**现状**:
- `scripts/lib/e_class_mini_debate.py:6-8` docstring 明示: *"uses deterministic placeholder scoring until an external debate backend is wired"*
- `e_class_mini_debate.py:144-147` 使用确定性 placeholder 评分（high=0.75 / else=0.65）
- `e_class_mini_debate.py:126-140` backend_report 仅在调用方显式传入时被采纳，**内部不调用 DebateEngine**
- `scripts/lib/debate_engine.py:20-167` DebateEngine 类存在但提供 registries/create_run，**无 `.run_debate()` 执行方法，未被 mini-debate 引用**
- `e_class_mini_debate.py:15-23` E_CLASS_CONFIG 仅含 max_rounds/team_size/timeout/required_consensus，**未引用 16 支 canonical 团队**
- `team_size=2` 与 PRD 要求 ≥3 人/团队冲突
- `debate_refs` 是本地拼接字符串（`debate://run/.../e-class/...`）而非真实 `debate_id`，**无法做同源隔离/可追溯审计**

**修复方向**: 替换 `execute_e_class_debate` 内部实现，调用 `DebateEngine.create_run()` 并返回标准 debate_id；同步修正 team_size 至 ≥3；wire-up 至 orch_gateway 改进闭环。

---

## ⚠️ 改进项中的"二阶缺口"（库就绪但未集成）

本次审计最有价值的发现：**sprint 交付 ≠ 生产可用**。具体表现为：

| ID | 文件已就绪 | 但… | 根因 |
|----|-----------|-----|------|
| **DEB-04** | `worker_source_isolation.py` 完整 + 13 测试 | `orch_gateway.py` / `worker_session.py` **无任何 import**；`orchestra.full.schema.json` 无 `adjudicator_source` 字段 | sprint-7 实质交付孤立工具库 |
| **CH-03** | `security_escape.py` + 14 测试 | `force_standard_for_security()` **仅在 tests 被 grep 命中**，主流程未挂载 | sprint-5 未对接 create_run 入口 |
| **CH-02** | `mini_debate_orchestration.py` quick 通道映射 | `config/performance/slo-policy.json:41` `quick.debate_rounds=0` **直接矛盾 PRD §7.2** 的 1 轮要求 | sprint-6 未对齐运行时配置 |
| **EVAL-02** | `global_evaluation_veto.py` 完整 library + 4 测试 | 主流程仍走 `gateway_evaluation._authority_route()` 旧 high_risk 逻辑；veto 库未被调用 | sprint-10 库就绪未接线 |
| **COR-02** | `correction_override.py` 11 测试通过 | `correction_gate.py` 写出的 jsonl **不进入** `run.override_records` 数组；未对接 run_projection 事件 | sprint-11 库就绪未接线 |

**根因模式**: sprint 模型是"创建 library + tests"，但缺少"wire-up into orch_gateway + run_projection 事件管道"步骤。**sprint-13 (#46) 终极闸门未对此类二阶缺口做强制校验** —— 这是下一轮 sprint 应当修复的 process 漏洞。

---

## 📈 维度级净变动

```
维度                          基线 → 当前      Δ     状态
─────────────────────────────────────────────────────────
Worker 执行 + DAG           5.3 → 9.0  (+3.8)  🟢 全面补齐
全局评估 + 用户纠正          4.0 → 7.2  (+3.2)  🟢 显著提升
通道分级                     3.4 → 6.4  (+3.0)  🟢 显著提升
需求补全                     6.7 → 8.3  (+1.7)  🟢 中度提升
改进闭环 + 持续改进          6.2 → 7.8  (+1.7)  🟢 中度提升
状态机                       6.0 → 7.5  (+1.5)  🟡 小幅提升
Schema + 成功指标 + 心跳      6.5 → 7.8  (+1.3)  🟡 小幅提升
辩论系统                     7.3 → 8.3  (+1.0)  🟡 小幅提升
```

---

## ➡️ 未变项 (8 项)

| ID | 维度 | 基线 | 当前 | 备注 |
|----|------|------|------|------|
| INT-01 | 需求补全 | 6 | 7 | `project_discovery.py` 自然小升，未触发 sprint |
| INT-03 | 需求补全 | 9 | 9 | 已满分 |
| DEB-01 | 辩论系统 | 10 | 10 | 已满分 |
| DEB-02 | 辩论系统 | 9 | 9 | 已满分 |
| DEB-03 | 辩论系统 | 9 | 9 | 已满分 |
| **IMP-03** | **改进闭环** | **4** | **4** | **唯一未消化缺口**（见上） |
| MET-02 | 成功指标 | 10 | 10 | 已满分 |
| HB-01 | 执行心跳 | 5 | 5 | 心跳断线重连（5 秒内拉最近 3 条历史）仍未实现 |

---

## 📌 Sprint 实现有效率

| 指标 | 值 |
|------|-----|
| sprint 声称触达 | 18 项 |
| 实际改善 | 16 项 |
| 实际回退 | 0 项 |
| **改善率** | **89%** |

未被 sprint 触动但仍变化的项：INT-01（+1，自然演进）。

### Sprint 落空的两项
1. (隐含) 部分 sprint 的 library 接线未完成（DEB-04/CH-03/CH-02/EVAL-02/COR-02 二阶缺口）
2. (隐含) sprint-13 (#46) 终极闸门未对"库就绪未集成"做强制契约校验

---

## 🎯 优先修复建议

### P0 — 阻塞级（影响核心正确性）

1. **IMP-03 真实引擎接入**（4/10 → 8/10）
   - 替换 `e_class_mini_debate.execute_e_class_debate` 内部实现
   - 调用 `DebateEngine.create_run()` 并返回标准 `debate_id`
   - team_size 修正至 ≥3
   - wire-up 至 `orch_gateway.improvement_loop`

### P1 — 高优（影响功能完整性 — 二阶缺口）

2. **DEB-04 gateway 接线**（5/10 → 9/10）
   - `orch_gateway.py` import `worker_source_isolation`
   - 在 worker session 创建前调用 `check_worker_source_isolation()`
   - `orchestra.full.schema.json` 增 `adjudicator_source` / `source_isolation_status` 字段

3. **CH-03 主流程集成**（7/10 → 9/10）
   - `orch_gateway.create_run` 前调 `force_standard_for_security()`
   - 落库至 `evidence_scanner.py` 审计管道

4. **CH-02 SLO 对齐**（6/10 → 8/10）
   - `config/performance/slo-policy.json:41` `quick.debate_rounds: 0` → `1`
   - mini_debate_orchestration 启用真实 wall-clock 30s 超时门控

5. **EVAL-02 主链切换**（7/10 → 9/10）
   - `gateway_evaluation._authority_route()` → `global_evaluation_veto`
   - 浮点 0-1 与 0-10 整数在 `normalize_global_evaluation` 处做转换

6. **COR-02 run projection**（8/10 → 9/10）
   - `correction_override` 写 `run.override_records[]`
   - 触发 `run_projection` 事件管道

### P2 — 中优（影响质量保障）

7. **INT-02 字段精细化**（9/10 → 10/10）
   - 冲突清单/风险边界/依赖图/验收矩阵 4 项独立字段建模
   - bundle → `requirement-completion-bundle.json` 序列化适配器

8. **DAG-02 cycle path 完整性**
   - `_back_edges` 报告完整 cycle path 而非单边
   - 大型 DAG（>10k 节点）`sys.setrecursionlimit` 提升

9. **HB-01 断线重连**
   - 5 秒内重连可获取最近 3 条历史心跳
   - 快照查询接口

10. **Process 漏洞修复**
    - sprint 模型增"wire-up into orch_gateway"硬性 gate
    - 终极闸门 sprint-N+1 校验 library 是否被主流程 import

---

## 📎 附录

### 数据来源
- 基线: `docs/PRD-COMPLIANCE-AUDIT-REPORT.md` (2026-06-05)
- 当前: 仓库 HEAD @ 2026-06-15
- PRD: `docs/prd_by_kimi.md` (v1.3)
- 用户流程: `docs/user-flow-guide_by_kimi.md`
- Sprint commits: sprint-2 (#35) ~ sprint-13 (#46)

### 审计 workflow
- 脚本: `.claude/workflows/prd-compliance-audit.js`
- 本次 drift 脚本: workflow pipeline（8 维度并行重审）
- Tokens: 305k / Tool uses: 196 / Duration: 6.8 分钟

### 输出文件
- 本报告: `docs/audit/prd-compliance-drift-audit-2026-06-15.md`
- 结构化数据: `docs/audit/prd-compliance-drift-audit-2026-06-15.json`（每项含 evidence/gaps/notes）

### 审计纪律
1. **必须读代码再给分** —— 每项 evidence 含 `文件:行号`，禁止凭 commit message 评分
2. **drift 阈值 ±2 分** —— 避免小幅波动误报
3. **库就绪 ≠ 集成** —— grep 验证 import 关系是二阶缺口核心判据

---

**报告生成**: workflow 自动化审计 + 人工综合
**下次审计建议**: P0/P1 修复完成后或下一个 sprint 周期（建议 2026-06-22）
