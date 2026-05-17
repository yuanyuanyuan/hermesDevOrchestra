# Full Cutover Is Staged By Artifact Family

The full system will not switch from the MVP Runtime Schema to the Full Schema Package through one global cutover. Each artifact family must pass its own Full Contract Readiness Gate before Gateway uses `orchestra.full.schema.json` as the active runtime validation target for that family. The staged cutover policy lives at `config/cutover/full-readiness-gates.json`.

Every family gate requires full contract validation, compatibility evidence against MVP/current artifacts or projections, runtime consumption tests, rollback or disable plan, and explicit cutover decision. Historical runs keep their original schema versions and artifacts; they are read through compatibility paths or lineage refs, not rewritten in place. New runs write full artifacts only for artifact families that have passed their gate. Mixed-family runs are allowed during staged cutover, but completion evaluates each family against its active contract.

This avoids a brittle all-or-nothing migration where a full schema change could break existing runs, legacy debate registries, current worker configs, or MVP Gateway projections. It also keeps rollback understandable: disabling one full family validator must preserve already-written full artifacts while falling back to the MVP/current runtime contract for new work in that family.
