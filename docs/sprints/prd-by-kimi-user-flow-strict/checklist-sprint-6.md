# Sprint 6 验收清单

## 验收条件（可独立验证子项）

### AC-1: 争议程度量化指标可计算且可回放
- **可执行断言**: 给定同一组 candidate_solutions，重复计算 `dispute_score` 结果偏差 < 0.01；`events.jsonl` 中存在 `"dispute_score"` 字段的 JSON 行
- **测试脚本**: `scripts/tests/test-debate-member-invocation.sh`
- **负向用例**: 修改 weights 后未重新归一化，导致 dispute_score 超出 [0,1] 范围，系统未拒绝该非法配置
- **状态**: ⬜

### AC-2: DAG 无环性验证可拦截含环图
- **可执行断言**: 构造含环测试 DAG（A→B→C→A），`scripts/lib/dag_validator.py` 返回 `cycle_detected=true` 并上报 `dag_cycle_detected` 事件到 `events.jsonl`
- **测试脚本**: `scripts/tests/test-dag-validator-cycle.sh`
- **负向用例**: AI 生成的 DAG 存在间接回环（通过跨边界依赖），DFS 深度不足导致漏检，三阶执行死锁
- **状态**: ⬜

### AC-3: DAG 连通性验证可发现孤立节点
- **可执行断言**: 构造含不可达节点的 DAG，验证器返回 `connectivity_passed=false` 并列出 orphan task ID；全连通 DAG 返回 `connectivity_passed=true`
- **测试脚本**: `scripts/tests/test-dag-validator-connectivity.sh`
- **负向用例**: 孤立节点被错误地标记为可达（邻接表遍历未覆盖所有边），导致三阶执行遗漏任务
- **状态**: ⬜

### AC-4: 同源隔离检测可发现碰撞并强制重分配
- **可执行断言**: 构造两个 task 具有相同 `source_fingerprint` 且指向同一 agent，系统触发 `source_collision` 事件并拒绝并行分派；`audit.jsonl` 中可检索到 `source_isolation_check` 记录
- **测试脚本**: `scripts/tests/test-source-isolation-collision.sh`
- **负向用例**: 两个 worker 使用相同临时路径但不同执行环境，因 `source_fingerprint` 仅依赖路径导致误报 collision，合法并行被阻断
- **状态**: ⬜

### AC-5: 模式选择矩阵按 dispute_score 正确路由
- **可执行断言**: `dispute_score=0.15` → `consensus_fast`；`dispute_score=0.45` → `standard_debate`；`dispute_score=0.75` → `deep_fork`；三种得分各执行 5 次，路由结果 100% 一致
- **测试脚本**: `scripts/tests/test-debate-member-invocation.sh`（模式路由子用例）
- **负向用例**: dispute_score 恰好等于阈值边界值（如 0.3），系统未定义边界行为导致路由随机漂移
- **状态**: ⬜

### AC-6: 自动门控在三阶就绪条件满足时自动推进
- **可执行断言**: 所有前置检查通过时，`events.jsonl` 中出现 `stage_transition: 2→3` 事件；任一检查失败时，出现 `stage2_blocker` 事件且 run stage 保持为 2
- **测试脚本**: `scripts/tests/test-e2e-ai-debate-flow.sh`
- **负向用例**: DAG 验证通过但同源隔离失败，系统仍错误地推进到三阶，导致后续执行碰撞
- **状态**: ⬜

## 架构红线合规
- [ ] 新增 `scripts/lib/dag_validator.py` 独立模块，DAG 验证逻辑未直接追加到 `orch_gateway.py`
- [ ] `orch_gateway.py` 净增长 ≤ 50 行（通过 `wc -l` 对比 sprint 开始前后）
- [ ] `dag_validator.py` 未反向依赖 `debate_member_invocation.py`（验证 `grep -r "debate_member_invocation" scripts/lib/dag_validator.py` 返回空）
- [ ] `config/debate/full/modes.json` 中新增 `consensus_fast`、`standard_debate`、`deep_fork` 三种 mode 定义

## 文档交付物
- [ ] `docs/adr/0002-full-debate-package-mode-registry.md` 已更新，包含 `dispute_score` 计算逻辑与 canonical mode 选择矩阵
- [ ] `docs/gateway-integration-architecture.md` 已更新，包含 DAG 验证与同源隔离的调用时序图
- [ ] `docs/sprints/prd-by-kimi-user-flow-strict/schema.md` 已补充 `debate_metrics`、`dag_validation_result`、`source_isolation_check` 数据模型
- [ ] 《具体实现报告》模板输出通过 Schema 校验（`scripts/tests/test-debate-report-schema.sh` 或等效校验）

## 任务完成状态
- [ ] U6 — 二阶方案辩论模式策略与 DAG 生成（所有 AC 断言通过）

## 验证命令汇总

```bash
rtk bash scripts/tests/test-debate-member-invocation.sh
rtk bash scripts/tests/test-e2e-ai-debate-flow.sh
rtk bash scripts/tests/test-gateway-ai-integration.sh
rtk bash scripts/tests/test-dag-validator-cycle.sh
rtk bash scripts/tests/test-dag-validator-connectivity.sh
rtk bash scripts/tests/test-source-isolation-collision.sh
```

## 签核
- [ ] 开发完成
- [ ] 测试通过（所有 AC 断言通过）
- [ ] Code Review 完成
- [ ] 架构红线合规确认
- [ ] 合并到 main
