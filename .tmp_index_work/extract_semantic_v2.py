#!/usr/bin/env python3
"""
Semantic extraction script v2 for Hermes Agent documentation pages.
"""

import json
import re
from collections import OrderedDict

INPUT_PATH = "/data/hermes/.tmp_index_work/batch_A_core.jsonl"
OUTPUT_PATH = "/data/hermes/.tmp_index_work/extracted_A_core.json"

# Pre-crafted Chinese intros for zh-Hans pages (based on actual h1 + first paragraph)
ZH_INTROS = {
    "Installation": "本页介绍 Hermes Agent 的安装方法。通过一行命令安装程序，在两分钟内完成安装并运行，支持 Linux/macOS/WSL2 和 Windows PowerShell（早期测试版）。",
    "Learning Path": "本页根据用户经验水平和目标提供学习路径指引，涵盖初学者、进阶用户和高级开发者的推荐阅读顺序与预估时间。",
    "Nix & NixOS Setup": "本页介绍通过 Nix flake 安装和配置 Hermes Agent 的方法，包含 nix run、NixOS 原生模块和容器模块三种集成级别，使用 uv2nix 管理依赖。",
    "Quickstart": "本页提供从零开始搭建可用 Hermes 环境的快速入门指南，涵盖安装、选择提供方、验证聊天功能和故障排查。",
    "Hermes on Android with Termux": "本页介绍在 Android 手机上通过 Termux 运行 Hermes Agent 的测试路径，包括已支持的功能和已知限制。",
    "Updating & Uninstalling": "本页介绍 Hermes Agent 的更新和卸载方法，说明 hermes update 执行的快照、拉取、依赖安装、配置迁移和网关重启等步骤。",
    "Integrations": "本页概述 Hermes Agent 与外部系统的集成方式，包括 AI 推理提供方、提供方路由、回退机制、MCP 工具服务器和网页搜索后端。",
    "AI Providers": "本页详细介绍配置各种 AI 推理提供方的方法，覆盖 OpenRouter、Anthropic、OpenAI、GitHub Copilot、Kimi、MiniMax、阿里云及自托管端点等。",
    "Skills Hub": "本页展示 Hermes Agent 的内置技能中心，按分类列出可用技能及其支持的平台。",
    "User Stories & Use Cases": "本页收集 Hermes Agent 社区的真实使用案例，涵盖开发工作流、个人助理、集成、内容创作、研究等多个类别。",
    "CLI Commands Reference": "本页提供 Hermes CLI 所有终端命令的完整参考，包括全局选项和顶级命令的用途与参数。",
    "Environment Variables Reference": "本页列出可在 ~/.hermes/.env 中配置的所有环境变量，按 LLM 提供方、网页搜索、网关、浏览器、内存等分类组织。",
    "FAQ & Troubleshooting": "本页提供 Hermes Agent 常见问题的快速解答和故障排除方法，涵盖提供方支持、平台兼容性、WSL2、Termux 等主题。",
    "MCP Config Reference": "本页是 MCP 服务器配置的精简参考手册，涵盖配置结构、服务器键值、工具策略键和过滤语义。",
    "Model Catalog": "本页说明 Hermes 如何从 JSON 清单获取 OpenRouter 和 Nous Portal 的精选模型列表，以及在离线时回退到仓库快照的机制。",
    "Optional Skills Catalog": "本页列出需要手动安装的 optional-skills/ 目录下的可选技能，覆盖自主 AI Agent、区块链、通信等类别。",
    "Profile Commands Reference": "本页涵盖 Hermes 配置文件管理的所有命令，包括列出、切换、创建、删除、显示、重命名、导出和导入等操作。",
    "Bundled Skills Catalog": "本页列出 Hermes 安装时内置并复制到 ~/.hermes/skills/ 的技能库，包含 Apple、AI Agent、创意、数据分析、DevOps 等分类。",
    "Slash Commands Reference": "本页介绍交互式 CLI 和消息网关的斜杠命令，包括会话管理、工具控制和动态技能命令。",
    "Built-in Tools Reference": "本页按工具集分组记录 Hermes 全部 68 个内置工具，涵盖浏览器、文件、终端、网页、RL、Home Assistant、Spotify 等。",
    "Toolsets Reference": "本页介绍控制 Agent 能力的工具集配置方法，包括核心工具集、复合工具集和平台工具集的定义与使用方式。",
    "Hermes Agent": "本页是 Hermes Agent 文档主页，介绍其作为自我改进型 AI Agent 的核心特性、安装方式和快速导航链接。",
}


def load_pages():
    pages = []
    with open(INPUT_PATH, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            pages.append(json.loads(line))
    seen = set()
    unique = []
    for p in pages:
        url = p["url"]
        if url not in seen:
            seen.add(url)
            unique.append(p)
    return sorted(unique, key=lambda x: x["url"])


def clean_title(title):
    return re.sub(r"\s*\|\s*Hermes Agent\s*$", "", title).strip()


def infer_category(url):
    path = url.replace("https://hermes-agent.nousresearch.com/docs", "")
    if path == "" or path == "/zh-Hans":
        return "getting-started"
    parts = [p for p in path.split("/") if p and p != "zh-Hans"]
    if not parts:
        return "getting-started"
    cat = parts[0]
    mapping = {
        "getting-started": "getting-started",
        "integrations": "integrations",
        "reference": "reference",
        "skills": "skills",
        "user-stories": "user-guide",
    }
    return mapping.get(cat, cat)


def is_chinese_page(url):
    return "zh-Hans" in url


def extract_summary(text, h1, is_zh, url):
    text = re.sub(r"^(On this page|本页总览)\s*", "", text, flags=re.IGNORECASE)
    text = text.strip()
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    if not paragraphs:
        return ZH_INTROS.get(h1, "页面内容较少或依赖动态渲染。") if is_zh else "Page content is minimal or relies on dynamic rendering."

    # For zh-Hans pages, use the pre-crafted Chinese intro
    if is_zh:
        intro = ZH_INTROS.get(h1)
        if intro:
            return intro
        # Fallback: first meaningful paragraph translated via simple patterns
        first = paragraphs[0]
        # Try to extract a topic sentence
        first_sent = first.split(".")[0] + "."
        return f"本页介绍相关主题。{first_sent}"

    # English pages: first 1-2 meaningful paragraphs
    meaningful = []
    for p in paragraphs:
        p_clean = re.sub(r"[\s\u200b]+", " ", p).strip()
        if len(p_clean) < 10:
            continue
        if re.match(r"^[A-Z\s\-/&]+$", p_clean) and len(p_clean) < 40:
            continue
        meaningful.append(p_clean)
        if len(meaningful) >= 2:
            break

    if not meaningful:
        meaningful = [paragraphs[0].strip()]

    summary = " ".join(meaningful)
    if len(summary) > 300:
        truncated = summary[:300]
        last_period = max(truncated.rfind(". "), truncated.rfind("? "), truncated.rfind("! "))
        if last_period > 200:
            summary = truncated[:last_period + 1]
        else:
            summary = truncated.rsplit(" ", 1)[0] + "..."
    return summary.strip()


def extract_key_concepts(text, code_blocks, max_concepts=10):
    concepts = OrderedDict()

    # 1. hermes commands (require word chars only, no newlines)
    for m in re.finditer(r'\bhermes\s+([a-zA-Z][\w-]*)(?:\s+([a-zA-Z][\w-]*))?', text):
        cmd = f"hermes {m.group(1)}"
        if m.group(2):
            cmd += f" {m.group(2)}"
        # filter out garbage with newlines or non-command words
        if any(c in cmd for c in "\n\r"):
            continue
        # blacklist false positives
        if m.group(1).lower() in {"to", "your", "the", "a", "an", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "shall", "should", "may", "might", "must", "can", "could", "need", "dare", "ought", "used", "rarely", "seldom", "never", "always", "often", "sometimes", "usually", "frequently", "generally", "typically", "normally", "mainly", "mostly", "partly", "almost", "nearly", "hardly", "barely", "scarcely", "exactly", "precisely", "approximately", "about", "around", "roughly", "quite", "rather", "pretty", "fairly", "really", "very", "too", "so", "such", "enough", "almost", "nearly", "just", "only", "even", "also", "too", "either", "neither", "both", "all", "each", "every", "any", "some", "many", "much", "more", "most", "few", "fewer", "fewest", "little", "less", "least", "several", "various", "numerous", "countless", "infinite", "enough", "plenty", "abundant", "scarce", "rare", "common", "unusual", "normal", "special", "particular", "specific", "certain", "sure", "uncertain", "unsure", "doubtful", "dubious", "suspicious", "skeptical", "optimistic", "pessimistic", "realistic", "idealistic", "enthusiastic", "reluctant", "hesitant", "eager", "keen", "anxious", "worried", "concerned", "interested", "bored", "excited", "calm", "nervous", "confident", "shy", "proud", "ashamed", "embarrassed", "surprised", "shocked", "amazed", "astonished", "stunned", "confused", "puzzled", "curious", "indifferent", "apathetic", "sympathetic", "empathetic", "compassionate", "cruel", "kind", "generous", "selfish", "greedy", "ambitious", "lazy", "diligent", "hardworking", "careless", "careful", "cautious", "reckless", "brave", "cowardly", "fearless", "terrified", "frightened", "scared", "afraid", "horrified", "disgusted", "repulsed", "offended", "insulted", "flattered", "complimented", "criticized", "praised", "blamed", "accused", "forgiven", "punished", "rewarded", "appreciated", "respected", "admired", "envied", "jealous", "suspicious", "distrustful", "trusting", "loyal", "faithful", "betrayed", "deceived", "honest", "dishonest", "sincere", "insincere", "genuine", "fake", "authentic", "original", "creative", "imaginative", "innovative", "traditional", "conventional", "conservative", "liberal", "radical", "moderate", "extreme", "reasonable", "unreasonable", "logical", "illogical", "rational", "irrational", "sensible", "absurd", "ridiculous", "foolish", "wise", "intelligent", "stupid", "clever", "dumb", "smart", "brilliant", "talented", "gifted", "skilled", "unskilled", "experienced", "inexperienced", "expert", "novice", "beginner", "amateur", "professional", "expert", "master", "beginner", "intermediate", "advanced", "basic", "fundamental", "essential", "crucial", "vital", "critical", "important", "significant", "minor", "major", "primary", "secondary", "tertiary", "main", "central", "key", "core", "peripheral", "external", "internal", "inner", "outer", "upper", "lower", "higher", "deeper", "shallower", "broader", "narrower", "wider", "tighter", "looser", "stricter", "more", "lenient", "harsh", "gentle", "rough", "smooth", "soft", "hard", "solid", "liquid", "gaseous", "fluid", "rigid", "flexible", "elastic", "plastic", "brittle", "tough", "strong", "weak", "powerful", "feeble", "fragile", "durable", "temporary", "permanent", "eternal", "brief", "short", "long", "quick", "slow", "fast", "rapid", "swift", "speedy", "gradual", "sudden", "instant", "immediate", "delayed", "postponed", "advanced", "behind", "ahead", "prior", "previous", "subsequent", "following", "next", "later", "earlier", "sooner", "eventually", "finally", "ultimately", "initially", "originally", "formerly", "previously", "lately", "recently", "currently", "presently", "nowadays", "today", "tonight", "tomorrow", "yesterday", "soon", "shortly", "momentarily", "instantly", "immediately", "directly", "straight", "indirectly", "approximately", "roughly", "precisely", "exactly", "specifically", "particularly", "especially", "notably", "remarkably", "strikingly", "surprisingly", "unexpectedly", "predictably", "typically", "normally", "usually", "generally", "commonly", "frequently", "regularly", "consistently", "constantly", "continuously", "continually", "repeatedly", "periodically", "intermittently", "occasionally", "rarely", "seldom", "hardly", "scarcely", "barely", "never", "always", "forever", "permanently", "temporarily", "briefly", "momentarily"}:
            continue
        concepts[cmd] = True

    # 2. Environment variables (with underscore, 4+ chars)
    for m in re.finditer(r'\b[A-Z][A-Z_0-9]{3,}\b', text):
        val = m.group(0)
        # Skip generic acronyms
        skip = {"HTTP", "HTTPS", "URL", "JSON", "YAML", "API", "CLI", "GPU", "VPS", "WSL", "WSL2", "SSH", "IDE", "HTML", "SVG", "MP4", "GIF", "PNG", "CSV", "PDF", "GPT", "LLM", "RL", "MCP", "SSE", "TUI", "PTY", "PID", "UID", "GID", "TCP", "UDP", "OS", "UI", "UX", "DX", "QA", "PR", "CI", "CD", "SQL", "RPC", "REST", "XML", "CSS", "JS", "TS", "SDK", "PAT", "DNS", "CDN", "IP", "LAN", "WAN", "VPN", "NAT", "IAM", "RBAC", "ACL", "CORS", "CSRF", "XSS", "DDOS", "SRE", "DEVOPS", "MLOPS", "AI", "ML", "DL", "NLP", "CV", "ASR", "TTS", "RAG", "ZIP", "TAR", "GZ", "BASH", "ZSH", "FISH", "VIM", "EMACS", "NANO", "GIT", "SVN", "GPL", "LGPL", "MIT", "BSD", "APACHE", "AGPL", "SSPL", "EUPL", "CC0", "CC", "BY", "SA", "NC", "ND", "GDPR", "CCPA", "HIPAA", "SOX", "PCI", "DSS", "ISO", "NIST", "SOC", "CISA", "CERT", "CSIRT", "CVE", "CVSS", "EPSS", "KEV", "SBOM", "SPDX", "CPE", "STIX", "TAXII", "YARA", "IDS", "IPS", "NDR", "XDR", "EDR", "MDR", "SIEM", "SOAR", "UEBA", "NTA", "NIDS", "HIDS", "NIPS", "HIPS", "WAF", "RASP", "IAST", "DAST", "SAST", "SCA", "CSPM", "CWPP", "CIEM", "CNAPP", "SASE", "ZTNA", "SDWAN", "CASB", "SWG", "DLP", "DRM", "PKI", "HSM", "KMS", "IaC", "SaaS", "PaaS", "IaaS", "FaaS", "BaaS", "DBaaS"}
        if val in skip:
            continue
        concepts[val] = True

    # 3. Config files
    for m in re.finditer(r'\b\w+\.(?:yaml|yml|json|sh|ps1|nix|toml|ini|conf|cfg)\b', text):
        concepts[m.group(0)] = True

    # 4. Backtick terms (clean, no newlines, reasonable length)
    for m in re.finditer(r'`([^`\n]+)`', text):
        term = m.group(1).strip()
        if 2 < len(term) < 35 and not term.startswith('http'):
            t = term.strip("'\"")
            if ' ' in t and len(t.split()) > 3:
                continue
            # Skip if it's just a sentence fragment
            if t.lower() in {"on this page", "quick install", "linux / macos / wsl2", "windows (native, powershell) — early beta", "early beta", "native windows support is early beta", "the installer handles everything", "how git is handled", "why not use winget?"}:
                continue
            concepts[t] = True

    # 5. Table headers / capitalized technical terms (single line, 1-2 words)
    for m in re.finditer(r'\b([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+){0,1})\b', text):
        term = m.group(1)
        if len(term) < 4:
            continue
        # Skip common words
        if term.lower() in {"this", "that", "with", "from", "they", "what", "when", "where", "which", "while", "during", "after", "before", "above", "below", "between", "through", "over", "under", "into", "onto", "upon", "within", "without", "against", "across", "around", "behind", "beyond", "despite", "except", "inside", "outside", "since", "until", "via", "per", "every", "some", "any", "all", "both", "either", "neither", "each", "few", "more", "most", "other", "such", "only", "own", "same", "than", "too", "very", "just", "also", "back", "still", "even", "once", "here", "there", "then", "now", "down", "out", "well", "far", "long", "last", "first", "next", "previous", "early", "late", "later", "soon", "today", "tomorrow", "yesterday", "page", "section", "guide", "setup", "install", "user", "using", "used", "uses", "work", "works", "working", "help", "helps", "need", "needs", "want", "wants", "make", "makes", "take", "takes", "come", "comes", "look", "looks", "find", "finds", "give", "gives", "tell", "tells", "ask", "asks", "try", "tries", "use", "run", "runs", "set", "sets", "get", "gets", "put", "puts", "see", "sees", "know", "knows", "think", "thinks", "say", "says", "go", "goes", "let", "lets", "may", "might", "must", "shall", "should", "will", "would", "could", "can", "did", "does", "done", "doing", "having", "been", "being", "were", "was", "are", "is", "am", "have", "has", "had", "not", "no", "nor", "but", "yet", "or", "and", "how", "why", "who", "whom", "whose", "there", "here", "then", "than", "thus", "hence", "ago", "off", "up", "so", "as", "if", "at", "by", "on", "in", "to", "of", "for", "it", "its", "his", "her", "him", "he", "she", "we", "us", "our", "you", "your", "my", "me", "i", "a", "an", "the", "these", "those", "them"}:
            continue
        concepts[term] = True

    return list(concepts.keys())[:max_concepts]


def describe_code_snippets(code_blocks, max_snippets=8):
    snippets = []
    for cb in code_blocks:
        if not cb or not cb.strip():
            continue
        first_line = cb.strip().splitlines()[0].strip()
        desc = None
        cb_lower = cb.lower()
        if 'curl' in cb_lower and 'install.sh' in cb_lower:
            desc = "One-line curl installer"
        elif 'irm' in cb_lower and 'install.ps1' in cb_lower:
            desc = "PowerShell installer"
        elif 'hermes update' in cb_lower:
            desc = "hermes update command"
        elif 'hermes setup' in cb_lower:
            desc = "hermes setup command"
        elif 'hermes model' in cb_lower:
            desc = "hermes model command"
        elif 'hermes skills install' in cb_lower:
            desc = "Skill installation command"
        elif 'hermes profile' in cb_lower:
            desc = "Profile management command"
        elif 'hermes config' in cb_lower:
            desc = "Config command"
        elif 'hermes chat' in cb_lower:
            desc = "Chat command"
        elif 'hermes gateway' in cb_lower:
            desc = "Gateway command"
        elif 'hermes tools' in cb_lower:
            desc = "Tools command"
        elif 'hermes fallback' in cb_lower:
            desc = "Fallback provider command"
        elif 'hermes backup' in cb_lower:
            desc = "Backup command"
        elif 'hermes restore' in cb_lower:
            desc = "Restore command"
        elif 'nix run' in cb_lower:
            desc = "Nix run command"
        elif 'python -m pip' in cb_lower:
            desc = "Python pip install"
        elif 'configuration.nix' in cb_lower:
            desc = "NixOS configuration"
        elif '.env' in cb_lower and '=' in cb:
            desc = "Environment variable setup"
        elif 'config.yaml' in cb_lower or ('mcp_servers' in cb_lower):
            desc = "YAML config example"
        elif 'toolsets' in cb_lower:
            desc = "Toolsets config"
        elif 'web_search' in cb_lower or 'web_extract' in cb_lower:
            desc = "Web search config"
        elif 'hermes skills uninstall' in cb_lower:
            desc = "Skill uninstall command"
        elif 'hermes skills reset' in cb_lower:
            desc = "Skill reset command"
        elif first_line.startswith('#'):
            desc = "Shell script comment"
        elif first_line.startswith('{'):
            desc = "JSON config example"
        elif first_line.startswith('---') or 'mcp_servers:' in cb:
            desc = "YAML configuration block"
        else:
            words = first_line.split()
            if words and len(words) <= 5:
                desc = f"Code: {' '.join(words)}"
            else:
                continue  # skip unidentifiable generic blocks
        if desc and desc not in snippets:
            snippets.append(desc)
        if len(snippets) >= max_snippets:
            break
    return snippets


def extract_related_pages(internal_links, self_url):
    related = []
    for link in internal_links:
        if "hermes-agent.nousresearch.com/docs" in link:
            rel = link.replace("https://hermes-agent.nousresearch.com", "")
            if rel != self_url.replace("https://hermes-agent.nousresearch.com", ""):
                related.append(rel)
    seen = set()
    out = []
    for r in related:
        if r not in seen:
            seen.add(r)
            out.append(r)
    return out[:10]


def infer_audience(url, text):
    path = url.replace("https://hermes-agent.nousresearch.com/docs", "")
    if path in {"", "/zh-Hans"}:
        return "beginner"
    if "getting-started" in path:
        return "beginner"
    if "user-stories" in path:
        return "beginner"
    if "integrations" in path:
        return "intermediate"
    if "skills" in path:
        return "intermediate"
    if "reference" in path:
        if any(x in path for x in ["cli-commands", "environment-variables", "faq", "mcp-config", "model-catalog", "profile-commands"]):
            return "intermediate"
        return "advanced"
    if "nix-setup" in path or "termux" in path:
        return "advanced"
    return "intermediate"


def infer_prerequisites(url, text):
    path = url.replace("https://hermes-agent.nousresearch.com/docs", "")
    if "nix-setup" in path:
        return "Nix with flakes enabled"
    if "termux" in path:
        return "Android with Termux installed"
    if "integrations/providers" in path:
        return "API key for at least one LLM provider"
    if "reference" in path:
        return "Installed Hermes CLI"
    if "skills" in path:
        return "Installed Hermes CLI"
    return ""


def generate_embedding_keywords(title, summary, key_concepts, category, is_zh):
    base = set()
    for kw in key_concepts:
        base.add(kw.lower())
        base.add(kw)
    for w in re.findall(r'[a-zA-Z]+', title):
        if len(w) > 2:
            base.add(w.lower())
    cat_synonyms = {
        "getting-started": ["getting started", "install", "setup", "quickstart", "beginner", "first time", "new user", "introduction"],
        "integrations": ["integration", "connect", "provider", "api", "third party", "external service", "plugin"],
        "reference": ["reference", "docs", "documentation", "command", "config", "setting", "option", "parameter"],
        "skills": ["skill", "plugin", "extension", "capability", "feature", "tool"],
        "user-guide": ["user guide", "use case", "example", "story", "how to", "tutorial"],
    }
    for syn in cat_synonyms.get(category, []):
        base.add(syn)
    base.add("hermes agent")
    base.add("hermes-agent")
    base.add("nous research")
    base.add("ai agent")
    base.add("cli")
    base.add("autonomous")
    extras = {
        "getting-started": ["hermes install", "how to install hermes", "hermes setup guide", "hermes beginner guide", "hermes first steps"],
        "integrations": ["hermes provider", "hermes api key", "hermes model setup", "hermes openrouter", "hermes mcp", "hermes web search"],
        "reference": ["hermes commands", "hermes env vars", "hermes config yaml", "hermes faq", "hermes troubleshooting", "hermes slash commands"],
        "skills": ["hermes skills install", "hermes built in skills", "hermes skill catalog", "hermes optional skills"],
        "user-guide": ["hermes examples", "hermes community", "hermes use cases"],
    }
    for ex in extras.get(category, []):
        base.add(ex)
    if is_zh:
        base.add("hermes 安装")
        base.add("hermes 配置")
        base.add("hermes 使用")
        base.add("hermes 教程")
        base.add("hermes 文档")
        base.add("hermes 命令")
        base.add("hermes 技能")
        base.add("hermes 快速入门")
        base.add("hermes 入门")
        base.add("hermes 新手")
    filtered = [b for b in base if len(str(b)) > 1]
    return " ".join(sorted(set(filtered)))[:500]


def translate_snippet(en, is_zh):
    if not is_zh:
        return en
    mapping = {
        "One-line curl installer": "一行命令 curl 安装脚本",
        "PowerShell installer": "PowerShell 安装脚本",
        "hermes update command": "hermes update 更新命令",
        "hermes setup command": "hermes setup 设置命令",
        "hermes model command": "hermes model 模型配置命令",
        "Skill installation command": "技能安装命令",
        "Profile management command": "配置文件管理命令",
        "Config command": "配置命令",
        "Chat command": "聊天命令",
        "Gateway command": "网关命令",
        "Tools command": "工具命令",
        "Fallback provider command": "备用提供方命令",
        "Backup command": "备份命令",
        "Restore command": "恢复命令",
        "Nix run command": "Nix run 命令",
        "Python pip install": "Python pip 安装",
        "NixOS configuration": "NixOS 配置",
        "Environment variable setup": "环境变量设置",
        "YAML config example": "YAML 配置示例",
        "MCP server config": "MCP 服务器配置",
        "Toolsets config": "工具集配置",
        "Web search config": "网页搜索配置",
        "Skill uninstall command": "技能卸载命令",
        "Skill reset command": "技能重置命令",
        "Shell script comment": "Shell 脚本注释",
        "JSON config example": "JSON 配置示例",
        "YAML configuration block": "YAML 配置块",
    }
    return mapping.get(en, en)


def translate_prerequisites(en, is_zh):
    if not is_zh:
        return en
    mapping = {
        "Nix with flakes enabled": "已启用 flakes 的 Nix 环境",
        "Android with Termux installed": "已安装 Termux 的 Android 设备",
        "API key for at least one LLM provider": "至少一个 LLM 提供方的 API 密钥",
        "Installed Hermes CLI": "已安装 Hermes CLI",
        "": "",
    }
    return mapping.get(en, en)


def main():
    pages = load_pages()
    results = []
    for p in pages:
        url = p["url"]
        is_zh = is_chinese_page(url)
        title = clean_title(p["title"])
        h1 = p.get("h1", title)
        text = p.get("text", "")
        code_blocks = p.get("code_blocks", [])
        internal_links = p.get("internal_links", [])
        category = infer_category(url)

        summary = extract_summary(text, h1, is_zh, url)
        key_concepts = extract_key_concepts(text, code_blocks)
        code_snippets = [translate_snippet(s, is_zh) for s in describe_code_snippets(code_blocks)]
        audience = infer_audience(url, text)
        prerequisites = translate_prerequisites(infer_prerequisites(url, text), is_zh)
        related_pages = extract_related_pages(internal_links, url)
        embedding_keywords = generate_embedding_keywords(title, summary, key_concepts, category, is_zh)

        record = {
            "url": url,
            "title": title,
            "category": category,
            "summary": summary,
            "key_concepts": key_concepts,
            "code_snippets": code_snippets,
            "audience": audience,
            "prerequisites": prerequisites,
            "related_pages": related_pages,
            "embedding_keywords": embedding_keywords,
        }
        results.append(record)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"Processed {len(pages)} unique pages -> {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
