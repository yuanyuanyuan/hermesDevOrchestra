# Self Evolution Uses Explicit Review Queue

Kimi-Audited Self Evolution sends Stage 6 and cross-run proposals into an explicit review queue instead of immediately interrupting Kimi for every proposal. Stage 6 still writes `system_improvement_proposals`, but those proposals are candidate-only and reference queued review items governed by `config/evolution/self-evolution-review-queue.json`.

The queue orders work by protected target class, severity, repeated failure count, evidence quality, source run count, and age. Low and medium non-protected items may be batched when they share review context. Critical items may interrupt; high items do not interrupt by default. Protected targets such as root rules, CI/CD, install scripts, risk policy, worker config, debate config, Gateway config, runtime config, release config, remote decision config, and full-contract cutover require Kimi review followed by Human Approval and can never auto-apply.

Rejected, deferred, accepted, superseded, and applied proposals are retained with decision refs, reasons, and audit refs. Rejected proposals are not deleted. Low-evidence proposals move to `needs_more_evidence` instead of being accepted. This keeps improvement throughput manageable without losing auditability or allowing self-modification to bypass authority boundaries.
