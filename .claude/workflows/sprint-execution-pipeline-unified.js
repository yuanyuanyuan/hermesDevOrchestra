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

// Sprint 依赖关系图
const DEPENDENCY_GRAPH = {
  1: [],           // 无依赖
  2: [1],          // 依赖 Sprint 1
  3: [2],          // 依赖 Sprint 2
  4: [2],          // 依赖 Sprint 2
  5: [4],          // 依赖 Sprint 4
  6: [4],          // 依赖 Sprint 4
  7: [2],          // 依赖 Sprint 2
  8: [2],          // 依赖 Sprint 2
  9: [6, 8],       // 依赖 Sprint 6 和 8
  10: [2],         // 依赖 Sprint 2
  11: [10],        // 依赖 Sprint 10
  12: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],  // 依赖所有前面的 sprint
  13: [12]         // 依赖 Sprint 12
}

// 轮询配置
const POLL_INTERVAL_SECONDS = 60  // 1分钟
const MAX_POLL_COUNT = 240        // 最多轮询 240 次 ≈ 4 小时
const REVIEW_MAX_ROUNDS = 5       // 最多处理 5 轮 review

// 独立 Reviewer 配置
const REVIEWER_CONFIG = {
  enabled: true,                     // 是否启用独立审查（默认启用）
  maxAttempts: 3,                    // 最多尝试 3 次 reviewer 审查
  reviewCriteria: [                  // 审查标准
    '代码质量和可维护性',
    '架构设计合理性',
    '测试覆盖率充分性',
    '安全性考虑',
    '性能影响评估',
    '文档完整性',
    '错误处理健壮性',
    '向后兼容性'
  ],
  passThreshold: 0.8,               // 通过阈值：80% 的标准满足
  autoFixEnabled: true              // 是否启用自动修复
}

// 状态文件路径
const STATE_FILE = '/tmp/sprint-pipeline-state.json'

// 辅助函数：检查 PR 是否已合并
async function checkPRMerged(repo, prNumber) {
  try {
    const result = await bash(`gh pr view ${prNumber} --repo ${repo} --json state,mergedAt`, {
      label: `检查 PR #${prNumber} 状态`
    })
    const prData = JSON.parse(result)
    return {
      merged: prData.mergedAt !== null,
      state: prData.state,
      mergedAt: prData.mergedAt
    }
  } catch (error) {
    log(`检查 PR #${prNumber} 状态失败: ${error.message}`)
    return { merged: false, state: 'unknown', error: error.message }
  }
}

// 辅助函数：执行独立 Reviewer 审查（可选）
async function executeReviewerReview(sprintNum, prNumber) {
  // 如果未启用独立审查，直接返回通过
  if (!REVIEWER_CONFIG.enabled) {
    log(`⏭️ 独立审查未启用，跳过 Reviewer 审查`)
    return { passed: true, status: 'disabled' }
  }

  log(`🔍 开始独立 Reviewer 审查（Sprint ${sprintNum}）...`)

  let attempt = 0
  let reviewPassed = false
  let reviewResult = null

  while (attempt < REVIEWER_CONFIG.maxAttempts && !reviewPassed) {
    attempt++
    log(`📝 Reviewer 审查尝试 ${attempt}/${REVIEWER_CONFIG.maxAttempts}...`)

    try {
      // 调用独立的 reviewer agent
      const reviewerPrompt = `
请对 Sprint ${sprintNum} 的代码进行独立审查。

审查标准：
${REVIEWER_CONFIG.reviewCriteria.map((c, i) => `${i + 1}. ${c}`).join('\n')}

请评估：
1. 代码是否满足所有审查标准
2. 是否有严重问题需要修复
3. 改进建议

输出格式：
{
  "passed": true/false,
  "score": 0.0-1.0,
  "issues": [
    {
      "severity": "critical/major/minor",
      "category": "审查标准类别",
      "description": "问题描述",
      "suggestion": "修复建议"
    }
  ],
  "summary": "总体评价"
}
`

      // 调用 reviewer agent
      const reviewResponse = await agent(reviewerPrompt, {
        label: `Reviewer 审查 Sprint ${sprintNum}（尝试 ${attempt}）`,
        phase: `Sprint-${sprintNum}`
      })

      // 解析 reviewer 的响应
      try {
        reviewResult = JSON.parse(reviewResponse)
      } catch (parseError) {
        // 如果 reviewer 返回的不是 JSON，尝试从文本中提取信息
        log(`⚠️ Reviewer 返回格式非 JSON，尝试解析...`)
        reviewResult = parseReviewerTextResponse(reviewResponse)
      }

      // 检查是否通过
      if (reviewResult.passed && reviewResult.score >= REVIEWER_CONFIG.passThreshold) {
        reviewPassed = true
        log(`✅ Reviewer 审查通过（得分: ${reviewResult.score}）`)
      } else {
        log(`⚠️ Reviewer 审查未通过（得分: ${reviewResult.score}）`)

        // 如果有严重问题，尝试自动修复
        if (REVIEWER_CONFIG.autoFixEnabled && hasCriticalIssues(reviewResult.issues)) {
          log(`🔧 尝试自动修复严重问题...`)
          const fixed = await autoFixReviewerIssues(reviewResult.issues, sprintNum)

          if (fixed) {
            log(`✅ 自动修复完成，重新审查...`)
            // 继续下一次循环，重新审查
          } else {
            log(`❌ 自动修复失败`)
            return {
              passed: false,
              result: reviewResult,
              attempt,
              status: 'auto_fix_failed'
            }
          }
        } else {
          // 没有严重问题或未启用自动修复，直接返回
          return {
            passed: false,
            result: reviewResult,
            attempt,
            status: 'review_failed'
          }
        }
      }
    } catch (error) {
      log(`❌ Reviewer 审查失败: ${error.message}`)
      return {
        passed: false,
        error: error.message,
        attempt,
        status: 'reviewer_error'
      }
    }
  }

  if (!reviewPassed) {
    log(`❌ Reviewer 审查在 ${REVIEWER_CONFIG.maxAttempts} 次尝试后仍失败`)
    return {
      passed: false,
      result: reviewResult,
      attempt,
      status: 'max_attempts_exceeded'
    }
  }

  return {
    passed: true,
    result: reviewResult,
    attempt,
    status: 'passed'
  }
}

// 辅助函数：解析 reviewer 文本响应
function parseReviewerTextResponse(text) {
  // 尝试从文本中提取关键信息
  const passed = text.toLowerCase().includes('passed') || text.toLowerCase().includes('通过')
  const scoreMatch = text.match(/(\d+(\.\d+)?)\s*\/\s*1\.0/)
  const score = scoreMatch ? parseFloat(scoreMatch[1]) : (passed ? 0.9 : 0.5)

  // 提取问题列表
  const issues = []
  const issuePatterns = [
    /(?:严重|critical)[:\s]+(.+)/gi,
    /(?:重要|major)[:\s]+(.+)/gi,
    /(?:次要|minor)[:\s]+(.+)/gi
  ]

  issuePatterns.forEach(pattern => {
    let match
    while ((match = pattern.exec(text)) !== null) {
      issues.push({
        severity: pattern.source.includes('严重') || pattern.source.includes('critical') ? 'critical' :
                  pattern.source.includes('重要') || pattern.source.includes('major') ? 'major' : 'minor',
        description: match[1].trim()
      })
    }
  })

  return {
    passed,
    score,
    issues,
    summary: text.substring(0, 200) + '...'
  }
}

// 辅助函数：检查是否有严重问题
function hasCriticalIssues(issues) {
  return issues.some(issue => issue.severity === 'critical')
}

// 辅助函数：自动修复 reviewer 发现的问题
async function autoFixReviewerIssues(issues, sprintNum) {
  log(`🔧 开始自动修复 ${issues.length} 个问题...`)

  try {
    // 过滤出严重问题
    const criticalIssues = issues.filter(issue => issue.severity === 'critical')

    if (criticalIssues.length === 0) {
      log(`✅ 没有严重问题需要修复`)
      return true
    }

    // 针对每个严重问题调用修复
    for (const issue of criticalIssues) {
      log(`修复问题: ${issue.description}`)

      // 调用修复 agent
      const fixPrompt = `
请修复以下代码问题：

问题描述：${issue.description}
Sprint：${sprintNum}

请：
1. 分析问题原因
2. 实施修复
3. 验证修复是否成功
`

      await agent(fixPrompt, {
        label: `修复 Sprint ${sprintNum} 问题`,
        phase: `Sprint-${sprintNum}`
      })
    }

    log(`✅ 自动修复完成`)
    return true
  } catch (error) {
    log(`❌ 自动修复失败: ${error.message}`)
    return false
  }
}

// 辅助函数：等待 PR 合并（轮询模式）
async function waitForPRMerge(repo, prNumber, sprintNum) {
  log(`开始等待 PR #${prNumber} 合并（Sprint ${sprintNum}）...`)

  let pollCount = 0
  let merged = false

  while (!merged && pollCount < MAX_POLL_COUNT) {
    // 轮询等待
    await sleep(POLL_INTERVAL_SECONDS * 1000)
    pollCount++

    // 检查 PR 状态
    const status = await checkPRMerged(repo, prNumber)

    if (status.merged) {
      merged = true
      log(`✅ PR #${prNumber} 已合并（轮询 ${pollCount} 次）`)
      break
    }

    // 检查是否有 review 反馈需要处理
    if (status.state === 'CHANGES_REQUESTED') {
      log(`⚠️ PR #${prNumber} 有 review 反馈，开始处理...`)
      const reviewHandled = await handleReviewFeedback(repo, prNumber, sprintNum)

      if (!reviewHandled) {
        log(`❌ Review 反馈处理失败，暂停 workflow`)
        await saveState({ sprintNum, prNumber, status: 'review_failed', pollCount })
        return { status: 'review_failed', prNumber, pollCount }
      }
    }

    // 进度日志
    if (pollCount % 10 === 0) {
      log(`⏳ 等待 PR #${prNumber} 合并...（已轮询 ${pollCount}/${MAX_POLL_COUNT} 次）`)
    }
  }

  // 超时处理
  if (!merged) {
    log(`⏰ 轮询超时（${MAX_POLL_COUNT} 次），暂停 workflow`)
    await saveState({ sprintNum, prNumber, status: 'timeout', pollCount })
    return { status: 'timeout', prNumber, pollCount }
  }

  return { status: 'merged', prNumber, pollCount }
}

// 辅助函数：处理 review 反馈
async function handleReviewFeedback(repo, prNumber, sprintNum) {
  log(`开始处理 PR #${prNumber} 的 review 反馈...`)

  let reviewRound = 0
  let allReviewsResolved = false

  while (reviewRound < REVIEW_MAX_ROUNDS && !allReviewsResolved) {
    reviewRound++
    log(`📝 处理第 ${reviewRound} 轮 review 反馈...`)

    try {
      // 调用 /my-pr-review-response 处理 review 反馈
      await agent('/my-pr-review-response', {
        label: `处理 PR #${prNumber} review 反馈（第 ${reviewRound} 轮）`,
        phase: `Sprint-${sprintNum}`
      })

      // 等待一下让 GitHub 更新状态
      await sleep(5000)

      // 检查是否还有未处理的 review
      const status = await checkPRMerged(repo, prNumber)

      if (status.state !== 'CHANGES_REQUESTED') {
        allReviewsResolved = true
        log(`✅ Review 反馈处理完成`)
      } else {
        log(`⚠️ 仍有 review 反馈，继续处理...`)
      }
    } catch (error) {
      log(`❌ Review 反馈处理失败: ${error.message}`)
      return false
    }
  }

  if (!allReviewsResolved) {
    log(`⚠️ 达到最大 review 轮次（${REVIEW_MAX_ROUNDS}）`)
    return false
  }

  return true
}

// 辅助函数：保存状态（用于 resume）
async function saveState(state) {
  const stateData = {
    ...state,
    timestamp: new Date().toISOString(),
    runId: process.env.WORKFLOW_RUN_ID || 'unknown'
  }

  await write(STATE_FILE, JSON.stringify(stateData, null, 2))
  log(`💾 状态已保存到 ${STATE_FILE}`)
}

// 辅助函数：加载状态（用于 resume）
async function loadState() {
  try {
    const state = await read(STATE_FILE)
    return JSON.parse(state)
  } catch (error) {
    return null
  }
}

// 辅助函数：执行单个 Sprint
async function executeSprint(sprintNum, repo) {
  log(`🚀 开始执行 Sprint ${sprintNum}...`)

  try {
    // 步骤 1：调用 /my-sprint-execute 执行开发
    log(`📝 步骤 1/3：执行开发任务...`)
    await agent('/my-sprint-execute', {
      label: `执行 Sprint ${sprintNum}`,
      phase: `Sprint-${sprintNum}`
    })

    // 获取创建的 PR 号
    const prResult = await bash(`gh pr list --repo ${repo} --head branch-sprint-${sprintNum} --json number --jq '.[0].number'`, {
      label: `获取 Sprint ${sprintNum} 的 PR 号`
    })

    const prNumber = parseInt(prResult.trim())

    if (!prNumber) {
      throw new Error(`未找到 Sprint ${sprintNum} 的 PR`)
    }

    log(`✅ 开发完成，PR #${prNumber} 已创建`)

    // 步骤 2：执行独立 Reviewer 审查（可选）
    log(`🔍 步骤 2/3：执行独立 Reviewer 审查...`)
    const reviewerResult = await executeReviewerReview(sprintNum, prNumber)

    if (!reviewerResult.passed) {
      log(`❌ Reviewer 审查未通过: ${reviewerResult.status}`)

      // 如果 reviewer 审查失败，暂停 workflow
      await saveState({
        sprintNum,
        prNumber,
        status: 'reviewer_failed',
        reviewerResult,
        pollCount: 0
      })

      return {
        sprintNum,
        prNumber,
        status: 'reviewer_failed',
        reviewerResult
      }
    }

    log(`✅ Reviewer 审查通过`)

    // 步骤 3：等待 PR 合并（包括 GitHub reviewer 的 review）
    log(`⏳ 步骤 3/3：等待 PR 合并...`)
    const mergeResult = await waitForPRMerge(repo, prNumber, sprintNum)

    return {
      sprintNum,
      prNumber,
      reviewerResult,
      ...mergeResult
    }
  } catch (error) {
    log(`❌ Sprint ${sprintNum} 执行失败: ${error.message}`)
    return {
      sprintNum,
      status: 'failed',
      error: error.message
    }
  }
}

// 辅助函数：检查依赖是否满足
function checkDependencies(sprintNum, completedSprints) {
  const dependencies = DEPENDENCY_GRAPH[sprintNum] || []
  return dependencies.every(dep => completedSprints.includes(dep))
}

// 主 workflow 逻辑
async function main() {
  log('🚀 启动统一版 Sprint 执行流水线...')
  log(`📋 配置信息：`)
  log(`   - 独立审查: ${REVIEWER_CONFIG.enabled ? '启用' : '禁用'}`)
  if (REVIEWER_CONFIG.enabled) {
    log(`   - 最大尝试次数: ${REVIEWER_CONFIG.maxAttempts}`)
    log(`   - 通过阈值: ${REVIEWER_CONFIG.passThreshold * 100}%`)
    log(`   - 自动修复: ${REVIEWER_CONFIG.autoFixEnabled ? '启用' : '禁用'}`)
  }

  // 获取仓库信息
  const repo = args.repo || 'stark/hermes'  // 默认仓库，可通过 args 传入

  // 记录已完成的 sprint
  const completedSprints = []
  const failedSprints = []

  // Sprint 执行配置
  const sprintConfig = [
    { phase: 'Sprint-1', sprints: [1] },
    { phase: 'Sprint-2', sprints: [2] },
    { phase: 'Sprint-3-4-7-8-10', sprints: [3, 4, 7, 8, 10] },
    { phase: 'Sprint-5-6-11', sprints: [5, 6, 11] },
    { phase: 'Sprint-9', sprints: [9] },
    { phase: 'Sprint-12', sprints: [12] },
    { phase: 'Sprint-13', sprints: [13] }
  ]

  // 执行每个 phase
  for (const config of sprintConfig) {
    log(`\n${'='.repeat(60)}`)
    log(`📋 Phase: ${config.phase}`)
    log(`${'='.repeat(60)}`)

    // 检查依赖
    const canExecute = config.sprints.every(sprintNum => {
      const depsSatisfied = checkDependencies(sprintNum, completedSprints)
      if (!depsSatisfied) {
        log(`⚠️ Sprint ${sprintNum} 依赖未满足，跳过`)
        return false
      }
      return true
    })

    if (!canExecute) {
      log(`❌ Phase ${config.phase} 依赖未满足，跳过`)
      continue
    }

    // 并行执行多个 sprint
    if (config.sprints.length > 1) {
      log(`⚡ 并行执行 Sprints: ${config.sprints.join(', ')}`)

      const results = await parallel(
        config.sprints.map(sprintNum => () => executeSprint(sprintNum, repo))
      )

      // 处理结果
      results.forEach((result, index) => {
        const sprintNum = config.sprints[index]
        if (result.status === 'merged') {
          completedSprints.push(sprintNum)
          log(`✅ Sprint ${sprintNum} 完成并合并`)
        } else {
          failedSprints.push(sprintNum)
          log(`❌ Sprint ${sprintNum} 失败: ${result.status}`)

          // 如果有超时或失败，保存状态并提示 resume
          if (result.status === 'timeout' || result.status === 'review_failed' || result.status === 'reviewer_failed') {
            log(`\n⏸️ Workflow 暂停，请处理后调用 resume`)
            log(`   命令: workflow resume ${process.env.WORKFLOW_RUN_ID}`)
            return {
              status: 'paused',
              completedSprints,
              failedSprints,
              pausedSprint: sprintNum,
              prNumber: result.prNumber,
              failureReason: result.status
            }
          }
        }
      })
    } else {
      // 串行执行单个 sprint
      const sprintNum = config.sprints[0]
      const result = await executeSprint(sprintNum, repo)

      if (result.status === 'merged') {
        completedSprints.push(sprintNum)
        log(`✅ Sprint ${sprintNum} 完成并合并`)
      } else {
        failedSprints.push(sprintNum)
        log(`❌ Sprint ${sprintNum} 失败: ${result.status}`)

        // 如果有超时或失败，保存状态并提示 resume
        if (result.status === 'timeout' || result.status === 'review_failed' || result.status === 'reviewer_failed') {
          log(`\n⏸️ Workflow 暂停，请处理后调用 resume`)
          log(`   命令: workflow resume ${process.env.WORKFLOW_RUN_ID}`)
          return {
            status: 'paused',
            completedSprints,
            failedSprints,
            pausedSprint: sprintNum,
            prNumber: result.prNumber,
            failureReason: result.status
          }
        }
      }
    }
  }

  // 完成总结
  log(`\n${'='.repeat(60)}`)
  log(`📊 执行总结`)
  log(`${'='.repeat(60)}`)
  log(`✅ 完成: ${completedSprints.length} 个 sprints`)
  log(`❌ 失败: ${failedSprints.length} 个 sprints`)

  if (failedSprints.length > 0) {
    log(`失败的 sprints: ${failedSprints.join(', ')}`)
  }

  return {
    status: failedSprints.length > 0 ? 'partial' : 'completed',
    completedSprints,
    failedSprints
  }
}

// Resume 逻辑（从暂停点恢复）
async function resume() {
  log('🔄 恢复 workflow 执行...')

  const state = await loadState()

  if (!state) {
    log('❌ 未找到保存的状态，无法恢复')
    return { status: 'no_state' }
  }

  log(`📋 从 Sprint ${state.sprintNum} 恢复，PR #${state.prNumber}`)
  log(`   失败原因: ${state.status || 'unknown'}`)

  // 根据失败原因决定恢复策略
  if (state.status === 'reviewer_failed') {
    log(`🔍 重新执行 Reviewer 审查...`)
    const reviewerResult = await executeReviewerReview(state.sprintNum, state.prNumber)

    if (!reviewerResult.passed) {
      log(`❌ Reviewer 审查仍然失败`)
      return { status: 'reviewer_failed', reviewerResult }
    }

    log(`✅ Reviewer 审查通过，继续等待 PR 合并...`)
  }

  // 继续等待 PR 合并
  const repo = args.repo || 'stark/hermes'
  const mergeResult = await waitForPRMerge(repo, state.prNumber, state.sprintNum)

  if (mergeResult.status === 'merged') {
    log(`✅ PR #${state.prNumber} 已合并，继续执行后续 sprints`)

    // 重新执行主流程（从当前点开始）
    return await main()
  } else {
    log(`❌ PR #${state.prNumber} 仍未合并，状态: ${mergeResult.status}`)
    return mergeResult
  }
}

// 入口点
const command = args.command || 'start'

if (command === 'resume') {
  return await resume()
} else {
  return await main()
}
