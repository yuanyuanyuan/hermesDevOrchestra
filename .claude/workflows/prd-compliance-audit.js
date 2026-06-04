export const meta = {
  name: 'prd-compliance-audit',
  description: '基于 PRD 和用户流程指南对 Hermes Dev Orchestra 代码实现还原度进行审计',
  phases: [
    { title: '定义 Checklist', detail: '从 PRD 提取关键需求，生成结构化审计清单' },
    { title: '逐条审计', detail: '并行审计各维度的实现还原度' },
    { title: '综合评估', detail: '汇总发现，生成最终审计报告' },
  ],
}

// ─── Checklist 定义 ──────────────────────────────────────────────────
const CHECKLIST = [
  // ===== 1. 六阶段 Gateway 状态机 =====
  {
    id: 'SM-01',
    dimension: '状态机',
    requirement: 'Run 状态机必须包含六阶段：direction_debate → solution_debate → implementation → improvement → global_evaluation → continuous_improvement',
    prdRef: 'PRD §3.6',
    auditPrompt: '检查 scripts/lib/orch_gateway.py 中是否定义了完整的六阶段状态机，阶段流转条件是否与 PRD §3.6 表格一致。重点关注：1) 状态枚举是否完整 2) 流转条件是否正确 3) 异常状态(paused/blocked/cancelled/rollback_requested)是否支持',
  },
  {
    id: 'SM-02',
    dimension: '状态机',
    requirement: 'Gateway 必须在阶段推进前校验证据完整性，证据缺失时阻塞',
    prdRef: 'PRD §8',
    auditPrompt: '检查 scripts/lib/orch_gateway.py 中阶段推进逻辑是否包含证据校验。重点关注 evidence_gate.py 和 gateway_evidence.py 的实现，以及 orch_gateway.py 中调用证据校验的位置。',
  },

  // ===== 2. 0阶需求补全 =====
  {
    id: 'INT-01',
    dimension: '需求补全',
    requirement: '新项目接入探测：自动读取文件树、依赖文件、CI/CD 配置，生成项目探测报告',
    prdRef: 'PRD §4.1 / UserFlow §6',
    auditPrompt: '检查 scripts/lib/project_discovery.py 是否实现了项目探测功能。验证：1) 是否读取 package.json/pyproject.toml/go.mod 等依赖文件 2) 是否检测 CI/CD 配置 3) 是否生成探测报告 4) 5分钟 SLA 是否有超时处理',
  },
  {
    id: 'INT-02',
    dimension: '需求补全',
    requirement: '0阶输出必须包含：原始意图、补全内容、已验证事实、未验证假设、冲突清单、依赖图、验收矩阵、执行 prompt envelope',
    prdRef: 'PRD §5.1 / UserFlow §6',
    auditPrompt: '检查 scripts/lib/gateway_intake.py 的输出结构是否包含 PRD §5.1 要求的所有字段。验证 requirement-completion-bundle 或等价数据结构的完整性。',
  },
  {
    id: 'INT-03',
    dimension: '需求补全',
    requirement: '每个顶层区块必须附 source_input_hash 和 projection_timestamp，关键结论必须附 source/confidence/verification_method',
    prdRef: 'UserFlow §6',
    auditPrompt: '检查 gateway_intake.py 和 gateway_projection.py 中是否实现了信息溯源字段（source_input_hash, projection_timestamp, source, confidence, verification_method）。',
  },

  // ===== 3. 辩论系统 =====
  {
    id: 'DEB-01',
    dimension: '辩论系统',
    requirement: '16 支 canonical 团队注册：security, compliance, data_engineering, devops_sre, frontend, ai_feature, scalability_arch, chaos_engineering, platform, privacy_ethics, oss_compliance, observability, business, documentation, api_design, i18n_l10n',
    prdRef: 'PRD §6.1',
    auditPrompt: '检查 config/debate/full/teams.json 或 config/debate/teams.json 是否包含全部 16 支 canonical 团队。验证 team id 是否与 PRD §6.1 完全一致。',
  },
  {
    id: 'DEB-02',
    dimension: '辩论系统',
    requirement: '8 种 canonical 模式：sequential_review, parallel_debate, adversarial_debate, jury_panel, dynamic_assembly, meta_review, risk_priority_matrix, cross_team_conflict_detector',
    prdRef: 'PRD §6.3',
    auditPrompt: '检查 config/debate/full/modes.json 或 config/debate/modes.json 是否包含全部 8 种 canonical 模式。验证 mode id 是否与 PRD §6.3 完全一致。',
  },
  {
    id: 'DEB-03',
    dimension: '辩论系统',
    requirement: '辩论引擎必须支持 dynamic_assembly 和 adversarial_debate 模式',
    prdRef: 'PRD §6.4',
    auditPrompt: '检查 scripts/lib/debate_assembly.py 和 scripts/lib/debate_engine.py 是否实现了 dynamic_assembly 和 adversarial_debate 模式的调度逻辑。',
  },
  {
    id: 'DEB-04',
    dimension: '辩论系统',
    requirement: '同源隔离检测：review/audit/cross_check worker 的 model_source 不得与上层裁决者同源',
    prdRef: 'PRD §4.3',
    auditPrompt: '检查 scripts/lib/worker_session.py 或 scripts/lib/dispatch_gate.py 中是否实现了 model_source 校验和 source_isolation_violation 检测。',
  },

  // ===== 4. 冲突管理 =====
  {
    id: 'CON-01',
    dimension: '冲突管理',
    requirement: 'Conflict Ledger 数据结构必须包含：conflict_id, run_id, stage, type, sources, severity, resolution, resolver, resolution_evidence, created_at, resolved_at',
    prdRef: 'PRD §3.5',
    auditPrompt: '搜索代码中 Conflict Ledger 或 conflict 相关的数据结构定义，验证字段是否与 PRD §3.5 表格一致。检查 scripts/lib/ 和 config/schemas/ 中的定义。',
  },
  {
    id: 'CON-02',
    dimension: '冲突管理',
    requirement: 'Gateway 在阶段推进前必须查询 open 状态冲突，存在 severity=high 且未解决时禁止推进',
    prdRef: 'PRD §3.5',
    auditPrompt: '检查 orch_gateway.py 中阶段推进逻辑是否查询 open 冲突，是否在 high severity 冲突未解决时阻塞推进。',
  },

  // ===== 5. 通道分级 =====
  {
    id: 'CH-01',
    dimension: '通道分级',
    requirement: '三层通道：快速通道(跳过一二阶)、轻量通道(跳过一二阶)、标准通道(无跳过)',
    prdRef: 'PRD §7.1 / UserFlow §5',
    auditPrompt: '检查 scripts/lib/channel_router.py 是否实现了三层通道分级逻辑。验证快速/轻量通道是否正确跳过一阶和二阶。',
  },
  {
    id: 'CH-02',
    dimension: '通道分级',
    requirement: '快速通道判定需经一轮极简辩论确认（1-2 支团队，1 轮，30 秒内），不可直接黑盒执行',
    prdRef: 'PRD §7.2 / UserFlow §5',
    auditPrompt: '检查 channel_router.py 中快速通道判定是否包含极简辩论确认步骤，而非直接通过规则引擎执行。',
  },
  {
    id: 'CH-03',
    dimension: '通道分级',
    requirement: '安全逃逸规则：含 password/secret/token/key 等敏感词时强制升级为标准通道',
    prdRef: 'PRD §7.5',
    auditPrompt: '检查 channel_router.py 或 security_scanner.py 中是否实现了安全逃逸规则，敏感词匹配是否完整。',
  },
  {
    id: 'CH-04',
    dimension: '通道分级',
    requirement: '快速通道自动合并功能，含 auto_merge 降级流程',
    prdRef: 'PRD §7.3 / §7.7',
    auditPrompt: '检查 scripts/lib/auto_merge_controller.py 是否实现了自动合并逻辑，以及合并失败时的降级流程（git冲突、CI失败、分支保护规则冲突）。',
  },
  {
    id: 'CH-05',
    dimension: '通道分级',
    requirement: 'Rollout Gate：observe_only → calibrating → enabled 渐进式启用',
    prdRef: 'PRD §7.6',
    auditPrompt: '检查 scripts/lib/rollout_gate.py 是否实现了三阶段 rollout 控制，以及误判率阈值和自动回退机制。',
  },

  // ===== 6. Worker 执行 =====
  {
    id: 'WRK-01',
    dimension: 'Worker 执行',
    requirement: 'Worker 生命周期管理：会话创建、工作区分配、写入范围、超时清理、输出收集',
    prdRef: 'PRD §9.2',
    auditPrompt: '检查 scripts/lib/worker_session.py 是否实现了完整的 Worker 生命周期管理，包括会话创建、工作区隔离、超时处理和输出收集。',
  },
  {
    id: 'WRK-02',
    dimension: 'Worker 执行',
    requirement: '写入范围校验：并行任务必须有 disjoint write set 或明确合并策略',
    prdRef: 'PRD §7.8',
    auditPrompt: '检查 scripts/lib/write_scope_validator.py 是否实现了写入范围校验，以及 scripts/lib/dag_validator.py 中并行任务冲突检测逻辑。',
  },
  {
    id: 'WRK-03',
    dimension: 'Worker 执行',
    requirement: 'Worker Zombie 检测和心跳机制',
    prdRef: 'PRD §4.4 / UserFlow §10',
    auditPrompt: '检查 scripts/lib/heartbeat_handler.py 和 scripts/lib/worker_session_sweeper.py 是否实现了心跳处理和僵尸 Worker 检测。',
  },

  // ===== 7. 执行心跳 =====
  {
    id: 'HB-01',
    dimension: '执行心跳',
    requirement: '每 30 秒或每完成一个子任务推送进度摘要，SSE 传输协议',
    prdRef: 'PRD §9.4 / UserFlow §10',
    auditPrompt: '检查 scripts/lib/heartbeat_handler.py 是否实现了 SSE 推送、30秒间隔心跳、断线重连恢复（5秒内重连可获取最近3条历史心跳）。',
  },

  // ===== 8. 改进闭环 =====
  {
    id: 'IMP-01',
    dimension: '改进闭环',
    requirement: '四阶 A-E 分类自动判定：A纯代码级/B需额外信息/C超范围/D回归/E争议',
    prdRef: 'PRD §4.5 / UserFlow §11',
    auditPrompt: '检查 scripts/lib/gateway_improvement.py 是否实现了 A-E 五类问题的自动分类逻辑，以及各类别的判定条件是否与 PRD §4.5 表格一致。',
  },
  {
    id: 'IMP-02',
    dimension: '改进闭环',
    requirement: 'D 类回归循环最多 3 次，第 3 次失败后上浮用户决策',
    prdRef: 'PRD §4.5',
    auditPrompt: '检查 gateway_improvement.py 中 D 类回归循环是否有 3 次上限控制，以及第 3 次失败后的上浮逻辑。',
  },
  {
    id: 'IMP-03',
    dimension: '改进闭环',
    requirement: 'E 类争议 mini-debate：最多 2 轮，每轮 60 秒，总时长 3 分钟',
    prdRef: 'PRD §4.5',
    auditPrompt: '检查 scripts/lib/debate_engine.py 中是否实现了 mini-debate 机制，包括轮次限制（2轮）、时间约束（60秒/轮，3分钟总时长）和超时处理。',
  },

  // ===== 9. 全局评估 =====
  {
    id: 'EVAL-01',
    dimension: '全局评估',
    requirement: '8 维评估：业务目标、补全正确性、安全合规、质量、性能、可维护性、文档、可观测性',
    prdRef: 'PRD §4.6 / UserFlow §12',
    auditPrompt: '检查 scripts/lib/gateway_evaluation.py 是否实现了 8 维评估，每个维度是否有 pass/warn/fail 评分和置信度。验证综合 verdict 生成规则（一票否决维度 fail → 整体 fail）。',
  },
  {
    id: 'EVAL-02',
    dimension: '全局评估',
    requirement: 'pass_with_warnings 的残余风险阈值：高风险零容忍，中风险≤1个，低风险≤3个',
    prdRef: 'PRD §4.6',
    auditPrompt: '检查 gateway_evaluation.py 中 pass_with_warnings 的阈值判定逻辑是否与 PRD §4.6 风险阈值表格一致。',
  },
  {
    id: 'EVAL-03',
    dimension: '全局评估',
    requirement: '通知级别配置：none/summary/full，生产环境禁止 none',
    prdRef: 'PRD §4.6',
    auditPrompt: '检查 gateway_evaluation.py 或相关模块中是否实现了通知级别配置，以及生产环境禁止 none 的强制策略。',
  },

  // ===== 10. 持续改进 =====
  {
    id: 'CI-01',
    dimension: '持续改进',
    requirement: '六阶审计输入完整性校验：需求补全包、执行日志、工具调用、错误栈、审查记录、Gateway 状态、Closeout artifacts',
    prdRef: 'PRD §4.7',
    auditPrompt: '检查 scripts/lib/self_evolution.py 或 gateway_closeout.py 中是否实现了审计输入完整性校验，缺失时是否拒绝进入 continuous_improvement 阶段。',
  },
  {
    id: 'CI-02',
    dimension: '持续改进',
    requirement: 'Self-evolution Queue：pending_review → applied / rejected',
    prdRef: 'PRD §4.7',
    auditPrompt: '检查 scripts/lib/self_evolution.py 是否实现了 self-evolution queue 的状态管理（pending_review/applied/rejected），以及 config/evolution/self-evolution-review-queue.json 的配置。',
  },
  {
    id: 'CI-03',
    dimension: '持续改进',
    requirement: 'Protected Target 审批：L3 需 human_approval_ref，L4 需 kimi_review_ref + human_approval_ref',
    prdRef: 'PRD §4.7',
    auditPrompt: '检查 scripts/lib/self_evolution.py 和 scripts/lib/gateway_closeout.py 中是否实现了 protected target 审批校验，L3/L4 审批级别是否正确。',
  },

  // ===== 11. 用户错误纠正 =====
  {
    id: 'COR-01',
    dimension: '用户纠正',
    requirement: '用户错误纠正机制：两轮渐进式纠正，第一轮极简，第二轮完整证据',
    prdRef: 'PRD §4.1 / UserFlow §4',
    auditPrompt: '检查 scripts/lib/correction_gate.py 是否实现了两轮渐进式纠正逻辑，包括第一轮极简提示和第二轮完整证据展示。',
  },
  {
    id: 'COR-02',
    dimension: '用户纠正',
    requirement: 'Override 记录格式：override_id, run_id, user_intent_original, correction_rounds, override_category, risk_level, approver_ref, evidence_refs, status, created_at',
    prdRef: 'PRD §4.1',
    auditPrompt: '检查代码中 Override 记录的数据结构是否包含 PRD §4.1 要求的全部字段。',
  },

  // ===== 12. 成功指标 =====
  {
    id: 'MET-01',
    dimension: '成功指标',
    requirement: '成功指标采集管道：events.jsonl NDJSON 格式，包含 event_type/timestamp/run_id/payload',
    prdRef: 'PRD §11.1',
    auditPrompt: '检查 scripts/lib/success_metrics.py 是否实现了事件采集管道，events.jsonl 格式是否为 NDJSON 且包含必要字段。',
  },
  {
    id: 'MET-02',
    dimension: '成功指标',
    requirement: 'orch-audit 和 orch-verify 工具实现',
    prdRef: 'PRD §11.1 / UserFlow §19',
    auditPrompt: '检查 scripts/bin/ 目录下是否存在 orch-audit 和 orch-verify 脚本，是否实现了指标聚合和阈值验证功能。',
  },

  // ===== 13. Schema 一致性 =====
  {
    id: 'SCH-01',
    dimension: 'Schema',
    requirement: 'config/schemas/orchestra.full.schema.json 包含所有事件字段定义',
    prdRef: 'PRD §11.1',
    auditPrompt: '检查 config/schemas/orchestra.full.schema.json 是否完整定义了 PRD 中要求的所有事件类型和字段。与 schema.md 做一致性比对。',
  },

  // ===== 14. DAG 管理 =====
  {
    id: 'DAG-01',
    dimension: 'DAG 管理',
    requirement: 'DAG 数据格式支持 nodes/edges/parallel_groups/rollback_checkpoint',
    prdRef: 'PRD §4.3',
    auditPrompt: '检查 scripts/lib/dag_validator.py 中 DAG 数据结构是否支持 nodes（含 task_id/worker_type/input_refs/output_refs/write_scope/test_strategy 等）、edges（含 dependency_type）、parallel_groups 和 rollback_checkpoint。',
  },
  {
    id: 'DAG-02',
    dimension: 'DAG 管理',
    requirement: 'Gateway 解析 DAG 时必须检测循环依赖，存在环时阻塞',
    prdRef: 'PRD §4.3',
    auditPrompt: '检查 scripts/lib/dag_validator.py 是否实现了循环依赖检测，存在环时是否返回 invalid_dag_cycle 错误。',
  },

  // ===== 15. 回滚策略 =====
  {
    id: 'RB-01',
    dimension: '回滚策略',
    requirement: '回滚策略支持：丢弃补全包、丢弃辩论报告、git revert、回滚到基线',
    prdRef: 'PRD §3.6',
    auditPrompt: '检查 orch_gateway.py 中是否实现了回滚逻辑，不同阶段的回滚范围是否与 PRD §3.6 回滚策略表格一致。',
  },
]

// ─── Workflow 主体 ──────────────────────────────────────────────────

// Phase 1: 输出 Checklist 摘要
phase('定义 Checklist')
log(`已定义 ${CHECKLIST.length} 项审计清单，覆盖 ${[...new Set(CHECKLIST.map(c => c.dimension))].length} 个维度`)

const dimensions = [...new Set(CHECKLIST.map(c => c.dimension))]
log(`维度列表: ${dimensions.join(', ')}`)

// Phase 2: 逐条审计 — 按维度并行
phase('逐条审计')

const auditResults = await pipeline(
  CHECKLIST,
  // Stage 1: 每条 checklist 生成审计 prompt 并执行
  async (item) => {
    const prompt = `你是一个 PRD 合规审计专家。请对以下需求进行实现还原度审计。

## 审计项
- ID: ${item.id}
- 维度: ${item.dimension}
- 需求: ${item.requirement}
- PRD 引用: ${item.prdRef}

## 审计指令
${item.auditPrompt}

## 项目上下文
- 项目根目录: /data/hermes
- Gateway 核心: scripts/lib/orch_gateway.py
- 配置目录: config/
- Schema: config/schemas/
- 测试: scripts/tests/

## 输出要求
请用以下 JSON 格式输出审计结果：
{
  "id": "${item.id}",
  "dimension": "${item.dimension}",
  "requirement": "...",
  "status": "fully_implemented | partially_implemented | not_implemented | not_found",
  "score": 0-10,
  "evidence": ["具体的文件路径和代码位置"],
  "gaps": ["未实现或不完整的部分"],
  "risks": ["潜在风险"],
  "recommendation": "改进建议"
}

注意：
1. 必须基于实际代码做出判断，不要猜测
2. status 为 partially_implemented 时，必须明确哪些部分已实现、哪些缺失
3. score 含义：0=完全未实现，5=部分实现，10=完全符合 PRD
4. 请阅读相关源代码文件后再给出结论`

    const result = await agent(prompt, {
      label: `audit:${item.id}`,
      phase: '逐条审计',
      schema: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          dimension: { type: 'string' },
          requirement: { type: 'string' },
          status: { type: 'string', enum: ['fully_implemented', 'partially_implemented', 'not_implemented', 'not_found'] },
          score: { type: 'number', minimum: 0, maximum: 10 },
          evidence: { type: 'array', items: { type: 'string' } },
          gaps: { type: 'array', items: { type: 'string' } },
          risks: { type: 'array', items: { type: 'string' } },
          recommendation: { type: 'string' },
        },
        required: ['id', 'dimension', 'status', 'score', 'evidence', 'gaps', 'risks', 'recommendation'],
      },
    })

    return result
  }
)

// Phase 3: 综合评估
phase('综合评估')

const validResults = auditResults.filter(Boolean)

// 按维度汇总
const byDimension = {}
for (const r of validResults) {
  if (!byDimension[r.dimension]) byDimension[r.dimension] = []
  byDimension[r.dimension].push(r)
}

// 计算维度得分
const dimensionScores = Object.entries(byDimension).map(([dim, items]) => {
  const avgScore = items.reduce((sum, i) => sum + i.score, 0) / items.length
  const fullyImpl = items.filter(i => i.status === 'fully_implemented').length
  const partialImpl = items.filter(i => i.status === 'partially_implemented').length
  const notImpl = items.filter(i => i.status === 'not_implemented' || i.status === 'not_found').length
  return { dimension: dim, avgScore, fullyImpl, partialImpl, notImpl, total: items.length }
})

// 生成报告
const overallScore = validResults.reduce((sum, r) => sum + r.score, 0) / validResults.length
const allGaps = validResults.flatMap(r => r.gaps.map(g => ({ id: r.id, dimension: r.dimension, gap: g })))
const allRisks = validResults.flatMap(r => r.risks.map(risk => ({ id: r.id, dimension: r.dimension, risk })))
const highPriorityGaps = validResults.filter(r => r.score < 5).flatMap(r => r.gaps.map(g => ({ id: r.id, dimension: r.dimension, gap: g, score: r.score })))

log(`\n${'═'.repeat(60)}`)
log(`  PRD 合规审计报告 — Hermes Dev Orchestra`)
log(`${'═'.repeat(60)}`)
log(`\n📊 总体得分: ${overallScore.toFixed(1)} / 10`)
log(`📋 审计项数: ${validResults.length} / ${CHECKLIST.length}`)
log(`✅ 完全实现: ${validResults.filter(r => r.status === 'fully_implemented').length}`)
log(`⚠️  部分实现: ${validResults.filter(r => r.status === 'partially_implemented').length}`)
log(`❌ 未实现: ${validResults.filter(r => r.status === 'not_implemented' || r.status === 'not_found').length}`)

log(`\n${'─'.repeat(60)}`)
log(`  维度得分概览`)
log(`${'─'.repeat(60)}`)
for (const d of dimensionScores.sort((a, b) => a.avgScore - b.avgScore)) {
  const bar = '█'.repeat(Math.round(d.avgScore)) + '░'.repeat(10 - Math.round(d.avgScore))
  log(`  ${d.dimension.padEnd(12)} ${bar} ${d.avgScore.toFixed(1)}/10  (${d.fullyImpl}✅ ${d.partialImpl}⚠️ ${d.notImpl}❌)`)
}

log(`\n${'─'.repeat(60)}`)
log(`  高优先级缺口 (得分 < 5)`)
log(`${'─'.repeat(60)}`)
if (highPriorityGaps.length === 0) {
  log(`  无高优先级缺口`)
} else {
  for (const g of highPriorityGaps.slice(0, 20)) {
    log(`  ❌ [${g.id}] ${g.gap}`)
  }
}

log(`\n${'─'.repeat(60)}`)
log(`  Top 风险项`)
log(`${'─'.repeat(60)}`)
for (const r of allRisks.slice(0, 15)) {
  log(`  ⚠️  [${r.id}] ${r.risk}`)
}

// 输出完整结果供后续写入报告文件
return {
  overallScore,
  totalItems: CHECKLIST.length,
  auditedItems: validResults.length,
  dimensionScores,
  results: validResults,
  gaps: allGaps,
  risks: allRisks,
  highPriorityGaps,
}
