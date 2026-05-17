# Full Optional Configs Use Disabled Formal Paths

Release Pipeline, Remote Decision Channel, and Runtime Domain Knowledge Base configuration will use their formal project paths immediately, but each config is disabled by default. There is no legacy runtime file to protect for these areas, so formal paths reduce future migration work while `enabled: false` prevents readers and runtime code from treating the presence of a config file as an enabled full-system capability.
