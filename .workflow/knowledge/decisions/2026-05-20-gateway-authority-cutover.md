# Gateway Authority Cutover Decision

- Date: 2026-05-20
- Family: `gateway_authority`
- Scope: activate Gateway authority-side validation and cutover module defaults without forcing a global schema switch
- Decision: allow default runtime access to Gateway cutover, degradation, fixture, and performance policy modules through the runtime family activation manifest
- Evidence:
  - `full_contract_validation_report`
  - `mvp_compatibility_report`
  - `runtime_consumption_test_report`
  - `projection_compatibility_report`
  - `rollback_or_disable_plan`
  - `explicit_cutover_decision`
