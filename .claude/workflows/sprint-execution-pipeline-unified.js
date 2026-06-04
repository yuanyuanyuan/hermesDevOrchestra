export const meta = {
  name: 'sprint-execution-pipeline-unified',
  description: 'Execute 13 sprints with configurable independent reviewer',
  phases: [
    { title: 'Sprint-1', model: 'sonnet' },
    { title: 'Sprint-2', model: 'sonnet' },
    { title: 'Sprint-3-4-7-8-10', model: 'sonnet' },
    { title: 'Sprint-5-6-11', model: 'sonnet' },
    { title: 'Sprint-9', model: 'sonnet' },
    { title: 'Sprint-12', model: 'sonnet' },
    { title: 'Sprint-13', model: 'sonnet' }
  ]
}

// ── Sprint 依赖关系图 ──
const DEPENDENCY_GRAPH = {
  1: [],
  2: [1],
  3: [2],
  4: [2],
  5: [4],
  6: [4],
  7: [2],
  8: [2],
  9: [6, 8],
  10: [2],
  11: [10],
  12: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  13: [12]
}

// ── 配置 ──
const REPO = 'yuanyuanyuan/hermesDevOrchestra'
const POLL_INTERVAL_SECONDS = 60
const MAX_POLL_MINUTES = 240
const REVIEWER_CONFIG = {
  enabled: true,
  maxAttempts: 3,
  reviewCriteria: [
    '代码质量和可维护性',
    '架构设计合理性',
    '测试覆盖率充分性',
    '安全性考虑',
    '性能影响评估',
    '文档完整性',
    '错误处理健壮性',
    '向后兼容性'
  ],
  passThreshold: 0.8,
  softPassThreshold: 0.70,
  autoFixEnabled: true
}

// ── 辅助函数 ──

function tryParseJSON(text) {
  try {
    const match = (text || '').match(/\{[\s\S]*\}/)
    if (match) return JSON.parse(match[0])
  } catch (_) {}
  return null
}

function extractNumber(text) {
  const match = (text || '').match(/\d+/)
  return match ? parseInt(match[0], 10) : null
}

function hasCriticalIssues(issues) {
  return issues && issues.some(i => i.severity === 'critical')
}

function parseReviewerTextResponse(text) {
  const passed = /passed|通过/i.test(text)
  const scoreMatch = text.match(/(\d+(?:\.\d+)?)\s*\/\s*1\.0/)
  const score = scoreMatch ? parseFloat(scoreMatch[1]) : (passed ? 0.9 : 0.5)
  const issues = []
  const patterns = [
    [/严重|critical/gi, 'critical'],
    [/重要|major/gi, 'major'],
    [/次要|minor/gi, 'minor']
  ]
  for (const [pat, sev] of patterns) {
    const re = new RegExp(`(?:${pat.source})[:\\s]+(.+)`, 'gi')
    let m
    while ((m = re.exec(text)) !== null) {
      issues.push({ severity: sev, description: m[1].trim() })
    }
  }
  return { passed, score, issues, summary: text.substring(0, 200) + '...' }
}

// ── Skill 调用封装 ──

/**
 * 调用 /my-sprint-execute 执行 Sprint 开发
 * Skill 接口: my-sprint-execute <PLAN_PATH> <CHECKLIST_PATH> <SPRINT>
 */
async function callSprintExecute(sprintNum, planPath, checklistPath) {
  log(`📝 调用 /my-sprint-execute 执行 Sprint ${sprintNum} 开发...`)

  const result = await agent(
    `Execute Sprint ${sprintNum} development using the /my-sprint-execute skill.\n\n` +
    `Call: /my-sprint-execute ${planPath} ${checklistPath} ${sprintNum}\n\n` +
    `The skill will handle:\n` +
    `- Git branch workflow (feat/sprint${sprintNum})\n` +
    `- Sequential task execution from the plan\n` +
    `- Verification against checklist\n` +
    `- PR creation via my-pr-skill's manage-pr.sh\n\n` +
    `After completion, report:\n` +
    `1. What was done (summary)\n` +
    `2. The PR number (format: "PR #NNN")\n` +
    `3. Any blockers encountered`,
    { label: `Sprint ${sprintNum} 开发`, phase: `Sprint-${sprintNum}` }
  )

  // 提取 PR 号
  const prMatch = (result || '').match(/PR\s*#(\d+)/i)
  return {
    prNumber: prMatch ? parseInt(prMatch[1], 10) : null,
    summary: result || ''
  }
}

/**
 * 调用 /my-pr-skill 查询 PR 状态
 * 使用 manage-pr.sh 的查询功能
 */
async function callPRStatus(prNumber) {
  const result = await agent(
    `Use the /my-pr-skill to check the status of PR #${prNumber} in repo ${REPO}.\n\n` +
    `Run: gh pr view ${prNumber} --repo ${REPO} --json state,mergedAt,reviewDecision,reviews\n\n` +
    `Return a JSON object with these fields:\n` +
    `{"merged": true/false, "state": "OPEN/CLOSED/MERGED", "reviewDecision": "APPROVED/CHANGES_REQUESTED/REVIEW_REQUIRED/none", "reviewCount": N, "hasChangeRequests": true/false}\n\n` +
    `Where hasChangeRequests = true if reviewDecision is CHANGES_REQUESTED OR any review has state CHANGES_REQUESTED.`,
    { label: `PR #${prNumber} 状态`, phase: 'Sprint-1' }
  )

  const parsed = tryParseJSON(result)
  if (parsed) return parsed

  // 降级解析
  const text = (result || '').toUpperCase()
  return {
    merged: text.includes('MERGED'),
    state: 'OPEN',
    reviewDecision: text.includes('CHANGES_REQUESTED') ? 'CHANGES_REQUESTED' : 'none',
    reviewCount: 0,
    hasChangeRequests: text.includes('CHANGES_REQUESTED')
  }
}

/**
 * 调用 /my-pr-review-response 处理 PR review 反馈
 * Skill 接口: /my-pr-review-response (交互式，读取当前 PR 上下文)
 */
async function callPRReviewResponse(prNumber, sprintNum) {
  log(`🔄 调用 /my-pr-review-response 处理 PR #${prNumber} review 反馈...`)

  const result = await agent(
    `PR #${prNumber} in repo ${REPO} has review feedback that needs to be addressed.\n\n` +
    `Please use the /my-pr-review-response skill to:\n` +
    `1. Read the PR review comments\n` +
    `2. Understand what changes are requested\n` +
    `3. Make the necessary code fixes\n` +
    `4. Push the fixes to the PR branch\n` +
    `5. Reply to each review comment explaining what was fixed\n\n` +
    `After completion, report whether all review feedback was successfully addressed.`,
    { label: `处理 PR #${prNumber} review (Sprint ${sprintNum})`, phase: `Sprint-${sprintNum}` }
  )

  return result || ''
}

/**
 * 独立 Reviewer 审查（workflow 自带的质量门禁）
 */
async function executeReviewerReview(sprintNum, prNumber) {
  if (!REVIEWER_CONFIG.enabled) {
    log(`⏭️ 独立审查未启用，跳过`)
    return { passed: true, status: 'disabled' }
  }

  log(`🔍 开始独立 Reviewer 审查（Sprint ${sprintNum} PR #${prNumber}）...`)

  const criteriaList = REVIEWER_CONFIG.reviewCriteria.map((c, i) => `${i + 1}. ${c}`).join('\n')

  for (let attempt = 1; attempt <= REVIEWER_CONFIG.maxAttempts; attempt++) {
    log(`📝 Reviewer 审查尝试 ${attempt}/${REVIEWER_CONFIG.maxAttempts}...`)

    const reviewResponse = await agent(
      `请对 Sprint ${sprintNum} 的 PR #${prNumber}（仓库 ${REPO}）代码进行独立审查。\n\n` +
      `审查标准：\n${criteriaList}\n\n` +
      `请查看 PR 的代码变更，评估是否满足所有标准。\n\n` +
      `请严格返回以下 JSON 格式（不要添加其他文字）：\n` +
      `{"passed": true/false, "score": 0.0-1.0, "issues": [{"severity": "critical/major/minor", "category": "类别", "description": "描述", "suggestion": "建议"}], "summary": "总体评价"}`,
      { label: `Reviewer Sprint ${sprintNum} #${prNumber} (${attempt}/${REVIEWER_CONFIG.maxAttempts})`, phase: `Sprint-${sprintNum}` }
    )

    const reviewResult = tryParseJSON(reviewResponse) || parseReviewerTextResponse(reviewResponse)
    const hasCriticals = hasCriticalIssues(reviewResult.issues)
    const scoreOk = reviewResult.passed && reviewResult.score >= REVIEWER_CONFIG.passThreshold
    const softOk = reviewResult.score >= REVIEWER_CONFIG.softPassThreshold && !hasCriticals

    if (scoreOk) {
      log(`✅ Reviewer 审查通过（得分: ${reviewResult.score}）`)
      return { passed: true, result: reviewResult, attempt, status: 'passed' }
    }
    if (softOk) {
      log(`⚠️ Reviewer 得分 ${reviewResult.score} 略低于阈值，但无严重问题，勉强通过`)
      return { passed: true, result: reviewResult, attempt, status: 'soft_passed' }
    }

    log(`⚠️ Reviewer 审查未通过（得分: ${reviewResult.score}，有严重问题: ${hasCriticals}）`)

    if (REVIEWER_CONFIG.autoFixEnabled && hasCriticals) {
      log(`🔧 尝试自动修复严重问题...`)
      for (const issue of reviewResult.issues.filter(i => i.severity === 'critical')) {
        await agent(
          `请修复以下代码问题：\n问题描述：${issue.description}\nSprint：${sprintNum}\n仓库：${REPO}\n请分析原因、实施修复、验证修复。`,
          { label: `修复: ${issue.description.substring(0, 40)}`, phase: `Sprint-${sprintNum}` }
        )
      }
      log(`✅ 自动修复完成，下一轮重新审查`)
    } else {
      return { passed: false, result: reviewResult, attempt, status: 'review_failed' }
    }
  }

  return { passed: false, status: 'max_attempts_exceeded' }
}

/**
 * 等待 PR 合并 — 单个 agent 内部轮询
 * 检测到 review 反馈时自动调用 /my-pr-review-response
 */
async function waitForPRMerge(prNumber, sprintNum) {
  log(`⏳ 开始等待 PR #${prNumber} 合并（Sprint ${sprintNum}）...`)

  const result = await agent(
    `You are monitoring PR #${prNumber} in repo ${REPO} for merge.\n\n` +
    `Do the following in a loop:\n\n` +
    `1. Run: gh pr view ${prNumber} --repo ${REPO} --json state,mergedAt,reviewDecision,reviews\n` +
    `2. If mergedAt is not null → return "MERGED"\n` +
    `3. If reviewDecision is "CHANGES_REQUESTED" or reviews contain comments that need addressing →\n` +
    `   a. Use the /my-pr-review-response skill to handle the review feedback\n` +
    `   b. The skill will read comments, make fixes, push, and reply to reviewers\n` +
    `   c. Wait 30 seconds after the skill completes, then re-check PR status\n` +
    `4. If still open with no issues → wait ${POLL_INTERVAL_SECONDS} seconds, then re-check\n` +
    `5. After ${MAX_POLL_MINUTES} minutes total → return "TIMEOUT"\n\n` +
    `IMPORTANT: When handling review feedback, you MUST use the /my-pr-review-response skill. ` +
    `Do NOT try to handle review comments manually.\n\n` +
    `Return ONLY one of: "MERGED", "TIMEOUT", or "REVIEW_FAILED: <reason>"`,
    { label: `等待 PR #${prNumber} 合并 (Sprint ${sprintNum})`, phase: `Sprint-${sprintNum}` }
  )

  const text = (result || '').toUpperCase()
  if (text.includes('MERGED')) return { status: 'merged', prNumber }
  if (text.includes('TIMEOUT')) return { status: 'timeout', prNumber }
  return { status: 'review_failed', prNumber, error: result }
}

/** 查找 Sprint 对应的已有 PR（open） */
async function findExistingPR(sprintNum) {
  const result = await agent(
    `Find any open PR in repo ${REPO} that belongs to Sprint ${sprintNum}.\n\n` +
    `Run: gh pr list --repo ${REPO} --state open --json number,title,headRefName\n\n` +
    `Look for a PR whose title or branch name contains "sprint" and "${sprintNum}" (case insensitive).\n` +
    `If found, return ONLY the PR number. If not found, return "NONE".`,
    { label: `查找 Sprint ${sprintNum} PR`, phase: `Sprint-${sprintNum}` }
  )
  if (!result || /none/i.test(result)) return null
  return extractNumber(result)
}

/** 查找 Sprint 对应的已合并 PR（用于恢复/跳过已完成 Sprint） */
async function findMergedPR(sprintNum) {
  const result = await agent(
    `Find any merged PR in repo ${REPO} that belongs to Sprint ${sprintNum}.\n\n` +
    `Run: gh pr list --repo ${REPO} --state merged --json number,title,headRefName,mergedAt --limit 30\n\n` +
    `Look for a PR whose title or branch name contains "sprint" and "${sprintNum}" (case insensitive).\n` +
    `If found, return a JSON object: {"prNumber": N, "mergedAt": "ISO date"}\n` +
    `If not found, return "NONE".`,
    { label: `检查 Sprint ${sprintNum} 已合并 PR`, phase: `Sprint-${sprintNum}` }
  )
  if (!result || /none/i.test(result)) return null
  const parsed = tryParseJSON(result)
  if (parsed && parsed.prNumber) return parsed
  const num = extractNumber(result)
  return num ? { prNumber: num, mergedAt: null } : null
}

/** 检查依赖是否满足 */
function checkDependencies(sprintNum, completedSprints) {
  const deps = DEPENDENCY_GRAPH[sprintNum] || []
  return deps.every(d => completedSprints.includes(d))
}

/** 执行单个 Sprint 完整流程 */
async function executeSprint(sprintNum, planPath, checklistPath) {
  log(`🚀 开始执行 Sprint ${sprintNum}...`)

  try {
    // 步骤 0a：检查是否已合并（恢复模式 — 跳过已完成 Sprint）
    const mergedPR = await findMergedPR(sprintNum)
    if (mergedPR) {
      log(`⏭️ Sprint ${sprintNum} 已完成（PR #${mergedPR.prNumber} 已合并${mergedPR.mergedAt ? ' @ ' + mergedPR.mergedAt : ''}），跳过`)
      return { sprintNum, prNumber: mergedPR.prNumber, status: 'merged', skipped: true }
    }

    // 步骤 0b：检查已有 open PR
    let prNumber = await findExistingPR(sprintNum)
    let devSummary = ''

    if (prNumber) {
      log(`ℹ️ Sprint ${sprintNum} 已有 PR #${prNumber}，跳过开发`)
    } else {
      // 步骤 1：调用 /my-sprint-execute 执行开发
      log(`📝 步骤 1/3：调用 /my-sprint-execute 执行开发任务...`)
      const devResult = await callSprintExecute(sprintNum, planPath, checklistPath)
      prNumber = devResult.prNumber
      devSummary = devResult.summary

      // 降级：如果 skill 没返回 PR 号，查 GitHub
      if (!prNumber) {
        log(`⚠️ 开发结果中未找到 PR 号，查询 GitHub...`)
        const fallback = await agent(
          `Run: gh pr list --repo ${REPO} --state open --json number,createdAt --jq 'sort_by(.createdAt) | reverse | .[0].number'\nReturn ONLY the number.`,
          { label: `查询最近 PR`, phase: `Sprint-${sprintNum}` }
        )
        prNumber = extractNumber(fallback)
      }

      if (!prNumber) throw new Error(`未找到 Sprint ${sprintNum} 的 PR`)
    }
    log(`✅ PR #${prNumber} 已确认`)

    // 步骤 2：独立 Reviewer 审查（workflow 质量门禁）
    log(`🔍 步骤 2/3：执行独立 Reviewer 审查...`)
    const reviewerResult = await executeReviewerReview(sprintNum, prNumber)
    if (!reviewerResult.passed) {
      log(`❌ Reviewer 审查未通过: ${reviewerResult.status}`)
      return { sprintNum, prNumber, status: 'reviewer_failed', reviewerResult }
    }

    // 步骤 3：等待 PR 合并（含 /my-pr-review-response 自动处理 review）
    log(`⏳ 步骤 3/3：等待 PR 合并...`)
    const mergeResult = await waitForPRMerge(prNumber, sprintNum)

    return { sprintNum, prNumber, ...mergeResult }
  } catch (error) {
    log(`❌ Sprint ${sprintNum} 执行失败: ${error.message || error}`)
    return { sprintNum, status: 'failed', error: String(error) }
  }
}

// ── 主逻辑 ──
async function main() {
  const safeArgs = args || {}
  const planPath = safeArgs.planPath || '/home/stark/.claude/plans/plan-sprint-*.md'
  const checklistPath = safeArgs.checklistPath || '/data/hermes/docs/execution-checklist.md'

  log('🚀 启动统一版 Sprint 执行流水线...')
  log(`📋 配置：`)
  log(`   仓库: ${REPO}`)
  log(`   独立审查: ${REVIEWER_CONFIG.enabled ? '启用' : '禁用'}`)
  log(`   Plan: ${planPath}`)
  log(`   Checklist: ${checklistPath}`)

  log(`\n📌 Skill 调用链:`)
  log(`   开发: /my-sprint-execute → Git 分支 + 代码 + 测试 + PR`)
  log(`   PR:   /my-pr-skill → PR 管理 (manage-pr.sh)`)
  log(`   Review: /my-pr-review-response → 读评论 + 修复 + 回复`)

  const completedSprints = []
  const failedSprints = []

  const sprintConfig = [
    { phase: 'Sprint-1', sprints: [1] },
    { phase: 'Sprint-2', sprints: [2] },
    { phase: 'Sprint-3-4-7-8-10', sprints: [3, 4, 7, 8, 10] },
    { phase: 'Sprint-5-6-11', sprints: [5, 6, 11] },
    { phase: 'Sprint-9', sprints: [9] },
    { phase: 'Sprint-12', sprints: [12] },
    { phase: 'Sprint-13', sprints: [13] }
  ]

  for (const config of sprintConfig) {
    log(`\n${'='.repeat(60)}`)
    log(`📋 Phase: ${config.phase}`)
    log(`${'='.repeat(60)}`)

    const canExecute = config.sprints.every(s => {
      if (!checkDependencies(s, completedSprints)) {
        log(`⚠️ Sprint ${s} 依赖未满足，跳过`)
        return false
      }
      return true
    })
    if (!canExecute) {
      log(`❌ Phase ${config.phase} 依赖未满足，跳过`)
      continue
    }

    // 为每个 Sprint 解析 plan 路径
    const resolvePlan = (s) => planPath.replace('*', s)

    if (config.sprints.length > 1) {
      log(`⚡ 并行执行 Sprints: ${config.sprints.join(', ')}`)
      const results = await parallel(
        config.sprints.map(s => () => executeSprint(s, resolvePlan(s), checklistPath))
      )
      results.forEach((result, idx) => {
        const s = config.sprints[idx]
        if (result && result.status === 'merged') {
          completedSprints.push(s)
          log(result.skipped ? `⏭️ Sprint ${s} 已完成（跳过）` : `✅ Sprint ${s} 完成`)
        } else {
          failedSprints.push(s)
          log(`❌ Sprint ${s} 失败: ${result ? result.status : 'unknown'}`)
        }
      })
    } else {
      const s = config.sprints[0]
      const result = await executeSprint(s, resolvePlan(s), checklistPath)
      if (result.status === 'merged') {
        completedSprints.push(s)
        log(result.skipped ? `⏭️ Sprint ${s} 已完成（跳过）` : `✅ Sprint ${s} 完成`)
      } else {
        failedSprints.push(s)
        log(`❌ Sprint ${s} 失败: ${result.status}`)
      }
    }

    if (failedSprints.length > 0) {
      log(`⚠️ 有失败的 Sprint，停止后续 Phase`)
      break
    }
  }

  log(`\n${'='.repeat(60)}`)
  log(`📊 执行总结`)
  log(`${'='.repeat(60)}`)
  log(`✅ 完成: ${completedSprints.length} — ${completedSprints.join(', ') || '无'}`)
  log(`❌ 失败: ${failedSprints.length} — ${failedSprints.join(', ') || '无'}`)

  return {
    status: failedSprints.length > 0 ? 'partial' : 'completed',
    completedSprints,
    failedSprints
  }
}

return await main()
