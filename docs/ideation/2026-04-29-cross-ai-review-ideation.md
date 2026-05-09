---
date: 2026-04-29
topic: cross-ai-code-review
focus: 多AI交叉复核代码审查协调工具
mode: elsewhere-software
---

# Ideation: Cross-AI Code Review Coordination Tool

## Grounding Context

**Topic Context**: A cross-AI code review coordination tool. Triggered from within a CLI session (e.g., Claude Code CLI) by typing a command. Spawns a subagent that calls a different AI model's CLI tool (e.g., OpenAI Codex CLI) to independently review the same code diff. Three modes: (1) code review with pass/fail threshold, (2) adversarial testing that actively digs for vulnerabilities, (3) open-ended consulting with session continuity. Generates cross-model comprehensive analysis reports showing overlapping conclusions and unique issues.

**External Context**: $9.46B AI code tools market (23.7% CAGR). Prior art: Zylos Research (3-5x bug catch improvement), Adversarial-Review (Claude+GPT 4-phase loop, ~21 API calls), Elenchus-MCP (Verifier↔Critic debate with 36 tools), Brunt/Synod-CLI (March 2026 launches with hostile personas). Cross-domain analogies: medical second opinion (probability distribution aggregation beats binary voting), security pentest (correlated findings need human synthesis), content moderation (ensemble consensus reduces false positives). Key gaps: no tool combines adversarial debate + auto-fix + verification; cross-model consensus reporting is immature; tiered model routing underexplored; no published pattern for spawning other AI models as subagents from within Claude Code CLI.

## Ranked Ideas

### 1. Structured Blind Review Protocol
**Description:** Models review completely independently without seeing each other's outputs or confidence scores. An arbiter synthesizes findings into three zones: consensus (both flagged), unique (only one flagged), and conflict (opposite assessments). Each zone is presented differently to the user — consensus items are high-confidence alerts, unique items are labeled with the discovering model's historical reliability for that pattern, and conflicts are surfaced as structured disagreements with both reasoning chains visible.
**Warrant:** `external:` Peer-reviewed journal meta-analyses (Nature) prove double-blind review significantly reduces anchoring bias and improves quality. Zylos Research's 3-5x improvement assumes independent judgment; serial review (A then B) contaminates independence.
**Rationale:** The core value proposition of cross-model review is "independent perspectives." If Model B sees Model A's output first, the independence is destroyed. A structured protocol enforces true statistical independence, making consensus mathematically meaningful and disagreements genuinely informative.
**Downsides:** Requires both models to complete before any synthesis — increases perceived latency. No partial early results. Conflict resolution is always manual (by design).
**Confidence:** 85%
**Complexity:** Medium
**Status:** Unexplored

### 2. Consensus Confidence Scoring
**Description:** Replace binary pass/fail with a confidence scoring system. Each finding is weighted by cross-model agreement depth: identical line ranges and rationale from 2+ models = "High Confidence"; same category but different specifics = "Moderate"; single-model flag = "Investigate" with dissenting models' counter-arguments attached. Users set auto-action thresholds (e.g., "auto-approve if consensus score > 0.8 and no High Confidence blocks").
**Warrant:** `direct:` The user's stated context explicitly flags "cross-model consensus reporting is immature" as a key gap. Zylos Research shows 3-5x improvement from multiple models, but no mechanism exists to quantify how much that overlap matters.
**Rationale:** Without confidence scoring, cross-model review produces more noise, not more signal. A scoring layer makes the tool automatable in CI/CD — something single-model review can't safely support — and lets teams calibrate risk tolerance explicitly.
**Downsides:** Threshold calibration requires trial and error. Teams may game the system by setting thresholds too permissive. Counter-arguments from dissenting models consume extra tokens.
**Confidence:** 90%
**Complexity:** Low
**Status:** Unexplored

### 3. Adversarial Auto-Fix with Verification Loop
**Description:** In adversarial mode, Model A proposes a fix for a vulnerability it found. Model B (the adversary) attempts to break the fix. Model C verifies whether the fix resolves the original issue without introducing regressions. The loop runs until convergence or a max iteration cap, producing a "fix provenance chain" linking each proposal to its validation.
**Warrant:** `direct:` The user's context explicitly flags "no tool combines adversarial debate + auto-fix + verification" as a key gap. Elenchus-MCP has debate but no fix generation; Brunt/Synod-CLI has hostile personas but no verification closure.
**Rationale:** Current AI-generated fixes are trusted blindly. A verification loop transforms "AI suggested this" into "AI A proposed, AI B failed to break, AI C confirmed" — a trust architecture, not just a feature. This directly differentiates from every existing competitor.
**Downsides:** Token costs scale superlinearly with iterations. Max iteration cap is a safety valve but may produce "best effort, unverified" results. Model C's verification is only as good as Model C.
**Confidence:** 75%
**Complexity:** High
**Status:** Unexplored

### 4. Cost-Optimized Model Router with Triage
**Description:** Before spawning expensive models, a lightweight classifier (cheap model like Haiku/4o-mini, or fast heuristics) scans the diff and routes to appropriate review depth: auto-approve trivial changes (docs, formatting), single-model review for standard changes, dual-model adversarial review for security-sensitive files, triple-model debate for critical paths. The router improves over time by learning from historical consensus patterns.
**Warrant:** `external:` Zylos Research reports $1-5/PR for full cross-model review. CodeRabbit's $550M valuation and 20% MoM growth prove the market but also imply cost sensitivity at scale. The user's three-mode design already implies differentiated depth.
**Rationale:** Running 2-3 models on every diff is economically unsustainable. A router makes the difference between a tool that scales with repo growth and one that gets disabled after the first bill. The compounding effect: every routed decision trains the classifier.
**Downsides:** Router misclassification is a catastrophic failure mode (critical diff routed to trivial path). Training data requires months of accumulated reviews. Adds latency before the actual review starts.
**Confidence:** 85%
**Complexity:** Medium
**Status:** Unexplored

### 5. Model Bias Dashboard
**Description:** Track over time which models over-flag (false positive rate by file type), under-flag (missed bugs caught by others), and exhibit systematic blind spots. Expose as a dashboard so users can strategically select reviewer combinations: "For this concurrency-heavy PR, include Claude and GPT-4o because their blind spots don't overlap."
**Warrant:** `reasoned:` If cross-model review exists, model divergence is guaranteed. The value proposition depends on heterogeneity, but no prior-art tool surfaces that heterogeneity as actionable intelligence. Zylos's 3-5x improvement implies variance; variance left unmeasured is waste.
**Rationale:** Teams currently pick models by brand or cost. A bias dashboard turns model selection into an engineering decision based on empirical evidence. Over time, it creates a defensible dataset for vendor negotiations and model selection.
**Downsides:** Requires large review volume before patterns are statistically meaningful. May strain vendor relationships if bias data is shared externally. Models change over time, so dashboards need version tracking.
**Confidence:** 80%
**Complexity:** Medium
**Status:** Unexplored

### 6. Auto-Generate Tests from Model Disagreement
**Description:** When two models disagree on whether a change is safe, the tool generates an executable test case that would prove which model is correct. For example, if Claude says "this race condition is safe because X" and Codex says "unsafe because Y", the tool generates a stress test targeting that specific interleaving. The test is suggested to the PR author; if accepted and passing, the disagreeing model's confidence is downweighted for similar patterns.
**Warrant:** `external:` Elenchus-MCP's debate framework and Adversarial-Review's consensus loop both stop at "report the disagreement." No prior art automatically produces executable artifacts to settle debates. The Brunt/Synod-CLI "failing-test-as-proof" pattern (March 2026) suggests the industry is moving in this direction.
**Rationale:** Disagreement without resolution is noise. Disagreement with an executable test is signal that either validates or refutes the concern. The test suite grows stronger precisely where models disagree most.
**Downsides:** Auto-generated tests may be flaky or slow. Not all disagreements are testable (e.g., architectural concerns). Requires test framework integration per language.
**Confidence:** 70%
**Complexity:** High
**Status:** Unexplored

### 7. Financial Circuit Breaker Review Budget
**Description:** Each review session has a dynamic budget (time + token + API call count). When models agree strongly (low divergence signal), the system releases remaining budget and fast-tracks approval. When divergence is extreme (e.g., one model finds L4 vulnerability, another calls it L1), a "circuit breaker" trips: the automatic loop pauses, remaining budget converts to a "human review reserve," and the disagreement is escalated with both reasoning chains preserved.
**Warrant:** `external:` Financial circuit breakers are proven mechanisms for "limited resources + uncertainty + preventing systemic loss." Current adversarial tools like Adversarial-Review (~21 API calls) have fixed, uninterruptible costs. The medical second-opinion literature shows that unresolved high-stakes disagreements should trigger human escalation, not infinite AI debate.
**Rationale:** Without budget governance, adversarial mode is a token black hole. A circuit breaker converts runaway costs into structured human escalation — the right resource for the right problem. Every tripped breaker produces training data for the Model Router.
**Downsides:** Threshold tuning is hard. Premature tripping wastes budget; late tripping wastes more. May create perverse incentives for models to "agree" to avoid escalation.
**Confidence:** 75%
**Complexity:** Medium
**Status:** Unexplored

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | Passive Diff Sentinel | Anchored to Hermes Runtime Bus; user excluded local project reference |
| 2 | Ambient Model Mesh | Anchored to Hermes tmux sessions and file bus |
| 3 | Native File Bus Integration | Explicitly Hermes-specific architecture |
| 4 | Remote Decision Escalation (Hermes) | Explicitly Hermes-specific remote channel |
| 5 | Risk-Gated Auto-Review (Hermes) | References Hermes risk rule table |
| 6 | Review-as-a-Marketplace | Subject-replacement; would be a completely different product |
| 7 | Unanimous Pass Gate | Extreme UX friction; any single REJECT blocks everything |
| 8 | Review-First Interface | Constraint-flip thought experiment; developers need code context |
| 9 | Self-Adversarial Review | Contradicts core value prop; if one model suffices, cross-model tool is unnecessary |
| 10 | On-Device Model Farm | Contradicts user's stated design (calling cloud Codex CLI); quality concerns for 7B models |
| 11 | Execution-Trace Review | Shifts subject from code review to runtime testing; large scope expansion |
| 12 | Async Review for Non-Dev Stakeholders | Different product category |
| 13 | Live Socratic Pair-Programming | Shifts to real-time generation rather than review |
| 14 | Consensus Dissent Annotation | Weaker version of Structured Blind Review Protocol |
| 15 | Risk-Triggered Tiered Routing | Weaker version of Cost-Optimized Model Router |
| 16 | Zero-Call Review Cache | Similar to Pre-Computed Review Fingerprint; less concrete |
| 17 | Auto-Fix Delegation | Similar to Confidence-Calibrated Auto-Fix; less grounded |
| 18 | Structured Dissensus Report | Absorbed into Structured Blind Review Protocol |
| 19 | Blind Adversarial Review Arena | Absorbed into Structured Blind Review Protocol |
| 20 | Peer Review Blinding | Absorbed into Structured Blind Review Protocol |
| 21 | Aviation TCAS Resolution | Partial overlap with Structured Blind Review Protocol's conflict handling |
| 22 | Nuclear Defense-in-Depth | Overlaps with Blind Review's parallel isolation |
| 23 | Court Adversarial Discovery | Interesting but procedural; less actionable than core protocol |
| 24 | Hawk-Eye Challenge Quota | Niche mechanism; less impactful than Circuit Breaker |
| 25 | Immutable Review Ledger | Enterprise-nice but not core to cross-model review value prop |
| 26 | Pre-Computed Review Fingerprint | Overlaps with Zero-Call Cache; requires heavy infra |
| 27 | Adversarial Auto-Loop | Hermes-anchored auto-trigger |
| 28 | Self-Writing Consensus Report | Template generation is trivial; not a differentiator |
| 29 | Silent Pre-Review on Staging | Git hook integration is standard; not a core innovation |
| 30 | Persistent Cross-Model Review Graph | Requires heavy infra; less immediately actionable than Bias Dashboard |
| 31 | Rotating Hostile Personas | Memory is valuable but complex; persona rotation adds operational burden |
| 32 | Confidence-Calibrated Auto-Fix | Overlaps with Adversarial Auto-Fix; less distinctive |
| 33 | Diff-Signature Regression Detector | Overlaps with caching ideas; narrower scope |
| 34 | Medical MDT Convergence | Overlaps with Structured Blind Review's zone approach |
| 35 | Same-Model Adversarial Ensemble | Quality of same-model different-role review is unproven vs cross-model |
| 36 | Review-Produces-Patch | Strong idea but narrower than Adversarial Auto-Fix |
| 37 | Async Evidence-Based Debate | Adds latency; file bus mechanism is infra, not product differentiator |
| 38 | Diff-Scoped Model Routing | Absorbed into Cost-Optimized Model Router |
| 39 | Adversarial Prompt Injection Audit | Niche security feature; not core to cross-model review |
| 40 | Review Drift Detection | Important for enterprise but operationally heavy |
| 41 | Immune System Tolerance Training | Strong idea but conceptually close to Bias Dashboard; latter is more actionable |
| 42 | Adaptive Blind Routing (combo) | Partially absorbed into survivors |
| 43 | Multi-Layer Smart Cache (combo) | Three overlapping caching mechanisms; over-engineered for v1 |
| 44 | Dispute-Settling Auto-Fix (combo) | Overlaps with Adversarial Auto-Fix + Auto-Generate Tests |
| 45 | Unified Resource Governance (combo) | Overlaps with Circuit Breaker + Router |
| 46 | Real-Time Execution Negotiation (combo) | Scope expansion into runtime; too ambitious |
| 47 | Persistent Review Graph (dup) | Heavy infra requirement; deferred |
