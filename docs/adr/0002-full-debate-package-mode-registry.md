# Full Debate Package Mode IDs Follow qnN4o510 Registry

The Full Debate Package uses the concrete eight-mode registry from Get笔记 knowledge base `qnN4o510` as the canonical mode id authority: `sequential_review`, `parallel_debate`, `adversarial_debate`, `jury_panel`, `dynamic_assembly`, `meta_review`, `risk_priority_matrix`, and `cross_team_conflict_detector`.

We chose the qnN4o510 registry over the current MVP config ids and earlier full-spec aliases because mode ids drive coverage policy, backend routing, report schemas, and compatibility checks. Existing ids such as `red_team`, `risk_review`, `consensus`, `closeout_review`, `tradeoff_matrix`, `implementation_review`, `test_strategy`, and `architecture_review` are treated as legacy or local aliases, not canonical full-package mode ids.

## Sprint 6 Stage 2 Canonical Routing

Sprint 6 adds three second-stage routing modes to the active registry:

- `consensus_fast`: `dispute_score < 0.3`; single confirmation pass, no mini-debate.
- `standard_debate`: `0.3 <= dispute_score < 0.6`; normal solution debate with mini-debate.
- `deep_fork`: `dispute_score >= 0.6`; preserve candidate branches for parallel downstream exploration.

The score is persisted in `debate_report.debate_metrics` and computed as:

```text
dispute_score =
  w1 * conflict_density +
  w2 * assumption_divergence +
  w3 * team_position_variance
```

Default weights are equal and must sum to `1.0`. `conflict_density` is conflicts divided by total solution claims, `assumption_divergence` is average pairwise Jaccard distance across candidate assumptions, and `team_position_variance` is normalized score standard deviation. The persisted score and selected mode are replayable from the same `candidate_solutions` input.
