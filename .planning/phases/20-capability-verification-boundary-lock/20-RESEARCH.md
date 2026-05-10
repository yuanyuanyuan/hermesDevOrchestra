# Phase 20 Research: Capability Verification & Boundary Lock

**Phase:** 20 — Capability Verification & Boundary Lock  
**Date:** 2026-05-10  
**Status:** Complete

## Research Questions

1. Phase 20 的 capability-verification matrix 到底要覆盖哪些官方能力，才能满足 roadmap 与 phase 19 的约束而不失控扩张？
2. 验证应以哪个版本作为权威锚点：本机安装版本，还是官方文档最新内容？
3. 当前环境下哪些能力适合最小实跑，哪些只能做 hybrid/doc-only 证据？
4. matrix 需要什么字段，才能支撑 “verified / unsupported / local-extension” 判定和 backlog 回写？
5. 执行顺序如何设计，才能避免边验证边改 phase 19 文档造成反复返工？

## Findings

### 1. Phase 20 的首轮能力集合应采用“核心 gating + 辅助声明”两层结构

roadmap 已把 Phase 20 的最小成功面写死为：

- Kanban
- Profile
- Dispatcher
- Curator
- Memory
- Gateway
- Hooks

同时，phase 19 Appendix A 还把下列能力当作“官方已验证”引用：

- `session_search`
- `terminal()`
- `clarify()`
- `skill_manage`
- `approvals.mode`

因此 Phase 20 不应只做 7 个大类名词检查，也不应无边界地把所有 Hermes 文档全盘重验。更合理的 matrix 分层是：

1. **核心 gating rows**：直接覆盖 roadmap Success Criteria 1 指定的 7 个能力面。
2. **辅助声明 rows**：只补 phase 19 已明确依赖、且会影响 v1.3 要求解释的官方 claim，例如 `terminal`、`clarify`、`session_search`、toolsets、`approvals.mode`、`skill_manage`。

这意味着 matrix 的种子不应来自“泛化能力 brainstorming”，而应来自：

- `.planning/phases/19-hermes-workflow-design/DESIGN.md` Appendix A
- `.planning/phases/19-hermes-workflow-design/WORKFLOW-EXPLAINED.md` 中所有 `[Hermes 官方]` 标注
- `.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` R1/R2 以及依赖官方能力成立的 R3-R24 描述

### 2. 版本锚点必须以“当前本机安装版本”为主，官方文档为辅

R1 明确要求 capability verification 证明“该能力在**当前安装的 Hermes Agent 版本**上能跑通最小端到端用例”。因此 Phase 20 的主锚点不能只写“官方文档说有”，必须先锁定本机版本：

- 本机 `hermes --version`：`Hermes Agent v0.13.0 (2026.5.7)`

官方文档仍然必需，但角色是辅助锚点：

- 用来确认命令面、能力命名、官方宣称与 hook 事件名
- 用来覆盖本机明显不适合闭环的能力
- 用来解释 CLI / docs 与本地运行时出现偏差时，偏差来自哪里

因此每个 matrix row 应同时保留两类锚点：

- **runtime anchor**：本地 `hermes --version` 对应的实际运行时
- **doc anchor**：2026-05-10 拉取的 Hermes 官方页面 URL

如果本地运行时与文档冲突，**runtime verdict 优先**，文档只能作为注释，不得覆盖本地失败事实。

### 3. 当前环境已经足以支撑一轮“最小实跑优先”验证，但需要把 mutating probes 隔离到 `/tmp`

当前环境基线：

- `hermes status` 可用
- Gateway service 处于运行中
- 当前 board 只有 `default`
- 当前 profile 只有 `default`
- `hermes hooks list` 显示当前 `~/.hermes/config.yaml` 未配置 shell hooks
- `hermes memory status` 显示 built-in memory 始终启用，外部 provider 当前为 none
- `hermes curator status` 显示 curator enabled、尚无 agent-created skills
- `hermes sessions stats` 显示 session store 正常可读
- `hermes tools list` 显示 `terminal`、`clarify`、`session_search`、`messaging` 等 toolsets 已注册

对执行设计的直接含义如下：

| 能力面 | 当前环境的最小证据路径 | 证据等级建议 | 备注 |
|--------|------------------------|--------------|------|
| Kanban | `init/boards/create/link/show/comment/block/unblock/complete` on temp board | runtime | 最适合本地实跑 |
| Profile | `list/create/show/use` on temp `HERMES_HOME` | runtime | 可完全隔离到 `/tmp` |
| Curator | `status` 必跑；`run/pin/archive` 可在 temp `HERMES_HOME` 做最小闭环 | runtime / hybrid | 不要污染真实 `~/.hermes/skills/` |
| Memory | `status`、`off/reset/setup` 可做部分验证 | runtime / hybrid | 外部 provider 集成不必在本 phase 深挖 |
| Gateway | `status/list/start/stop` 可做服务级验证 | hybrid | 当前未配置消息平台，无法做真实消息投递 |
| Hooks | `hooks list/doctor/test` + temp hook config | hybrid | 事件名与插件 API 仍需官方 docs 辅证 |
| Dispatcher | `kanban dispatch` 相关最小任务流可尝试 | runtime / fallback hybrid | 真实 worker spawn 受 provider/profile 影响，需独立容错 |
| Tools / toolsets | `hermes tools list` + 官方 tools/toolsets docs | hybrid | 适合覆盖 `terminal`/`clarify`/`session_search` 的官方存在性 |
| `skill_manage` | 官方 docs + live agent surface | doc-only / fallback backlog | 当前 CLI 不直接暴露该 tool，需避免伪验证 |
| `approvals.mode` | 官方 docs + config surface | doc-only / hybrid | 属于官方命令审批层，不必伪装成本地端到端 |

最关键的操作边界是：

- **所有会修改 board/profile/hook/config/skill 状态的验证，都应优先在 `/tmp` 下的临时 `HERMES_HOME` 内执行。**
- 只读探测（如 `hermes --version`、`hermes status`、`hermes tools list`、`hermes sessions stats`）可以使用现有环境。

### 4. Dispatcher、Gateway、Hooks 不能被粗暴地当作“纯本地实跑”或“纯文档验证”

这三个能力面的证据形态都更适合 **hybrid**：

- **Dispatcher**：命令面与 “dispatcher now runs in the gateway” 关系可由 CLI / docs 证明；真正的 ready→running→worker outcome 则受 provider、profile、prompt 与 gateway 状态影响，应作为单独 row 处理。
- **Gateway**：服务存在、命令存在、status 正常，可本地证明；但多平台投递因平台未配置，不应强行判为 unsupported。
- **Hooks**：当前用户配置里没有 hook，不等于 Hermes 不支持 hook；应通过 temp config 做 framework-level closure，再用官方 Event Hooks 页面锁定 `pre_tool_call` / `post_tool_call` / `on_session_end` 名称与注册方式。

因此 Phase 20 的 verdict 需要和 evidence class 分离：

- verdict：`verified` / `unsupported` / `local-extension`
- evidence class：`runtime` / `hybrid` / `doc-only`

### 5. `skill_manage` 应被视为高风险 claim，优先进入“单独行、允许回退”的处理方式

phase 19 Appendix A 把 `skill_manage` 直接标成“✅ Phase 0 验证”，但当前本机 CLI 证据并不直接暴露这一 tool。已有官方配置文档会提到 `~/.hermes/skills/` 由 `skill_manage` 管理，但这更接近文档存在性，而非“当前环境最小可运行证据”。

因此最稳妥的处理不是硬判：

- 不要把 `skill_manage` 混在 Curator row 里一并算 verified
- 给它单独 matrix row
- 优先收集 docs + live runtime surface 能提供的最强证据
- 若仍不能达到 R1 的证据标准，则把“skill_manage 作为 phase 19 官方已验证 claim”降级为 `local-extension` 或 `unsupported-claim rewrite` 入口，并把后续工作写入 backlog

### 6. 官方文档的最小引用面已足够支撑 Phase 20 研究与计划

根据 `reference/hermes-docs-index/` 的 index-first 流程，Phase 20 至少需要引用这些官方页面：

- `https://hermes-agent.nousresearch.com/docs/reference/cli-commands`
- `https://hermes-agent.nousresearch.com/docs/reference/profile-commands`
- `https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban`
- `https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks`
- `https://hermes-agent.nousresearch.com/docs/reference/tools-reference`
- `https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference`

这些页面已经足以确认：

- CLI 顶层命令面存在 `gateway / kanban / hooks / curator / memory / tools / sessions / profile`
- Kanban 文档覆盖 board、task、dispatcher 语义
- Hooks 文档覆盖 `pre_tool_call`、`post_tool_call`、`on_session_end` 等事件名与注册方式
- tools/toolsets 文档覆盖 `terminal`、`clarify`、`session_search` 等官方工具面

Phase 20 不需要在 research 阶段额外扩张到 provider、TTS、voice、browser 等无关页面。

## Recommended Matrix Shape

建议 `20-CAPABILITY-MATRIX.md` 至少包含这些列：

| 列名 | 用途 |
|------|------|
| `claim_id` | 稳定引用，例如 `KANBAN-LINK`、`HOOK-POST-TOOL-CALL` |
| `capability_area` | Kanban / Profile / Dispatcher / Curator / Memory / Gateway / Hooks / Tools |
| `phase19_ref` | 指向 Phase 19 原 claim 所在文件和段落 |
| `official_source` | CLI help、官方 docs URL 或两者 |
| `runtime_anchor` | 本机 `Hermes Agent v0.13.0 (2026.5.7)` |
| `local_feasible` | `yes` / `partial` / `no` |
| `evidence_class` | `runtime` / `hybrid` / `doc-only` |
| `command_or_probe` | 实际执行的命令或探测方式 |
| `exit_code` | 命令退出码 |
| `key_output` | 关键输出片段 |
| `verdict` | `verified` / `unsupported` / `local-extension` |
| `writeback_target` | 需要修改的 phase 19 文件或条目 |
| `backlog_ref` | 若失败，写入 `.planning/ROADMAP.md` 的 backlog 标识 |

这个 schema 可以直接支撑 D-20-03 到 D-20-06。

## Recommended Implementation

1. 先从 Appendix A 与 `[Hermes 官方]` 标注生成 matrix skeleton，只做 claim inventory，不做 verdict。
2. 对 **Kanban / Profile / Curator / Memory / Tools / Sessions** 这类低风险能力先做本地实跑或只读探测，尽快积累稳定 runtime evidence。
3. 对 **Dispatcher / Gateway / Hooks / approvals.mode / skill_manage** 做独立行处理，把 hybrid 与 doc-only 边界说清，不要伪造“已实跑”。
4. 仅在 matrix verdict 稳定后，回写 `.planning/phases/19-hermes-workflow-design/` 下的 claim 标记与需求归类。
5. 所有 unsupported 或被降级的官方 claim 都必须同步生成 roadmap backlog 入口，再允许标记 VFY-01 / VFY-02 complete。

## Validation Architecture

### Quick Baseline Probes

这些命令已经证明本地 Phase 20 执行前提成立，可直接纳入后续 matrix 证据或 wave 0：

```bash
rtk hermes --version
rtk hermes status
rtk hermes kanban boards list
rtk hermes profile list
rtk hermes curator status
rtk hermes memory status
rtk hermes hooks list
rtk hermes sessions stats
rtk hermes tools list
```

### Execution Isolation Rule

所有 mutating 验证默认放在临时环境：

```bash
export HERMES_HOME=/tmp/hermes-phase20-home
export HERMES_KANBAN_BOARD=phase20-matrix
```

如果某条验证必须依赖当前真实安装态（例如 gateway service status、现有 provider auth），则只允许做最小只读探测，不允许在真实 `~/.hermes/` 下做破坏性试验。

## Risks

| Risk | Mitigation |
|------|------------|
| 将“官方 docs 中存在”误判成“本机当前版本已可运行”。 | matrix 强制区分 runtime anchor、doc anchor 和 evidence class。 |
| 为了凑通过率，把 Gateway/Dispatcher/Hooks 伪装成本地闭环。 | 允许 hybrid verdict，但不允许把 doc-only 写成 runtime。 |
| Phase 20 过程中污染用户真实 `~/.hermes/` 配置。 | 一切 mutating probe 默认切到 `/tmp` 的 `HERMES_HOME`。 |
| `skill_manage` 证据不足却被沿用为“官方已验证”。 | 单独 row，必要时降级并写 roadmap backlog。 |
| matrix 与 phase 19 文档同时改动导致 verdict 漂移。 | 严格遵守 matrix-first，再统一 writeback。 |

## Research Complete

Phase 20 可以作为单个 matrix-first documentation-and-verification plan 执行。关键决策已经明确：

- 能力集合采用“核心 gating + 辅助声明”两层结构
- 版本锚点以本机 `Hermes Agent v0.13.0 (2026.5.7)` 为主
- Gateway / Dispatcher / Hooks 默认按 hybrid 证据路径处理
- `skill_manage` 单独处理，不得借位通过
- 所有失败项自动进入 `.planning/ROADMAP.md` backlog
