# Phase 24: Risk Policy & Role Guardrails - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-11
**Phase:** 24-risk-policy-role-guardrails
**Areas discussed:** 风险分级边界, Reviewer/Orchestrator 护栏, Implementer 强制 block 契约, L1/L2 分界, L4 确认形式, policy 文件结构

---

## 风险分级边界

| Option | Description | Selected |
|--------|-------------|----------|
| 继续四层 | `L1/L2/L3/L4` 都继续作为正式语义保留 | ✓ |
| 三层为主，四层兼容 | 新规则只写三层，旧 `L4` 作为兼容别名归一到最高阻塞层 | |
| 彻底三层化 | 文档、脚本、策略都统一成三层，不保留 `L4` | |

**User's choice:** 继续四层  
**Notes:** 用户明确接受四层风险分级，不希望在 Phase 24 把 `L4` 抹平为纯兼容层。

---

## L3 与 L4 的行为差异

| Option | Description | Selected |
|--------|-------------|----------|
| 行为完全一样 | `L3/L4` 都是一次批准即可继续，只在审计严重度上区分 | |
| `L4` 更严格 | `L3` 一次批准即可继续；`L4` 需要更强确认 | ✓ |
| `L4` 只能修订后重提 | 第一次永不直接放行，必须改写方案后再审批 | |

**User's choice:** `L4` 更严格  
**Notes:** 用户接受 `L4` 和 `L3` 有不同交互强度，避免把两层做成“只有名字不同”。

---

## L4 范围

| Option | Description | Selected |
|--------|-------------|----------|
| 宽范围 L4 | 只要高破坏性、高不可逆都可进 `L4` | |
| 窄范围事故按钮 | `L4` 只保留给删库、删生产资源、关键分支强推、不可逆大删这类事故按钮 | ✓ |
| 只限生产环境 | 仅生产破坏性操作才允许 `L4`，开发环境最高到 `L3` | |

**User's choice:** 窄范围事故按钮  
**Notes:** 用户希望 `L4` 非常稀有，避免把大量高风险操作全塞进最高级。

---

## Reviewer / Orchestrator 护栏层次

| Option | Description | Selected |
|--------|-------------|----------|
| 主要靠 prompt/SOUL | 只通过文字约束角色行为 | |
| 三层一起上但有主次 | 主防线是 toolset/CLI allowlist，次防线是 hook，外层是 SOUL/skill | ✓ |
| 只靠硬拦截 | 主要靠 allowlist + hook，不强调 prompt/skill 层 | |

**User's choice:** 三层一起上，但有主次  
**Notes:** 用户接受 prompt 层只做提醒，不把它当作主防线。

---

## Implementer 强制 block 契约

| Option | Description | Selected |
|--------|-------------|----------|
| 最小清单 | 只保留四类强制 block 触发项 | |
| 最小清单 + 禁止绕过 | 四类强制 block 触发项固定，并明确不得自行降级绕过 | ✓ |
| 扩大清单 | 在四类基础上继续纳入需求歧义、review findings 冲突等 | |

**User's choice:** 最小清单 + 禁止绕过  
**Notes:** 用户要求 Implementer 不得擅自改走“低风险替代路径”来逃避 `kanban_block`。

---

## L1 / L2 分界

| Option | Description | Selected |
|--------|-------------|----------|
| 按风险大小粗分 | 只给规则作者留出宽泛判断空间 | |
| `L1=记录级`、`L2=介入级` | `L1` 只记录/通知；`L2` 需要 supervisor/orchestrator 明确介入 | ✓ |
| `L2` 直接 block | 从 `L2` 开始就先停住再处理 | |

**User's choice:** `L1=记录级`、`L2=介入级`  
**Notes:** 用户希望 `L2` 比 `L1` 更强，但不要直接把 `L2` 全部升级成 block。

---

## L2 介入后的允许动作

| Option | Description | Selected |
|--------|-------------|----------|
| 只告警继续 | 只通知，不改任务流 | |
| 可改任务流但不能降级高风险 | 可暂停扩散、补任务、补证据，但不能把应进 `L3/L4` 的事按 `L2` 偷放 | ✓ |
| 一律先停住 | 所有 `L2` 都先 block，再由 supervisor/orchestrator 处理 | |

**User's choice:** 可改任务流但不能降级高风险  
**Notes:** 用户允许 `L2` 触发审查和补充任务，但不允许它成为“高风险绕行口”。

---

## L4 确认形式

| Option | Description | Selected |
|--------|-------------|----------|
| 不统一 | 每次动态生成确认文案 | |
| 统一固定格式 | 使用固定确认词，绑定 `approval_id` | ✓ |
| 半固定 | 固定前缀，后半段可变 | |

**User's choice:** 统一固定格式  
**Notes:** 用户接受固定确认词，以便减少手滑并让审计和测试稳定。

---

## Policy 文件结构

| Option | Description | Selected |
|--------|-------------|----------|
| 一份平铺 YAML | 所有规则平铺在一个文件里 | |
| 一份 YAML，按公共规则 + role 分支 + level 分段组织 | 一套 policy 文件，但结构化区分共享规则、角色特例和层级语义 | ✓ |
| 多文件拆分 | 公共规则和每个角色拆成多个文件 | |

**User's choice:** 一份 YAML，按公共规则 + role 分支 + level 分段组织  
**Notes:** 用户希望保留单一 policy surface，避免 reviewer/orchestrator 两套规则未来漂移。

---

## the agent's Discretion

- `L4` 固定确认词的精确文案尚未锁定，交由 planning/research 细化，只要求固定格式且绑定 `approval_id`。
- Policy 文件的精确路径与字段命名尚未锁定，交由 planning/research 在单一 canonical policy surface 前提下决定。

## Deferred Ideas

- None — discussion stayed within phase scope.
