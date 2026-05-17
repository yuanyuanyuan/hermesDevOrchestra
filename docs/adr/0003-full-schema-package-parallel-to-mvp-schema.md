# Full Schema Package Runs Parallel to MVP Schema

The Full Schema Package will be added as a separate human-readable contract and machine-readable JSON Schema instead of overwriting the current MVP runtime schema. The current `orchestra.schema.json` remains the MVP/current-runtime contract until the full implementation is ready to switch, while the full schema package defines the future full-system acceptance boundary and marks the MVP schema as degraded local acceptance only.
