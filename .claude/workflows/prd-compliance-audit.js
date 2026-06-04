export const meta = {
  name: 'prd-compliance-audit',
  description: '验证代码对 PRD 的合规性，检查文档一致性，列出清理建议，最终生成用户手册。Phase 1 逐项比对 prd_by_kimi.md + user-flow-guide_by_kimi.md 与代码实现；Phase 2 检查文档一致性并归档过期文档，扫描项目列出移除建议；Phase 3 基于审计结果生成 SOP 级用户手册。',
  whenToUse: '当用户需要验证当前代码是否完整实现 PRD 要求、检查文档是否过期、清理项目冗余内容、或生成用户手册时使用。执行前确保代码已 commit。',
  phases: [
    { title: "Extract", detail: "从两份 PRD 提取所有可验证需求检查点" },
    { title: "Verify", detail: "并行验证每个需求维度的代码/配置/测试实现" },
    { title: "Compliance Report", detail: "生成合规矩阵，判定 PASS/FAIL" },
    { title: "Doc Audit", detail: "检查文档一致性，归档过期文档" },
    { title: "Cleanup Scan", detail: "扫描项目内容，列出移除建议" },
    { title: "User Manual", detail: "基于审计结果生成 SOP 级用户手册" },
  ],
}

// ─── Constants ───
const PASS_THRESHOLD = 0.85
const VETO_DIMENSIONS = [
  "six_stage_state_machine_and_gates",
  "evidence_gate",
  "conflict_ledger",
  "override_recording",
  "debate_teams_registry",
  "debate_modes_registry",
  "channel_routing",
]
const VETO_DIMENSION_IDS = new Set(VETO_DIMENSIONS)
const VETO_DIMENSION_ALIASES = {
  six_stage_run_state_machine: "six_stage_state_machine_and_gates",
  six_stage_state_machine: "six_stage_state_machine_and_gates",
  run_state_machine: "six_stage_state_machine_and_gates",
  gateway_evidence_gate: "evidence_gate",
  evidence_gating: "evidence_gate",
  override_approval: "override_recording",
  override_audit: "override_recording",
  debate_teams: "debate_teams_registry",
  canonical_debate_teams: "debate_teams_registry",
  debate_modes: "debate_modes_registry",
  canonical_debate_modes: "debate_modes_registry",
  channel_router: "channel_routing",
}
const PROJECT_ROOT = "."
const DOCS_DIR = `${PROJECT_ROOT}/docs`
const LIB_DIR = `${PROJECT_ROOT}/scripts/lib`
const CONFIG_DIR = `${PROJECT_ROOT}/config`
const TESTS_DIR = `${PROJECT_ROOT}/scripts/tests`
const BIN_DIR = `${PROJECT_ROOT}/scripts/bin`

function canonicalDimensionId(id) {
  return VETO_DIMENSION_ALIASES[id] || id
}

function isVetoDimension(dim) {
  return VETO_DIMENSION_IDS.has(canonicalDimensionId(dim.id))
}

function countResultStatuses(results) {
  const safeResults = Array.isArray(results) ? results : []
  return {
    pass: safeResults.filter(r => r.status === "pass").length,
    fail: safeResults.filter(r => r.status === "fail").length,
    partial: safeResults.filter(r => r.status === "partial").length,
    not_found: safeResults.filter(r => r.status === "not_found").length,
    total: safeResults.length,
  }
}

// ─── Schemas ───
// Batch extraction schema — each batch handles 3-6 dimensions to avoid timeout
const BATCH_EXTRACT_SCHEMA = {
  type: "object",
  required: ["batch_id", "dimensions"],
  properties: {
    batch_id: { type: "string", description: "批次标识，如 batch_1_state_machine" },
    dimensions: {
      type: "array",
      minItems: 2,
      maxItems: 7,
      items: {
        type: "object",
        required: ["id", "name", "prd_section", "is_veto", "checkpoints"],
        properties: {
          id: { type: "string" },
          name: { type: "string" },
          prd_section: { type: "string" },
          is_veto: { type: "boolean" },
          checkpoints: {
            type: "array",
            items: {
              type: "object",
              required: ["check_id", "description", "verify_method"],
              properties: {
                check_id: { type: "string" },
                description: { type: "string" },
                verify_method: { enum: ["code_exists", "function_grep", "config_check", "test_exists", "manual_review"] },
                expected_files: { type: "array", items: { type: "string" } },
                grep_pattern: { type: "string" },
              },
            },
          },
        },
      },
    },
  },
}

const VERIFY_SCHEMA = {
  type: "object",
  required: ["dimension_id", "results"],
  properties: {
    dimension_id: { type: "string" },
    results: {
      type: "array",
      items: {
        type: "object",
        required: ["check_id", "status"],
        properties: {
          check_id: { type: "string" },
          status: { enum: ["pass", "partial", "fail", "not_found"] },
          evidence: { type: "string" },
          details: { type: "string" },
        },
      },
    },
    dimension_score: { type: "number" },
    summary: { type: "string" },
  },
}

const COMPLIANCE_REPORT_SCHEMA = {
  type: "object",
  required: ["overall_verdict", "coverage_rate", "dimensions"],
  properties: {
    overall_verdict: { enum: ["PASS", "FAIL"] },
    coverage_rate: { type: "number" },
    veto_status: {
      type: "array",
      items: {
        type: "object",
        required: ["dimension", "passed"],
        properties: {
          dimension: { type: "string" },
          passed: { type: "boolean" },
          reason: { type: "string" },
        },
      },
    },
    dimensions: {
      type: "array",
      items: {
        type: "object",
        required: ["id", "name", "is_veto", "score", "pass_count", "fail_count", "partial_count", "not_found_count"],
        properties: {
          id: { type: "string" },
          name: { type: "string" },
          is_veto: { type: "boolean" },
          score: { type: "number" },
          pass_count: { type: "number" },
          fail_count: { type: "number" },
          partial_count: { type: "number" },
          not_found_count: { type: "number" },
          issues: { type: "array", items: { type: "string" } },
        },
      },
    },
    critical_gaps: { type: "array", items: { type: "string" } },
  },
}

const DOC_AUDIT_SCHEMA = {
  type: "object",
  required: ["docs"],
  properties: {
    docs: {
      type: "array",
      items: {
        type: "object",
        required: ["file", "status"],
        properties: {
          file: { type: "string" },
          status: { enum: ["current", "outdated", "contradicts_prd", "redundant", "orphaned"] },
          reason: { type: "string" },
          action: { enum: ["keep", "archive", "update", "merge"] },
          archive_reason: { type: "string" },
        },
      },
    },
  },
}

const CLEANUP_SCHEMA = {
  type: "object",
  required: ["items"],
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        required: ["path", "category", "reason", "risk"],
        properties: {
          path: { type: "string" },
          category: { enum: ["duplicate_doc", "orphaned_config", "dead_test", "legacy_alias", "temp_file", "stale_archive"] },
          reason: { type: "string" },
          risk: { enum: ["low", "medium", "high"] },
          dependencies: { type: "array", items: { type: "string" } },
        },
      },
    },
  },
}

const MANUAL_SCHEMA = {
  type: "object",
  required: ["manual_title", "manual_content", "sections", "based_on", "output_path"],
  properties: {
    manual_title: { type: "string", description: "手册标题" },
    manual_content: { type: "string", description: "完整的用户手册内容（Markdown 格式），从用户视角、对话式、SOP 级别，包含调试指南" },
    sections: {
      type: "array",
      items: {
        type: "object",
        required: ["title", "description"],
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          content_preview: { type: "string", description: "该章节内容预览（前 200 字）" },
        },
      },
    },
    based_on: {
      type: "object",
      required: ["verified_dimensions", "total_dimensions", "compliance_rate"],
      properties: {
        verified_dimensions: { type: "number", description: "手册基于的已验证需求数" },
        total_dimensions: { type: "number", description: "总需求数" },
        compliance_rate: { type: "string", description: "合规率" },
        key_features_covered: { type: "array", items: { type: "string" }, description: "手册覆盖的核心功能列表" },
      },
    },
    output_path: { type: "string", description: "手册输出路径" },
  },
}

// ─── Phase 1: Extract requirements from both PRDs (3 parallel batches) ───
phase("Extract")
log("从 prd_by_kimi.md 和 user-flow-guide_by_kimi.md 提取需求检查点（3 批并行）...")

const PRD_CONTEXT =
  "### 输入文件\n" +
  "1. `" + DOCS_DIR + "/prd_by_kimi.md` — 产品需求文档\n" +
  "2. `" + DOCS_DIR + "/user-flow-guide_by_kimi.md` — 用户流程指南\n\n" +
  "### 项目代码位置\n" +
  "- 运行时代码：`" + LIB_DIR + "/`\n" +
  "- 配置文件：`" + CONFIG_DIR + "/`\n" +
  "- 测试脚本：`" + TESTS_DIR + "/`\n" +
  "- CLI 工具：`" + BIN_DIR + "/`\n\n" +
  "### 通用提取规则\n" +
  "1. 读取两份文件，逐章节提取本批次指定维度的可验证需求点\n" +
  "2. 每个需求维度：id(snake_case)、name、prd_section、is_veto、checkpoints[]\n" +
  "3. 固定一票否决维度必须使用以下精确 id：" + VETO_DIMENSIONS.join(", ") + "\n" +
  "4. 每个检查点：check_id、description、verify_method(code_exists|function_grep|config_check|test_exists|manual_review)、expected_files(可选)、grep_pattern(可选)\n\n"

const BATCH_PROMPTS = [
  {
    label: "extract-batch-1-state-machine",
    prompt:
      "## 任务：PRD 需求提取 — 批次 1：六阶段状态机\n\n" + PRD_CONTEXT +
      "### 本批次聚焦\n" +
      "- 六阶段 Run 状态机（§3.6, §4.0）→ orch_gateway.py\n" +
      "  - 阶段入口函数（阶段 0-5）\n" +
      "  - 阶段出口门禁\n" +
      "  - 阶段状态持久化（phase_status.json）\n" +
      "  - 阶段转换/回退机制\n" +
      "- 0阶 需求补全（§4.1）→ gateway_intake.py, project_discovery.py\n" +
      "- 一阶 方向辩论（§4.2）→ debate_ticket_generator.py, debate_assembly.py\n" +
      "- 二阶 方案辩论（§4.3）→ dag_validator.py, debate_engine.py\n" +
      "- 三阶 具体执行（§4.4）→ worker_session.py, heartbeat_handler.py\n" +
      "- 四阶 改进实现（§4.5）→ gateway_improvement.py\n" +
      "- 五阶 全局评估（§4.6）→ gateway_evaluation.py\n" +
      "- 六阶 持续改进（§4.7）→ self_evolution.py, gateway_closeout.py\n\n" +
      "请先读取两份 PRD 文件的相关章节，然后读取 scripts/lib/ 确认文件名，最后输出结构化结果。\n\nStructured output only.",
  },
  {
    label: "extract-batch-2-evidence-security",
    prompt:
      "## 任务：PRD 需求提取 — 批次 2：证据门控 + 安全 + 冲突管理\n\n" + PRD_CONTEXT +
      "### 本批次聚焦\n" +
      "- Gateway 证据门控（§8）→ evidence_gate.py, security_gate.py\n" +
      "  - 证据收集函数、签名验证、完整性校验\n" +
      "  - 证据链路追踪\n" +
      "- Conflict Ledger（§3.5）→ 冲突数据结构\n" +
      "- Override 留痕（§4.1）→ correction_gate.py\n" +
      "- 自动合并安全（§7.3）→ auto_merge_controller.py\n" +
      "- Worker 执行模型（§9）→ worker_registry.py\n\n" +
      "请先读取两份 PRD 文件的相关章节，然后读取 scripts/lib/ 确认文件名，最后输出结构化结果。\n\nStructured output only.",
  },
  {
    label: "extract-batch-3-config-infra",
    prompt:
      "## 任务：PRD 需求提取 — 批次 3：配置 + 基础设施\n\n" + PRD_CONTEXT +
      "### 本批次聚焦\n" +
      "- 16支辩论团队（§6.1）→ config/debate/full/teams.json\n" +
      "- 8种辩论模式（§6.3）→ config/debate/full/modes.json\n" +
      "- 通道分级（§7）→ channel_router.py, rollout_gate.py\n" +
      "- 成功指标采集（§11.1）→ success_metrics.py\n" +
      "- 项目骨架生成（§5）→ project_scaffolder.py, template_engine.py\n" +
      "- 变更日志（§10）→ change_logger.py\n\n" +
      "请先读取两份 PRD 文件的相关章节，然后读取 scripts/lib/ 和 config/ 确认文件名，最后输出结构化结果。\n\nStructured output only.",
  },
]

const batchResults = await parallel(
  BATCH_PROMPTS.map(batch => () =>
    agent(batch.prompt, { label: batch.label, phase: "Extract", schema: BATCH_EXTRACT_SCHEMA })
  )
)

// Merge all batch results
const extractResult = {
  dimensions: batchResults.filter(Boolean).flatMap(b => b.dimensions || []),
}

if (!extractResult.dimensions.length) {
  return { error: "需求提取失败，无法继续。" }
}
log("提取完成：" + extractResult.dimensions.length + " 个需求维度（3 批合并）")

// ─── Phase 2: Verify each dimension in parallel ───
phase("Verify")
log("并行验证 " + extractResult.dimensions.length + " 个需求维度...")

const VERIFY_PROMPT = (dim) =>
  "## 任务：验证需求维度「" + dim.name + "」\n\n" +
  "**PRD 章节**：" + dim.prd_section + "\n" +
  "**是否一票否决**：" + (dim.is_veto ? "是" : "否") + "\n\n" +
  "### 检查点列表\n" +
  dim.checkpoints.map((cp, i) =>
    (i + 1) + ". **" + cp.check_id + "**：" + cp.description + "\n" +
    "   验证方法：" + cp.verify_method + "\n" +
    (cp.expected_files ? "   预期文件：" + cp.expected_files.join(", ") + "\n" : "") +
    (cp.grep_pattern ? "   搜索模式：" + cp.grep_pattern + "\n" : "")
  ).join("") + "\n" +
  "### 验证方法\n" +
  "1. **code_exists**: 检查文件是否存在于 `" + LIB_DIR + "/` 或 `" + CONFIG_DIR + "/`\n" +
  "2. **function_grep**: 在代码文件中搜索函数/类定义（使用 Grep 工具）\n" +
  "3. **config_check**: 检查 JSON/YAML 配置文件内容\n" +
  "4. **test_exists**: 检查 `" + TESTS_DIR + "/` 下是否有对应测试\n" +
  "5. **manual_review**: 读取代码片段，人工判断是否符合需求\n\n" +
  "对每个检查点，输出：\n" +
  "- `check_id`: 检查点 ID\n" +
  "- `status`: pass / partial / fail / not_found\n" +
  "- `evidence`: 找到的证据（文件路径、函数名、配置项等）\n" +
  "- `details`: 详细说明（特别是 partial 和 fail 的原因）\n\n" +
  "最后给出该维度的整体评分（0-1）和摘要。\n\n" +
  "⚠️ **重要**：你必须使用 StructuredOutput 工具返回结果，不要直接输出文本。返回的 JSON 必须包含 `dimension_id`、`results`、`dimension_score` 和 `summary` 字段。"

const verifyResults = await parallel(
  extractResult.dimensions.map(dim => () =>
    agent(VERIFY_PROMPT(dim), {
      label: "verify:" + dim.id,
      phase: "Verify",
      schema: VERIFY_SCHEMA,
    }).then(r => {
      if (!r) return { dimension_id: dim.id, results: [], dimension_score: 0, summary: "验证失败" }
      // 强制设置 dimension_id 为提取维度的 id，确保后续匹配
      r.dimension_id = dim.id
      log(dim.name + ": " + (r.dimension_score * 100).toFixed(0) + "% (" +
        r.results.filter(x => x.status === "pass").length + " pass, " +
        r.results.filter(x => x.status === "fail").length + " fail)")
      return r
    })
  )
)

const validResults = verifyResults.filter(Boolean)
log("验证完成：" + validResults.length + "/" + extractResult.dimensions.length + " 维度已验证")

// 构建 id -> index 映射，用于 veto_status 和 critical_gaps 查找
const dimIdToIndex = {}
const dimById = {}
extractResult.dimensions.forEach((dim, idx) => {
  const canonicalId = canonicalDimensionId(dim.id)
  if (dimIdToIndex[canonicalId] === undefined) dimIdToIndex[canonicalId] = idx
  if (!dimById[canonicalId]) dimById[canonicalId] = dim
})

// 直接用索引匹配，处理 null 值
const complianceReport = {
  dimensions: extractResult.dimensions.map((dim, idx) => {
    const vr = verifyResults[idx]  // 直接用索引访问，可能是 null
    const score = vr ? vr.dimension_score : 0
    const counts = countResultStatuses(vr && vr.results)
    const issues = vr
      ? vr.results.filter(r => r.status === "fail" || r.status === "not_found").map(r => r.check_id + ": " + (r.details || r.status))
      : ["验证未完成"]
    return {
      id: dim.id,
      name: dim.name,
      is_veto: isVetoDimension(dim),
      score,
      pass_count: counts.pass,
      fail_count: counts.fail,
      partial_count: counts.partial,
      not_found_count: counts.not_found,
      issues,
    }
  }),
  veto_status: VETO_DIMENSIONS
    .map(vetoId => {
      const dim = dimById[vetoId]
      if (!dim) {
        return {
          dimension: vetoId,
          passed: false,
          reason: "固定一票否决维度未被提取，按失败处理",
        }
      }
      const idx = dimIdToIndex[vetoId]
      const vr = verifyResults[idx]
      const score = vr ? vr.dimension_score : 0
      const counts = countResultStatuses(vr && vr.results)
      const passed = score >= PASS_THRESHOLD
      return {
        dimension: dim.name,
        passed,
        reason: passed
          ? `${counts.pass}/${counts.total} 通过，score ${(score * 100).toFixed(0)}%`
          : `${counts.pass}/${counts.total} 通过，score ${(score * 100).toFixed(0)}%`,
      }
    }),
  critical_gaps: VETO_DIMENSIONS
    .filter(vetoId => {
      const dim = dimById[vetoId]
      if (!dim) return true
      const idx = dimIdToIndex[vetoId]
      const vr = verifyResults[idx]
      return !vr || vr.dimension_score < PASS_THRESHOLD
    })
    .map(vetoId => {
      const dim = dimById[vetoId]
      if (!dim) return `${vetoId}: 固定一票否决维度未被提取`
      const idx = dimIdToIndex[vetoId]
      const vr = verifyResults[idx]
      const score = vr ? vr.dimension_score : 0
      const counts = countResultStatuses(vr && vr.results)
      return `${dim.name} (${dim.prd_section}): score ${(score * 100).toFixed(0)}%, ${counts.fail + counts.not_found} 项失败/未找到`
    }),
}

// 计算总体覆盖率
const totalCheckpoints = complianceReport.dimensions.reduce((sum, d) => sum + d.pass_count + d.fail_count + d.partial_count + d.not_found_count, 0)
const totalPass = complianceReport.dimensions.reduce((sum, d) => sum + d.pass_count, 0)
complianceReport.coverage_rate = totalCheckpoints > 0 ? totalPass / totalCheckpoints : 0

// 判定整体结果
const hasVetoFail = complianceReport.veto_status.some(v => !v.passed)
complianceReport.overall_verdict = hasVetoFail || complianceReport.coverage_rate < PASS_THRESHOLD ? "FAIL" : "PASS"

log("=== 合规判定 ===")
log("整体判定：" + complianceReport.overall_verdict)
log("覆盖率：" + (complianceReport.coverage_rate * 100).toFixed(1) + "%")
log("一票否决：" + complianceReport.veto_status.map(v => v.dimension + "=" + (v.passed ? "PASS" : "FAIL")).join(", "))

if (complianceReport.critical_gaps && complianceReport.critical_gaps.length > 0) {
  log("关键缺失：")
  complianceReport.critical_gaps.forEach(g => log("  ✗ " + g))
}

// ─── Phase 2 gate: only proceed if Phase 1 PASS ───
if (complianceReport.overall_verdict !== "PASS") {
  log("⚠️ Phase 1 合规验证未通过，跳过 Phase 2（文档审计 + 清理扫描）。")
  log("请先修复上述关键缺失后重新运行。")
  return {
    phase1: complianceReport,
    phase2_skipped: true,
    reason: "合规验证未通过，需先修复关键缺失。",
  }
}

log("✅ Phase 1 合规验证通过，继续 Phase 2...")

// ─── Phase 4: Doc Audit ───
phase("Doc Audit")
log("检查 docs/ 目录下所有文档的一致性...")

const docAudit = await agent(
  "## 任务：文档一致性审计\n\n" +
  "检查 `" + DOCS_DIR + "/` 目录下所有 `.md` 文件（不含 archive/ 子目录），判断每份文档是否与当前代码和 PRD 保持一致。\n\n" +
  "### 检查规则\n" +
  "1. **代码路径引用**：文档中引用的代码文件路径是否仍存在\n" +
  "2. **API/命令有效性**：文档中描述的命令、接口是否与当前代码匹配\n" +
  "3. **版本/日期**：文档声明的版本是否过期（对比当前 sprint）\n" +
  "4. **PRD 一致性**：文档内容是否与 prd_by_kimi.md 矛盾\n" +
  "5. **冗余检查**：是否有内容高度重复的文档\n\n" +
  "### 归档条件\n" +
  "- 引用的核心路径 >50% 不存在 → archive\n" +
  "- 描述的功能已移除或重构 → archive\n" +
  "- 与 PRD 矛盾且未标注为 legacy → archive\n" +
  "- archive/ 中已有更新版本 → archive\n\n" +
  "### 需要检查的文件\n" +
  "先用 Glob 工具列出 `" + DOCS_DIR + "/**/*.md`（不含 archive/），然后逐个读取并检查。\n\n" +
  "### 输出\n" +
  "对每个文档输出：\n" +
  "- `file`: 文件路径\n" +
  "- `status`: current / outdated / contradicts_prd / redundant / orphaned\n" +
  "- `reason`: 判断原因\n" +
  "- `action`: keep / archive / update / merge\n" +
  "- `archive_reason`: 如需归档，说明归档原因\n\nStructured output only.",
  { label: "doc-audit", phase: "Doc Audit", schema: DOC_AUDIT_SCHEMA }
)

if (docAudit) {
  const toArchive = docAudit.docs.filter(d => d.action === "archive")
  const toKeep = docAudit.docs.filter(d => d.action === "keep")
  log("文档审计完成：" + docAudit.docs.length + " 份文档")
  log("  保持：" + toKeep.length + " 份")
  log("  建议归档：" + toArchive.length + " 份")
  toArchive.forEach(d => log("  📦 " + d.file + " — " + d.archive_reason))
} else {
  log("文档审计未返回结果")
}

// ─── Phase 5: Cleanup Scan ───
phase("Cleanup Scan")
log("扫描项目内容，列出移除建议...")

const cleanupScan = await agent(
  "## 任务：项目内容清理扫描\n\n" +
  "扫描 `" + PROJECT_ROOT + "` 项目中的潜在冗余或不需要保留的内容。\n\n" +
  "### 扫描维度\n" +
  "1. **重复文档**：docs/ 下内容高度相似的文件\n" +
  "2. **孤立配置**：config/ 下不再被代码引用的 JSON/YAML（用 Grep 检查引用计数）\n" +
  "3. **失效测试**：scripts/tests/ 下被测模块已不存在的测试脚本\n" +
  "4. **Legacy 别名**：config/debate/ 下已标注 deprecated 的旧配置\n" +
  "5. **临时文件**：.hermes/ 下的调试/临时产物\n" +
  "6. **Archive 冗余**：docs/archive/ 下内容完全被替代的旧文档\n\n" +
  "### 扫描方法\n" +
  "1. 用 Glob 列出各目录文件\n" +
  "2. 用 Grep 检查文件被引用次数\n" +
  "3. 读取文件内容判断是否过期\n\n" +
  "### 输出\n" +
  "对每个建议移除的项输出：\n" +
  "- `path`: 文件路径\n" +
  "- `category`: 类别（duplicate_doc / orphaned_config / dead_test / legacy_alias / temp_file / stale_archive）\n" +
  "- `reason`: 移除原因\n" +
  "- `risk`: 风险等级（low / medium / high）\n" +
  "- `dependencies`: 是否有其他文件依赖它\n\n" +
  "**重要**：只列出有明确移除理由的项，不要过于激进。历史架构决策文档（如 ADR）即使不再活跃也应保留。\n\nStructured output only.",
  { label: "cleanup-scan", phase: "Cleanup Scan", schema: CLEANUP_SCHEMA }
)

if (cleanupScan) {
  log("清理扫描完成：" + cleanupScan.items.length + " 项建议")
  const byRisk = { high: [], medium: [], low: [] }
  cleanupScan.items.forEach(item => byRisk[item.risk].push(item))
  if (byRisk.high.length > 0) {
    log("  🔴 高风险：" + byRisk.high.length + " 项（需谨慎评估）")
    byRisk.high.forEach(i => log("    " + i.path + " — " + i.reason))
  }
  if (byRisk.medium.length > 0) {
    log("  🟡 中风险：" + byRisk.medium.length + " 项")
    byRisk.medium.forEach(i => log("    " + i.path + " — " + i.reason))
  }
  if (byRisk.low.length > 0) {
    log("  🟢 低风险：" + byRisk.low.length + " 项")
    byRisk.low.forEach(i => log("    " + i.path + " — " + i.reason))
  }
} else {
  log("清理扫描未返回结果")
}

// ─── Phase 6: User Manual (based on verified audit results) ───
phase("User Manual")
log("基于审计结果生成 SOP 级用户手册...")

// Build context from audit results for accurate manual generation
const verifiedFeatures = complianceReport.dimensions
  .filter(d => d.score >= 0.8)
  .map(d => d.name)
const failedFeatures = complianceReport.dimensions
  .filter(d => d.score < 0.8)
  .map(d => d.name + " (score: " + (d.score * 100).toFixed(0) + "%)")
const archivedDocs = docAudit ? docAudit.docs.filter(d => d.action === "archive").map(d => d.file) : []
const removedItems = cleanupScan ? cleanupScan.items.map(i => i.path + " — " + i.reason) : []

const manualResult = await agent(
  "## 任务：生成 SOP 级用户使用手册\n\n" +
  "基于前面审计阶段的**实际验证结果**，为 Hermes Dev Orchestra 编写一份用户使用手册。\n\n" +
  "### 审计结果（你必须基于这些事实来写手册）\n\n" +
  "**合规状态**：" + complianceReport.overall_verdict + "\n" +
  "**覆盖率**：" + (complianceReport.coverage_rate * 100).toFixed(1) + "%\n" +
  "**已验证的功能维度**（≥80% 通过）：\n" +
  verifiedFeatures.map(f => "- " + f).join("\n") + "\n\n" +
  (failedFeatures.length > 0 ? "**未完全实现的功能维度**（<80%）：\n" + failedFeatures.map(f => "- " + f).join("\n") + "\n\n" : "") +
  "**已归档的文档**：\n" +
  (archivedDocs.length > 0 ? archivedDocs.map(d => "- " + d).join("\n") : "- 无") + "\n\n" +
  "**已识别的清理项**：\n" +
  (removedItems.length > 0 ? removedItems.map(i => "- " + i).join("\n") : "- 无") + "\n\n" +
  "### 手册要求\n\n" +
  "1. **视角**：从用户（开发者）使用的角度出发，不是从系统设计角度\n" +
  "2. **风格**：对话聊天式，像一个老手带新手走一遍流程\n" +
  "3. **粒度**：SOP step-by-step 级别，每一步都有具体命令和预期输出\n" +
  "4. **示例**：以「开发一个新功能」为完整示例贯穿全流程\n" +
  "5. **调试**：必须包含常见问题与调试指南，每个问题有诊断步骤和解决方案\n" +
  "6. **准确性**：只写已验证通过的功能，未实现的功能不要出现在手册中\n" +
  "7. **语言**：中文\n\n" +
  "### 手册结构（建议）\n\n" +
  "1. 开始之前：环境准备和安装验证\n" +
  "2. 初始化项目：orch-init 的完整交互流程\n" +
  "3. 提交开发任务：如何编写 task.md，任务注入流程\n" +
  "4. 观察执行：tmux 会话监控，如何查看 Codex 工作状态\n" +
  "5. 处理审批请求：L2/L3/L4 风险等级，approve/reject 操作\n" +
  "6. 查看执行结果：codex-result.md、review-result.md 的解读\n" +
  "7. 提交代码：git 操作和测试验证\n" +
  "8. 常见问题与调试：4 大类问题（安装、任务执行、审批、性能），每类有诊断步骤和解决方案表格\n" +
  "9. 命令速查表：所有 CLI 命令分类整理\n" +
  "10. 附录：完整示例文件、配置示例、流程图\n\n" +
  "### 输出\n\n" +
  "- `manual_title`: 手册标题\n" +
  "- `manual_content`: 完整的 Markdown 手册内容（这是核心输出，要完整、可直接使用）\n" +
  "- `sections`: 章节列表（title + description + content_preview）\n" +
  "- `based_on`: 手册基于的审计数据（verified_dimensions, total_dimensions, compliance_rate, key_features_covered）\n" +
  "- `output_path`: 建议的手册保存路径（`" + DOCS_DIR + "/USER-MANUAL.md`）\n\nStructured output only.",
  { label: "user-manual", phase: "User Manual", schema: MANUAL_SCHEMA }
)

if (manualResult) {
  log("用户手册生成完成：" + manualResult.manual_title)
  log("  章节数：" + manualResult.sections.length)
  log("  基于已验证需求：" + manualResult.based_on.verified_dimensions + "/" + manualResult.based_on.total_dimensions)
  log("  合规率：" + manualResult.based_on.compliance_rate)
  log("  输出路径：" + manualResult.output_path)
  log("  章节预览：")
  manualResult.sections.forEach(s => log("    📖 " + s.title + " — " + s.description))
} else {
  log("用户手册生成未返回结果")
}

// ─── Final Return ───
return {
  phase1: {
    verdict: complianceReport.overall_verdict,
    coverage: complianceReport.coverage_rate,
    veto_status: complianceReport.veto_status,
    dimensions: complianceReport.dimensions,
    critical_gaps: complianceReport.critical_gaps,
  },
  phase2: {
    doc_audit: docAudit || { docs: [], error: "未返回结果" },
    cleanup_scan: cleanupScan || { items: [], error: "未返回结果" },
  },
  phase3: {
    user_manual: manualResult || { error: "未返回结果" },
  },
  summary: {
    prd_compliant: complianceReport.overall_verdict === "PASS",
    coverage_rate: (complianceReport.coverage_rate * 100).toFixed(1) + "%",
    docs_to_archive: docAudit ? docAudit.docs.filter(d => d.action === "archive").length : 0,
    items_to_review: cleanupScan ? cleanupScan.items.length : 0,
    manual_generated: !!manualResult,
    manual_path: manualResult ? manualResult.output_path : null,
  },
}
