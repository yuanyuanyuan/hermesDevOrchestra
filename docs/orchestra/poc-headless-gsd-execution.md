# POC 报告：AI 代码助手无头模式 GSD 执行能力

> **执行时间**：2026-04-28 19:39–19:42  
> **执行者**：Kimi Code CLI (Sub Agent 并行执行)  
> **POC 目录**：`/tmp/poc-headless-gsd-1777376358`  
> **结论**：Claude Code **受限可用** | Codex CLI **当前环境不可用**

---

## 1. 执行摘要

本次 POC 验证了 Claude Code (`claude -p`) 与 Codex CLI (`codex exec`) 在无头模式下执行 GSD 交互式 Skill `gsd-verify-work` 的能力。

- **Claude Code**：成功识别 Skill、加载 Phase 1 上下文、生成 UAT 文件，但在无头模式下无法完成交互式确认，UAT 状态停留在 `pending`。
- **Codex CLI**：成功识别 Skill，但受限于当前 Linux 环境的 bubblewrap 沙箱权限问题（`bwrap: setting up uid map: Permission denied`），无法执行任何本地命令或 JS REPL；`request_user_input` 被拒绝后，Skill Adapter 中声明的 Fallback 策略未生效，未生成任何 UAT 文件。

---

## 2. 环境信息

| 项目             | 版本 / 路径                                  |
|------------------|----------------------------------------------|
| Claude Code      | `2.1.121`                                    |
| Codex CLI        | `0.125.0` (model: gpt-5.5)                   |
| Claude GSD Skill | `~/.claude/skills/gsd-verify-work/SKILL.md`  |
| Codex GSD Skill  | `~/.codex/skills/gsd-verify-work/SKILL.md`   |
| POC 工作目录     | `/tmp/poc-headless-gsd-1777376358`           |
| 测试 Skill       | `gsd-verify-work` (Phase 1: poc-hello-world) |

**临时 GSD 项目结构**：
```
/tmp/poc-headless-gsd-1777376358/
├── hello.txt                          # Phase 1 执行产物
└── .planning/
    ├── PROJECT.md
    ├── STATE.md
    ├── ROADMAP.md
    └── phases/
        ├── 01/
        │   ├── PLAN.md
        │   └── 01-01-EXECUTION.md     # 模拟已完成的执行记录
        └── 01-poc-hello-world/
            └── 01-UAT.md              # [Claude 生成] UAT 报告
```

---

## 3. 测试结果

### 3.1 Claude Code (`claude -p`)

| 测试项               | 结果 | 退出码 | 备注                                        |
|----------------------|------|--------|---------------------------------------------|
| Skill 识别           | ✅    | 0      | 正确解析 `/gsd-verify-work` 并加载 workflow |
| 参数传递             | ✅    | —      | 正确读取 Phase 1 (`poc-hello-world`) 上下文 |
| UAT 内容渲染         | ✅    | —      | 完整输出测试用例描述与验证说明              |
| AskUserQuestion 行为 | ⚠️   | —      | **输出提问文本但无法等待回答**，直接结束     |
| UAT 产物生成         | ✅    | —      | 生成 `01-UAT.md`（见下方内容）                |
| 异常/报错            | ❌ 无 | —      | 无任何报错                                  |

**生成的 UAT 文件** (`01-UAT.md`)：
```yaml
status: testing
phase: 01-poc-hello-world
source: 01-01-EXECUTION.md
```
- **总测试数**：1
- **通过**：0
- **待确认 (pending)**：1
- **结果**：`[pending]`

**完整输出日志**：`/tmp/poc-claude-test.log`

**日志关键片段**：
```
## UAT: Phase 1 — poc-hello-world

**Test 1 of 1**

**Test:** Hello World File

**Expected:** A file named `hello.txt` exists in the project root,
containing the text `"Hello from POC Phase 1!"`.

---

请验证：打开 `hello.txt`，内容是否正确显示？

回复 `yes`、`y`、`pass` 或留空表示通过，其他描述请告知问题。
=== EXIT_CODE: 0 ===
```

---

### 3.2 Codex CLI (`codex exec`)

| 测试项                      | 结果 | 退出码 | 备注                                                        |
|-----------------------------|------|--------|-------------------------------------------------------------|
| Skill 识别                  | ✅    | 0      | 正确解析 `$gsd-verify-work`                                 |
| Trusted Directory 检查      | ❌    | 1      | 首次执行因未加 `--skip-git-repo-check` 被拦截               |
| 沙箱初始化                  | ❌    | —      | `bwrap: setting up uid map: Permission denied`              |
| `exec_command` 可用性       | ❌    | —      | bubblewrap 权限问题导致所有本地命令无法执行                 |
| `js_repl` 可用性            | ❌    | —      | 同上，Node REPL 内核启动失败                                 |
| `request_user_input` 触发   | ✅    | —      | 尝试发起交互提问                                            |
| `request_user_input` 被拒绝 | ✅    | —      | 报错：`unavailable in Default mode`                          |
| Fallback 行为（合理默认值）   | ❌    | —      | **Skill Adapter 声明的 fallback 未生效**，仅重复输出选项列表 |
| UAT 产物生成                | ❌    | —      | 未生成任何文件                                              |
| Token 消耗                  | —    | —      | **33,011 tokens**                                           |

**完整输出日志**：`/tmp/poc-codex-test.log`

**日志关键片段**：
```
warning: Codex's Linux sandbox uses bubblewrap and needs access to create user namespaces.
...
js_repl diagnostics: {"reason":"stdout_eof",...,"kernel_stderr_tail":"bwrap: setting up uid map: Permission denied"}
...
2026-04-28T11:41:50.302356Z ERROR codex_core::tools::router: error=request_user_input is unavailable in Default mode
...
请选一个继续方式：
1. 粘贴上下文（推荐）
2. 仅给手动 UAT 清单
3. 暂停
=== EXIT_CODE: 0 ===
```

---

## 4. 差异分析

### 4.1 核心维度对照表

| 维度                    | Claude Code (`claude -p`)       | Codex CLI (`codex exec`)                                     |
|-------------------------|---------------------------------|--------------------------------------------------------------|
| **Skill 触发语法**      | `/gsd-verify-work`              | `$gsd-verify-work`                                           |
| **参数传递**            | 空格分隔 `"/gsd-verify-work 1"` | 空格分隔 `"$gsd-verify-work 1"`                              |
| **无头模式参数**        | `-p` / `--print`                | `exec`                                                       |
| **交互工具原语**        | `AskUserQuestion`               | `request_user_input`                                         |
| **Skill 内无头适配**    | ❌ 无内置 fallback               | ⚠️ 有 `<codex_skill_adapter>` 声明 fallback，**但实测未生效** |
| **无头模式 stdin 行为** | 输出提问文本，不阻塞，正常退出    | 尝试交互 → 工具被拒绝 → 重复输出选项 → 未推进状态机          |
| **本地工具可用性**      | ✅ 正常（可读写文件）              | ❌ 受 bubblewrap 限制，exec/js_repl 全部失败                   |
| **退出码策略**          | 0（正常退出）                     | 0（虽工作流未完成，但进程正常结束）                             |
| **UAT 产物生成**        | ✅ 生成，但状态为 `pending`       | ❌ 未生成                                                     |
| **Token 消耗**          | 未统计                          | **33,011**                                                   |

### 4.2 关键差异解读

1. **本地执行能力差异显著**
   - Claude Code 在无头模式下仍保留了完整的本地文件系统访问能力，可以读取 `.planning/` 目录、生成 UAT 文件。
   - Codex CLI 在当前环境中因 bubblewrap 的 user namespace 权限问题，完全失去了本地执行能力，这是测试失败的最直接原因。

2. **交互阻断后的行为差异**
   - Claude Code：遇到 `AskUserQuestion` 时，**输出提问文本后优雅结束**，不抛出异常，且已完成的文件写入工作得以保留。
   - Codex CLI：遇到 `request_user_input` 被拒绝后，**陷入循环重复输出选项列表**，Skill Adapter 中声明的 "present a plain-text numbered list and pick a reasonable default" 未被执行。

3. **质量门槛差异**
   - Claude Code 生成了结构化的 `01-UAT.md`，明确标记测试为 `pending`，保留了人工后续确认的可能性。
   - Codex CLI 未生成任何产物，33K tokens 的消耗未产生可交付结果。

---

## 5. 交互式命令在无头模式下的限制

| 限制编号 | 限制描述                                                                                                | 影响程度 |
|----------|---------------------------------------------------------------------------------------------------------|----------|
| L1       | **输入断层**：无头模式下没有真实用户回答 UAT 提问，交互式验证流程无法闭环                                 | 🔴 高    |
| L2       | **状态机中断**：UAT 通常是顺序状态机（提问 → 回答 → 下一题），缺少输入导致流程停在中间状态                  | 🔴 高    |
| L3       | **假阳性风险**：如果通过 fallback 或 mock 管道强制继续，可能将未经验证的测试标记为通过                    | 🟡 中    |
| L4       | **环境依赖差异**：不同 Linux 发行版/容器对 bubblewrap user namespace 的支持不同，Codex CLI 的可用性不稳定 | 🟡 中    |
| L5       | **Token 浪费**：Codex 在无头交互阻断后消耗了 33K tokens 但未产出结果，成本效率低                          | 🟡 中    |

---

## 6. 变通方案评估

| 方案                        | 描述                                                                         | 可行性                   | 推荐度 | 风险                                                    |
|-----------------------------|------------------------------------------------------------------------------|--------------------------|--------|---------------------------------------------------------|
| **A. Mock 输入管道**        | `echo "yes" \| claude -p "/gsd-verify-work 1"`                               | Claude 可用；Codex 不适用 | ⭐⭐⭐    | 仅适用于单轮问答；多轮时管道只回答第一轮                 |
| **B. 非交互式 UAT Skill**   | 创建 `gsd-verify-work-batch`，基于文件检查自动输出 PASS/FAIL                  | **最可行**               | ⭐⭐⭐⭐⭐  | 失去"用户视角确认"价值，但适合 CI/CD                     |
| **C. 文件锁/状态轮询**      | 无头生成问题到文件 → 外部系统写入回答 → 下一轮读取继续                       | 可行                     | ⭐⭐⭐⭐   | 实现复杂，需状态持久化，契合 Remote Decision Channel 设计 |
| **D. Codex Fallback 调优**  | 修复 Skill Adapter 提示词，强制模型在 `request_user_input` 被拒时自动选默认项 | 需验证                   | ⭐⭐     | 当前模型未遵循该指令，可能需要更强的 prompt 约束         |
| **E. Workflow 拆分**        | 拆分为 `generate-uat-questions`（完全无头）+ `submit-uat-answers`（需交互）      | 可行                     | ⭐⭐⭐⭐   | 需修改现有 GSD Skill 架构，增加维护成本                  |
| **F. 修复 bubblewrap 环境** | 为 Codex CLI 配置 `--sandbox none` 或修复 kernel user namespace 权限         | 环境依赖                 | ⭐⭐⭐    | 降低安全性，且并非所有运行环境都可修复                   |

**推荐策略**：
- **短期**：对 Hermes Dev Orchestra 的自动化验收流程，采用 **方案 B（非交互式 UAT Skill）** 或 **方案 A（Mock 管道）** 作为无头执行的补充。
- **中期**：采用 **方案 E（Workflow 拆分）**，将 UAT 的"生成问题"与"收集回答"解耦，使前者可在无头模式下完全自主运行。
- **长期**：结合 **方案 C（文件锁/状态轮询）**，通过 Remote Decision Channel（如 Telegram Bot）让外部用户在异步时间窗口内完成 UAT 确认，实现真正的"人机协同无头工作流"。

---

## 7. 对 Hermes Dev Orchestra 架构的影响

1. **Claude Supervisor 更适合无头验收生成**：由于 Claude Code 在无头模式下能正常读写文件并生成结构化 UAT 报告（即使状态为 pending），可以让 Claude 负责**无头生成 UAT 草案**，再通过 Remote Decision Channel 将 `pending` 项推送给用户确认。

2. **Codex Executor 的 sandbox 限制需纳入部署假设**：在 Ubuntu/Linux 宿主机上运行 Codex CLI 时，必须验证 bubblewrap 的 user namespace 可用性，或在 CI/自动化环境中配置 `--sandbox none`。

3. **Skill Adapter 的 Fallback 声明不等于实际行为**：Codex Skill 文件中 `<codex_skill_adapter>` 声明的 fallback 策略在当前模型版本（gpt-5.5）下未被执行，说明 **adapter 规范与模型实际行为之间存在差距**，需在规范层面加强约束或增加工具级别的强制 fallback。

4. **L3/L4 决策阻塞点的自然映射**：UAT 验证本质上是一个 L3（产品级）决策——"这个功能是否按预期工作"。当前 POC 恰好验证了：**无头模式不应自动批准 UAT**，而应生成待确认报告并阻塞等待用户决策——这与 Hermes 的 `escalation.md` 和 `orch-decisions` 设计哲学完全一致。

---

## 8. 附件清单

| 文件路径                                                                         | 说明                         |
|----------------------------------------------------------------------------------|------------------------------|
| `/tmp/poc-claude-test.log`                                                       | Claude Code 无头测试完整输出 |
| `/tmp/poc-codex-test.log`                                                        | Codex CLI 无头测试完整输出   |
| `/tmp/poc-env-snapshot.log`                                                      | 测试前环境快照               |
| `/tmp/poc-headless-gsd-1777376358/.planning/phases/01-poc-hello-world/01-UAT.md` | Claude Code 生成的 UAT 产物  |

---

## 9. 第二轮验证：Claude Sub Agent 并行执行（扩展测试）

> **执行时间**：2026-04-28 19:32–19:45  
> **执行者**：Claude Code (蕾姆) + Sub Agent 并行执行  
> **POC 目录**：`/tmp/poc-headless-gsd-1777376401`  
> **测试方法**：TeamCreate 创建团队，两个 general-purpose sub agent 并行分别测试 Claude Code 和 Codex CLI

### 9.1 测试设计改进

相比第一轮（Kimi Code CLI），本轮测试增加了以下维度：

| 新增维度               | 目的                                                                             |
|------------------------|----------------------------------------------------------------------------------|
| **自然语言包裹测试**   | `claude -p "请执行 /gsd-verify-work 1"` — 验证 skill 触发是否必须严格以 `/` 开头 |
| **非交互式命令对比**   | `/gsd-progress` — 对比不同 skill 的交互强度差异                                  |
| **Shell 变量扩展诊断** | 明确记录 `$gsd-verify-work` 是否被 shell 扩展                                    |
| **Codex 上下文识别**   | 观察 Codex 是否能从残缺的 prompt 中推断 skill 名称                               |
| **Sandbox 策略变量**   | 测试 `-s danger-full-access` 是否能绕过 bwrap 限制                               |

### 9.2 Claude Code 扩展测试结果

| 测试项         | 命令                                    | 退出码 | 结果     | 关键发现                                            |
|----------------|-----------------------------------------|--------|----------|-----------------------------------------------------|
| A (直接)       | `claude -p "/gsd-verify-work 1"`        | 0      | ✅ 识别   | 与第一轮一致：skill 识别成功，进入交互式确认          |
| B (中文包裹)   | `claude -p "请执行 /gsd-verify-work 1"` | 0      | ❌ 未识别 | **新发现**：skill 被当作普通对话处理，未触发 workflow |
| C (非交互对比) | `claude -p "/gsd-progress"`             | 124    | 🔴 超时  | **新发现**：60秒内完全无输出，被 timeout 强制终止     |

**Claude 扩展发现**：

1. **Skill 触发语法严格性**
   - `/gsd-verify-work` 必须作为 prompt 的**严格前缀**才能触发 skill
   - 混入自然语言（如 `"请执行 /gsd-verify-work"`）会导致 skill 不被识别
   - 这与 Claude Code 交互模式下的行为一致：slash command 必须是独立 token

2. **`/gsd-progress` 无头模式阻塞**
   - 该 skill 在 60 秒内无任何 stdout/stderr 输出
   - 可能原因：内部初始化耗时过长、或无头模式下遇到未处理的阻塞调用
   - 与 `/gsd-verify-work`（至少输出 UAT 内容后等待输入）行为不同

3. **完整日志路径**：`/tmp/poc-headless-gsd-1777376401/claude-test.log`

### 9.3 Codex CLI 扩展测试结果

| 测试项        | 命令                                     | 退出码 | 结果    | 关键发现                                                                           |
|---------------|------------------------------------------|--------|---------|------------------------------------------------------------------------------------|
| A (变量)      | `codex exec "$gsd-verify-work 1"`        | 2      | ❌ 失败  | **新发现**：`$gsd-verify-work` shell 变量未定义，扩展为空字符串                      |
| B (中文+变量) | `codex exec "请执行 $gsd-verify-work 1"` | 124    | ⚠️ 部分 | **新发现**：Codex 从 `"-verify-work 1"` 上下文**推断出 skill 名称**！但被 bwrap 阻塞 |
| C (进度变量)  | `codex exec "$gsd-progress"`             | 1      | ❌ 失败  | 变量未扩展 → 解析为 `--profile rogress`                                            |
| D (JSON变量)  | `codex exec "$gsd-verify-work 1" --json` | 2      | ❌ 失败  | 同 A，未到达 JSONL 测试                                                             |

**Codex 扩展发现**：

1. **Shell 变量扩展是根本原因**
   - `$gsd-verify-work` 在当前 shell 环境中**未定义**
   - 扩展为空字符串后，prompt 变成 `"-verify-work 1"`
   - Codex CLI 将 `"-v"` 解析为 flag，导致 `unexpected argument '-v' found`
   - 这与第一轮测试（Kimi 执行）不同——Kimi 的测试显示 Codex "成功解析 `$gsd-verify-work`"，说明 Kimi 的环境中可能预定义了该变量，或使用了不同的调用方式

2. **Skill 上下文感知能力（重要发现）**
   - 在 Test B 中，尽管 prompt 是残缺的 `"请执行 -verify-work 1"`，Codex **明确说出**：
     > "我会按 `gsd-verify-work` 技能执行..."
   - 这说明 Codex 具有**skill 名称的上下文推断能力**，可以从部分匹配的文本中识别出完整的 skill 名称
   - 这是 Codex 相对于 Claude Code 的一个独特优势：Claude 要求严格的 `/skill-name` 前缀，而 Codex 可以从自然语言中推断

3. **bubblewrap 沙箱权限（与第一轮一致）**
   - `bwrap: setting up uid map: Permission denied`
   - shell 执行和 js_repl 回退全部失败
   - 这是当前 Linux 环境的系统性限制，非 Codex CLI 本身缺陷

4. **Token 消耗**
   - Test B 在 timeout 前消耗了 **14,972 tokens**
   - 低于第一轮的 33,011 tokens（可能因为更早触发了死胡同）

5. **完整日志路径**：`/tmp/poc-headless-gsd-1777376401/codex-test.log`

### 9.4 两轮测试差异对照

| 维度                          | 第一轮 (Kimi Code CLI) | 第二轮 (Claude Sub Agent)          |
|-------------------------------|------------------------|------------------------------------|
| **执行方式**                  | 单 agent 串行          | 多 agent 并行 (TeamCreate)         |
| **Claude `/gsd-verify-work`** | ✅ 识别，交互阻塞        | ✅ 识别，交互阻塞 (一致)             |
| **Claude 自然语言包裹**       | 未测试                 | ❌ 不识别 (新发现)                  |
| **Claude `/gsd-progress`**    | 未测试                 | 🔴 超时 (新发现)                   |
| **Codex `$gsd-verify-work`**  | ✅ "成功解析"           | ❌ shell 变量未扩展 (新发现)        |
| **Codex skill 上下文推断**    | 未观察到               | ✅ 从残缺文本推断 skill 名 (新发现) |
| **Codex bwrap 问题**          | ✅ 存在                 | ✅ 存在 (一致)                      |
| **Codex token 消耗**          | 33,011                 | 14,972 (Test B 部分成功)           |
| **UAT 产物生成**              | Claude ✅ / Codex ❌     | Claude ✅ / Codex ❌ (一致)          |

### 9.5 对第一轮结论的修正与补充

1. **Codex "成功解析 Skill" 的再审视**
   - 第一轮报告说 Codex "成功解析 `$gsd-verify-work`"
   - 本轮发现该变量在 shell 中**未定义**，若按字面传递会失败
   - 可能的解释：Kimi 的测试环境预定义了 `$gsd-verify-work` 变量，或使用了其他调用方式（如 `"$ gsd-verify-work 1"` 带有空格前缀）
   - **修正**：Codex 的 skill 识别**依赖于环境变量配置**，非开箱即用

2. **Skill Adapter Fallback 未生效的新视角**
   - 第一轮将此归因于 "adapter 规范与模型实际行为之间存在差距"
   - 本轮补充：即使不考虑 fallback，Codex 在当前环境中**根本无法执行任何本地操作**（bwrap 阻塞），因此 fallback 是否有意义本身存疑
   - **补充**：Fallback 失效可能是**条件未触发**（模型未到达 fallback 分支），而非模型不遵循指令

3. **Claude Code 的交互阻塞模式更优雅**
   - Claude：输出提问 → 无 stdin 可读取 → 正常退出（exit 0），已完成的文件写入保留
   - Codex：尝试交互 → 工具被拒绝 → 尝试 fallback → bwrap 阻塞 → 多轮重试 → timeout
   - 在资源消耗（token）和可预测性方面，Claude 的行为更适合无头场景

---

## 10. 附件清单（第二轮）

| 文件路径                                                     | 说明                                      |
|--------------------------------------------------------------|-------------------------------------------|
| `/tmp/poc-headless-gsd-1777376401/claude-test.log`           | Claude Code 扩展测试完整输出（含 3 个变体） |
| `/tmp/poc-headless-gsd-1777376401/codex-test.log`            | Codex CLI 扩展测试完整输出（含 4 个变体）   |
| `/tmp/poc-headless-gsd-1777376401/codex-test-supplement.log` | Codex 补充测试（字面量 + sandbox 策略）     |

---

## 9.6 Codex 补充测试详解（字面量 + Sandbox 策略）

> **执行者**：Claude Sub Agent (general-purpose)  
> **测试数**：3 个变体  
> **关键变量**：skill 名称传递方式（字面量 vs shell 变量）、sandbox 策略（workspace-write vs danger-full-access）

### 9.6.1 补充测试结果

| 测试  | 命令                                                   | 退出码 | Skill 识别 | 本地执行     | 最终结果                                |
|-------|--------------------------------------------------------|--------|------------|--------------|-----------------------------------------|
| **E** | `codex exec "gsd-verify-work 1"`                       | 0      | ✅ 识别     | ❌ bwrap 阻塞 | 无法读取任何文件                        |
| **F** | `codex exec "gsd-progress"`                            | 0      | ✅ 识别     | ❌ bwrap 阻塞 | 无法读取任何文件                        |
| **G** | `codex exec "gsd-verify-work 1" -s danger-full-access` | 124    | ✅ 识别     | ✅ 完全正常   | **Skill 完整执行到交互输入点，然后超时** |

### 9.6.2 核心发现

#### 发现 1：Shell 变量扩展是之前失败的唯一原因

- `$gsd-verify-work` 在当前 shell 中**未定义**
- 之前的测试 A-D 中，变量扩展为空字符串，导致 prompt 变成 `"-verify-work 1"` 或 `"-progress"`
- 使用**字面量文本** `"gsd-verify-work 1"` 后，Codex 在**所有测试中都能正确识别 skill**
- **结论**：Codex 的 skill 解析机制完全正常，之前的失败是 shell 层面的变量扩展问题

#### 发现 2：`-s danger-full-access` 完全绕过 bwrap 限制

Test G 中，使用 `danger-full-access` sandbox 后：

| 操作                   | 默认 sandbox | danger-full-access       |
|------------------------|--------------|--------------------------|
| 读取 `SKILL.md`        | ❌ bwrap 阻塞 | ✅ 0ms 成功               |
| 读取 `.planning/` 文件 | ❌ bwrap 阻塞 | ✅ 0ms 成功               |
| `git status`           | ❌ bwrap 阻塞 | ✅ 0ms 成功               |
| `ripgrep` 搜索         | ❌ bwrap 阻塞 | ✅ 0ms 成功               |
| `sed`/`wc` 等工具      | ❌ bwrap 阻塞 | ✅ 0ms 成功               |
| `js_repl`              | ❌ bwrap 阻塞 | ✅ 无需使用（shell 已可用） |

**关键日志对比**：

```
# 默认 sandbox
warning: Codex's Linux sandbox uses bubblewrap and needs access to create user namespaces.
js_repl kernel exited unexpectedly: bwrap: setting up uid map: Permission denied

# danger-full-access
sandbox: danger-full-access
/bin/bash -lc "sed -n '1,220p' /home/stark/.codex/skills/gsd-verify-work/SKILL.md"
  succeeded in 0ms:
```

#### 发现 3：即使 sandbox 解决，交互式输入仍是瓶颈

Test G 中，Codex 在 `danger-full-access` 下成功：
1. 读取了 `SKILL.md` 和 `RTK.md`
2. 执行了 `git status`、`ripgrep`、`sed` 等命令
3. 读取了 `.planning/phases/01-test-phase/01-UAT.md`
4. 核对了 `hello.txt` 的存在和内容
5. **然后尝试调用 `request_user_input`**
6. **失败**：`request_user_input is unavailable in Default mode`
7. 命令在 60 秒 timeout 时仍在等待，exit code 124

这说明：**Codex 在 `danger-full-access` 下可以完整执行 GSD skill 的所有文件操作和分析步骤，只是在最后一步的交互确认上受阻。**

#### 发现 4：Codex 比 Claude 更"执着"

Test G 中 Codex 在无头模式下尝试了**多轮交互**：
- 展示检查点 → 请求用户输入 → 工具被拒绝 → 再次尝试
- 消耗了约 60 秒和大量 tokens 后才被 timeout 终止
- 而 Claude Code（测试 A）输出提问后**直接正常退出**（exit 0），不阻塞

这种差异意味着：在自动化脚本中使用 Codex 时，必须显式设置 timeout，否则会长时间挂起。

### 9.6.3 完整决策矩阵

| 条件                                                  | 结果                                               |
|-------------------------------------------------------|----------------------------------------------------|
| `$gsd-verify-work` (变量)                             | ❌ 扩展为空 → 解析失败                              |
| `"gsd-verify-work 1"` (字面量) + 默认 sandbox         | ⚠️ Skill 识别成功，但 bwrap 阻塞所有操作            |
| `"gsd-verify-work 1"` (字面量) + `danger-full-access` | ✅ Skill 完整执行，直到交互输入点                    |
| 交互输入点                                            | ❌ `request_user_input unavailable in Default mode` |

### 9.6.4 对第一轮结论的最终修正

**第一轮报告说**："Codex CLI 在当前环境中因 bubblewrap 的 user namespace 权限问题，完全失去了本地执行能力，这是测试失败的最直接原因。"

**本轮修正**：
- bubblewrap 权限问题**确实存在**，但**可以通过 `-s danger-full-access` 完全绕过**
- 绕过 sandbox 后，Codex 能完整执行 skill 的所有非交互步骤
- **真正的瓶颈不是 sandbox，而是 GSD skill 的交互式设计**（`request_user_input` / `AskUserQuestion`）与无头模式的根本冲突

---

## 10. 附件清单（完整版）

| 文件路径                                                                         | 说明                                  | 轮次   |
|----------------------------------------------------------------------------------|---------------------------------------|--------|
| `/tmp/poc-claude-test.log`                                                       | Claude Code 无头测试完整输出（Kimi）    | 第一轮 |
| `/tmp/poc-codex-test.log`                                                        | Codex CLI 无头测试完整输出（Kimi）      | 第一轮 |
| `/tmp/poc-env-snapshot.log`                                                      | 测试前环境快照                        | 第一轮 |
| `/tmp/poc-headless-gsd-1777376358/.planning/phases/01-poc-hello-world/01-UAT.md` | Claude Code 生成的 UAT 产物           | 第一轮 |
| `/tmp/poc-headless-gsd-1777376401/claude-test.log`                               | Claude Code 扩展测试（3 个变体）        | 第二轮 |
| `/tmp/poc-headless-gsd-1777376401/codex-test.log`                                | Codex CLI 扩展测试（4 个变体）          | 第二轮 |
| `/tmp/poc-headless-gsd-1777376401/codex-test-supplement.log`                     | Codex 补充测试（字面量 + sandbox 策略） | 第二轮 |

---

## 11. 最终结论

### 11.1 无头模式 GSD 执行可行性

| 场景           | Claude Code `-p`                | Codex CLI `exec`                                         |
|----------------|---------------------------------|----------------------------------------------------------|
| **开箱即用**   | ⚠️ Skill 识别成功，但交互阻塞    | ❌ Shell 变量未定义 + bwrap 阻塞                          |
| **配置后可用** | ⚠️ 需 `--auto` 标志或 mock 管道 | ⚠️ 需字面量文本 + `-s danger-full-access` + 处理交互阻塞 |
| **完全自动化** | ❌ 需要 GSD Skill 架构变更       | ❌ 需要 GSD Skill 架构变更                                |

### 11.2 核心瓶颈

**不是 runtime 差异，而是 skill 设计假设**：

所有 GSD skills（`gsd-verify-work`、`gsd-discuss-phase`、`gsd-plan-phase` 等）都内置了 `AskUserQuestion` / `request_user_input` 作为核心工作流步骤。这种设计在交互式终端中非常合理，但在无头模式下形成了**不可逾越的语义断层**——没有用户，就没有回答，UAT 无法闭环。

### 11.3 推荐的 CI/CD 适配路径

1. **短期**：使用 `echo "yes" | claude -p "/gsd-verify-work 1"` 的单轮 mock 管道（仅限简单场景）
2. **中期**：为 GSD 创建 `--auto` / `--batch` 模式，将 `AskUserQuestion` 替换为基于文件检查的自动判断
3. **长期**：将 UAT 拆分为 `generate-uat`（无头生成报告）+ `submit-uat`（交互确认），前者可在 CI 中完全自主运行

---

*报告生成时间: 2026-04-28*  
*第一轮执行者: Kimi Code CLI*  
*第二轮执行者: Claude Code (蕾姆) + Sub Agent 并行*  
*对应文档: `docs/orchestra/poc-headless-gsd-execution.md` (实施方案)*
