---
title: REQUIREMENTS.md REV2 差量补丁草稿
date: 2026-05-09
context: phase-19-hermes-workflow-design
source: /gsd-explore reflexion on REQUIREMENTS.md
status: draft (no edits applied to REQUIREMENTS.md yet)
companion: explore-pressure-test-r4-r5-r7-r10.md
---

# REQUIREMENTS.md REV2 差量补丁

本文档列出对 `/data/hermes/.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md` 的精确差量补丁，源自 `/gsd-explore` 的 4 轮反例压测。**不直接修改主文件**——审阅通过后由您决定 apply 方式（建议另存为 `REQUIREMENTS-REV2.md`，与项目已有的 `REQUIREMENTS-REV1.md` 命名一致）。

每条修改给出：
- **位置**（原文件行号）
- **类型**（改写 / 收缩 / 扩展 / 新增 / 保留）
- **改前 / 改后**（精确文本对比）
- **理由摘要**（详见 `explore-pressure-test-r4-r5-r7-r10.md`）

---

## 改动 1：R4 改写（line 75）

**类型**：改写（触发条件重新定义）

**改前**：
```
R4. Worker 进程崩溃时（PID 不存在或心跳超时），系统必须将该 worker 占用的 git worktree 恢复到任务开始前的干净状态，再由 dispatcher 将任务回退到 ready 重新派发。
```

**改后**：
```
R4. Worker 任务需要回收时（PID 不存在 OR 任务执行超出声明的 expected_duration_max OR 用户/orchestrator 主动 cancel），系统必须将该 worker 占用的 git worktree 恢复到任务开始前的干净状态，再由 dispatcher 将任务回退到 ready 重新派发。
```

**理由**：选定"心跳进程化"（反例 #1），原"心跳超时"语义与"PID 不存在"等价，需以任务级 timeout / 主动 cancel 替代。

---

## 改动 2：R8 收缩（line 79）

**类型**：收缩（兜底语义）

**改前**：
```
R8. 当 reviewer profile 调用 terminal 工具时，所有写操作（rm / write / git push / DROP TABLE 等）必须被技术性拦截而非仅靠 SOUL.md prompt 约束；拦截行为可配置为 dry-run 返回或直接拒绝；所有拦截事件必须写入审计日志。
```

**改后**：
```
R8. 在 R10 白名单基础上，若 reviewer profile 的白名单中包含 terminal 工具（如审查时需运行 lint / typecheck），terminal 工具的所有写操作（rm / write / git push / DROP TABLE 等）必须被技术性拦截而非仅靠 SOUL.md prompt 约束；拦截行为可配置为 dry-run 返回或直接拒绝；所有拦截事件必须写入审计日志。R8 作为白名单内 terminal abuse 的兜底，不是 reviewer 写防护的主防线（主防线见 R10）。
```

**理由**：R8 原文是"黑名单 + 单工具屏蔽"，无法覆盖 file_write / web_fetch / memory_write 等其他写路径（反例 #2）。降级为白名单内 terminal 兜底。

---

## 改动 3：R10 改写（line 84）

**类型**：改写（黑名单 → 白名单）

**改前**：
```
R10. Reviewer profile 的 SOUL.md 必须声明"只读"立场：禁止任何写操作、禁止 `code_execution` 工具集；该声明与 R8 的技术拦截配合形成"prompt + 技术"双层约束。
```

**改后**：
```
R10. Reviewer profile 的 toolsets 配置必须采用白名单显式列举形式，仅 enable 必需的只读 + kanban 写工具集（默认白名单：`file_read` / `kanban_read` / `kanban_block` / `kanban_complete` / `clarify`），其他 toolsets 默认 disabled。Hermes Agent 升级引入新 toolset 时，必须经过显式审计才能加入 reviewer 白名单。Reviewer 的 SOUL.md 须声明"只读"立场作为 prompt 层强化，与 toolsets 白名单（主防线）+ R8 terminal 兜底（次防线）形成纵深防御。
```

**理由**：黑名单（disabled `code_execution`）+ pattern 拦截（R8 terminal）只锁住 reviewer 可用工具的小部分写路径（反例 #2）。改为白名单收口为根本解决。

---

## 改动 4：R12 改写（line 86）

**类型**：改写（心跳契约语义重新定义）

**改前**：
```
R12. Worker skill 必须为长任务（执行预期 >2 分钟）定义心跳节奏契约，心跳间隔不得超过 dispatcher 的 stale claim 阈值的一半。
```

**改后**：
```
R12. Worker skill 必须为每个任务在 task metadata 中声明 `expected_duration_max`（任务的最大合理执行时长），dispatcher 据此触发 R4 的任务级 timeout 流程。Worker 进程的存活通过 OS 进程级别（PID 探测 + 进程级 keep-alive 信号）判定，不再要求任务循环显式调用 heartbeat API。
```

**理由**：反例 #1 选定 (a) 进程活着即心跳后，原 50% 节奏契约失去语义。改为任务级时长声明。

---

## 改动 5：R13 扩展（line 87）

**类型**：扩展（结构校验 → 结构 + 值校验）

**改前**：
```
R13. Worker skill 必须为 `kanban_complete` 定义结构化 handoff metadata 形态，至少包含 changed_files、tests_run、tests_passed、decisions、pitfalls 五个字段（具体 schema 留给 ce-plan）。
```

**改后**：
```
R13. Worker skill 必须为 `kanban_complete` 定义结构化 handoff metadata 形态，至少包含 changed_files、tests_run、tests_passed、decisions、pitfalls 五个字段（具体 schema 留给 ce-plan）。schema 校验必须覆盖字段值的安全性：decisions / pitfalls 等自由文本字段不允许包含可执行 payload 模式（shebang / bash heredoc / 含 auth token 的 URL / shell 命令注入元字符等），由 ce-plan 阶段定义具体过滤清单。
```

**理由**：handoff metadata 是 reviewer / 上游 implementer 向下游 worker 投毒的合法路径（反例 #2 子场景），仅有结构约束不足。

---

## 改动 6：新增 R15（line 89 之后）

**类型**：新增

**新增内容**：
```
- R15. Dispatcher 必须支持任务级 timeout：基于 task metadata 中的 `expected_duration_max` 字段，超时后触发 R4 的 dirty-state cleanup 与 ready 重派流程。timeout 默认值（按 profile 给保守值，如 implementer 60min / reviewer 10min）由 ce-plan 阶段确定。
```

**理由**：闭合反例 #1 中"心跳进程化后软死锁无回收机制"的漏洞。配合 R4 / R12 的改写形成完整任务生命周期管理。

---

## 改动 7：新增 R16（line 89 之后）

**类型**：新增

**新增内容**：
```
- R16. 下游 worker（任意 profile）读取 parent task 的 handoff metadata 时，必须将 metadata 标注为 untrusted input：在 LLM 上下文中使用专用包裹标签（如 `<untrusted-handoff source="<parent_task_id>">…</untrusted-handoff>`）隔离，禁止将 metadata 内容直接拼接到指令性 prompt；worker skill 必须显式声明对 untrusted-handoff 内容的处理边界（仅作为参考信息使用，不作为指令源）。
```

**理由**：闭合反例 #2 中 reviewer 通过 handoff metadata 对下游 implementer 进行 prompt injection 的灰色路径。

---

## 改动 8：R7 拆分扩展（line 78 之后）

**类型**：保留 R7 + 新增 R7b / R7c / R7d / R7e

**R7 保留原文**（line 78 不动）：
```
- R7. Learnings/memory 默认必须写入"项目专属"命名空间；只有显式标记 cross-project 且通过 curator 审核的条目才进入"全局"命名空间；agent 查找时项目命名空间优先于全局。
```

**新增 R7b**（同主题合并）：
```
- R7b. Curator 必须支持基于语义相似度的"同主题 learning"识别：当多个项目命名空间的 learning 在主题与建议上相似度超过阈值（具体值留 ce-plan）时，curator 必须主动触发合并流程或生成跨项目复审 task；不允许"5 个项目独立记录同一条经验"长期沉默存在。
```

**新增 R7c**（矛盾浮现）：
```
- R7c. 当 agent 查询 learning 时，若项目命名空间条目与全局命名空间条目在主题相似但内容矛盾，查询结果必须显式包含 `<conflict_warning>` 元数据（含两端条目摘要）；agent 不允许沉默选用项目版本而忽略全局矛盾。
```

**新增 R7d**（删除传染）：
```
- R7d. Learning 删除必须显式声明传染范围之一：(a) 仅本项目（默认）(b) 本项目 + 触发其他项目对同主题条目的复审（curator 派发 review task）(c) 全局回退（必须经 curator 二次审核与用户/orchestrator 确认）。不允许"沉默删除"——即不允许仅删除项目条目而绕过对应全局条目的状态评估。
```

**新增 R7e**（晋升源责任）：
```
- R7e. "cross-project" 标记仅允许由 orchestrator profile 或用户显式标注；worker（implementer / reviewer）调用 `memory_promote(cross_project=True)` 等 API 必须被 curator 拒绝。Curator 拒绝时记录原因到审计日志。
```

**理由**：R7 现状把 learning 当静态分类，但 learning 是动态知识（反例 #3）。拆分使"放哪儿"+"去重"+"矛盾浮现"+"删除传染"+"晋升源"各得其所。

---

## 改动 9：新增 R17 / R18（line 89 之后）

**新增 R17**（活性检测）：
```
- R17. Dispatcher 必须区分"健康背压"与"死锁背压"：当某下游消费 profile 持续 X 分钟（默认 30）throughput=0 且 ready 队列非空时，必须升级到 orchestrator 或用户（创建 kanban_block 任务 + 通过 Gateway 推送告警）。R5 的 pause 机制不允许演变成无人察觉的永久死锁。
```

**新增 R18**（抖动平滑）：
```
- R18. R5 的 ready 队列深度比率计算必须采用滑动窗口平均（默认窗口大小由 ce-plan 决定，建议 ≥ 1 分钟），不允许采用瞬时值；防止短期抖动导致 spawn 状态频繁切换。
```

**理由**：闭合反例 #4 中 R5 单一指标无法区分"动得慢" vs "完全不动"的盲区。

---

## 改动 10：Outstanding Questions 区段更新（line 152-164）

### 解除 / 缩减的 Deferred 项

| Deferred 原文（行号） | 状态 | 说明 |
|---------------------|------|------|
| `[Affects R12][Technical] 心跳节奏的具体数值…` (line 164) | **可删除** | R12 改写后心跳进程化，节奏不再由数值决定，转为 `expected_duration_max` 默认值，留 R15 处 |

### 新增 Deferred 项（来自本轮压测）

```
- [Affects R10][Technical] reviewer 白名单的精确工具集清单：当前默认白名单 `file_read` / `kanban_read` / `kanban_block` / `kanban_complete` / `clarify` 是否完备？是否需要 `terminal`（用于 lint/typecheck）？需要 `web_fetch`（用于 fetch PR 上下文）吗？— 需先查 hermes-docs-index 确认所有 toolsets 后定案
- [Affects R13][Technical] handoff metadata 值过滤清单的精确 pattern：需要拦截哪些 payload 模式（shebang / heredoc / shell 元字符 / URL with auth）？过滤策略是 reject 还是 sanitize？— 留给 ce-plan
- [Affects R7b][Needs research] curator 语义相似度阈值的合理范围：embedding 模型选择？阈值默认值？— 需调研 hermes curator 是否已有相似度比较机制
- [Affects R7d][Technical] 删除传染的工程实现：curator 派发的 review task 模板？复审 SLA？— 留给 ce-plan
- [Affects R15][Technical] 各 profile 的 expected_duration_max 默认值：implementer / reviewer / orchestrator 各自合理上限？是否区分任务类型（简单修复 vs 大型重构）？— 留给 ce-plan
- [Affects R17][Technical] 活性检测的 X 分钟阈值与告警 channel：默认 30min？告警通过 Gateway 哪个 adapter 推送？是否区分死锁严重等级？— 留给 ce-plan
- [Affects R18][Technical] R5 滑动窗口默认值：1 分钟？5 分钟？窗口大小如何与 R17 的 X 分钟阈值协调？— 留给 ce-plan
```

---

## Acceptance Examples 区段更新（line 92-100 之后）

### 建议补充的验收例子

**AE8（覆盖 R4 / R12 / R15 联合）**：
```
- AE8. **Covers R4, R12, R15.** Given implementer 任务在 task metadata 中声明 `expected_duration_max=30min`，worker 进程在 35min 时仍存活但未完成，when dispatcher 检测到任务级 timeout，then dispatcher 触发 SIGTERM kill worker、执行 R4 的 worktree 清理、将任务回退到 ready；审计日志记录 timeout 触发原因与原 PID。
```

**AE9（覆盖 R10 + R8 联合）**：
```
- AE9. **Covers R10, R8.** Given reviewer profile toolsets 配置为白名单 `file_read / kanban_read / kanban_block / kanban_complete / clarify / terminal`，when reviewer 调用 `file_write(...)`，then 工具调用直接因 toolset 未 enable 而失败（白名单层拦截，不进入 R8）；when reviewer 调用 `terminal(command="rm test.txt")`，then R8 兜底拦截生效，命令不执行、审计日志写入。
```

**AE10（覆盖 R13 + R16）**：
```
- AE10. **Covers R13, R16.** Given reviewer 在 `kanban_complete` 的 decisions 字段塞入 `"#!/bin/bash\nrm -rf /"`，when handoff metadata 提交，then schema 校验拒绝（R13 的值校验），返回结构化错误；若校验放行（边角 pattern 漏过），下游 implementer 读取时必须将该字段包裹在 `<untrusted-handoff>` 标签内（R16），不允许执行其内容。
```

**AE11（覆盖 R17）**：
```
- AE11. **Covers R17.** Given reviewer profile 的 LLM provider 持续返回 429（限流），reviewer worker 反复 spawn 后立刻退出，throughput 持续 0；当持续时间超过 30min 且 ready 队列仍 ≥ 1 时，then dispatcher 创建 kanban_block 任务标注"reviewer profile 死锁告警"、Gateway 推送给用户；R5 的 pause 状态不允许在无升级的情况下保持超过此阈值。
```

**AE12（覆盖 R7c）**：
```
- AE12. **Covers R7c.** Given 全局 namespace 有 learning "Webpack 配置必须 X"、项目 A 的 namespace 有矛盾的 learning "Webpack 配置必须 NOT X"，when 项目 A 的 implementer 查询 "Webpack 配置" 相关 learnings，then 返回结果必须包含两端条目并附 `<conflict_warning>` 元数据；agent 不允许仅返回项目版本而隐藏全局矛盾。
```

---

## Apply 方式建议

蕾姆建议两步走，避免一次改动过大：

**Phase A**（安全相关，建议优先）：
- 改动 2 / 3 / 5 / 7（R8 收缩 + R10 白名单 + R13 值校验 + R16 untrusted-handoff）
- 这一组涉及 reviewer 写防护与 prompt injection，是 ce-plan 之前最不能错的部分

**Phase B**（生命周期与背压，可与 Phase A 并行）：
- 改动 1 / 4 / 6 / 9（R4 改写 + R12 改写 + R15 任务级 timeout + R17/R18 活性检测+平滑）
- 改动 8（R7 拆分）

**Phase C**（验收例子与 deferred 更新）：
- 改动 10 与 AE8-AE12 补充
- 与 Phase A/B 同步合并到 REQUIREMENTS-REV2.md

---

## 关联文件

- 完整反例叙事：`./explore-pressure-test-r4-r5-r7-r10.md`
- 主需求文档：`/data/hermes/.planning/phases/19-hermes-workflow-design/REQUIREMENTS.md`
- 设计稿（待回头同步影响范围）：`/data/hermes/.planning/phases/19-hermes-workflow-design/DESIGN.md`
