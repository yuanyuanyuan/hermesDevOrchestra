# PRD Compliance Audit Remediation Sprint Overview

## Planning Mode

Generated with `my-sprint-plan` manual fallback because local helper scripts `parse-plan.sh`, `split-sprints.sh`, and `generate-sprint-files.sh` are not present in this repo.

## Sprint Table

| Sprint | SP | Focus | Depends On |
|--------|----|-------|------------|
| 1 | 5 | Finish Conflict Ledger schema, severity normalization, closeout audit | Prior executed Conflict Ledger gate slice |
| 2 | 5 | PRD lifecycle state machine and transition guards | Sprint 1 |
| 3 | 5 | Rollback request and execution strategy | Sprint 2 |
| 4 | 5 | Channel routing propagation into run/stage behavior | Sprint 2 |
| 5 | 6 | Security escape rules and heartbeat reconnect/snapshot | Sprint 4 |
| 6 | 5 | Quick/Light mini-debate integration | Sprint 4 |
| 7 | 5 | Worker `model_source` source isolation | Sprint 2 |
| 8 | 5 | Worker write-scope, DAG, review/commit evidence hardening | Sprint 2 |
| 9 | 6 | Intake completeness and E-class mini-debate | Sprints 6, 8 |
| 10 | 5 | Global evaluation veto and residual-risk thresholds | Sprint 2 |
| 11 | 5 | User correction and Override approval records | Sprint 10 |
| 12 | 3 | Schema/docs/success metrics synchronization | Sprints 1-11 |
| 13 | 5 | Final strict PRD compliance audit gate | Sprint 12 |

Capacity warning: sprints intentionally vary between 3, 5, and 6 SP; this is not a uniform 5 SP split.

## Cross-Sprint Contracts

| Producer | Consumer | Contract |
|----------|----------|----------|
| Sprint 1 | Sprints 2, 10, 13 | `conflict_ledger` schema and open/high query semantics. |
| Sprint 2 | Sprints 3, 4, 7, 8, 10 | `run.lifecycle_status` and transition guard API. |
| Sprint 4 | Sprints 5, 6 | `run.channel_decision` with required debate/evidence depth. |
| Sprint 6 | Sprint 9 | Mini-debate report refs and consensus score fields. |
| Sprint 10 | Sprint 11 | `authority_route` and residual-risk approval requirements. |
| Sprint 12 | Sprint 13 | Schema/doc/metric gate scripts and required evidence refs. |

## Known Limitations

- The prior Conflict Ledger gate slice remains in `docs/sprints/prd-compliance-audit-remediation/`; this full plan does not overwrite it.
- DAG work is scoped to Gateway integration because low-level cycle detection already exists.
- Rollback implementation is limited to current-run refs and must not touch unrelated branches or protected targets.

