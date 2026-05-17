# qnN4o510 Knowledge Synthesis

Status: Synthesis complete for implementation planning
Purpose: Requirements and design-source traceability for Hermes full-system reconstruction

## Boundary

`qnN4o510` is an external requirements and design knowledge source. It is used to support planning, terminology alignment, and grill-with-docs decisions.

It is not the Hermes runtime knowledge base, not state authority, not completion evidence, and not a cache backend.

Runtime domain knowledge for specialized domains such as WeChat Mini Program development must be built as a project-owned Runtime Domain Knowledge Base with its own storage backend, ingestion rules, retrieval contract, freshness policy, and audit trail.

The target backend is gbrain, using its local PGLite brain plus CLI/MCP surfaces. Hermes should not build a separate SQLite runtime knowledge base while gbrain is available.

## Source Inventory

Current `qnN4o510` notes observed during this grill session:

| Note ID | Title | Theme |
| --- | --- | --- |
| `1910188644074536856` | HeavySkill: 将深度思考作为智能体框架中的核心内在技能 | Heavy thinking, agentic harness |
| `1910188222094023744` | HeavySkill：复杂推理的双阶段测试时扩展技术 | Parallel reasoning, sequential deliberation |
| `1910180145407499328` | AI多Agent协作项目实战：从调度博弈到成本优化的工程经验 | Orchestrator/agent split, cost control, backend drift |
| `1910105800597189552` | index | Knowledge-base index |
| `1910105621282829232` | AI智能体协作系统架构 | Agent collaboration architecture |
| `1910105106960495536` | Hermes-Agent Kanban功能深度测评与工程实践指南：从架构解析到混合编排方案 | Hermes Kanban, hybrid orchestration |
| `1910105091927585712` | AI智能体开发实战复盘：从OpenClaw到Hermes-agent的工程化探索 | OpenClaw lessons, Hermes migration |
| `1910105075821982640` | Hermes-Agent生产环境实战：AI智能体驱动的研发效能革命 | Production practice, Kimi audit, multi-agent workflow |
| `1910013219356613144` | Harness Engineering：AI驱动的全链路智能开发工作流解决方案 | Harness, workflow controls |
| `1910012284128817872` | 辩论团队系统设计与实践：基于多Agent协作的全维度评审框架 | Debate teams, debate modes, adapter pitfalls |
| `1910012251914513816` | Hermes-Agent生产环境实战：AI代理协作架构与降本增效全解析 | Agent collaboration, cost reduction, debate mechanism |

## Design Knowledge Map

- Six-stage workflow: direction debate, solution debate, implementation, improvement, global evaluation, continuous improvement.
- Debate system: sixteen canonical teams, eight canonical modes, dynamic assembly, auditable member fan-out, and Kimi decision handoff.
- Gateway and Kanban: Gateway owns state/projection/adapter boundaries; Kanban remains task lifecycle substrate, not a raw mutation API for Kimi.
- Harness and guardrails: schema validation, DAG/Kanban constraints, risk policy, approval gates, and audit prevent process drift.
- Backend strategy: backend adapters are replaceable; simulation/template outputs must be marked degraded; real evidence must preserve per-member invocation traceability.
- Cost and context control: split upper orchestration from lower execution, use cheaper execution/debate backends where appropriate, and prevent unbounded context dumping.
- Self-evolution: Kimi audits experience before durable promotion; system changes become proposals and require approval when they affect authority or risk boundaries.
- HeavySkill and deep reasoning: useful research reference for parallel reasoning plus sequential deliberation, but not yet a runtime requirement.

## Spec Traceability

Already reflected in `.planning/specs/HERMES-ORCHESTRA-FULL-SPEC.md`:

- `qnN4o510` is the primary design knowledge source, not runtime authority.
- Full Debate Package team and mode registries follow the qnN4o510 canonical ids.
- Default debate member personas map to the qnN4o510 team dimensions.
- Backend adapter design records simulation/template degradation and per-member auditability.
- Kimi remains external orchestrator, reviewer, and low/medium-risk decision authority below human-risk gates.

Still research/reference only:

- HeavySkill as an implementation technique for deep reasoning.
- Specific domain content for WeChat Mini Program development or other vertical domains.
- Concrete runtime domain knowledge schema, ingestion policy, retrieval contract, and audit policy.

Future runtime knowledge work:

- Turn the confirmed Runtime Domain Knowledge Base decisions into implementation tasks.

## Runtime Knowledge Entry Schema

Runtime domain knowledge entries are gbrain markdown pages with YAML frontmatter.

Slug format:

`domain/<domain>/<topic>/<short-id>`

Required frontmatter:

- `type`
- `domain`
- `topic`
- `source_type`
- `source_refs`
- `confidence`
- `freshness`
- `valid_from`
- `last_verified_at`
- `tags`
- `owner`

Required body sections:

- `Claim`
- `Context`
- `Applies When`
- `Does Not Apply When`
- `Evidence`
- `Operational Guidance`
- `Failure Modes`
- `Review Checklist`

Unverified material starts as `candidate_knowledge` and must be verified before promotion to `domain_knowledge`.

## Runtime Knowledge Ingestion Policy

Runtime knowledge ingestion follows gbrain's official CLI/MCP usage model.

Allowed sources:

- Official documentation.
- Code or SDK examples.
- Platform rules and review requirements.
- Project test or production observations.
- Human expert entries.
- Reviewed summaries from external notes.

Forbidden direct promotion sources:

- Model chat conclusions without source evidence.
- Unverified blog summaries.
- Raw Get笔记 note copies.
- Stale platform rules.

Concrete gbrain operations:

- `gbrain put <slug> --content <markdown-with-frontmatter>` creates or updates one entry.
- `gbrain import <dir>` imports curated markdown directories.
- `gbrain sync --repo <path>` syncs approved repository-backed knowledge directories.
- `gbrain link <from> <to> --link-type <type>` creates typed relationships.
- `gbrain query <question>` performs hybrid retrieval.
- `gbrain report --type knowledge-ingestion --title ... --content ...` records ingestion audit.
- `gbrain serve` exposes the MCP server surface.

Every promotion, overwrite, supersession, or deprecation must create a `knowledge_ingestion_record` through gbrain report or an equivalent audited artifact.

## Runtime Knowledge Retrieval Contract

Hermes and Gateway retrieve runtime domain knowledge through gbrain CLI or MCP. Default retrieval uses gbrain hybrid query.

Runtime query artifacts contain:

- `query_id`
- `run_id`
- `task_id`
- `domain`
- `question`
- `allowed_types`
- `required_freshness`
- `max_results`
- `evidence_scope`

Runtime result artifacts contain:

- `query_id`
- `backend: "gbrain"`
- `result_refs`
- `slugs`
- `titles`
- `snippets`
- `confidence`
- `freshness_status`
- `source_refs`
- `warnings`
- `created_at`

Default retrieval returns only `domain_knowledge`. `candidate_knowledge` may only appear in explicit research or debate modes and must carry warnings.

Expired entries are warning context only and cannot serve as strong evidence.

## Runtime Knowledge Freshness, Provenance, Redaction, and Audit

Freshness policy:

- `platform_policy`, `sdk_api`, and `cloud_runtime`: 30-day re-verification.
- `project_observation`: 90-day re-verification.
- `conceptual_pattern`: 180-day re-verification.
- Expired entries downgrade to warning context.

Provenance policy:

- `domain_knowledge` requires `source_refs`, `source_type`, `last_verified_at`, and `verification_method`.
- Official documentation and project test or production observations outrank blogs and external-note summaries.

Redaction policy:

- Do not persist secrets, tokens, personal data, customer data, or sensitive internal path details.
- Store redacted summaries plus source hash or source ref when sources contain sensitive material.

Audit policy:

- Promotion, overwrite, deprecation, and failed re-verification write a `knowledge_ingestion_record`.
- Runtime lookups write `runtime_knowledge_query` and `runtime_knowledge_result`.

Evidence boundary:

- gbrain retrieval is not final fact authority.
- Critical platform, API, SDK, policy, compliance, release, or security conclusions must trace to official sources, test evidence, production observations, or Human Approval where required.
