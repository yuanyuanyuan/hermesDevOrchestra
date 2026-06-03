export const meta = {
  name: 'prd-compliance-audit',
  description: '验证代码对 PRD 的合规性，检查文档一致性，列出清理建议。Phase 1 逐项比对 prd_by_kimi.md + user-flow-guide_by_kimi.md 与代码实现；Phase 2 检查文档一致性并归档过期文档，扫描项目列出移除建议。',
  whenToUse: '当用户需要验证当前代码是否完整实现 PRD 要求、检查文档是否过期、或清理项目冗余内容时使用。执行前确保代码已 commit。',
  phases: [
    { title: "Extract", detail: "从两份 PRD 提取所有可验证需求检查点" },
    { title: "Verify", detail: "并行验证每个需求维度的代码/配置/测试实现" },
    { title: "Compliance Report", detail: "生成合规矩阵，判定 PASS/FAIL" },
    { title: "Doc Audit", detail: "检查文档一致性，归档过期文档" },
    { title: "Cleanup Scan", detail: "扫描项目内容，列出移除建议" },
  ],
}

// ─── Constants ───
const PASS_THRESHOLD = 0.85
const VETO_DIMENSIONS = ["six_stage_state_machine", "evidence_gate", "security_compliance"]

// ─── Schemas ───
const EXTRACT_SCHEMA = {
  type: "object",
  required: ["dimensions"],
  properties: {
    dimensions: {
      type: "array",
      minItems: 10,
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
        required: ["id", "name", "is_veto", "score", "pass_count", "fail_count", "partial_count"],
        properties: {
          id: { type: "string" },
          name: { type: "string" },
          is_veto: { type: "boolean" },
          score: { type: "number" },
          pass_count: { type: "number" },
          fail_count: { type: "number" },
          partial_count: { type: "number" },
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

// ─── Phase 1: Extract requirements from both PRDs ───
phase("Extract")
log("从 prd_by_kimi.md 和 user-flow-guide_by_kimi.md 提取需求检查点...")

const extractResult = await agent(
  "## 任务：PRD 需求提取\n\n" +
  "你需要从两份产品文档中提取所有可验证的技术需求检查点。\n\n" +
  "### 输入文件\n" +
  "1. `/data/hermes/docs/prd_by_kimi.md` — 产品需求文档\n" +
  "2. `/data/hermes/docs/user-flow-guide_by_kimi.md` — 用户流程指南\n\n" +
  "### 提取规则\n" +
  "1. 读取两份文件，逐章节提取所有可验证的需求点\n" +
  "2. 每个需求维度需要包含：\n" +
  "   - `id`: 唯一标识（snake_case）\n" +
  "   - `name`: 维度名称\n" +
  "   - `prd_section`: 对应 PRD 章节号\n" +
  "   - `is_veto`: 是否为一票否决维度（安全合规、证据门控、状态机为核心维度）\n" +
  "   - `checkpoints`: 具体检查点列表\n" +
  "3. 每个检查点需要：\n" +
  "   - `check_id`: 唯一标识\n" +
  "   - `description`: 检查内容描述\n" +
  "   - `verify_method`: 验证方法（code_exists / function_grep / config_check / test_exists / manual_review）\n" +
  "   - `expected_files`: 预期的代码/配置文件路径（可选）\n" +
  "   - `grep_pattern`: 用于搜索的模式（可选）\n\n" +
  "### 需要覆盖的维度（至少）\n" +
  "- 六阶段 Run 状态机（§3.6, §4.0）→ orch_gateway.py\n" +
  "- 0阶 需求补全（§4.1）→ gateway_intake.py, project_discovery.py\n" +
  "- 一阶 方向辩论（§4.2）→ debate_ticket_generator.py, debate_assembly.py\n" +
  "- 二阶 方案辩论（§4.3）→ dag_validator.py, debate_engine.py\n" +
  "- 三阶 具体执行（§4.4）→ worker_session.py, heartbeat_handler.py\n" +
  "- 四阶 改进实现（§4.5）→ gateway_improvement.py\n" +
  "- 五阶 全局评估（§4.6）→ gateway_evaluation.py\n" +
  "- 六阶 持续改进（§4.7）→ self_evolution.py, gateway_closeout.py\n" +
  "- 16支辩论团队（§6.1）→ config/debate/full/teams.json\n" +
  "- 8种辩论模式（§6.3）→ config/debate/full/modes.json\n" +
  "- 通道分级（§7）→ channel_router.py, rollout_gate.py\n" +
  "- Gateway 证据门控（§8）→ evidence_gate.py, security_gate.py\n" +
  "- Worker 执行模型（§9）→ worker_registry.py\n" +
  "- Conflict Ledger（§3.5）→ 冲突数据结构\n" +
  "- Override 留痕（§4.1）→ correction_gate.py\n" +
  "- 成功指标采集（§11.1）→ success_metrics.py\n" +
  "- 自动合并安全（§7.3）→ auto_merge_controller.py\n\n" +
  "### 项目代码位置\n" +
  "- 运行时代码：`/data/hermes/scripts/lib/`\n" +
  "- 配置文件：`/data/hermes/config/`\n" +
  "- 测试脚本：`/data/hermes/scripts/tests/`\n" +
  "- CLI 工具：`/data/hermes/scripts/bin/`\n\n" +
  "请先读取两份 PRD 文件，然后读取 scripts/lib/ 目录列表确认文件名，最后输出结构化的需求维度列表。\n\nStructured output only.",
  { label: "extract", phase: "Extract", schema: EXTRACT_SCHEMA }
)

if (!extractResult) {
  return { error: "需求提取失败，无法继续。" }
}
log("提取完成：" + extractResult.dimensions.length + " 个需求维度")

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
  "1. **code_exists**: 检查文件是否存在于 `/data/hermes/scripts/lib/` 或 `/data/hermes/config/`\n" +
  "2. **function_grep**: 在代码文件中搜索函数/类定义（使用 Grep 工具）\n" +
  "3. **config_check**: 检查 JSON/YAML 配置文件内容\n" +
  "4. **test_exists**: 检查 `/data/hermes/scripts/tests/` 下是否有对应测试\n" +
  "5. **manual_review**: 读取代码片段，人工判断是否符合需求\n\n" +
  "对每个检查点，输出：\n" +
  "- `check_id`: 检查点 ID\n" +
  "- `status`: pass / partial / fail / not_found\n" +
  "- `evidence`: 找到的证据（文件路径、函数名、配置项等）\n" +
  "- `details`: 详细说明（特别是 partial 和 fail 的原因）\n\n" +
  "最后给出该维度的整体评分（0-1）和摘要。\n\nStructured output only."

const verifyResults = await parallel(
  extractResult.dimensions.map(dim => () =>
    agent(VERIFY_PROMPT(dim), {
      label: "verify:" + dim.id,
      phase: "Verify",
      schema: VERIFY_SCHEMA,
    }).then(r => {
      if (!r) return { dimension_id: dim.id, results: [], dimension_score: 0, summary: "验证失败" }
      log(dim.name + ": " + (r.dimension_score * 100).toFixed(0) + "% (" +
        r.results.filter(x => x.status === "pass").length + " pass, " +
        r.results.filter(x => x.status === "fail").length + " fail)")
      return r
    })
  )
)

const validResults = verifyResults.filter(Boolean)
log("验证完成：" + validResults.length + "/" + extractResult.dimensions.length + " 维度已验证")

// ─── Phase 3: Compliance Report ───
phase("Compliance Report")
log("生成合规矩阵...")

const reportInput = extractResult.dimensions.map(dim => {
  const vr = validResults.find(r => r.dimension_id === dim.id)
  return {
    id: dim.id,
    name: dim.name,
    is_veto: dim.is_veto,
    prd_section: dim.prd_section,
    checkpoint_count: dim.checkpoints.length,
    score: vr ? vr.dimension_score : 0,
    pass_count: vr ? vr.results.filter(r => r.status === "pass").length : 0,
    fail_count: vr ? vr.results.filter(r => r.status === "fail").length : 0,
    partial_count: vr ? vr.results.filter(r => r.status === "partial").length : 0,
    issues: vr ? vr.results.filter(r => r.status === "fail" || r.status === "not_found").map(r => r.check_id + ": " + (r.details || r.status)) : ["验证未完成"],
  }
})

const complianceReport = await agent(
  "## 任务：生成 PRD 合规矩阵\n\n" +
  "### 输入数据\n" +
  "以下是各维度的验证结果：\n\n" +
  JSON.stringify(reportInput, null, 2) + "\n\n" +
  "### 判定规则\n" +
  "1. **一票否决维度**（is_veto=true）：任一未通过则整体 FAIL\n" +
  "2. **整体覆盖率**：所有检查点中 pass 占比 ≥ " + (PASS_THRESHOLD * 100) + "% 为 PASS\n" +
  "3. **critical_gaps**：列出所有一票否决维度中 fail 的检查点\n\n" +
  "### 输出要求\n" +
  "- `overall_verdict`: PASS 或 FAIL\n" +
  "- `coverage_rate`: 总体覆盖率（0-1）\n" +
  "- `veto_status`: 每个一票否决维度的通过状态\n" +
  "- `dimensions`: 每个维度的详细评分\n" +
  "- `critical_gaps`: 关键缺失列表\n\nStructured output only.",
  { label: "compliance-report", phase: "Compliance Report", schema: COMPLIANCE_REPORT_SCHEMA }
)

if (!complianceReport) {
  return { error: "合规报告生成失败。" }
}

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
  "检查 `/data/hermes/docs/` 目录下所有 `.md` 文件（不含 archive/ 子目录），判断每份文档是否与当前代码和 PRD 保持一致。\n\n" +
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
  "先用 Glob 工具列出 `/data/hermes/docs/**/*.md`（不含 archive/），然后逐个读取并检查。\n\n" +
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
  "扫描 `/data/hermes` 项目中的潜在冗余或不需要保留的内容。\n\n" +
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
  summary: {
    prd_compliant: complianceReport.overall_verdict === "PASS",
    coverage_rate: (complianceReport.coverage_rate * 100).toFixed(1) + "%",
    docs_to_archive: docAudit ? docAudit.docs.filter(d => d.action === "archive").length : 0,
    items_to_review: cleanupScan ? cleanupScan.items.length : 0,
  },
}
