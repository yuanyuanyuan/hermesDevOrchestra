/**
 * Sprint Execution Pipeline - 简化测试版本
 *
 * 关键设计点：
 * 1. 人工阻塞点：轮询等待 PR 合并
 * 2. 超时暂停：保存状态支持 resume
 * 3. Review 循环：自动处理多轮 review
 * 4. 依赖链：每个 PR 合并后继续对应依赖
 */

export const meta = {
  name: 'sprint-execution-pipeline-test',
  description: '简化测试版本 - 验证核心逻辑',
  phases: [
    { title: 'Test-Sprint-1' },
    { title: 'Test-Sprint-2' }
  ]
}

// 测试配置：只执行前 2 个 sprint
const TEST_SPRINTS = [1, 2]

// 简化的依赖关系
const DEPENDENCY_GRAPH = {
  1: [],
  2: [1]
}

// 轮询配置
const POLL_INTERVAL_SECONDS = 10  // 测试用：10秒
const MAX_POLL_COUNT = 10         // 测试用：最多10次

// 辅助函数：检查 PR 状态
async function checkPRStatus(prNumber) {
  try {
    const result = await bash(`gh pr view ${prNumber} --json state,mergedAt`, {
      label: `检查 PR #${prNumber} 状态`
    })
    const prData = JSON.parse(result)
    return {
      merged: prData.mergedAt !== null,
      state: prData.state
    }
  } catch (error) {
    log(`检查 PR #${prNumber} 失败: ${error.message}`)
    return { merged: false, state: 'error', error: error.message }
  }
}

// 辅助函数：等待 PR 合并
async function waitForPRMerge(prNumber, sprintNum) {
  log(`开始等待 PR #${prNumber} 合并（Sprint ${sprintNum}）...`)

  let pollCount = 0
  let merged = false

  while (!merged && pollCount < MAX_POLL_COUNT) {
    await sleep(POLL_INTERVAL_SECONDS * 1000)
    pollCount++

    const status = await checkPRStatus(prNumber)

    if (status.merged) {
      merged = true
      log(`✅ PR #${prNumber} 已合并（轮询 ${pollCount} 次）`)
      break
    }

    log(`⏳ 等待 PR #${prNumber}...（${pollCount}/${MAX_POLL_COUNT}）`)

    // 检查是否需要处理 review
    if (status.state === 'CHANGES_REQUESTED') {
      log(`⚠️ PR #${prNumber} 有 review 反馈`)
      // 测试版本：直接跳过 review 处理
      log(`📝 测试模式：跳过 review 处理`)
    }
  }

  if (!merged) {
    log(`⏰ 轮询超时（${MAX_POLL_COUNT} 次）`)
    return { status: 'timeout', prNumber, pollCount }
  }

  return { status: 'merged', prNumber, pollCount }
}

// 辅助函数：执行 Sprint
async function executeSprint(sprintNum) {
  log(`🚀 开始执行 Sprint ${sprintNum}...`)

  try {
    // 模拟执行 /my-sprint-execute
    log(`📝 调用 /my-sprint-execute 执行 Sprint ${sprintNum}`)

    // 测试：模拟创建 PR
    const prNumber = 100 + sprintNum  // 模拟 PR 号
    log(`✅ Sprint ${sprintNum} 执行完成，PR #${prNumber} 已创建`)

    // 等待 PR 合并
    const mergeResult = await waitForPRMerge(prNumber, sprintNum)

    return {
      sprintNum,
      prNumber,
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

// 主逻辑
async function main() {
  log('🚀 启动 Sprint 执行流水线（测试版本）...')

  const completedSprints = []
  const failedSprints = []

  // 执行测试 Sprint
  for (const sprintNum of TEST_SPRINTS) {
    log(`\n${'='.repeat(50)}`)
    log(`📋 执行 Sprint ${sprintNum}`)
    log(`${'='.repeat(50)}`)

    const result = await executeSprint(sprintNum)

    if (result.status === 'merged') {
      completedSprints.push(sprintNum)
      log(`✅ Sprint ${sprintNum} 完成并合并`)
    } else {
      failedSprints.push(sprintNum)
      log(`❌ Sprint ${sprintNum} 失败: ${result.status}`)

      // 超时处理
      if (result.status === 'timeout') {
        log(`\n⏸️ Workflow 暂停，请合并 PR #${result.prNumber} 后调用 resume`)
        return {
          status: 'paused',
          completedSprints,
          failedSprints,
          pausedSprint: sprintNum,
          prNumber: result.prNumber
        }
      }
    }
  }

  // 完成总结
  log(`\n${'='.repeat(50)}`)
  log(`📊 执行总结`)
  log(`${'='.repeat(50)}`)
  log(`✅ 完成: ${completedSprints.length} 个 sprints`)
  log(`❌ 失败: ${failedSprints.length} 个 sprints`)

  return {
    status: failedSprints.length > 0 ? 'partial' : 'completed',
    completedSprints,
    failedSprints
  }
}

// Resume 逻辑
async function resume() {
  log('🔄 恢复 workflow 执行...')

  // 测试版本：直接继续执行
  log(`📋 测试模式：从 Sprint 2 继续`)

  const result = await executeSprint(2)

  if (result.status === 'merged') {
    log(`✅ Sprint 2 完成并合并`)
    return { status: 'completed', completedSprints: [1, 2] }
  } else {
    log(`❌ Sprint 2 仍然失败: ${result.status}`)
    return result
  }
}

// 入口点
const command = args.command || 'start'

if (command === 'resume') {
  return await resume()
} else {
  return await main()
}
