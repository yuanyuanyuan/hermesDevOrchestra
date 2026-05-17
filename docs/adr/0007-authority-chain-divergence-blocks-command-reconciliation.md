# Authority Chain Divergence Blocks Command Reconciliation

When Command Reconciliation finds that Gateway State, Audit, Hermes Kanban, or artifact refs disagree after a crash or restart, Gateway blocks the run instead of replaying side effects or synthesizing missing Audit. This preserves audit truth over automatic recovery: Kimi receives a Command Reconciliation Report with four-source observations and repair options, then decides whether to accept the orphan side effect through an explicit repair path, create revision work, stop the run, or escalate for Human Approval.
