export const meta = {
  name: 'sprint-execution-pipeline-unified',
  description: 'Execute sprints with auto-discovery and resume support',
  phases: [
    { title: 'Discover', detail: '扫描目录发现 sprints' },
    { title: 'Execute', detail: '按拓扑顺序执行开发' },
    { title: 'Review', detail: '代码审查和 PR 合并' },
  ]
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
    const matches = [...text.matchAll(re)]
    for (const m of matches) {
      issues.push({ severity: sev, description: m[1].trim() })
    }
  }
  return { passed, score, issues, summary: text.substring(0, 200) + '...' }
}

// ── Sprint 发现与依赖解析 ──

/**
 * 从目录中发现所有 sprint 文件
 * 返回: { sprintNum: { planPath, checklistPath }, ... }
 */
async function discoverSprints(dir) {
  log(`🔍 扫描 sprint 目录: ${dir}`)

  const result = await agent(
    `List all files in the directory ${dir}.\n\n` +
    `Run: ls -1 ${dir}\n\n` +
    `Return the FULL file list, one file per line. Do not summarize or filter.`,
    { label: '扫描 sprint 目录' }
  )

  const files = (result || '').split('\n').map(f => f.trim()).filter(Boolean)
  const sprints = {}

  // 匹配 plan-sprint-N.md 和 checklist-sprint-N.md
  const planRe = /^plan-sprint-(\d+)\.md$/
  const checkRe = /^checklist-sprint-(\d+)\.md$/

  for (const f of files) {
    const planMatch = f.match(planRe)
    if (planMatch) {
      const num = parseInt(planMatch[1], 10)
      sprints[num] = sprints[num] || {}
      sprints[num].planPath = `${dir}/${f}`
    }
    const checkMatch = f.match(checkRe)
    if (checkMatch) {
      const num = parseInt(checkMatch[1], 10)
      sprints[num] = sprints[num] || {}
      sprints[num].checklistPath = `${dir}/${f}`
    }
  }

  const sprintNums = Object.keys(sprints).map(Number).sort((a, b) => a - b)
  log(`📋 发现 ${sprintNums.length} 个 Sprint: ${sprintNums.join(', ')}`)

  // 验证每个 sprint 都有 plan 和 checklist
  for (const num of sprintNums) {
    if (!sprints[num].planPath) throw new Error(`Sprint ${num} 缺少 plan 文件`)
    if (!sprints[num].checklistPath) throw new Error(`Sprint ${num} 缺少 checklist 文件`)
  }

  return sprints
}

/**
 * 从 sprint-overview.md 解析依赖关系
 * 表格格式: | Sprint | ... | Depends On |
 * Depends On 可以是: Sprint 1, Sprints 1, 2, Sprints 2, 3, 4 等
 * 返回: { sprintNum: [depNums], ... }
 */
async function parseDependencyGraph(dir, sprintNums) {
  log(`📊 解析依赖关系...`)

  const result = await agent(
    `Read the file ${dir}/sprint-overview.md and extract the sprint dependency table.\n\n` +
    `Find the table with columns including "Sprint" and "Depends On".\n` +
    `For each row, extract:\n` +
    `- The sprint number\n` +
    `- The "Depends On" column value\n\n` +
    `Return a JSON object mapping each sprint number to its dependency list.\n` +
    `Example: {"1": [], "2": [1], "3": [2], "9": [6, 8], "12": [1,2,3,4,5,6,7,8,9,10,11]}\n\n` +
    `Parse "Sprint N" as [N], "Sprints N, M" as [N, M], "Prior ..." as [].\n` +
    `Return ONLY the JSON object.`,
    { label: '解析依赖图' }
  )

  let depGraph = tryParseJSON(result)

  if (!depGraph || Object.keys(depGraph).length === 0) {
    log(`⚠️ 未能解析依赖表，使用无依赖模式（所有 sprint 独立执行）`)
    depGraph = {}
    for (const num of sprintNums) {
      depGraph[num] = []
    }
  }

  // 确保所有发现的 sprint 都在图中
  for (const num of sprintNums) {
    if (!(num in depGraph)) {
      depGraph[num] = []
    }
  }

  log(`📊 依赖图: ${Object.entries(depGraph).map(([k, v]) => `${k}←[${v}]`).join(', ')}`)
  return depGraph
}

/**
 * 拓扑排序 → 生成可并行的执行阶段
 * 返回: [{ phase: 'Sprint-1', sprints: [1] }, { phase: 'Sprint-2-3', sprints: [2, 3] }, ...]
 */
function buildExecutionPhases(sprintNums, depGraph) {
  const remaining = new Set(sprintNums)
  const completed = new Set()
  const phases = []

  while (remaining.size > 0) {
    // 找出所有依赖已满足的 sprint
    const ready = [...remaining].filter(num => {
      const deps = depGraph[num] || []
      return deps.every(d => completed.has(d))
    })

    if (ready.length === 0) {
      // 循环依赖 — 强制执行剩余的
      log(`⚠️ 检测到循环依赖，强制执行剩余: ${[...remaining].join(', ')}`)
      phases.push({ phase: `Sprint-${[...remaining].join('-')}`, sprints: [...remaining] })
      break
    }

    const phaseName = ready.length === 1
      ? `Sprint-${ready[0]}`
      : `Sprint-${ready.join('-')}`
    phases.push({ phase: phaseName, sprints: ready })

    ready.forEach(num => {
      completed.add(num)
      remaining.delete(num)
    })
  }

  return phases
}

// ── Skill 调用封装 ──

/**
 * 调用 /my-sprint-execute 执行 Sprint 开发
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

  const prMatch = (result || '').match(/PR\s*#(\d+)/i)
  return {
    prNumber: prMatch ? parseInt(prMatch[1], 10) : null,
    summary: result || ''
  }
}

/**
 * 调用 /my-pr-review-response 处理 PR review 反馈
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
      {
        agentType: 'compound-engineering:ce-correctness-reviewer',
        label: `Reviewer Sprint ${sprintNum} #${prNumber} (${attempt}/${REVIEWER_CONFIG.maxAttempts})`,
        phase: `Sprint-${sprintNum}`
      }
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
          {
            agentType: 'bugfix',
            label: `修复: ${issue.description.substring(0, 40)}`,
            phase: `Sprint-${sprintNum}`
          }
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
function checkDependencies(sprintNum, completedSprints, depGraph) {
  const deps = depGraph[sprintNum] || []
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

    if (prNumber) {
      log(`ℹ️ Sprint ${sprintNum} 已有 PR #${prNumber}，跳过开发`)
    } else {
      // 步骤 1：调用 /my-sprint-execute 执行开发
      log(`📝 步骤 1/3：调用 /my-sprint-execute 执行开发任务...`)
      const devResult = await callSprintExecute(sprintNum, planPath, checklistPath)
      prNumber = devResult.prNumber

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
  const rawArgs = args || {}
  const safeArgs = typeof rawArgs === 'string' ? tryParseJSON(rawArgs) || {} : rawArgs
  const sprintsDir = safeArgs.sprintsDir

  // sprintsDir 是必须的
  if (!sprintsDir) {
    throw new Error(
      '缺少必需参数 sprintsDir。用法: Workflow({ name: "sprint-execution-pipeline-unified", args: { sprintsDir: "/path/to/sprints/dir" } })'
    )
  }

  log('🚀 启动 Sprint 执行流水线...')
  log(`📂 Sprint 目录: ${sprintsDir}`)

  // 步骤 1：发现 sprint 文件
  const sprintFiles = await discoverSprints(sprintsDir)
  const sprintNums = Object.keys(sprintFiles).map(Number).sort((a, b) => a - b)

  if (sprintNums.length === 0) {
    throw new Error(`在 ${sprintsDir} 中未找到任何 sprint 文件（需要 plan-sprint-N.md + checklist-sprint-N.md）`)
  }

  // 步骤 2：解析依赖图
  const depGraph = await parseDependencyGraph(sprintsDir, sprintNums)

  // 步骤 3：拓扑排序生成执行阶段
  const executionPhases = buildExecutionPhases(sprintNums, depGraph)
  log(`\n📋 执行计划（${executionPhases.length} 个阶段）:`)
  for (const p of executionPhases) {
    log(`   ${p.phase}: Sprints [${p.sprints.join(', ')}]`)
  }

  log(`\n📋 配置:`)
  log(`   仓库: ${REPO}`)
  log(`   独立审查: ${REVIEWER_CONFIG.enabled ? '启用' : '禁用'}`)
  log(`\n📌 Skill 调用链:`)
  log(`   开发: /my-sprint-execute → Git 分支 + 代码 + 测试 + PR`)
  log(`   PR:   /my-pr-skill → PR 管理 (manage-pr.sh)`)
  log(`   Review: /my-pr-review-response → 读评论 + 修复 + 回复`)

  const completedSprints = []
  const failedSprints = []

  for (const config of executionPhases) {
    log(`\n${'='.repeat(60)}`)
    log(`📋 Phase: ${config.phase}`)
    log(`${'='.repeat(60)}`)

    const canExecute = config.sprints.every(s => {
      if (!checkDependencies(s, completedSprints, depGraph)) {
        log(`⚠️ Sprint ${s} 依赖未满足，跳过`)
        return false
      }
      return true
    })
    if (!canExecute) {
      log(`❌ Phase ${config.phase} 依赖未满足，跳过`)
      continue
    }

    if (config.sprints.length > 1) {
      log(`⚡ 并行执行 Sprints: ${config.sprints.join(', ')}`)
      const results = await parallel(
        config.sprints.map(s => () => executeSprint(s, sprintFiles[s].planPath, sprintFiles[s].checklistPath))
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
      const result = await executeSprint(s, sprintFiles[s].planPath, sprintFiles[s].checklistPath)
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
