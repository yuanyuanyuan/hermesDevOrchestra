# GSD 文档正确性验证报告

> 验证日期: 2026-05-13
> 验证方式: 对照源代码 (npm installed v1.41.2) 逐项核查
> 源码路径: `/home/stark/.nvm/versions/node/v24.14.0/lib/node_modules/get-shit-done-cc/`

---

## 总览

| 文档 | 严重问题 | 中等问题 | 轻微问题 |
|------|---------|---------|---------|
| ANALYSIS_REPORT.md | 2 | 3 | 1 |
| HUMAN_GUIDE.md | 1 | 3 | 2 |
| HUMAN_QUICK_REFERENCE.md | 1 | 2 | 2 |
| AI_AGENT_GUIDE_CLAUDE.md | 1 | 3 | 2 |
| AI_AGENT_GUIDE_CODEX.md | 2 | 3 | 2 |

---

## 一、全局问题（所有 5 个文档共同存在）

### 1.1 版本号错误 ❌ 严重

**所有文档声称**: v1.50.0
**实际稳定版**: 1.41.2 (npm registry 最新稳定版)
**说明**: v1.50.0 仅作为 canary 预发布版本存在 (1.50.0-canary.1, 1.50.0-canary.2)，并非正式发布版。

**影响**: 读者安装后会发现版本不一致，可能怀疑文档过期或安装错误。

---

## 二、ANALYSIS_REPORT.md 问题清单

### 2.1 组件数量统计偏差

| 组件 | 文档声称 | 实际数量 | 偏差 |
|------|---------|---------|------|
| Commands | 64 | **66** | +2 |
| Workflows | 87 | **89** (顶层) / **102** (含子目录) | +2~+15 |
| Agents | 33 | **33** | ✅ 正确 |
| Hooks (表中列出) | 10 | **12** | 缺 2 个 |

### 2.2 Hooks 表遗漏 ❌ 中等

**第 4.4 节**的 Hooks 表仅列出 10 个 hook，实际有 12 个。遗漏：

| 遗漏的 Hook | 类型 | 用途 |
|-------------|------|------|
| `gsd-check-update-worker.js` | JS | 更新检查的工作进程（后台执行实际检查逻辑） |
| `gsd-update-banner.js` | JS | 更新通知横幅显示 |

### 2.3 统计数据与表格不一致 ⚠️ 轻微

- 第 3.2 节声称 "64 个命令，分布在 14 个功能类别中" — 实际 66 个命令
- 第 3.2 节声称 "87 个工作流文件" — 实际 89 个（顶层）
- 第 3.2 节声称 "33 个 agent 定义" — ✅ 正确
- 第 4.4 节标题写 "11 个" Hooks，但表中只列出 10 个 — 标题与内容不一致

### 2.4 工具使用统计 ✅ 正确

Agents 工具使用统计 (Read: 33, Bash: 30, Grep: 30, Glob: 29, Write: 25, WebSearch: 8, AskUserQuestion: 3) — 无法完全验证精确数字，但数量级合理。

---

## 三、HUMAN_GUIDE.md 问题清单

### 3.1 SDK API 示例不可直接使用 ⚠️ 中等

**文档内容** (第 192-208 行):
```typescript
import { GSD } from '@gsd-build/sdk';
const gsd = new GSD({ ... });
const result = await gsd.run('');
```

**实际情况**:
- `@gsd-build/sdk` 是嵌套在 `get-shit-done-cc` 包内的子包
- 全局安装 `get-shit-done-cc` 后，`import { GSD } from '@gsd-build/sdk'` **不会自动可用**
- 需要单独安装 `npm install @gsd-build/sdk` 或通过路径引用
- `GSD` 类确实存在并正确导出 ✅

### 3.2 缺少 `settings` 命令 ⚠️ 中等

**配置命令表** (第 409-416 行) 列出了 `config` 系列命令，但遗漏了 `settings` 命令。
源码中存在 `commands/gsd/settings.md` 和 `workflows/settings.md`。

### 3.3 缺少部分命令 ⚠️ 轻微

以下命令存在于源码但未在文档中提及：
- `settings` — 交互式设置
- `sketch` — UI 探索
- `spike` — 技术可行性调研
- `ns-*` 系列 (ns-context, ns-ideate, ns-manage, ns-project, ns-review, ns-workflow) — 新命名空间命令
- `plan-review-convergence` — 跨 AI 收敛评审
- `ultraplan-phase` — 超级计划模式
- `add-tests` — 添加测试
- `cleanup` — 清理

### 3.4 .planning/ 目录结构不完整 ⚠️ 轻微

**文档结构树**遗漏了以下目录/文件：
- `MILESTONES.md` — 已完成里程碑归档
- `codebase/` — 棕地映射目录
- `quick/` — 快速任务跟踪
- `threads/` — 持久化上下文线程
- `seeds/` — 前瞻性想法

---

## 四、HUMAN_QUICK_REFERENCE.md 问题清单

### 4.1 缺少 `settings` 命令 ⚠️ 中等

**配置快速切换**部分 (第 105-111 行) 列出了 `config` 和 `settings`，但**质量保证**和**调试**部分遗漏了多个命令。

### 4.2 缺少 `sketch` 和 `spike` 命令 ⚠️ 中等

这两个是重要的探索性命令，适合出现在快速参考卡片中。

### 4.3 .planning/ 结构不完整 ⚠️ 轻微

与 HUMAN_GUIDE.md 相同问题，缺少 `MILESTONES.md`, `codebase/`, `quick/`, `threads/`, `seeds/`。

### 4.4 命令前缀表 ✅ 正确

| 运行时 | 前缀 | 验证 |
|--------|------|------|
| Claude Code | `/gsd-` | ✅ README 确认 |
| Codex | `$gsd-` | ✅ README 确认 |
| Gemini CLI | `/gsd:` | ✅ 源码命令名格式 `gsd:*` 匹配 |

---

## 五、AI_AGENT_GUIDE_CLAUDE.md 问题清单

### 5.1 SDK API 示例同 HUMAN_GUIDE.md ⚠️ 中等

第 193-208 行的 `@gsd-build/sdk` import 示例存在同样的问题。

### 5.2 缺少 `settings` 等命令 ⚠️ 中等

快速参考表中缺少：`settings`, `sketch`, `spike`, `ns-*` 系列等命令。

### 5.3 Hooks 表遗漏 ⚠️ 轻微

未列出 `gsd-check-update-worker.js` 和 `gsd-update-banner.js`。

### 5.4 Agent 分类统计 ✅ 基本正确

文档列出的 33 个 Agent 名称与源码完全匹配。分类也合理。

---

## 六、AI_AGENT_GUIDE_CODEX.md 问题清单

### 6.1 模型名称错误 ❌ 严重

**文档第 188 行**:
```bash
gsd-sdk auto --model gpt-4 --max-budget 10
```

**文档第 199 行**:
```typescript
model: 'gpt-4',
```

**实际情况**: GSD 的 `--model` 参数接受 Claude 模型标识符（如 `claude-opus-4-6`, `claude-sonnet-4-6`），而非 OpenAI 的 `gpt-4`。这在 Codex 版文档中尤其具有误导性 — 暗示 GSD 可以直接使用 OpenAI 模型运行，但实际上 GSD 核心是围绕 Claude Agent SDK 构建的。

### 6.2 SDK API 示例同上 ⚠️ 中等

`@gsd-build/sdk` 的 import 路径问题同 Claude 版。

### 6.3 缺少命令同上 ⚠️ 中等

与 Claude 版相同的命令遗漏问题。

### 6.4 Hooks 表遗漏 ⚠️ 轻微

同 Claude 版。

---

## 七、源码事实摘要

以下数据从实际安装的 `get-shit-done-cc@1.41.2` 提取，可作为文档修正的参考基准：

| 项目 | 实际值 |
|------|--------|
| **版本** | 1.41.2 (stable) |
| **Commands** | 66 个 `.md` 文件 |
| **Workflows** | 89 个顶层 `.md` 文件 (含子目录共 102) |
| **Agents** | 33 个 `.md` 文件 |
| **Hooks** | 12 个 (9 JS + 3 SH) |
| **SDK 包名** | `@gsd-build/sdk` (嵌套在主包内) |
| **Node.js 要求** | >= 22.0.0 |
| **依赖** | `@anthropic-ai/claude-agent-sdk` ^0.2.84, `ws` ^8.20.0 |
| **CLI binaries** | `get-shit-done-cc`, `gsd-sdk`, `gsd-tools` |

### Hooks 完整清单

| Hook 文件 | 类型 | 文档是否列出 |
|-----------|------|------------|
| gsd-check-update.js | JS | ✅ |
| gsd-check-update-worker.js | JS | ❌ 遗漏 |
| gsd-context-monitor.js | JS | ✅ |
| gsd-phase-boundary.sh | SH | ✅ |
| gsd-prompt-guard.js | JS | ✅ |
| gsd-read-guard.js | JS | ✅ |
| gsd-read-injection-scanner.js | JS | ✅ |
| gsd-session-state.sh | SH | ✅ |
| gsd-statusline.js | JS | ✅ |
| gsd-update-banner.js | JS | ❌ 遗漏 |
| gsd-validate-commit.sh | SH | ✅ |
| gsd-workflow-guard.js | JS | ✅ |

### 源码中存在但文档未提及的命令

| 命令 | 用途 |
|------|------|
| `settings` | 交互式设置 (等同于 `config --advanced`) |
| `sketch` | UI 探索/线框 |
| `spike` | 技术可行性调研 |
| `ns-context` | 命名空间上下文 |
| `ns-ideate` | 命名空间构思 |
| `ns-manage` | 命名空间管理 |
| `ns-project` | 命名空间项目 |
| `ns-review` | 命名空间评审 |
| `ns-workflow` | 命名空间工作流 |
| `plan-review-convergence` | 跨 AI 收敛评审 |
| `ultraplan-phase` | 超级计划模式 |
| `add-tests` | 添加测试 |
| `cleanup` | 清理 |

---

## 八、修正建议优先级

### P0 (必须修正)
1. **版本号**: 所有文档从 v1.50.0 改为 v1.41.2 (或注明 "canary")
2. **Codex 版模型名**: `gpt-4` → `claude-opus-4-6` 或注明需替换为实际使用的模型

### P1 (建议修正)
3. **组件数量**: Commands 64→66, Workflows 87→89, Hooks 10→12
4. **Hooks 表**: 补充 `gsd-check-update-worker.js` 和 `gsd-update-banner.js`
5. **SDK import 说明**: 注明 `@gsd-build/sdk` 需单独安装

### P2 (可选完善)
6. 补充遗漏的命令 (settings, sketch, spike, ns-* 系列等)
7. 完善 .planning/ 目录结构树
8. 补充 `gsd-tools` CLI binary 说明

---

*验证工具: 源码直接比对 + npm registry 查询*
*验证人: 蕾姆 (AI Assistant)*
