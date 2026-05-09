#!/usr/bin/env python3
"""Extract structured metadata from Hermes optional skills pages - v6 final."""

import json
import re


def clean_title(title):
    return title.replace(" | Hermes Agent", "").strip()


def extract_category(url):
    m = re.search(r"/skills/optional/([^/]+)", url)
    return f"user-guide/skills/optional/{m.group(1)}" if m else "user-guide/skills/optional"


def normalize_text(text):
    """Normalize whitespace: collapse multiple spaces, replace newlines with spaces."""
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def extract_summary(text, is_zh):
    """Extract the first meaningful paragraph(s) after 'On this page'."""
    if text.startswith("On this page"):
        text = text[len("On this page"):].lstrip("\n")
    elif text.startswith("本页总览"):
        text = text[len("本页总览"):].lstrip("\n")
    
    paras = [p.strip() for p in text.split("\n\n") if p.strip()]
    
    candidate_paras = []
    for para in paras[:15]:
        if "Skill metadata" in para or "技能元数据" in para:
            continue
        if "Path\n" in para and "Version\n" in para:
            continue
        if "Reference: full SKILL.md" in para or "参考：完整 SKILL.md" in para:
            continue
        if "complete skill definition" in para or "完整技能定义" in para:
            continue
        if "The following is the complete skill definition" in para or "以下是由 Hermes 加载的完整技能定义" in para:
            continue
        if "info\n" in para or "信息\n" in para:
            continue
        if len(para) < 15:
            continue
        if para.startswith("Source\n") or (para.startswith("Optional") and "install with" in para):
            continue
        candidate_paras.append(para)
    
    if not candidate_paras:
        return ""
    
    # Build summary
    summary = candidate_paras[0]
    for para in candidate_paras[1:]:
        if len(summary) >= 200:
            break
        if para.startswith("terminal(") or para.startswith("$") or para.startswith("#"):
            continue
        if re.match(r'^[-\u2022\d]', para):
            continue
        summary += " " + para
    
    # Deduplicate repeated title/content
    # If summary starts with title words repeated, trim
    summary = normalize_text(summary)
    
    # Truncate to 200-300 chars at sentence boundary
    if len(summary) > 300:
        truncated = summary[:300]
        for delim in ['. ', '。', '! ', '? ']:
            idx = truncated.rfind(delim)
            if idx > 200:
                summary = truncated[:idx + len(delim)].strip()
                break
        else:
            summary = truncated.strip()
    
    return summary


def extract_key_concepts(text):
    """Extract key section headers from the SKILL.md content."""
    skill_start = text.find("Reference: full SKILL.md")
    if skill_start < 0:
        skill_start = text.find("参考：完整 SKILL.md")
    skill_text = text[skill_start:] if skill_start > 0 else text
    
    key_concepts = []
    seen = set()
    
    headers1 = re.findall(r"\n([A-Z][A-Za-z0-9 \-/]{2,40})\n\u200b\n", skill_text)
    for h in headers1:
        h = h.strip()
        if h in seen or len(h) < 3:
            continue
        skip = {"Prerequisites", "Use cases", "Usage", "Installation", "Configuration",
                "Quick Start", "Examples", "Notes", "See Also", "Reference", "Tags",
                "Related skills", "Platforms", "Author", "License", "Source", "Path",
                "Version", "On this page", "Skill metadata", "info"}
        if h in skip:
            continue
        seen.add(h)
        key_concepts.append(h)
    
    # Extract important terms from the first description
    desc_match = re.search(r"(?:On this page|本页总览)\n\n(.+?)(?:\n\nSkill metadata|\n\n技能元数据|\n\n$)", text, re.DOTALL)
    if desc_match:
        desc = desc_match.group(1)
        terms = re.findall(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})\b", desc)
        for t in terms:
            t = t.strip()
            if t not in seen and len(t) < 40 and t not in {"The Following", "Hermes Agent", "Blackbox Ai", "Blackbox Cli"}:
                seen.add(t)
                key_concepts.append(t)
                if len(key_concepts) >= 10:
                    return key_concepts[:10]
    
    # Extract tags from metadata
    tags_match = re.search(r"Tags\s*\n\s*(.*?)(?:\n\n|\n\s*Related skills|\n\s*参考)", text, re.DOTALL)
    if tags_match:
        tags_text = tags_match.group(1)
        tags = [t.strip() for t in re.split(r"[,\n]", tags_text) if t.strip()]
        for t in tags:
            if t not in seen:
                seen.add(t)
                key_concepts.append(t)
                if len(key_concepts) >= 10:
                    return key_concepts[:10]
    
    return key_concepts[:10]


def extract_code_snippets(code_blocks):
    """Extract meaningful code snippets."""
    snippets = []
    for code in code_blocks[:5]:
        code = code.strip()
        if not code:
            continue
        lines = code.split("\n")
        
        prefix = ""
        if code.startswith("pip install"):
            prefix = "Install: "
        elif code.startswith("hermes "):
            prefix = "Hermes CLI: "
        elif code.startswith("npm ") or code.startswith("npx "):
            prefix = "Node: "
        elif code.startswith("docker "):
            prefix = "Docker: "
        elif code.startswith("python") or code.startswith("import "):
            prefix = "Python: "
        elif code.startswith("git "):
            prefix = "Git: "
        elif "terminal(" in code:
            prefix = "Terminal: "
        elif code.startswith("curl ") or code.startswith("wget "):
            prefix = "Shell: "
        elif code.startswith("conda "):
            prefix = "Conda: "
        elif "ssh " in lines[0]:
            prefix = "SSH: "
        
        if len(lines) == 1:
            snippet = prefix + lines[0][:180]
        else:
            snippet = prefix + "\n".join(lines[:2])[:250]
        
        snippets.append(snippet)
        if len(snippets) >= 5:
            break
    
    return snippets


def determine_audience(text, is_zh):
    """Determine target audience."""
    text_lower = text.lower()
    
    advanced_terms = [
        "distributed", "gpu", "training", "fine-tuning", "inference",
        "deployment", "kubernetes", "docker", "api", "library",
        "framework", "pytorch", "transformer", "model", "embedding",
        "vector", "cluster", "pipeline", "scheduler", "orchestration",
        "rl", "reinforcement learning", "megatron", "fsdp", "deepSpeed",
        "分布式", "训练", "微调", "推理", "部署", "库", "框架",
        "模型", "嵌入", "向量", "集群", "强化学习"
    ]
    
    beginner_terms = [
        "getting started", "introduction", "beginner", "tutorial",
        "入门", "新手", "简介", "教程", "simplest"
    ]
    
    adv_count = sum(1 for t in advanced_terms if t in text_lower)
    beg_count = sum(1 for t in beginner_terms if t in text_lower)
    
    if beg_count > adv_count:
        return "初学者" if is_zh else "Beginner"
    elif adv_count > 2:
        return "进阶用户" if is_zh else "Advanced user"
    else:
        return "开发者" if is_zh else "Developer"


def extract_prerequisites(text, is_zh):
    """Extract prerequisites from the Prerequisites section."""
    prereq = ""
    
    all_markers = ["Prerequisites", "Requirements", "前置要求", "前置条件", "先决条件"]
    
    for marker in all_markers:
        pattern = re.compile(re.escape(marker) + r"\n\u200b\n\n(.*?)(?:\n[A-Z][a-z].*?\n\u200b\n|\Z)", re.DOTALL)
        match = pattern.search(text)
        if match:
            prereq = match.group(1).strip()
            break
        
        pattern2 = re.compile(re.escape(marker) + r"\n:\s*(.*?)(?:\n\n[A-Z][a-z]|\n[A-Z][a-z].*?\n\u200b\n|\Z)", re.DOTALL)
        match2 = pattern2.search(text)
        if match2:
            prereq = match2.group(1).strip()
            break
        
        pattern3 = re.compile(re.escape(marker) + r"\n\s*\n(.*?)(?:\n[A-Z][a-z].*?\n\u200b\n|\n\n[A-Z][a-z]|\Z)", re.DOTALL)
        match3 = pattern3.search(text)
        if match3:
            prereq = match3.group(1).strip()
            break
    
    if prereq:
        prereq = re.sub(r"\n\s*[-\u2022]\s*", "; ", prereq)
        prereq = re.sub(r"\s+", " ", prereq)
        prereq = prereq.strip()
        if len(prereq) > 300:
            prereq = prereq[:300]
    
    return prereq


def extract_related_pages(text):
    """Extract internal /docs/ links."""
    links = re.findall(r'(/docs/[^\s\)\]\">\'`,]+)', text)
    seen = set()
    clean_links = []
    for link in links:
        link = link.rstrip(".,;")
        if link not in seen:
            seen.add(link)
            clean_links.append(link)
    return clean_links[:10]


def generate_keywords(title, h1, category, text, key_concepts):
    """Generate embedding keywords."""
    parts = []
    
    title_clean = re.sub(r"[—–\-]", " ", title.lower())
    parts.extend([w for w in title_clean.split() if len(w) > 1])
    
    if h1:
        parts.extend(h1.lower().split())
    
    cat_words = category.replace("user-guide/skills/optional/", "").replace("-", " ").split()
    parts.extend(cat_words)
    
    tags_match = re.search(r"Tags\s*\n\s*(.*?)(?:\n\n|\n\s*Related skills|\n\s*参考)", text, re.DOTALL)
    if tags_match:
        tags_text = tags_match.group(1)
        tags = [t.strip().lower() for t in re.split(r"[,\n]", tags_text) if t.strip()]
        parts.extend(tags)
    
    parts.extend([k.lower() for k in key_concepts])
    
    # Add platform info if available
    platforms_match = re.search(r"Platforms\s*\n\s*(.*?)(?:\n\n|\n\s*Tags|\n\s*Related skills)", text, re.DOTALL)
    if platforms_match:
        platforms = [p.strip() for p in platforms_match.group(1).split(",") if p.strip()]
        parts.extend([p.lower() for p in platforms])
    
    # Add related skills
    related_match = re.search(r"Related skills\s*\n\s*(.*?)(?:\n\n|\n\s*Reference:)", text, re.DOTALL)
    if related_match:
        related = [r.strip().lower() for r in related_match.group(1).split(",") if r.strip()]
        parts.extend(related)
    
    seen = set()
    unique = []
    for p in parts:
        p = p.strip(".,;()\"'")
        if p and p not in seen and len(p) > 1:
            seen.add(p)
            unique.append(p)
    
    # If still short, add category-related terms
    if len(unique) < 20:
        cat = category.replace("user-guide/skills/optional/", "")
        extra = {
            "autonomous-ai-agents": ["ai agent", "coding", "cli", "automation"],
            "blockchain": ["blockchain", "crypto", "wallet", "ethereum", "solana"],
            "communication": ["communication", "decision", "framework"],
            "creative": ["creative", "design", "video", "image", "3d", "animation"],
            "devops": ["devops", "docker", "infrastructure", "deployment"],
            "dogfood": ["testing", "ux", "qa", "dogfood"],
            "email": ["email", "inbox", "smtp", "mail"],
            "finance": ["finance", "excel", "valuation", "modeling", "investment"],
            "health": ["health", "fitness", "nutrition", "workout", "bci"],
            "mcp": ["mcp", "model context protocol", "server", "tools"],
            "migration": ["migration", "import", "openclaw"],
            "mlops": ["mlops", "machine learning", "deep learning", "pytorch", "huggingface", "gpu"],
            "productivity": ["productivity", "automation", "workflow", "crm"],
            "research": ["research", "search", "scraping", "data"],
            "security": ["security", "osint", "forensics", "pentest"],
            "web-development": ["web", "frontend", "html", "css", "browser"],
        }
        if cat in extra:
            for term in extra[cat]:
                if term not in seen:
                    seen.add(term)
                    unique.append(term)
    
    return " ".join(unique[:30])


def extract_page(page):
    url = page["url"]
    title = clean_title(page["title"])
    h1 = page.get("h1", "")
    text = page.get("text", "")
    code_blocks = page.get("code_blocks", [])
    is_zh = "zh-Hans" in url
    
    category = extract_category(url)
    summary = extract_summary(text, is_zh)
    key_concepts = extract_key_concepts(text)
    code_snippets = extract_code_snippets(code_blocks)
    audience = determine_audience(text, is_zh)
    prerequisites = extract_prerequisites(text, is_zh)
    related_pages = extract_related_pages(text)
    embedding_keywords = generate_keywords(title, h1, category, text, key_concepts)
    
    return {
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


def main():
    all_results = []
    
    for batch_num in range(1, 13):
        batch_path = f"/data/hermes/.tmp_index_work/batches_E/batch_{batch_num:02d}.json"
        with open(batch_path) as f:
            pages = json.load(f)
        
        for page in pages:
            result = extract_page(page)
            all_results.append(result)
        
        print(f"Processed batch {batch_num}: {len(pages)} pages")
    
    output_path = "/data/hermes/.tmp_index_work/extracted_E_ug_skills_optional.json"
    with open(output_path, "w") as f:
        json.dump(all_results, f, ensure_ascii=False, indent=2)
    
    print(f"\nTotal pages processed: {len(all_results)}")
    print(f"Output written to: {output_path}")


if __name__ == "__main__":
    main()
