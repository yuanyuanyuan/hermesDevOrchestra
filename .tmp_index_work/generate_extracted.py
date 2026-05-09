import json, textwrap

results = []

def add_en(url_path, title, category, summary, key_concepts, code_snippets, audience, prerequisites, related_pages, embedding_keywords):
    results.append({
        "url": f"https://hermes-agent.nousresearch.com{url_path}",
        "title": title,
        "category": category,
        "summary": summary,
        "key_concepts": key_concepts,
        "code_snippets": code_snippets,
        "audience": audience,
        "prerequisites": prerequisites,
        "related_pages": related_pages,
        "embedding_keywords": embedding_keywords,
    })

def add_zh(url_path, title, category, summary, key_concepts, code_snippets, audience, prerequisites, related_pages, embedding_keywords):
    results.append({
        "url": f"https://hermes-agent.nousresearch.com{url_path}",
        "title": title,
        "category": category,
        "summary": summary,
        "key_concepts": key_concepts,
        "code_snippets": code_snippets,
        "audience": audience,
        "prerequisites": prerequisites,
        "related_pages": related_pages,
        "embedding_keywords": embedding_keywords,
    })

# ===== Batch 1: EN root + getting-started =====

add_en("/docs", "Hermes Agent Documentation", "root",
    "The landing page for Hermes Agent documentation. It introduces Hermes as a self-improving AI agent built by Nous Research with a built-in learning loop that creates skills from experience, persists knowledge, and builds a user model across sessions. It provides one-line installers for Linux/macOS/WSL2, Windows PowerShell, and Android Termux, plus quick links to Installation, Quickstart, Learning Path, Configuration, Messaging Gateway, Tools & Toolsets, Memory System, Skills System, and MCP Integration.",
    ["Hermes Agent", "Nous Research", "self-improving AI agent", "learning loop", "skills system", "memory system", "MCP integration", "one-line installer", "Termux", "WSL2"],
    ["curl one-line installer for Linux/macOS/WSL2", "PowerShell one-line installer for Windows"],
    "初学者", "",
    ["/docs/getting-started/installation", "/docs/getting-started/quickstart", "/docs/getting-started/learning-path", "/docs/integrations", "/docs/skills"],
    "Hermes Agent documentation homepage install quickstart Nous Research AI agent autonomous agent learning loop skills memory MCP Telegram Discord CLI Linux macOS Windows WSL2 Termux Android setup"
)

add_en("/docs/getting-started/installation", "Installation", "getting-started",
    "This page teaches users how to install Hermes Agent in under two minutes using a one-line installer. It covers Linux/macOS/WSL2 via curl, native Windows PowerShell (early beta), and explains how the installer handles uv, Python 3.11, Node.js 22, ripgrep, ffmpeg, and portable Git Bash (MinGit). It also covers post-install PATH setup, profile loading, and the full manual install path for users who prefer transparency or need to debug.",
    ["one-line installer", "curl", "PowerShell", "MinGit", "uv", "virtualenv", "PATH setup", "WSL2", "manual install", "git clone"],
    ["curl one-line installer", "PowerShell one-line installer", "source ~/.bashrc and start hermes", "hermes model/tools/setup commands"],
    "初学者", "Linux/macOS/WSL2 or Windows with PowerShell; internet connection",
    ["/docs/getting-started/quickstart", "/docs/getting-started/termux", "/docs/getting-started/nix-setup", "/docs/getting-started/updating"],
    "Hermes Agent installation install setup one-line installer curl bash PowerShell Windows Linux macOS WSL2 MinGit uv Python Node.js ripgrep ffmpeg PATH manual install git clone virtualenv"
)

add_en("/docs/getting-started/learning-path", "Learning Path", "getting-started",
    "This page helps users figure out where to start based on their experience level and goals. It provides a reading order for Beginner (Installation, Quickstart, CLI Usage, Configuration), Intermediate (Sessions, Messaging, Tools, Skills, Memory, Cron), and Advanced (Architecture, Adding Tools, Creating Skills, RL Training, Contributing) tiers. It also maps specific use cases such as CLI coding assistant, Telegram/Discord bot, task automation, voice assistant, and research/data analysis to the relevant documentation pages.",
    ["learning path", "beginner", "intermediate", "advanced", "CLI coding assistant", "Telegram bot", "Discord bot", "task automation", "voice assistant", "RL training"],
    [],
    "初学者", "Working Hermes installation",
    ["/docs/getting-started/installation", "/docs/getting-started/quickstart", "/docs/integrations", "/docs/skills", "/docs/reference/cli-commands"],
    "Hermes Agent learning path beginner intermediate advanced getting started roadmap study guide CLI bot Telegram Discord automation voice RL training skills memory cron architecture"
)

add_en("/docs/getting-started/nix-setup", "Nix & NixOS Setup", "getting-started",
    "This page covers installing and running Hermes Agent via Nix flake with three integration levels: nix run / nix profile install for any Nix user, NixOS module (native) for declarative server deployments with systemd and secrets management, and NixOS module (container) for agents needing self-modification via a persistent Ubuntu container. It explains differences from the standard curl installer, prerequisites, quick start, flake configuration, secrets via sops-nix/agenix, MCP server setup, OAuth handling, sampling config, plugin development, and troubleshooting.",
    ["Nix flake", "nix run", "nix profile install", "NixOS module", "systemd", "sops-nix", "agenix", "uv2nix", "configuration.nix", "container mode", "MCP servers", "OAuth", "sampling", "plugins", "direnv"],
    ["nix run github:NousResearch/hermes-agent -- setup", "nix profile install", "flake.nix with hermes-agent.nixosModules.default", "configuration.nix services.hermes-agent", "sops-nix secrets", "agenix secrets", "MCP server config in Nix", "nix develop shell", "direnv allow"],
    "进阶用户", "Nix with flakes enabled; API keys (OpenRouter or Anthropic minimum)",
    ["/docs/getting-started/installation", "/docs/getting-started/quickstart", "/docs/integrations", "/docs/reference/mcp-config-reference"],
    "Hermes Agent Nix NixOS flake nix run nix profile install uv2nix systemd declarative config sops-nix agenix secrets container mode MCP OAuth plugins direnv nix develop"
)

add_en("/docs/getting-started/quickstart", "Quickstart", "getting-started",
    "This guide gets users from zero to a working Hermes setup. It teaches installing via one-liner, choosing a provider with hermes model, running the first chat, using the TUI, resuming sessions, setting up terminal backends (local, Docker, SSH), installing voice extras, searching and installing skills, adding MCP servers, and using ACP. It emphasizes getting one clean conversation working before layering gateway, cron, skills, voice, or routing.",
    ["quickstart", "hermes setup", "hermes model", "hermes chat", "TUI", "session resume", "terminal backend", "Docker isolation", "SSH terminal", "voice extras", "skills", "MCP servers", "ACP"],
    ["curl one-line installer", "hermes model interactive provider selection", "hermes chat", "hermes --tui", "hermes --continue", "hermes config set", "hermes gateway setup", "pip install hermes-agent[voice]", "MCP server github config"],
    "初学者", "Linux/macOS/WSL2/Windows WSL2 or Termux; API key for chosen provider",
    ["/docs/getting-started/installation", "/docs/getting-started/learning-path", "/docs/getting-started/termux", "/docs/integrations"],
    "Hermes Agent quickstart tutorial first setup hermes setup hermes model hermes chat TUI session resume terminal backend Docker SSH voice skills MCP ACP getting started"
)

add_en("/docs/getting-started/termux", "Android / Termux", "getting-started",
    "This page documents the tested path for running Hermes Agent on Android phones via Termux. It covers the one-line installer with Termux auto-detection, manual install with pkg and pip, supported features (CLI, cron, PTY, Telegram gateway, MCP, Honcho memory, ACP), and unsupported features (.[all], voice extras due to ctranslate2, Playwright browser bootstrap, Docker isolation). It includes troubleshooting for compilation errors, PATH issues, and Node.js installation.",
    ["Termux", "Android", "one-line installer", "pkg", "pip", ".[termux]", "constraints-termux.txt", "cron", "PTY", "Telegram gateway", "MCP", "Honcho memory", "ACP", "ctranslate2"],
    ["curl one-line installer on Termux", "python -m pip install -e '.[termux]'", "pkg install git python clang rust", "git clone --recurse-submodules", "python -m venv", "export ANDROID_API_LEVEL", "ln -sf venv/bin/hermes to PREFIX/bin"],
    "初学者", "Android phone with Termux installed",
    ["/docs/getting-started/installation", "/docs/getting-started/quickstart", "/docs/getting-started/updating"],
    "Hermes Agent Android Termux mobile install one-line installer pkg pip termux extras cron PTY Telegram gateway MCP Honcho ACP ctranslate2 compilation error manual install"
)

add_en("/docs/getting-started/updating", "Updating & Uninstalling", "getting-started",
    "This page explains how to update Hermes Agent with hermes update, what happens during an update (pairing-data snapshot, git pull, dependency install, config migration, gateway auto-restart), preview with --check, full backup with --backup, manual update steps, rollback via git checkout, Nix update paths, uninstallation with hermes uninstall or manual cleanup, and stopping the gateway service on Linux/macOS.",
    ["hermes update", "hermes update --check", "hermes update --backup", "config migration", "gateway auto-restart", "git pull", "uv pip install", "hermes backup", "hermes import", "hermes uninstall", "nix profile upgrade", "nix profile rollback", "systemd", "launchd"],
    ["hermes update", "hermes update --backup", "hermes config check", "hermes config migrate", "git checkout for rollback", "nix flake update", "hermes uninstall", "rm -rf manual cleanup", "systemctl disable hermes-gateway"],
    "初学者", "Existing Hermes installation",
    ["/docs/getting-started/installation", "/docs/getting-started/quickstart", "/docs/reference/cli-commands"],
    "Hermes Agent update upgrade uninstall hermes update --check --backup config migration gateway restart git pull uv pip rollback Nix profile uninstall cleanup systemd launchd"
)

# ===== Batch 2: EN integrations + reference (part 1) =====

add_en("/docs/integrations", "Integrations", "integrations",
    "This page is an overview of Hermes Agent integrations with external systems. It covers AI Providers & Routing (OpenRouter, Anthropic, OpenAI, Google, auto-detected capabilities), Provider Routing (sorting, whitelists, blacklists), Fallback Providers, Tool Servers via MCP (stdio and SSE transports, tool filtering), Web Search Backends (Firecrawl, Parallel, Tavily, Exa), Browser Automation (MCP bridge, Playwright, CDP, Browserbase, Camofox), IDE Integration (VS Code, Cursor, Windsurf, Neovim via ACP), Webhooks, and Python SDK.",
    ["AI providers", "OpenRouter", "provider routing", "fallback providers", "MCP servers", "web search backends", "Firecrawl", "Tavily", "Exa", "browser automation", "Playwright", "CDP", "Browserbase", "Camofox", "ACP", "IDE integration", "webhooks", "Python SDK"],
    ["web.backend config for search backends", "MCP server config example", "VS Code ACP integration", "Python SDK run_agent example"],
    "初学者", "Hermes installation; API keys for desired integrations",
    ["/docs/integrations/providers", "/docs/reference/mcp-config-reference", "/docs/getting-started/quickstart"],
    "Hermes Agent integrations AI providers routing fallback MCP servers web search Firecrawl Tavily Exa Parallel browser automation Playwright CDP Browserbase Camofox IDE VS Code Cursor Neovim ACP webhooks Python SDK"
)

add_en("/docs/integrations/providers", "AI Providers", "integrations",
    "This reference page covers setting up inference providers for Hermes Agent. It documents cloud providers (Nous Portal, OpenAI Codex, GitHub Copilot, Anthropic, OpenRouter, AI Gateway, z.ai/GLM, Kimi/Moonshot, Arcee AI, GMI Cloud, MiniMax, Alibaba Cloud, Kilo Code, StepFun, NVIDIA, Hugging Face), OAuth flows, self-hosted endpoints (Ollama, vLLM, SGLang, llama.cpp, LM Studio), custom providers (Together, Groq, Perplexity), WSL2 networking setup, provider routing, and fallback configuration. Each provider includes setup commands, env vars, and config.yaml examples.",
    ["OpenRouter", "Anthropic", "GitHub Copilot", "OpenAI Codex", "Nous Portal", "z.ai", "GLM", "Kimi", "Moonshot", "MiniMax", "Alibaba Cloud", "Ollama", "vLLM", "SGLang", "llama.cpp", "LM Studio", "custom providers", "provider routing", "fallback_model", "WSL2 networking"],
    ["hermes model interactive selection", "export API keys in ~/.hermes/.env", "model provider config in config.yaml", "Ollama serve and custom endpoint", "vLLM serve command", "SGLang launch_server", "litellm proxy setup", "provider_routing sort config", "fallback_model config"],
    "初学者", "Hermes installation; API key or OAuth for at least one provider",
    ["/docs/integrations", "/docs/reference/environment-variables", "/docs/reference/faq", "/docs/getting-started/quickstart"],
    "Hermes AI providers inference OpenRouter Anthropic Copilot OpenAI Nous Portal z.ai GLM Kimi Moonshot MiniMax Alibaba Ollama vLLM SGLang llama.cpp LM Studio custom providers Together Groq Perplexity provider routing fallback WSL2 OAuth API key config"
)

add_en("/docs/reference/cli-commands", "CLI Commands Reference", "reference",
    "This reference page documents all terminal commands in the Hermes CLI. It covers the global entrypoint hermes [global-options] <command>, global flags (--profile, --resume, --continue, --worktree, --yolo, --tui, --dev), and top-level commands: chat, model, fallback, gateway, setup, whatsapp, slack, auth, status, cron, kanban, webhook, doctor, dump, debug share, backup, checkpoints, import, logs, config, pairing, skills, curator, hooks, memory, acp, mcp, plugins, tools, sessions, insights, claw migrate, dashboard, profile, completion, and update. Each command includes purpose, options, and usage examples.",
    ["hermes chat", "hermes model", "hermes gateway", "hermes setup", "hermes auth", "hermes status", "hermes cron", "hermes kanban", "hermes webhook", "hermes doctor", "hermes dump", "hermes backup", "hermes logs", "hermes skills", "hermes mcp", "hermes profile", "hermes update", "--yolo", "--worktree", "--tui"],
    ["hermes chat -q for one-shot", "hermes -z for zero-shot", "hermes model interactive picker", "hermes gateway <subcommand>", "hermes setup wizard", "hermes auth list/add/remove", "hermes backup --quick", "hermes logs --level WARNING", "hermes skills install", "hermes profile create --clone"],
    "进阶用户", "Hermes installation",
    ["/docs/reference/slash-commands", "/docs/reference/profile-commands", "/docs/getting-started/quickstart", "/docs/reference/tools-reference"],
    "Hermes CLI commands reference terminal hermes chat model gateway setup auth status cron kanban webhook doctor dump backup logs skills MCP profile update yolo worktree TUI completion"
)

add_en("/docs/reference/environment-variables", "Environment Variables", "reference",
    "This reference page documents all environment variables used by Hermes Agent, stored in ~/.hermes/.env or set via hermes config set. It covers LLM provider keys (OPENROUTER_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, GLM_API_KEY, KIMI_API_KEY, etc.), base URL overrides, caching (HERMES_OPENROUTER_CACHE, HERMES_OPENROUTER_CACHE_TTL), Copilot tokens, web search backend keys (FIRECRAWL_API_KEY, TAVILY_API_KEY, EXA_API_KEY, PARALLEL_API_KEY), gateway tokens (TELEGRAM_BOT_TOKEN, DISCORD_BOT_TOKEN, SLACK_BOT_TOKEN), browser/service keys (BROWSERBASE_API_KEY, CAMOFOX_API_KEY), feature toggles (HERMES_TUI, HERMES_VOICE, HERMES_RL), terminal config, compression settings, and fallback provider config.",
    ["OPENROUTER_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GLM_API_KEY", "KIMI_API_KEY", "FIRECRAWL_API_KEY", "TAVILY_API_KEY", "EXA_API_KEY", "TELEGRAM_BOT_TOKEN", "DISCORD_BOT_TOKEN", "HERMES_TUI", "HERMES_OPENROUTER_CACHE", "COPILOT_GITHUB_TOKEN", "BROWSERBASE_API_KEY", "compression", "fallback_providers"],
    ["~/.hermes/.env format", "compression enabled/threshold/target_ratio config", "fallback_providers list config"],
    "进阶用户", "Hermes installation",
    ["/docs/integrations/providers", "/docs/reference/faq", "/docs/reference/cli-commands"],
    "Hermes environment variables reference .env OPENROUTER_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY GLM_API_KEY KIMI_API_KEY FIRECRAWL Tavily Exa TELEGRAM DISCORD SLACK BROWSERBASE CAMOFOX HERMES_TUI caching Copilot tokens fallback compression config"
)

add_en("/docs/reference/faq", "FAQ & Troubleshooting", "reference",
    "This reference page provides quick answers and fixes for common questions and issues. Topics include supported LLM providers, Windows compatibility (WSL2 required), Android/Termux support, local model setup (Ollama, vLLM), programmatic usage via Python SDK, PATH issues, Python version requirements, terminal backend config, provider errors, context length issues, Docker setup for terminal isolation, gateway troubleshooting, WSL2 Chrome control via MCP, compression, MCP setup, subagent delegation, skill/gateway display config, migration from OpenClaw, and backup/restore.",
    ["FAQ", "troubleshooting", "WSL2", "Termux", "Ollama", "Python SDK", "PATH", "Docker", "gateway", "MCP", "context length", "compression", "provider errors", "OpenClaw migration", "backup", "restore"],
    ["Ollama custom endpoint config", "Python SDK run_agent example", "Docker group setup", "gateway status and logs", "MCP server config", "hermes backup and import", "profile export/import"],
    "初学者", "Hermes installation",
    ["/docs/getting-started/installation", "/docs/getting-started/quickstart", "/docs/integrations/providers", "/docs/reference/environment-variables"],
    "Hermes FAQ troubleshooting Windows WSL2 Android Termux Ollama local model Python SDK PATH Docker gateway MCP context length compression provider error OpenClaw migration backup restore"
)

add_en("/docs/reference/mcp-config-reference", "MCP Config Reference", "reference",
    "This compact reference page documents the Model Context Protocol (MCP) server configuration schema for Hermes. It covers the root config shape (mcp_servers with command/args/env for stdio or url/headers for HTTP), server keys (enabled, timeout, connect_timeout, auth, sampling), tools policy keys (include, exclude, resources, prompts), filtering semantics, naming convention (mcp_<server>_<tool>), OAuth setup, and utility tool policy. It is the companion to the main MCP conceptual docs.",
    ["MCP", "Model Context Protocol", "mcp_servers", "stdio", "SSE", "HTTP", "command", "args", "env", "url", "headers", "enabled", "timeout", "connect_timeout", "tools", "include", "exclude", "resources", "prompts", "auth", "OAuth", "sampling", "mcp_<server>_<tool>"],
    ["mcp_servers root config shape", "stdio server with command and args", "HTTP server with url and headers", "tools include/exclude filtering", "OAuth auth config", "sampling policy config", "/reload-mcp slash command"],
    "进阶用户", "Hermes installation; basic understanding of MCP",
    ["/docs/integrations", "/docs/reference/tools-reference", "/docs/getting-started/quickstart"],
    "Hermes MCP config reference Model Context Protocol mcp_servers stdio HTTP command args url headers tools include exclude resources prompts auth OAuth sampling utility tool"
)

add_en("/docs/reference/model-catalog", "Model Catalog", "reference",
    "This reference page explains how Hermes fetches curated model lists for OpenRouter and Nous Portal from a JSON manifest hosted on the docs site. It covers the live manifest URL, schema (version, updated_at, metadata, providers with models array), offline fallback to in-repo snapshot, model_catalog config options (enabled, url, ttl_hours, providers), custom provider curation URLs, and the build_model_catalog.py script for regenerating the manifest from hardcoded lists.",
    ["model catalog", "manifest", "OpenRouter", "Nous Portal", "JSON schema", "version", "metadata", "providers", "model_catalog config", "ttl_hours", "offline fallback", "build_model_catalog.py"],
    ["model_catalog.json schema example", "model_catalog config in config.yaml", "custom provider curation URL config", "python scripts/build_model_catalog.py"],
    "开发者", "Hermes installation",
    ["/docs/integrations/providers", "/docs/reference/cli-commands"],
    "Hermes model catalog manifest OpenRouter Nous Portal JSON schema version metadata providers model_catalog config ttl_hours offline fallback build_model_catalog.py curation"
)

# ===== Batch 3: EN reference (part 2) + skills =====

add_en("/docs/reference/optional-skills-catalog", "Optional Skills Catalog", "reference",
    "This reference page catalogs optional skills that ship with hermes-agent under optional-skills/ but are not active by default. Users install them with hermes skills install official/<category>/<skill>. Categories include autonomous-ai-agents (blackbox, honcho), blockchain (base, solana), communication (one-three-one-rule), creative (blender-mcp), data (sql, pandas, polars), devops (docker, kubernetes, terraform), finance (yahoo-finance), mlops (flash-attention, onnx-export), security (1password, bitwarden, gpg), and more. Each skill has a dedicated page with setup and usage.",
    ["optional skills", "hermes skills install", "blackbox", "honcho", "base blockchain", "solana blockchain", "blender-mcp", "sql", "pandas", "docker", "kubernetes", "yahoo-finance", "flash-attention", "1password", "bitwarden"],
    ["hermes skills install official/blockchain/solana", "hermes skills uninstall <skill-name>"],
    "进阶用户", "Hermes installation",
    ["/docs/reference/skills-catalog", "/docs/skills", "/docs/reference/cli-commands"],
    "Hermes optional skills catalog blackbox honcho blockchain base solana communication creative blender data sql pandas devops docker kubernetes finance yahoo-finance mlops flash-attention security 1password bitwarden"
)

add_en("/docs/reference/profile-commands", "Profile Commands Reference", "reference",
    "This reference page documents all commands related to Hermes profiles. It covers hermes profile with subcommands: list, use, create, delete, show, alias, rename, export, import, install, update, and info. Options include --clone, --clone-all, --clone-from, --no-alias, --force, and --yes. It also explains profile distribution format (distribution.yaml), cross-profile command invocation with -p, shell completion setup, and installing profiles from GitHub repos, HTTPS URLs, SSH URLs, or local directories.",
    ["hermes profile", "profile list", "profile use", "profile create", "profile delete", "profile show", "profile alias", "profile rename", "profile export", "profile import", "profile install", "distribution.yaml", "--clone", "--clone-all", "-p"],
    ["hermes profile list", "hermes profile use work", "hermes profile create work --clone", "hermes profile export work", "hermes profile import archive.tar.gz", "hermes profile install github.com/user/repo", "hermes -p work chat", "distribution.yaml format"],
    "进阶用户", "Hermes installation",
    ["/docs/reference/cli-commands", "/docs/getting-started/quickstart"],
    "Hermes profile commands reference hermes profile list use create delete show alias rename export import install distribution.yaml clone clone-all -p cross-profile"
)

add_en("/docs/reference/skills-catalog", "Bundled Skills Catalog", "reference",
    "This reference page catalogs all built-in skills shipped with Hermes and copied into ~/.hermes/skills/ on install. Skills are organized by category: apple (apple-notes, apple-reminders, findmy, imessage, macos-computer-use), autonomous-ai-agents (claude-code, codex, hermes-agent, opencode), creative (architecture-diagram, ascii-art, ascii-video, baoyu-comic, baoyu-infographic, claude-design, comfyui), data (sql, pandas, polars, yahoo-finance), devops (docker, kubernetes, terraform), and many more. Each entry links to a dedicated page. Skills sync on hermes update but respect local edits.",
    ["bundled skills", "apple-notes", "claude-code", "codex", "architecture-diagram", "ascii-art", "comfyui", "sql", "pandas", "docker", "kubernetes", "hermes skills reset", "generate-skill-docs.py"],
    ["hermes skills reset <name> --restore"],
    "初学者", "Hermes installation",
    ["/docs/skills", "/docs/reference/optional-skills-catalog", "/docs/getting-started/quickstart"],
    "Hermes bundled skills catalog built-in skills apple-notes claude-code codex architecture-diagram ascii-art comfyui data sql pandas devops docker kubernetes hermes skills reset"
)

add_en("/docs/reference/slash-commands", "Slash Commands Reference", "reference",
    "This reference page documents Hermes slash commands for both interactive CLI and messaging gateway surfaces, driven by a central COMMAND_REGISTRY. CLI slash commands include session management (/new, /clear, /history, /save, /retry, /undo, /title, /compress), checkpoints (/rollback, /snapshot), process control (/stop, /queue, /steer), model switching (/model), tool management (/tools), gateway (/gateway), skills (/skills), memory (/memory), plans (/plan), and custom quick commands. Messaging slash commands include platform-specific commands and help menus.",
    ["slash commands", "/new", "/clear", "/history", "/compress", "/rollback", "/snapshot", "/stop", "/queue", "/steer", "/model", "/tools", "/gateway", "/skills", "/memory", "/plan", "quick_commands", "model_aliases"],
    ["quick_commands config example", "model_aliases config example", "/model fav --global", "hermes config set model.aliases"],
    "进阶用户", "Hermes installation",
    ["/docs/reference/cli-commands", "/docs/reference/tools-reference", "/docs/getting-started/quickstart"],
    "Hermes slash commands reference /new /clear /history /compress /rollback /snapshot /stop /queue /steer /model /tools /gateway /skills /memory /plan quick_commands model_aliases CLI messaging"
)

add_en("/docs/reference/tools-reference", "Built-in Tools Reference", "reference",
    "This reference page documents all 68 built-in tools in the Hermes tool registry, grouped by toolset. It covers browser tools (browser_back, browser_click, browser_console, browser_get_images, browser_navigate, browser_press, browser_scroll, browser_snapshot, browser_type, browser_vision, web_search), file tools (read_file, write_file, patch, search_files), terminal tools (execute_command, shell), web tools (web_search, web_extract), RL tools, Home Assistant tools, Feishu tools, Spotify tools, Yuanbao tools, Discord tools, and MCP tools (server-name prefixed). Availability varies by platform, credentials, and enabled toolsets.",
    ["built-in tools", "browser tools", "file tools", "terminal tools", "web tools", "RL tools", "MCP tools", "browser_navigate", "browser_click", "browser_snapshot", "read_file", "write_file", "patch", "search_files", "execute_command", "web_search", "web_extract"],
    [],
    "开发者", "Hermes installation",
    ["/docs/reference/toolsets-reference", "/docs/reference/mcp-config-reference", "/docs/integrations"],
    "Hermes built-in tools reference browser file terminal web RL Home Assistant Feishu Spotify Yuanbao Discord MCP browser_navigate browser_click read_file write_file patch search_files execute_command web_search web_extract"
)

add_en("/docs/reference/toolsets-reference", "Toolsets Reference", "reference",
    "This reference page documents toolsets, which are named bundles of tools controlling what the agent can do. It explains three kinds of toolsets: Core (single logical group like file, browser, terminal), Composite (combines multiple core toolsets like debugging), and Platform (complete configuration for a deployment context like hermes-cli). It covers per-session CLI configuration (--toolsets), per-platform config.yaml configuration, interactive management via hermes tools and in-session /tools commands, and a table of all core toolsets with their included tools.",
    ["toolsets", "core toolsets", "composite toolsets", "platform toolsets", "hermes chat --toolsets", "hermes tools", "/tools list", "browser", "file", "terminal", "web", "rl", "debugging", "hermes-cli", "custom_toolsets"],
    ["hermes chat --toolsets web,file,terminal", "toolsets config in config.yaml", "hermes tools curses UI", "/tools disable browser", "custom_toolsets definition in config.yaml"],
    "进阶用户", "Hermes installation",
    ["/docs/reference/tools-reference", "/docs/reference/cli-commands", "/docs/getting-started/quickstart"],
    "Hermes toolsets reference core composite platform browser file terminal web rl debugging hermes-cli custom_toolsets hermes chat --toolsets config.yaml"
)

add_en("/docs/skills", "Skills Hub", "skills",
    "This page is the Skills Hub catalog showing all available skills with their name, availability (built-in or optional), description, category, and supported platforms. Categories include Apple (apple-notes, findmy, imessage, macos-computer-use), AI Agents (claude-code, codex, hermes-agent, opencode), Creative (architecture-diagram, ascii-art, comfyui, claude-design), Data (sql, pandas, yahoo-finance), DevOps (docker, kubernetes, terraform), and many others. Each skill links to its dedicated documentation page. Platform compatibility is shown with Linux, macOS, and Windows icons.",
    ["skills hub", "built-in skills", "optional skills", "apple-notes", "macos-computer-use", "claude-code", "codex", "architecture-diagram", "ascii-art", "comfyui", "sql", "pandas", "docker", "kubernetes", "platform compatibility"],
    [],
    "初学者", "Hermes installation",
    ["/docs/reference/skills-catalog", "/docs/reference/optional-skills-catalog", "/docs/getting-started/quickstart"],
    "Hermes Skills Hub catalog built-in optional apple-notes macos-computer-use claude-code codex architecture-diagram ascii-art comfyui sql pandas docker kubernetes platform Linux macOS Windows"
)

# ===== Batch 4: EN user-stories + ZH root/getting-started =====

add_en("/docs/user-stories", "User Stories & Use Cases", "user-stories",
    "This page showcases real-world community use cases for Hermes Agent, scraped from X, GitHub, Reddit, Hacker News, YouTube, blogs, and podcasts. It contains 99 stories across 15 categories including Dev Workflow, Personal Assistant, Integrations, Meta & Ecosystem, Business Ops, Enterprise, Content Creation, Research, Messaging, Cost Optimization, Trading & Markets, Creative, Privacy & Self-Hosted, and Marketing. Each story links to the original source with quotes from community members describing their Hermes setups and workflows.",
    ["user stories", "use cases", "community", "Dev Workflow", "Personal Assistant", "Integrations", "Enterprise", "Content Creation", "Research", "Messaging", "Cost Optimization", "Trading", "Creative", "Privacy", "Self-Hosted"],
    [],
    "初学者", "",
    ["/docs/getting-started/quickstart", "/docs/skills", "/docs/integrations"],
    "Hermes user stories use cases community Dev Workflow Personal Assistant Integrations Enterprise Content Creation Research Messaging Cost Optimization Trading Creative Privacy Self-Hosted"
)

add_zh("/docs/zh-Hans", "Hermes Agent Documentation", "root",
    "Hermes Agent 文档的主页。介绍 Hermes 是由 Nous Research 构建的具有内置学习循环的自改进 AI 智能体，能够从经验创建技能、在使用中改进、促使用户持久化知识，并在多会话中构建用户模型。提供 Linux/macOS/WSL2、Windows PowerShell 和 Android Termux 的一键安装命令，以及指向安装、快速入门、学习路径、配置、消息网关、工具与工具集、记忆系统、技能系统和 MCP 集成的快速链接。",
    ["Hermes Agent", "Nous Research", "自改进 AI 智能体", "学习循环", "技能系统", "记忆系统", "MCP 集成", "一键安装", "Termux", "WSL2"],
    ["curl 一键安装 Linux/macOS/WSL2", "PowerShell 一键安装 Windows"],
    "初学者", "",
    ["/docs/zh-Hans/getting-started/installation", "/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/getting-started/learning-path", "/docs/zh-Hans/integrations", "/docs/zh-Hans/skills"],
    "Hermes Agent 文档主页 安装 快速入门 Nous Research AI 智能体 自主智能体 学习循环 技能 记忆 MCP Telegram Discord CLI Linux macOS Windows WSL2 Termux Android 设置"
)

add_zh("/docs/zh-Hans/getting-started/installation", "Installation", "getting-started",
    "本页教用户如何通过一行命令安装程序在不到两分钟内安装 Hermes Agent。涵盖通过 curl 安装 Linux/macOS/WSL2、原生 Windows PowerShell（早期测试版），并解释安装程序如何处理 uv、Python 3.11、Node.js 22、ripgrep、ffmpeg 和便携式 Git Bash（MinGit）。还涵盖安装后的 PATH 设置、配置文件加载以及完整的 manual install 路径。",
    ["一行安装", "curl", "PowerShell", "MinGit", "uv", "虚拟环境", "PATH 设置", "WSL2", "手动安装", "git clone"],
    ["curl 一行安装命令", "PowerShell 一行安装命令", "source ~/.bashrc 并启动 hermes", "hermes model/tools/setup 命令"],
    "初学者", "Linux/macOS/WSL2 或带 PowerShell 的 Windows；网络连接",
    ["/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/getting-started/termux", "/docs/zh-Hans/getting-started/nix-setup", "/docs/zh-Hans/getting-started/updating"],
    "Hermes Agent 安装 设置 一行安装 curl bash PowerShell Windows Linux macOS WSL2 MinGit uv Python Node.js ripgrep ffmpeg PATH 手动安装 git clone 虚拟环境"
)

add_zh("/docs/zh-Hans/getting-started/learning-path", "Learning Path", "getting-started",
    "本页帮助用户根据经验水平和目标确定从哪里开始。为初学者（安装、快速入门、CLI 使用、配置）、中级（会话、消息、工具、技能、记忆、定时任务）和高级（架构、添加工具、创建技能、RL 训练、贡献）提供阅读顺序。还将 CLI 编码助手、Telegram/Discord 机器人、任务自动化、语音助手和研究数据分析等具体用例映射到相关文档页面。",
    ["学习路径", "初学者", "中级", "高级", "CLI 编码助手", "Telegram 机器人", "Discord 机器人", "任务自动化", "语音助手", "RL 训练"],
    [],
    "初学者", "已安装 Hermes",
    ["/docs/zh-Hans/getting-started/installation", "/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/integrations", "/docs/zh-Hans/skills", "/docs/zh-Hans/reference/cli-commands"],
    "Hermes Agent 学习路径 初学者 中级 高级 入门指南 学习路线图 CLI 机器人 Telegram Discord 自动化 语音 RL 训练 技能 记忆 定时任务 架构"
)

add_zh("/docs/zh-Hans/getting-started/nix-setup", "Nix & NixOS Setup", "getting-started",
    "本页介绍通过 Nix flake 安装和运行 Hermes Agent 的三种集成级别：nix run / nix profile install 适用于任何 Nix 用户；NixOS 模块（原生）用于声明式服务器部署，带 systemd 和 secrets 管理；NixOS 模块（容器）用于需要自修改的智能体，通过持久化 Ubuntu 容器实现。还解释了与标准 curl 安装程序的区别、前提条件、快速开始、flake 配置、sops-nix/agenix 密钥管理、MCP 服务器设置、OAuth 处理、采样配置、插件开发和故障排查。",
    ["Nix flake", "nix run", "nix profile install", "NixOS 模块", "systemd", "sops-nix", "agenix", "uv2nix", "configuration.nix", "容器模式", "MCP 服务器", "OAuth", "采样", "插件", "direnv"],
    ["nix run github:NousResearch/hermes-agent -- setup", "nix profile install", "flake.nix 配置 hermes-agent.nixosModules.default", "configuration.nix services.hermes-agent", "sops-nix 密钥", "agenix 密钥", "nix develop shell", "direnv allow"],
    "进阶用户", "启用 flakes 的 Nix；至少一个 API 密钥（OpenRouter 或 Anthropic）",
    ["/docs/zh-Hans/getting-started/installation", "/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/integrations", "/docs/zh-Hans/reference/mcp-config-reference"],
    "Hermes Agent Nix NixOS flake nix run nix profile install uv2nix systemd 声明式配置 sops-nix agenix 密钥 容器模式 MCP OAuth 插件 direnv nix develop"
)

add_zh("/docs/zh-Hans/getting-started/quickstart", "Quickstart", "getting-started",
    "本指南帮助用户从零开始建立可用的 Hermes 设置。教用户通过一行命令安装、使用 hermes model 选择提供商、运行首次对话、使用 TUI、恢复会话、设置终端后端（本地、Docker、SSH）、安装语音扩展、搜索和安装技能、添加 MCP 服务器和使用 ACP。强调在添加网关、定时任务、技能、语音或路由之前，先确保一次干净的对话正常工作。",
    ["快速入门", "hermes setup", "hermes model", "hermes chat", "TUI", "会话恢复", "终端后端", "Docker 隔离", "SSH 终端", "语音扩展", "技能", "MCP 服务器", "ACP"],
    ["curl 一行安装", "hermes model 交互式选择提供商", "hermes chat", "hermes --tui", "hermes --continue", "hermes config set", "hermes gateway setup", "pip install hermes-agent[voice]", "MCP 服务器 github 配置"],
    "初学者", "Linux/macOS/WSL2/Windows WSL2 或 Termux；所选提供商的 API 密钥",
    ["/docs/zh-Hans/getting-started/installation", "/docs/zh-Hans/getting-started/learning-path", "/docs/zh-Hans/getting-started/termux", "/docs/zh-Hans/integrations"],
    "Hermes Agent 快速入门 教程 首次设置 hermes setup hermes model hermes chat TUI 会话恢复 终端后端 Docker SSH 语音 技能 MCP ACP 入门"
)

add_zh("/docs/zh-Hans/getting-started/termux", "Android / Termux", "getting-started",
    "本页记录通过 Termux 在安卓手机上运行 Hermes Agent 的测试路径。涵盖带 Termux 自动检测的一行安装程序、使用 pkg 和 pip 的手动安装、支持的功能（CLI、cron、PTY、Telegram 网关、MCP、Honcho 记忆、ACP）和不支持的功能（.[all]、语音扩展因 ctranslate2 缺失、Playwright 浏览器引导、Docker 隔离）。还包括编译错误、PATH 问题和 Node.js 安装的故障排查。",
    ["Termux", "Android", "一行安装", "pkg", "pip", ".[termux]", "constraints-termux.txt", "cron", "PTY", "Telegram 网关", "MCP", "Honcho 记忆", "ACP", "ctranslate2"],
    ["Termux 上 curl 一行安装", "python -m pip install -e '.[termux]'", "pkg install git python clang rust", "git clone --recurse-submodules", "python -m venv", "export ANDROID_API_LEVEL", "ln -sf venv/bin/hermes 到 PREFIX/bin"],
    "初学者", "已安装 Termux 的安卓手机",
    ["/docs/zh-Hans/getting-started/installation", "/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/getting-started/updating"],
    "Hermes Agent Android Termux 移动端 安装 一行安装 pkg pip termux 扩展 cron PTY Telegram 网关 MCP Honcho ACP ctranslate2 编译错误 手动安装"
)

add_zh("/docs/zh-Hans/getting-started/updating", "Updating & Uninstalling", "getting-started",
    "本页解释如何使用 hermes update 更新 Hermes Agent，更新过程中会发生什么（配对数据快照、git pull、依赖安装、配置迁移、网关自动重启），使用 --check 预览，使用 --backup 完整备份，手动更新步骤，通过 git checkout 回滚，Nix 更新路径，使用 hermes uninstall 或手动清理卸载，以及在 Linux/macOS 上停止网关服务。",
    ["hermes update", "hermes update --check", "hermes update --backup", "配置迁移", "网关自动重启", "git pull", "uv pip install", "hermes backup", "hermes import", "hermes uninstall", "nix profile upgrade", "nix profile rollback", "systemd", "launchd"],
    ["hermes update", "hermes update --backup", "hermes config check", "hermes config migrate", "git checkout 回滚", "nix flake update", "hermes uninstall", "rm -rf 手动清理", "systemctl disable hermes-gateway"],
    "初学者", "已安装 Hermes",
    ["/docs/zh-Hans/getting-started/installation", "/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/reference/cli-commands"],
    "Hermes Agent 更新 升级 卸载 hermes update --check --backup 配置迁移 网关重启 git pull uv pip 回滚 Nix profile 卸载 清理 systemd launchd"
)

# ===== Batch 5: ZH integrations + reference (part 1) =====

add_zh("/docs/zh-Hans/integrations", "Integrations", "integrations",
    "本页概述 Hermes Agent 与外部系统的集成。涵盖 AI 提供商与路由（OpenRouter、Anthropic、OpenAI、Google、自动检测功能）、提供商路由（排序、白名单、黑名单）、备用提供商、通过 MCP 的工具服务器（stdio 和 SSE 传输、工具过滤）、网页搜索后端（Firecrawl、Parallel、Tavily、Exa）、浏览器自动化（MCP 桥接、Playwright、CDP、Browserbase、Camofox）、IDE 集成（VS Code、Cursor、Windsurf、Neovim 通过 ACP）、Webhook 和 Python SDK。",
    ["AI 提供商", "OpenRouter", "提供商路由", "备用提供商", "MCP 服务器", "网页搜索后端", "Firecrawl", "Tavily", "Exa", "浏览器自动化", "Playwright", "CDP", "Browserbase", "Camofox", "ACP", "IDE 集成", "Webhook", "Python SDK"],
    ["web.backend 搜索后端配置", "MCP 服务器配置示例", "VS Code ACP 集成", "Python SDK run_agent 示例"],
    "初学者", "Hermes 安装；所需集成的 API 密钥",
    ["/docs/zh-Hans/integrations/providers", "/docs/zh-Hans/reference/mcp-config-reference", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes Agent 集成 AI 提供商 路由 备用 MCP 服务器 网页搜索 Firecrawl Tavily Exa Parallel 浏览器自动化 Playwright CDP Browserbase Camofox IDE VS Code Cursor Neovim ACP Webhook Python SDK"
)

add_zh("/docs/zh-Hans/integrations/providers", "AI Providers", "integrations",
    "本参考页介绍为 Hermes Agent 设置推理提供商。记录云提供商（Nous Portal、OpenAI Codex、GitHub Copilot、Anthropic、OpenRouter、AI Gateway、z.ai/GLM、Kimi/Moonshot、Arcee AI、GMI Cloud、MiniMax、阿里云、Kilo Code、StepFun、NVIDIA、Hugging Face）、OAuth 流程、自托管端点（Ollama、vLLM、SGLang、llama.cpp、LM Studio）、自定义提供商（Together、Groq、Perplexity）、WSL2 网络设置、提供商路由和备用配置。每个提供商包含设置命令、环境变量和 config.yaml 示例。",
    ["OpenRouter", "Anthropic", "GitHub Copilot", "OpenAI Codex", "Nous Portal", "z.ai", "GLM", "Kimi", "Moonshot", "MiniMax", "阿里云", "Ollama", "vLLM", "SGLang", "llama.cpp", "LM Studio", "自定义提供商", "提供商路由", "fallback_model", "WSL2 网络"],
    ["hermes model 交互式选择", "在 ~/.hermes/.env 中导出 API 密钥", "config.yaml 中的 model provider 配置", "Ollama serve 和自定义端点", "vLLM serve 命令", "SGLang launch_server", "litellm 代理设置", "provider_routing sort 配置", "fallback_model 配置"],
    "初学者", "Hermes 安装；至少一个提供商的 API 密钥或 OAuth",
    ["/docs/zh-Hans/integrations", "/docs/zh-Hans/reference/environment-variables", "/docs/zh-Hans/reference/faq", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes AI 提供商 推理 OpenRouter Anthropic Copilot OpenAI Nous Portal z.ai GLM Kimi Moonshot MiniMax 阿里云 Ollama vLLM SGLang llama.cpp LM Studio 自定义提供商 Together Groq Perplexity 提供商路由 备用 WSL2 OAuth API 密钥 配置"
)

add_zh("/docs/zh-Hans/reference/cli-commands", "CLI Commands Reference", "reference",
    "本参考页记录 Hermes CLI 中的所有终端命令。涵盖全局入口 hermes [global-options] <command>、全局标志（--profile、--resume、--continue、--worktree、--yolo、--tui、--dev）和顶层命令：chat、model、fallback、gateway、setup、whatsapp、slack、auth、status、cron、kanban、webhook、doctor、dump、debug share、backup、checkpoints、import、logs、config、pairing、skills、curator、hooks、memory、acp、mcp、plugins、tools、sessions、insights、claw migrate、dashboard、profile、completion 和 update。每个命令包含用途、选项和使用示例。",
    ["hermes chat", "hermes model", "hermes gateway", "hermes setup", "hermes auth", "hermes status", "hermes cron", "hermes kanban", "hermes webhook", "hermes doctor", "hermes dump", "hermes backup", "hermes logs", "hermes skills", "hermes mcp", "hermes profile", "hermes update", "--yolo", "--worktree", "--tui"],
    ["hermes chat -q 一次性", "hermes -z 零次", "hermes model 交互式选择", "hermes gateway <subcommand>", "hermes setup 向导", "hermes auth list/add/remove", "hermes backup --quick", "hermes logs --level WARNING", "hermes skills install", "hermes profile create --clone"],
    "进阶用户", "Hermes 安装",
    ["/docs/zh-Hans/reference/slash-commands", "/docs/zh-Hans/reference/profile-commands", "/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/reference/tools-reference"],
    "Hermes CLI 命令参考 终端 hermes chat model gateway setup auth status cron kanban webhook doctor dump backup logs skills MCP profile update yolo worktree TUI completion"
)

add_zh("/docs/zh-Hans/reference/environment-variables", "Environment Variables", "reference",
    "本参考页记录 Hermes Agent 使用的所有环境变量，存储在 ~/.hermes/.env 中或通过 hermes config set 设置。涵盖 LLM 提供商密钥（OPENROUTER_API_KEY、ANTHROPIC_API_KEY、OPENAI_API_KEY、GLM_API_KEY、KIMI_API_KEY 等）、基础 URL 覆盖、缓存（HERMES_OPENROUTER_CACHE、HERMES_OPENROUTER_CACHE_TTL）、Copilot 令牌、网页搜索后端密钥（FIRECRAWL_API_KEY、TAVILY_API_KEY、EXA_API_KEY、PARALLEL_API_KEY）、网关令牌（TELEGRAM_BOT_TOKEN、DISCORD_BOT_TOKEN、SLACK_BOT_TOKEN）、浏览器/服务密钥（BROWSERBASE_API_KEY、CAMOFOX_API_KEY）、功能开关（HERMES_TUI、HERMES_VOICE、HERMES_RL）、终端配置、压缩设置和备用提供商配置。",
    ["OPENROUTER_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GLM_API_KEY", "KIMI_API_KEY", "FIRECRAWL_API_KEY", "TAVILY_API_KEY", "EXA_API_KEY", "TELEGRAM_BOT_TOKEN", "DISCORD_BOT_TOKEN", "HERMES_TUI", "HERMES_OPENROUTER_CACHE", "COPILOT_GITHUB_TOKEN", "BROWSERBASE_API_KEY", "压缩", "fallback_providers"],
    ["~/.hermes/.env 格式", "compression enabled/threshold/target_ratio 配置", "fallback_providers 列表配置"],
    "进阶用户", "Hermes 安装",
    ["/docs/zh-Hans/integrations/providers", "/docs/zh-Hans/reference/faq", "/docs/zh-Hans/reference/cli-commands"],
    "Hermes 环境变量参考 .env OPENROUTER_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY GLM_API_KEY KIMI_API_KEY FIRECRAWL Tavily Exa TELEGRAM DISCORD SLACK BROWSERBASE CAMOFOX HERMES_TUI 缓存 Copilot 令牌 备用 压缩 配置"
)

add_zh("/docs/zh-Hans/reference/faq", "FAQ & Troubleshooting", "reference",
    "本参考页提供常见问题和问题的快速答案和修复。主题包括支持的 LLM 提供商、Windows 兼容性（需要 WSL2）、Android/Termux 支持、本地模型设置（Ollama、vLLM）、通过 Python SDK 编程使用、PATH 问题、Python 版本要求、终端后端配置、提供商错误、上下文长度问题、Docker 终端隔离设置、网关故障排查、通过 MCP 控制 WSL2 Chrome、压缩、MCP 设置、子代理委托、技能/网关显示配置、从 OpenClaw 迁移以及备份/恢复。",
    ["FAQ", "故障排查", "WSL2", "Termux", "Ollama", "Python SDK", "PATH", "Docker", "网关", "MCP", "上下文长度", "压缩", "提供商错误", "OpenClaw 迁移", "备份", "恢复"],
    ["Ollama 自定义端点配置", "Python SDK run_agent 示例", "Docker 组设置", "网关状态和日志", "MCP 服务器配置", "hermes backup 和 import", "profile export/import"],
    "初学者", "Hermes 安装",
    ["/docs/zh-Hans/getting-started/installation", "/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/integrations/providers", "/docs/zh-Hans/reference/environment-variables"],
    "Hermes FAQ 故障排查 Windows WSL2 Android Termux Ollama 本地模型 Python SDK PATH Docker 网关 MCP 上下文长度 压缩 提供商错误 OpenClaw 迁移 备份 恢复"
)

add_zh("/docs/zh-Hans/reference/mcp-config-reference", "MCP Config Reference", "reference",
    "本紧凑参考页记录 Hermes 的模型上下文协议（MCP）服务器配置模式。涵盖根配置结构（stdio 的 mcp_servers 带 command/args/env 或 HTTP 的 url/headers）、服务器键（enabled、timeout、connect_timeout、auth、sampling）、工具策略键（include、exclude、resources、prompts）、过滤语义、命名约定（mcp_<server>_<tool>）、OAuth 设置和实用工具策略。它是主要 MCP 概念文档的配套参考。",
    ["MCP", "Model Context Protocol", "mcp_servers", "stdio", "SSE", "HTTP", "command", "args", "env", "url", "headers", "enabled", "timeout", "connect_timeout", "tools", "include", "exclude", "resources", "prompts", "auth", "OAuth", "sampling", "mcp_<server>_<tool>"],
    ["mcp_servers 根配置结构", "带 command 和 args 的 stdio 服务器", "带 url 和 headers 的 HTTP 服务器", "tools include/exclude 过滤", "OAuth auth 配置", "sampling 策略配置", "/reload-mcp 斜杠命令"],
    "进阶用户", "Hermes 安装；MCP 基础知识",
    ["/docs/zh-Hans/integrations", "/docs/zh-Hans/reference/tools-reference", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes MCP 配置参考 Model Context Protocol mcp_servers stdio HTTP command args url headers tools include exclude resources prompts auth OAuth sampling 实用工具"
)

# ===== Batch 6: ZH reference (part 2) =====

add_zh("/docs/zh-Hans/reference/model-catalog", "Model Catalog", "reference",
    "本参考页解释 Hermes 如何从文档站点托管的 JSON 清单中获取 OpenRouter 和 Nous Portal 的精选模型列表。涵盖实时清单 URL、模式（version、updated_at、metadata、带模型数组的 providers）、离线回退到仓库快照、model_catalog 配置选项（enabled、url、ttl_hours、providers）、自定义提供商策展 URL 以及用于从硬编码列表重新生成清单的 build_model_catalog.py 脚本。",
    ["模型目录", "清单", "OpenRouter", "Nous Portal", "JSON 模式", "version", "metadata", "providers", "model_catalog 配置", "ttl_hours", "离线回退", "build_model_catalog.py"],
    ["model_catalog.json 模式示例", "config.yaml 中的 model_catalog 配置", "自定义提供商策展 URL 配置", "python scripts/build_model_catalog.py"],
    "开发者", "Hermes 安装",
    ["/docs/zh-Hans/integrations/providers", "/docs/zh-Hans/reference/cli-commands"],
    "Hermes 模型目录 清单 OpenRouter Nous Portal JSON 模式 version metadata providers model_catalog 配置 ttl_hours 离线回退 build_model_catalog.py 策展"
)

add_zh("/docs/zh-Hans/reference/optional-skills-catalog", "Optional Skills Catalog", "reference",
    "本参考页编录随 hermes-agent 在 optional-skills/ 下分发但默认不激活的可选技能。用户通过 hermes skills install official/<category>/<skill> 安装。类别包括 autonomous-ai-agents（blackbox、honcho）、blockchain（base、solana）、communication（one-three-one-rule）、creative（blender-mcp）、data（sql、pandas、polars）、devops（docker、kubernetes、terraform）、finance（yahoo-finance）、mlops（flash-attention、onnx-export）、security（1password、bitwarden、gpg）等。每个技能都有专门的设置和使用页面。",
    ["可选技能", "hermes skills install", "blackbox", "honcho", "base 区块链", "solana 区块链", "blender-mcp", "sql", "pandas", "docker", "kubernetes", "yahoo-finance", "flash-attention", "1password", "bitwarden"],
    ["hermes skills install official/blockchain/solana", "hermes skills uninstall <skill-name>"],
    "进阶用户", "Hermes 安装",
    ["/docs/zh-Hans/reference/skills-catalog", "/docs/zh-Hans/skills", "/docs/zh-Hans/reference/cli-commands"],
    "Hermes 可选技能目录 blackbox honcho 区块链 base solana 通信 creative blender 数据 sql pandas devops docker kubernetes 金融 yahoo-finance mlops flash-attention 安全 1password bitwarden"
)

add_zh("/docs/zh-Hans/reference/profile-commands", "Profile Commands Reference", "reference",
    "本参考页记录与 Hermes 配置文件相关的所有命令。涵盖 hermes profile 及其子命令：list、use、create、delete、show、alias、rename、export、import、install、update 和 info。选项包括 --clone、--clone-all、--clone-from、--no-alias、--force 和 --yes。还解释配置文件分发格式（distribution.yaml）、使用 -p 的跨配置文件命令调用、shell 补全设置以及从 GitHub 仓库、HTTPS URL、SSH URL 或本地目录安装配置文件。",
    ["hermes profile", "profile list", "profile use", "profile create", "profile delete", "profile show", "profile alias", "profile rename", "profile export", "profile import", "profile install", "distribution.yaml", "--clone", "--clone-all", "-p"],
    ["hermes profile list", "hermes profile use work", "hermes profile create work --clone", "hermes profile export work", "hermes profile import archive.tar.gz", "hermes profile install github.com/user/repo", "hermes -p work chat", "distribution.yaml 格式"],
    "进阶用户", "Hermes 安装",
    ["/docs/zh-Hans/reference/cli-commands", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes 配置文件命令参考 hermes profile list use create delete show alias rename export import install distribution.yaml clone clone-all -p 跨配置文件"
)

add_zh("/docs/zh-Hans/reference/skills-catalog", "Bundled Skills Catalog", "reference",
    "本参考页编录所有随 Hermes 内置并复制到 ~/.hermes/skills/ 的技能。技能按类别组织：apple（apple-notes、apple-reminders、findmy、imessage、macos-computer-use）、autonomous-ai-agents（claude-code、codex、hermes-agent、opencode）、creative（architecture-diagram、ascii-art、ascii-video、baoyu-comic、baoyu-infographic、claude-design、comfyui）、data（sql、pandas、polars、yahoo-finance）、devops（docker、kubernetes、terraform）等。每个条目链接到专用页面。技能在 hermes update 时同步但尊重本地编辑。",
    ["内置技能", "apple-notes", "claude-code", "codex", "architecture-diagram", "ascii-art", "comfyui", "sql", "pandas", "docker", "kubernetes", "hermes skills reset", "generate-skill-docs.py"],
    ["hermes skills reset <name> --restore"],
    "初学者", "Hermes 安装",
    ["/docs/zh-Hans/skills", "/docs/zh-Hans/reference/optional-skills-catalog", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes 内置技能目录 apple-notes claude-code codex architecture-diagram ascii-art comfyui 数据 sql pandas devops docker kubernetes hermes skills reset"
)

add_zh("/docs/zh-Hans/reference/slash-commands", "Slash Commands Reference", "reference",
    "本参考页记录 Hermes 的交互式 CLI 和消息网关两个表面的斜杠命令，由中央 COMMAND_REGISTRY 驱动。CLI 斜杠命令包括会话管理（/new、/clear、/history、/save、/retry、/undo、/title、/compress）、检查点（/rollback、/snapshot）、进程控制（/stop、/queue、/steer）、模型切换（/model）、工具管理（/tools）、网关（/gateway）、技能（/skills）、记忆（/memory）、计划（/plan）和自定义快速命令。消息斜杠命令包括平台特定命令和帮助菜单。",
    ["斜杠命令", "/new", "/clear", "/history", "/compress", "/rollback", "/snapshot", "/stop", "/queue", "/steer", "/model", "/tools", "/gateway", "/skills", "/memory", "/plan", "quick_commands", "model_aliases"],
    ["quick_commands 配置示例", "model_aliases 配置示例", "/model fav --global", "hermes config set model.aliases"],
    "进阶用户", "Hermes 安装",
    ["/docs/zh-Hans/reference/cli-commands", "/docs/zh-Hans/reference/tools-reference", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes 斜杠命令参考 /new /clear /history /compress /rollback /snapshot /stop /queue /steer /model /tools /gateway /skills /memory /plan quick_commands model_aliases CLI 消息"
)

add_zh("/docs/zh-Hans/reference/tools-reference", "Built-in Tools Reference", "reference",
    "本参考页记录 Hermes 工具注册表中所有 68 个内置工具，按工具集分组。涵盖浏览器工具（browser_back、browser_click、browser_console、browser_get_images、browser_navigate、browser_press、browser_scroll、browser_snapshot、browser_type、browser_vision、web_search）、文件工具（read_file、write_file、patch、search_files）、终端工具（execute_command、shell）、网页工具（web_search、web_extract）、RL 工具、Home Assistant 工具、Feishu 工具、Spotify 工具、Yuanbao 工具、Discord 工具和 MCP 工具（带服务器名前缀）。可用性因平台、凭证和启用的工具集而异。",
    ["内置工具", "浏览器工具", "文件工具", "终端工具", "网页工具", "RL 工具", "MCP 工具", "browser_navigate", "browser_click", "browser_snapshot", "read_file", "write_file", "patch", "search_files", "execute_command", "web_search", "web_extract"],
    [],
    "开发者", "Hermes 安装",
    ["/docs/zh-Hans/reference/toolsets-reference", "/docs/zh-Hans/reference/mcp-config-reference", "/docs/zh-Hans/integrations"],
    "Hermes 内置工具参考 浏览器 文件 终端 网页 RL Home Assistant Feishu Spotify Yuanbao Discord MCP browser_navigate browser_click read_file write_file patch search_files execute_command web_search web_extract"
)

# ===== Batch 7: ZH reference (part 3) + skills + user-stories =====

add_zh("/docs/zh-Hans/reference/toolsets-reference", "Toolsets Reference", "reference",
    "本参考页记录工具集，即控制智能体能做什么的命名工具包。解释三种工具集：Core（单个逻辑组如 file、browser、terminal）、Composite（组合多个核心工具集如 debugging）和 Platform（特定部署上下文的完整配置如 hermes-cli）。涵盖每会话 CLI 配置（--toolsets）、每平台 config.yaml 配置、通过 hermes tools 和会话内 /tools 命令的交互式管理，以及所有核心工具集及其包含工具的表格。",
    ["工具集", "核心工具集", "复合工具集", "平台工具集", "hermes chat --toolsets", "hermes tools", "/tools list", "browser", "file", "terminal", "web", "rl", "debugging", "hermes-cli", "custom_toolsets"],
    ["hermes chat --toolsets web,file,terminal", "config.yaml 中的 toolsets 配置", "hermes tools curses UI", "/tools disable browser", "config.yaml 中的 custom_toolsets 定义"],
    "进阶用户", "Hermes 安装",
    ["/docs/zh-Hans/reference/tools-reference", "/docs/zh-Hans/reference/cli-commands", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes 工具集参考 核心 复合 平台 browser file terminal web rl debugging hermes-cli custom_toolsets hermes chat --toolsets config.yaml"
)

add_zh("/docs/zh-Hans/skills", "Skills Hub", "skills",
    "本页是技能中心目录，展示所有可用技能及其名称、可用性（内置或可选）、描述、类别和支持的平台。类别包括 Apple（apple-notes、findmy、imessage、macos-computer-use）、AI Agents（claude-code、codex、hermes-agent、opencode）、Creative（architecture-diagram、ascii-art、comfyui、claude-design）、Data（sql、pandas、yahoo-finance）、DevOps（docker、kubernetes、terraform）等。每个技能链接到其专用文档页面。平台兼容性以 Linux、macOS 和 Windows 图标显示。",
    ["技能中心", "内置技能", "可选技能", "apple-notes", "macos-computer-use", "claude-code", "codex", "architecture-diagram", "ascii-art", "comfyui", "sql", "pandas", "docker", "kubernetes", "平台兼容性"],
    [],
    "初学者", "Hermes 安装",
    ["/docs/zh-Hans/reference/skills-catalog", "/docs/zh-Hans/reference/optional-skills-catalog", "/docs/zh-Hans/getting-started/quickstart"],
    "Hermes 技能中心 目录 内置 可选 apple-notes macos-computer-use claude-code codex architecture-diagram ascii-art comfyui sql pandas docker kubernetes 平台 Linux macOS Windows"
)

add_zh("/docs/zh-Hans/user-stories", "User Stories & Use Cases", "user-stories",
    "本页展示 Hermes Agent 的真实社区用例，从 X、GitHub、Reddit、Hacker News、YouTube、博客和播客中抓取。包含 99 个故事，涵盖 15 个类别，包括开发工作流、个人助理、集成、元与生态系统、业务运营、企业、内容创作、研究、消息、成本优化、交易市场、创意、隐私与自托管以及营销。每个故事链接到原始来源，并引用社区成员描述其 Hermes 设置和工作流程的内容。",
    ["用户故事", "用例", "社区", "开发工作流", "个人助理", "集成", "企业", "内容创作", "研究", "消息", "成本优化", "交易", "创意", "隐私", "自托管"],
    [],
    "初学者", "",
    ["/docs/zh-Hans/getting-started/quickstart", "/docs/zh-Hans/skills", "/docs/zh-Hans/integrations"],
    "Hermes 用户故事 用例 社区 开发工作流 个人助理 集成 企业 内容创作 研究 消息 成本优化 交易 创意 隐私 自托管"
)

with open('/data/hermes/.tmp_index_work/extracted_A_core.json', 'w') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

print(f"Wrote {len(results)} entries to extracted_A_core.json")
