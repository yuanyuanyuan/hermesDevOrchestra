# Hermes 官方能力 Double Check 报告

> **调查时间**: 2026-05-10  
> **调查范围**: Hermes Agent 官方文档（540 页）+ GitHub issues/releases + 本地代码库  
> **目的**: 验证 `ascii-decision-matrix.md` 中 Worker/Dispatcher/Gateway/L1-L2-L3/Sentinel/Risk Policy 等概念在 Hermes 官方系统中的实际存在性，区分"已实现"与"需自建"。

---

## 一、调查方法

### 1.1 官方文档索引检索
- 数据源: `reference/hermes-docs-index/hermes_docs_index.json`（540 页，2026-05-09 索引）
- 检索关键词: `worker`, `dispatcher`, `orchestrator`, `gateway`, `sentinel`, `risk`, `policy`, `approval`, `gate`, `guard`, `L1`, `L2`, `L3`, `hard gate`
- 结果验证: 对高匹配页面使用 `FetchURL` 获取完整原文

### 1.2 本地代码库搜索
- 搜索范围: `/data/hermes` 全目录（含 `.py`, `.yaml`, `.yml`, `.json`, `.md`）
- 搜索关键词: `sentinel`, `HERMES_RISK`, `risk_policy`, `hard gate`, `L1.*Worker`, `L2.*Reviewer`, `L3.*CEO`

### 1.3 Web 搜索（GitHub issues + releases）
- 搜索范围: `github.com/NousResearch/hermes-agent`
- 搜索关键词: `approval gate`, `sentinel`, `risk policy`, `L1 L2 L3`, `kanban orchestrator`

---

## 二、概念逐一验证

### 2.1 Worker — ✅ 官方已实现

| 维度 | 验证结果 |
|---|---|
| 官方文档 | **有** — Kanban 文档 "How workers interact with the board" 章节 |
| 官方 Skill | **有** — `kanban-worker`（bundled skill，随安装同步） |
| 实现方式 | Dispatcher 通过 `subprocess.Popen` spawn 指定 profile 的 Hermes 进程，注入 `HERMES_KANBAN_TASK` 环境变量，Worker 通过 `kanban_*` 工具集（`kanban_show`, `kanban_complete`, `kanban_block`, `kanban_heartbeat` 等）与看板交互 |
| 原文引用 | *"When the dispatcher spawns a worker it sets `HERMES_KANBAN_TASK=t_abcd` in the child's env, and that env var flips on a dedicated **kanban toolset** in the model's schema"* |

**结论**: Worker 是 Hermes 官方 Kanban 系统的核心组件，已完全实现。

---

### 2.2 Dispatcher — ✅ 官方已实现

| 维度 | 验证结果 |
|---|---|
| 官方文档 | **有** — Kanban 文档 "Gateway-embedded dispatcher (default)" 章节 |
| 实现位置 | 内嵌在 `gateway/run.py` 的 `GatewayRunner` 中 |
| 运行机制 | 每 `dispatch_interval_seconds`（默认 60s）tick 一次：回收僵死 claim、回收崩溃 Worker、提升依赖就绪任务、原子性 claim、spawn Worker |
| 配置项 | `kanban.dispatch_in_gateway: true`（默认） |
| 原文引用 | *"The dispatcher runs inside the gateway process... every N seconds (default 60): reclaims stale claims, reclaims crashed workers, promotes ready tasks, atomically claims, spawns assigned profiles"* |

**结论**: Dispatcher 是官方已实现的组件，默认内嵌于 Gateway。

---

### 2.3 Gateway — ✅ 官方已实现

| 维度 | 验证结果 |
|---|---|
| 官方文档 | **有** — "Gateway Internals" 文档（Architecture 中也有概述） |
| 实现位置 | `gateway/run.py` — `GatewayRunner`（~12,000 行） |
| 平台适配器 | 20 个：telegram, discord, slack, whatsapp, signal, matrix, mattermost, email, sms, dingtalk, feishu, wecom, weixin, bluebubbles, qqbot, webhook, api_server, homeassistant, yuanbao |
| 核心功能 | 消息收发、SessionStore 持久化、用户授权（allowlist + DM pairing）、Slash Command 分发、Cron ticking、Hooks、内嵌 Dispatcher |
| 原文引用 | *"Long-running process with 20 platform adapters, unified session routing, user authorization, slash command dispatch, hook system, cron ticking, and background maintenance"* |

**结论**: Gateway 是官方最成熟的核心组件之一。

---

### 2.4 L1/L2/L3 风险分级 — ❌ 官方不存在

| 维度 | 验证结果 |
|---|---|
| 官方文档索引（540 页） | **0 命中** — `L1`, `L2`, `L3` 作为风险/审批分级无任何匹配 |
| 本地代码库 | **0 命中** — 无 `.py`/`.yaml` 文件包含 L1/L2/L3 风险分级逻辑 |
| GitHub issues/releases | **0 命中** — 无相关功能请求或实现 |
| 官方实际使用的 L0-L3 | 官方在其他场景使用了 L0-L3，但**含义完全不同**： |
| | • Issue #344: L0-L3 = **上下文共享级别**（隔离→结果传递→共享草稿→实时对话） |
| | • Issue #5701: L1-L3 = **上下文压缩级别**（详细→要点→截断） |
| | • Issue #19546: L0-L4 = **记忆层级**（即时→情景→程序→语义→身份） |

**结论**: L1（Worker 自行决定）/ L2（Reviewer Hard Gate）/ L3（CEO 用户决策）的三级风险分级是**本项目设计文档的独创概念**，Hermes 官方没有任何对应实现。

---

### 2.5 Risk Policy YAML — ❌ 官方不存在

| 维度 | 验证结果 |
|---|---|
| 官方文档索引 | **0 命中** — `risk_policy`, `risk.yaml`, `HERMES_RISK_POLICY` 无任何匹配 |
| 本地代码库 | **0 命中** — 无实际代码文件包含这些关键词（仅 `.planning/` 设计文档和索引批次文件） |
| GitHub issues/releases | **0 命中** |
| 官方实际的安全配置 | `~/.hermes/config.yaml` 中仅有 `approvals.mode`（manual/smart/off）和 `command_allowlist`，无分级策略配置 |

**结论**: `policies/risk.yaml` 声明式风险策略引擎是**本项目设计文档的独创**，Hermes 官方无此机制。

---

### 2.6 Sentinel 统一拦截 — ❌ 官方不存在

| 维度 | 验证结果 |
|---|---|
| 官方文档索引 | **0 命中** |
| 本地代码库 | **0 命中** — 无任何 `.py`/`.yaml`/`.json` 文件包含 `sentinel` 作为安全组件 |
| GitHub issues/releases | **0 命中** |

**结论**: Sentinel 组件是**本项目设计文档的独创**，Hermes 官方无此组件。

---

### 2.7 Reviewer Hard Gate — ⚠️ 部分存在（Skill 软约定，非 Kernel 硬门）

| 维度 | 验证结果 |
|---|---|
| 官方 Skill | **有** — `kanban-orchestrator` skill 中定义了 `reviewer` profile |
| 角色定义 | *"`reviewer` — Reads output, leaves findings, **gates approval**"* |
| 实现性质 | **软约定**（convention），非 kernel 强制： |
| | • `reviewer` 只是建议的 profile 名称，可替换为 `audit`、`qa` 等 |
| | • 无 kernel 机制阻止 reviewer 不通过时任务自动继续 |
| | • 通过 `kanban_link(parents=[reviewer_task])` 实现顺序依赖，属于 task graph 层面 |
| `delegate_task` 子代理 | 可实现只读审查（限制 `toolsets`），但无"Hard Gate"概念 |

**结论**: Reviewer 角色在官方 Kanban 中以 Skill 约定形式存在，但**没有 "Hard Gate" 这种 kernel 级别的强制拦截机制**。

---

### 2.8 "Approval Gate" 这个词的官方用法 — ⚠️ 存在但含义不同

| 官方出处 | "Approval Gate" 实际含义 | 与本项目设计的区别 |
|---|---|---|
| Issue #10639 | **危险命令审批门**：Agent 调用 `terminal_tool` 时，`check_all_command_guards()` 做 regex 匹配，触发 `/approve` | 单层拦截，无分级 |
| Issue #4542 | Gateway 中 `/approve` 命令的 bug 修复 | 同上 |
| Issue #13124 | Discord outbound 消息审批：发消息前 DM 管理员确认 | 消息层面，非任务决策 |
| **RFC #16102** | **明确列为 v1 不做**：*"Deliberately not in v1: ... **approval gates** ... All user-space (plugins or profile conventions)"* | 官方明确说 approval gates 属于 user-space |

**关键发现**: Hermes 官方 RFC #16102 明确将 "approval gates" 列为 **v1 不实现** 的功能，并指明应由社区通过 **plugins 或 profile conventions** 自行构建。

---

## 三、Hermes 官方实际的安全/审批机制

作为对比，以下是 Hermes **实际**的安全模型（两层）：

### 第一层：Hardline Blocklist（永远拦截，无覆盖）

- 实现: `tools/approval.py::UNRECOVERABLE_BLOCKLIST`
- 覆盖: `rm -rf /`, fork bomb, `mkfs.*`, `dd if=/dev/zero of=/dev/sd*`, `curl ... | sh` 等
- 特性: **不可覆盖**，即使 `--yolo` 或 `approvals.mode: off` 也拦截

### 第二层：Dangerous Command Approval（可配置）

- 配置: `~/.hermes/config.yaml` 中 `approvals.mode`
- 三种模式:
  - `manual`（默认）：匹配 `DANGEROUS_PATTERNS` 时提示用户审批
  - `smart`：辅助 LLM 评估，低危自动通过，高危自动拒绝，不确定时人工提示
  - `off`：关闭所有审批（等价于 `--yolo`）
- 触发模式: `rm -r`, `chmod 777`, `DROP TABLE`, `curl | sh`, `systemctl stop` 等 30+ 种
- 审批方式:
  - CLI: 交互式 `[o]nce | [s]ession | [a]lways | [d]eny`
  - Gateway: 用户回复 `yes`/`no` 或点击 Approval Buttons（Slack/Telegram/Feishu）

**与 L1/L2/L3 的核心区别**: 官方机制是**命令级**的危险拦截，而本项目设计的是**任务级**的分级决策系统（变量命名→AI 自定、API 设计→Reviewer 审查、删库→用户决策）。

---

## 四、 verdict 总表

| 本项目设计概念 | Hermes 官方是否有？ | 实际对应 | 实现 verdict |
|---|---|---|---|
| **Worker** | ✅ 有 | Kanban Worker（`kanban-worker` skill + `kanban_*` 工具集） | 已完全实现 |
| **Dispatcher** | ✅ 有 | Gateway 内嵌调度循环（`kanban.dispatch_in_gateway: true`） | 已完全实现 |
| **Gateway** | ✅ 有 | `GatewayRunner`（20+ 平台适配器） | 已完全实现 |
| **L1 Worker 自行决定** | ❌ 无 | — | 需自建 |
| **L2 Reviewer Hard Gate** | ⚠️ 软约定有，硬门无 | `kanban-orchestrator` 中的 reviewer profile 约定 | 需自建 kernel 强制门 |
| **L3 CEO 用户决策** | ❌ 无 | — | 需自建 |
| **Risk Policy YAML** | ❌ 无 | — | 需自建 |
| **Sentinel 统一拦截** | ❌ 无 | — | 需自建 |
| **"Approval Gate" 机制** | ⚠️ 有但含义不同 | 危险命令审批（`DANGEROUS_PATTERNS`）+ RFC 明确列为 v1 不做 | 需自建任务级 gate |

---

## 五、推荐的自建实现路径

基于 Hermes 官方给出的扩展点（RFC #16102 明确 approval gates 属于 user-space），建议通过以下路径实现：

### 路径 A：Plugin 层（推荐）

```
plugins/risk-gate/
├── manifest.json          # plugin 注册
├── pre_tool_call.py       # 在 invoke_hook("pre_tool_call") 中拦截
└── risk_policy.py         # 读取 policies/risk.yaml，匹配 pattern → 分级
```

- 优点: 与 Hermes 核心解耦，升级安全
- 利用点: `ToolRegistry` 的 `pre_tool_call` hook 可拦截所有工具调用

### 路径 B：Skill 层

- `risk-policy` skill: 注入 system prompt，让 Worker 自我评估风险级别
- `kanban-reviewer-gate` skill: 扩展 `kanban-orchestrator`，在分解剧本中强制插入 reviewer 任务并设置 `parents` 依赖

### 路径 C：扩展 `tools/approval.py`

- 在现有 `DANGEROUS_PATTERNS` 基础上增加分级逻辑
- 但此路径会触及核心代码，与官方升级冲突风险较高

---

## 六、验证数据来源清单

| 数据类型 | 来源 | 时间戳 |
|---|---|---|
| 官方文档索引 | `reference/hermes-docs-index/hermes_docs_index.json` | 2026-05-09 |
| 官方文档原文 | `FetchURL` 获取: Gateway Internals, Architecture, Kanban, Security, Tools Runtime, Subagent Delegation | 2026-05-10 |
| 本地代码库搜索 | `/data/hermes` 全目录 `grep -ri`（`.py`, `.yaml`, `.yml`, `.json`, `.md`） | 2026-05-10 |
| GitHub issues/releases | Web 搜索: `site:github.com/NousResearch/hermes-agent` + 关键词 | 2026-05-10 |
| 官方 Kanban RFC | GitHub Issue #16102 (RFC: review the Kanban) | 2026-04-26 |

---

## 七、关键发现摘要

1. **Worker/Dispatcher/Gateway 是官方已实现的核心组件**，本项目的设计与官方实现高度对齐。
2. **L1/L2/L3 风险分级、Risk Policy YAML、Sentinel 是本项目的设计独创**，Hermes 官方无任何对应实现。
3. **Reviewer 角色在官方 Kanban 中以 Skill 软约定存在**，但无 kernel 级别的强制拦截。
4. **Hermes 官方 RFC #16102 明确将 "approval gates" 列为 v1 不实现的功能**，并指明应通过 plugins 或 profile conventions 在 user-space 构建——这实际上为社区实现此类功能开了绿灯。
5. **Hermes 当前的安全模型只有两层**（Hardline Blocklist + Dangerous Command Approval），属于命令级拦截，而非任务级分级决策。

---

*报告生成于 2026-05-10。如需对特定概念做更深度的源码级验证，可进一步 checkout Hermes 官方仓库进行 AST/符号分析。*
