# Fixtures Split Contract Fixtures And Runtime Fake Adapters

The full system uses two explicit fixture layers. Contract fixtures validate schema, config, edge cases, and readiness gates without runtime side effects. Runtime fake adapters exercise Gateway integration paths in isolated tests, but they must be marked as fixture backends, degraded fixtures, and test-scope only. The policy lives at `config/testing/full-fixture-policy.json`.

Neither layer may become completion evidence, release evidence, approval authority, strong debate evidence, or authority repair proof. Runtime fake adapters may mutate only test sandbox state and must emit fixture/degradation markers plus audit refs. This keeps test coverage useful without letting fake debate output, fake workers, fake release executors, fake recovery stores, fake runtime knowledge, or fake remote decisions masquerade as real production evidence.
