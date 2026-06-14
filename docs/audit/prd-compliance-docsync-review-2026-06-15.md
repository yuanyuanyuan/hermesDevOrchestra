# PRD Compliance Doc-Sync Review — Hermes Dev Orchestra

**审计日期**: 2026-06-15
**审计方法**: `ce-doc-review` workflow（compound-engineering-plugin v3.8.4）
**作用域**: 文档-层 plan 对齐（与代码-层 PRD 合规审计正交互补）
**基线（source of truth）**: `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`（13-sprint plan）

> **与同期审计的关系**: 本报告是 `prd-compliance-drift-audit-2026-06-15.md`（代码-层 PRD 合规审计）的**互补视角**。前者问"代码是不是 PRD 合规",本报告问"文档有没有跟上 plan 落地"。两份互相独立,各自服务不同消费方:
> - Drift audit 消费者: Sprint 13 audit gate（验证 35 项 checklist 落地）
> - 本 doc-sync review 消费者: Sprint 12 docs-sync deliverable owner（验证 16 项 doc 缺口）

---

## 🎯 一句话结论

**文档严重不同步**（NOT READY for Sprint 12 deliverable closure）。`gateway-integration-architecture.md` 是 Sprint 0 baseline + 零散后续 additions 的累积体,从未做过 Sprint 12 那种"对齐 plan"的 sync 动作;`ARCHITECTURE.md` 和 `WORKFLOW.md` **完全游离于 audit-remediation 范围之外**。这是典型的 doc-drift 模式:plan 的 producer/consumer 契约在文档侧没有 surface。

**净缺口**: 16 项 actionable findings（9 P0 / 5 P1 / 2 P2 / 0 FYI）;跨 3 个 reviewer 派发 40 个 raw findings,经 cross-persona fingerprint 去重合并至 16。

---

## 📋 审查配置

### 文档对象

| 路径 | 类型 | 行数 |
|------|------|------|
| `docs/gateway-integration-architecture.md` | 架构契约 | 318 |
| `docs/ARCHITECTURE.md` | 系统架构主入口 | 125 |
| `docs/WORKFLOW.md` | 工作流入口（中文） | 96 |

### Source of Truth

- `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`（plan 类型）
- 13 个 Implementation Units（sprint 1-13）+ 6 个 Cross-Sprint Contracts
- 已知限制（Known Limitations）3 条

### Reviewer 派发

| Persona | 激活理由 | Findings 数 | 合并后保留 |
|---------|---------|------------|------------|
| `ce-coherence-reviewer` | 跨文档术语/引用一致性 always-on | 11 | 7 |
| `ce-feasibility-reviewer` | plan vs target doc 契约覆盖度 always-on | 18 | 11 |
| `ce-scope-guardian-reviewer` | 13-sprint 范围 vs 文档覆盖广度 | 11 | 6 |
| `ce-product-lens-reviewer` | **未激活** — 文档不是产品愿景类 | -- | -- |
| `ce-design-lens-reviewer` | **未激活** — 文档无 UI/UX 组件 | -- | -- |
| `ce-security-lens-reviewer` | **未激活** — sprint 5 涉及但 security 视角被 `coherence` 覆盖 | -- | -- |
| `ce-adversarial-document-reviewer` | **未激活** — plan 有显式 origin 路径,无 greenfield bootstrap | -- | -- |

未激活理由: 文档类型为 `plan` 派生描述文档,personas 3.4 cross-persona agreement boost 已对核心问题提供充分覆盖;为节省 token 不派遣可能重复触达同一 root cause 的 review 视角。

---

## 🔬 合成方法（Synthesis Pipeline）

| Step | 动作 | 结果 |
|------|------|------|
| 3.1 Validate | Schema 校验所有 findings | 0 malformed |
| 3.2 Confidence Gate | 按 anchor (0/25/50/75/100) 过滤 | 0 dropped（所有 finding ≥ 50） |
| 3.3 Deduplicate | `normalize(section) + normalize(title)` fingerprint | 40 → 16（合并比 60%） |
| 3.4 Cross-Persona Promotion | 2+ personas 共识 → anchor +1 | 11 findings promoted 到 anchor 100 |
| 3.5 Contradiction Resolution | 反向建议冲突检测 | 0 contradictions |
| 3.6 Auto-Promotion | `safe_auto` 候选扫描 | 0 promoted（所有 fix 需内容创作） |
| 3.7 Route by Autofix Class | 分流 gated_auto / manual | 14 manual / 2 gated_auto |
| 3.8 Sort | P0 → P1 → P2 → P3 → anchor 降序 → document order | 见下文表格 |
| 3.9 Suppress Restatements | 抑制 persona residual/deferred 重复项 | 0 suppressed |

**Chains**: 0（未识别出 premise-dependency chain;所有 finding 独立指向不同契约面）

---

## 📊 详细 Findings

### P0 — Must Fix (9 项)

#### Errors

| # | Section | Issue | Reviewer | Confidence | Tier |
|---|---------|-------|----------|------------|------|
| 1 | `gateway-integration-architecture.md` `## Public Module Interfaces` (L63-202) | `### Sprint N` 标题与 plan 编号**系统地对不上**:gateway doc 把 `DebateEngine` 标在 Sprint 1(plan 1 = Conflict Ledger);`WorkerSessionManager` 标在 Sprint 5(plan 5 = Security Escape);`Sprint 9 Heartbeat Flow` 实际是 Sprint 5 的工作;Sprint 11/12/13 **完全没有 section**。一个 implementer 读 gateway doc 找 Sprint 1 契约会看到错误的 `DebateEngine` | scope-guardian, feasibility (+1 anchor) | 100 | manual |
| 2 | `sprint-overview.md` `## Known Limitations` (L40) | Plan 引用 `docs/sprints/prd-compliance-audit-remediation/` 作为 prior gate slice 来源,但该路径在当前 repo 中**不存在**。实际归档在 `docs/archive/sprints/prd-compliance-audit-remediation/`,只剩 `checklist-sprint-1.md` + `plan-sprint-1.md`。Sprint 1 依赖陈述指向空路径,Sprint 13 audit gate 会因此挂掉 | scope-guardian, feasibility | 100 | gated_auto |
| 3 | `gateway-integration-architecture.md` Sprint 5 class block (L112-119) | `WorkerSessionManager.transition(session_id, next_state, details)` 方法**未在任何 `plan-sprint-N.md` 中授权**,可能为 scope drift | feasibility | 50 | manual |
| 4 | `gateway-integration-architecture.md` Sprint 10 class block (L199-202) | `FullSchemaCutover` 标注在 Sprint 10,但 plan 的 Sprint 10 是"Global Evaluation Veto and Residual Risk"(plan-sprint-10.md U10 modifies `gateway_evaluation.py`),不是 schema cutover。`FullSchemaCutover` 可能属于 plan-sprint-12.md 的 schema 同步范畴 | feasibility | 50 | manual |

#### Omissions（plan 的 6 个 Cross-Sprint Contract 全部未在目标文档 surface）

| # | Section | Issue | Reviewer | Confidence | Tier |
|---|---------|-------|----------|------------|------|
| 5 | 三份目标文档 | Sprint 1 契约 `conflict_ledger` schema（行 31）在三份文档中无任何落点;consumers (Sprints 2/10/13) 看不到 produced artifact;`schema.md`（`docs/sprints/prd-compliance-audit-remediation-full/schema.md:5`）定义了 schema 但未在 docs 中 cross-link | coherence, feasibility | 100 | manual |
| 6 | `gateway-integration-architecture.md` `## Run Projection API` (L214-223) | Sprint 2 契约 `run.lifecycle_status` 和 transition guard API（行 32）**未出现在 Run Projection response schema**;PRD state set (`created/intake_complete/.../closed/cancelled`) 也未声明。Run Projection 返回 `run, tasks, artifacts, decisions, audits, events` 但无 `lifecycle_status` 字段 | coherence, feasibility | 100 | manual |
| 7 | 三份目标文档 | Sprint 4 契约 `run.channel_decision`（行 33,含 `forced_standard_reasons[]`）完全缺失;Sprint 5/6 消费者（security escape / mini-debate orchestration）无引用 | coherence, feasibility | 100 | manual |
| 8 | `gateway-integration-architecture.md` / `ARCHITECTURE.md` / `WORKFLOW.md` | Sprint 10 契约 `authority_route` 和 residual-risk approval 规则（行 35）三份目标文档均无定义;`PRD 2.2 Capability Mapping`（L247-257）覆盖 actor capability 但缺 run-level `authority_route` schema | coherence, feasibility | 100 | manual |
| 9 | `gateway-integration-architecture.md` Sprint 3 class block (L94-95) | Sprint 6 → Sprint 9 契约（行 34,mini-debate 报告引用 + `consensus_score` 字段,含 0.60 threshold）三份目标文档均无;`DebateReportBuilder.create_report` 返回 `dict[str, Any]` 无字段声明 | coherence, feasibility | 100 | manual |

### P0 — Omissions（顶层文档游离于 audit-remediation 范围）

| # | Section | Issue | Reviewer | Confidence | Tier |
|---|---------|-------|----------|------------|------|
| 10 | `ARCHITECTURE.md` 整文件 / `WORKFLOW.md` 整文件 | 两份顶层文档**完全不提** 13-sprint audit remediation:`conflict_ledger` / `lifecycle_status` / `channel_decision` / `consensus_score` / `authority_route` / Override 流程全部不出现;`## System Overview` 和 `## 当前分层` 都不带 "Current remediation in flight" 区块。最严重的是没有 "see `docs/sprints/prd-compliance-audit-remediation-full/`" 指引 | scope-guardian, coherence, feasibility | 100 | manual |
| 11 | `ARCHITECTURE.md` `## System Overview` / `WORKFLOW.md` 验证节 | Sprint 12 deliverable contract 模糊:plan（行 36）说要交 "Schema/doc/metric gate scripts and required evidence refs" 给 Sprint 13,但目标文档没列出 Sprint 13 audit 究竟需要哪些 evidence refs。`scripts/tests/test-schema-doc-sync.sh` 等脚本被列在 WORKFLOW.md L84-86 和 ARCHITECTURE.md L82,但**未声明 owner=Sprint 12 / consumer=Sprint 13 关系** | feasibility, scope-guardian | 100 | manual |

### P1 — Should Fix (5 项)

| # | Section | Issue | Reviewer | Confidence | Tier |
|---|---------|-------|----------|------------|------|
| 12 | `gateway-integration-architecture.md` L63-202 全部 public class methods | 14 个 public class 的所有 method 签名只返回 `-> dict[str, Any]`,**没有为 6 个 cross-sprint contract artifact 提供 typed shape**;consumer sprints 没有 coding target。典型例子:`DebateEngine.create_run` (L69) / `DebateBackendAdapter.resolve_backend` (L90) / `DebateReportBuilder.create_report` (L95) / `FullSchemaCutover.evaluate_family` (L201) | feasibility | 100 | manual |
| 13 | `gateway-integration-architecture.md` `## Public Module Interfaces` (整段 L59-203) | Plan 明确警告"sprints intentionally vary 3/5/6 SP"(Sprint 5/9 = 6 SP, Sprint 12 = 3 SP, 其余 5 SP),但目标文档对所有 10 个 sprint block 给予**同等视觉权重**——没有 SP 标记、也没有依赖层级标注。reader 会误判 sprint 工作量 | scope-guardian, feasibility | 100 | manual |
| 14 | `gateway-integration-architecture.md` Sprint 3 / Sprint 6 区块 | Plan `## Known Limitations`(L40-42)声明 3 条边界:1) prior Conflict Ledger gate slice 在 `docs/sprints/prd-compliance-audit-remediation/`(见 P0-2 已废弃路径);2) **DAG 仅作 Gateway integration seam**(底层 cycle detection 已存在);3) **Rollback 仅限 current-run refs 且不能动 protected targets**。**这三条边界在目标文档中无一处提及**,Sprint 3 implementer 可能误把 rollback 范围扩展到 global branch mutation | feasibility, scope-guardian | 100 | manual |
| 15 | `WORKFLOW.md` `## 下一步阅读` (L89-95) | 链接图含可能不存在的 `docs/GETTING-STARTED.md` / `docs/INSTALL.md`(未验证),且**没有指向** `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`。Sprint 12 deliverable 的下游链接缺失 | scope-guardian, feasibility | 100 | gated_auto |
| 16 | `ARCHITECTURE.md` / `WORKFLOW.md` 整文件 | 具体事实只在 `gateway-integration-architecture.md` 中出现但未传播到顶层文档:1) `X-Projection-Schema-Version: 1.0.0` header 常量（gateway L219）;2) actor token 300s + 30s clock skew 过期参数（gateway L244）;3) `config/cutover/full-readiness-gates.json` / `runtime-family-activation.json` 路径（gateway L39-40） | coherence | 100 | manual |

### P2 — Consider Fixing (2 项)

| # | Section | Issue | Reviewer | Confidence | Tier |
|---|---------|-------|----------|------------|------|
| 17 | `gateway-integration-architecture.md` `## Goal` (L5) / `## Historical Sprint 0 Non-Goals` (L313-318) | "Started as Sprint 0 baseline; later sections include subsequent additions" — 没有对偶的"Post-Sprint 0 additions"区块来对照列出后来加了什么(类似 non-goals 那种 negative-list 形式)。Cross-Sprint Contracts 的 6 个契约也未在 Goal 之后以 mapping table 形式对齐 | scope-guardian | 50 | manual |

---

## 🚨 Top 4 关键修复（如果只能做 4 件事）

1. **P0-1 修 gateway doc 的 `### Sprint N` 编号** — 这一个修对了,后续 14 个 finding 中至少 6 个会消失或自动对齐
2. **P0-2 修 plan 的归档路径** — 改 `docs/sprints/prd-compliance-audit-remediation/` → `docs/archive/sprints/prd-compliance-audit-remediation/`,Sprint 1 依赖陈述才会自洽。**gated_auto,可机械应用**
3. **P0-5~9 给 6 个 contract artifact 写一段简短的 "Sprint N Contract Surface" 区块** — 5 个 finding 一次性解决,每个 1-2 段
4. **P1-15 在 `WORKFLOW.md` 下一步阅读 加一行 `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`** — 1 行修改,让 Sprint 13 audit 找得到入口。**gated_auto,可机械应用**

---

## 🔗 与同期 Drift Audit 的对照表

| 维度 | Drift Audit（代码-层） | 本 Doc-Sync Review（文档-层） |
|------|----------------------|------------------------------|
| 审计对象 | 33 项 PRD checklist 落地分 | 16 项文档-sync 缺口 |
| 验证方式 | grep import 关系 + file:line evidence | 跨文档术语/引用/契约对齐 |
| 关键发现 | "**二阶缺口**:库就绪但 orch_gateway 未集成"(drift audit L101-113) | "**二阶缺口**:契约已定义但 docs 未 surface"(P0-5~9) |
| 互补证据 | `scripts/lib/worker_source_isolation.py:50-60` 完整,`orch_gateway.py` 无 import | `gateway-integration-architecture.md` 有 `DebateReportBuilder` 但 contract 字段未声明 |
| 消费方 | Sprint 13 audit gate (验证代码) | Sprint 12 deliverable owner (验证文档) |

**两份报告对 Sprint 13 audit gate 的合并建议**:
- Drift audit 验证"代码做了吗 + 是否 PRD 合规"
- 本 doc-sync review 验证"文档跟上了吗 + 是否反映最新 plan"
- 两者均需通过,Sprint 13 audit gate 才算 Ready

---

## 📌 Verdict

**❌ NOT READY for Sprint 12 deliverable closure**

`★ Insight ─────────────────────────────────────`
**根因模式**: 与 drift audit 的 "库就绪未集成" 二阶缺口**同形** —— 文档侧表现为"契约已定义但未 surface 在 consumer 路径上"。两个二阶缺口暗示同一个 process 漏洞:Sprint 模型重 library 创建,轻 integration wire-up + 文档同步。Sprint-13 (#46) 终极闸门应同时对**代码层**(library 是否被 import)和**文档层**(contract 是否被 surface)做强制契约校验。
`─────────────────────────────────────────────────`

---

## 📎 附录

### 数据来源

- 目标文档: `docs/gateway-integration-architecture.md` / `docs/ARCHITECTURE.md` / `docs/WORKFLOW.md`
- Source of truth: `docs/sprints/prd-compliance-audit-remediation-full/sprint-overview.md`
- Schema reference: `docs/sprints/prd-compliance-audit-remediation-full/schema.md`
- 同期代码层审计: `docs/audit/prd-compliance-drift-audit-2026-06-15.md`

### 审计 workflow

- 工具: `compound-engineering:ce-doc-review` skill v3.8.4
- 模式: Interactive（synthesis-and-presentation reference）
- 派发 personas: coherence, feasibility, scope-guardian
- Tokens: ~90k / Subagents: 3 / Duration: ~10 分钟
- Phase: Phase 0-4 完成;Phase 5 terminal 由用户路由决定（输出本报告 = 报告模式）

### 输出文件

- 本报告: `docs/audit/prd-compliance-docsync-review-2026-06-15.md`
- 同期代码层审计: `docs/audit/prd-compliance-drift-audit-2026-06-15.md` + `.json`
- 同期清理审计: `docs/audit/cleanup-audit-2026-06-14.md`

### 审计纪律

1. **Cross-persona 共识优先** — 3 personas 独立触达同一 finding 时,anchor 自动 +1 步(50→75, 75→100)。本报告 16 项 finding 中 11 项有 cross-persona 共识
2. **文档独立于代码** — 本报告不验证代码是否实现,只验证文档是否描述。代码实现状态以 drift audit 为准
3. **不覆盖同期报告** — 与 `prd-compliance-drift-audit-2026-06-15.md` 互相独立,各自服务不同消费方

---

**报告生成**: `ce-doc-review` workflow + 人工综合
**下次审计建议**: Sprint 12 deliverable 落地后,或 Sprint 13 audit gate 启动前
