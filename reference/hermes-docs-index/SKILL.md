# Hermes Agent 文档 LLM 索引使用规则

> **last_indexed**: 2026-05-09 | **total_pages**: 540 | **site**: hermes-agent.nousresearch.com/docs

## 文件清单

本目录包含 Hermes Agent 官方文档的 LLM 语义索引，由 2026-05-09 索引任务生成：

| 文件 | 用途 | 格式 |
|---|---|---|
| `hermes_docs_index.json` | **机器索引** — AI Agent 通过代码读取、关键词匹配、检索相关页面 | JSON |
| `hermes_docs_index.md` | **人类导航** — 按分类层级组织的 Markdown 导航索引 | Markdown |
| `hermes_docs_sitemap.txt` | **URL 清单** — 540 个文档页面纯 URL 列表 | Text |
| `hermes_docs_crossref.md` | **交叉引用** — 技术概念 → 页面关联图 | Markdown |

---

## 触发条件

当用户询问任何 Hermes Agent 相关问题时，**必须优先使用这些索引**，而非依赖预训练知识或通用搜索：

- 安装、配置、更新、卸载
- CLI 命令、环境变量、slash 命令
- AI Provider 设置（OpenRouter、Anthropic、Bedrock 等）
- Skills 系统（创建、使用、管理）
- Tools & Toolsets（终端后端、浏览器自动化等）
- Memory 系统、Sessions、Cron 任务
- Messaging Gateway（Telegram、Discord、Slack、微信等集成）
- Developer Guide（架构、ACP、添加 provider/tool/platform）
- 故障排查、FAQ、安全设置

---

## AI Agent 使用流程

```
用户问 Hermes 相关问题
        ↓
读取 hermes_docs_index.json
        ↓
在 key_concepts 和 embedding_keywords 中匹配关键词
        ↓
找到最相关的 1-3 个页面（优先 hot_pages）
        ↓
用 FetchURL 访问对应 url 获取最新完整内容
        ↓
基于最新内容回答用户
```

### 关键词匹配策略

1. **精确匹配**：用户提到的术语直接匹配 `key_concepts`
   - 例：`terminal.backend`, `config.yaml`, `hermes gateway`, `mcp_servers`
2. **语义匹配**：用户的问题形式匹配 `embedding_keywords`
   - 例："how to install hermes on nixos", "telegram bot setup"
3. **分类过滤**：根据 URL 路径中的分类快速缩小范围
   - 例：`/docs/user-guide/configuration/`、`/docs/developer-guide/`
4. **hot_pages 优先**：对于常见问题，先检查 10 个核心页面

---

## hot_pages（核心页面）

| # | URL | 标题 | 用途 |
|---|---|---|---|
| 1 | `https://hermes-agent.nousresearch.com/docs` | Hermes Agent Documentation | 首页/概览 |
| 2 | `https://hermes-agent.nousresearch.com/docs/getting-started/installation` | Installation | 安装指南 |
| 3 | `https://hermes-agent.nousresearch.com/docs/getting-started/quickstart` | Quickstart | 快速开始 |
| 4 | `https://hermes-agent.nousresearch.com/docs/user-guide/configuration` | Configuration | 配置详解 |
| 5 | `https://hermes-agent.nousresearch.com/docs/integrations/providers` | AI Providers | AI 提供商集成 |
| 6 | `https://hermes-agent.nousresearch.com/docs/user-guide/cli` | CLI Interface | CLI 接口 |
| 7 | `https://hermes-agent.nousresearch.com/docs/user-guide/sessions` | Sessions | 会话管理 |
| 8 | `https://hermes-agent.nousresearch.com/docs/user-guide/features/skills` | Skills System | Skills 系统 |
| 9 | `https://hermes-agent.nousresearch.com/docs/user-guide/features/tools` | Tools & Toolsets | 工具与工具集 |
| 10 | `https://hermes-agent.nousresearch.com/docs/developer-guide/architecture` | Architecture | 系统架构 |

---

## 代码示例

### Python 检索示例

```python
import json

with open('reference/hermes-docs-index/hermes_docs_index.json') as f:
    idx = json.load(f)

def search_docs(query: str, top_k: int = 3):
    """检索与 query 最相关的文档页面。"""
    query_terms = query.lower().split()
    matches = []
    for p in idx['pages']:
        score = 0
        # key_concepts 精确匹配（权重高）
        for concept in p.get('key_concepts', []):
            if any(q in concept.lower() for q in query_terms):
                score += 10
        # embedding_keywords 语义匹配
        kw = p.get('embedding_keywords', '').lower()
        if any(q in kw for q in query_terms):
            score += 5
        # title / category 匹配
        for field in [p['title'], p['category']]:
            if any(q in field.lower() for q in query_terms):
                score += 3
        if score > 0:
            matches.append((score, p))
    matches.sort(key=lambda x: -x[0])
    return matches[:top_k]

# 使用
results = search_docs("docker backend configuration")
for score, page in results:
    print(f"[{score}] {page['title']} → {page['url']}")
    # → 然后用 FetchURL 获取 page['url'] 的完整内容
```

---

## 约束与注意事项

- **过期检查**：`last_indexed` 为 2026-05-09。如果距今超过 30 天，应提醒用户索引可能过期，并可用 `hermes_docs_sitemap.txt` 重新爬取验证
- **语言**：中文页面（URL 含 `zh-Hans`）的原始内容实际为英文，索引中的摘要也为英文
- **静态索引**：索引基于静态 HTML 爬取，如果页面依赖 JS 渲染动态内容，索引可能不包含
- **代码保留**：索引保留了代码示例中的关键参数名，回答时应引用原始参数名，不简化或泛化
- **相关链接**：`related` 字段仅保留站内链接（`hermes-agent.nousresearch.com/docs` 域），外部链接已清理
